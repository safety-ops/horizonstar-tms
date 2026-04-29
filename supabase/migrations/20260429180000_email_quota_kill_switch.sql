-- P0 Workstream C: Edge function hardening — quota, kill-switch, audit log.
--
-- Adds three things:
--   A. email_send_log    — append-only audit table (one row per send attempt).
--   B. app_config        — singleton key/value table; seed kill-switch flag.
--   C. email_quota_check_and_log() — atomic preflight RPC (kill-switch +
--                          idempotency replay + 1h rate limit + insert pending).
--   D. email_quota_finalize()      — companion RPC to mark pending → sent/rejected.
--
-- All RPCs are SECURITY DEFINER with `SET search_path = public, pg_temp` to
-- prevent search_path injection. Service-role keys bypass RLS by default;
-- the edge function calls these RPCs with the SERVICE_ROLE_KEY and passes
-- the caller's auth.uid() explicitly so we still log per-user.

-- =========================================================================
-- A. email_send_log — append-only audit table
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.email_send_log (
  id                     BIGSERIAL PRIMARY KEY,
  ts                     TIMESTAMPTZ NOT NULL DEFAULT now(),
  auth_uid               UUID,
  user_id                INTEGER REFERENCES public.users(id)   ON DELETE SET NULL,
  driver_id              INTEGER REFERENCES public.drivers(id) ON DELETE SET NULL,
  ip                     TEXT,
  origin                 TEXT,
  email_kind             TEXT,
  recipient_count        INTEGER,
  attachment_count       INTEGER,
  attachment_total_bytes BIGINT,
  status                 TEXT NOT NULL,           -- 'pending' | 'sent' | 'rejected_<reason>'
  reject_reason          TEXT,
  resend_id              TEXT,
  idempotency_key        TEXT,
  duration_ms            INTEGER
);

-- Fast quota lookups: "rows for this auth_uid in the last hour, newest first".
CREATE INDEX IF NOT EXISTS idx_email_send_log_auth_uid_ts
  ON public.email_send_log (auth_uid, ts DESC);

-- Idempotency replay lookup. Partial unique — NULLs allowed for callers that
-- don't supply a key, but any non-null key must be unique PER AUTH_UID
-- (cross-tenant scoping prevents two different users from colliding on the
-- same client-generated key, which could otherwise leak a `replay` decision
-- and the prior tenant's resend_id back to the second caller).
CREATE UNIQUE INDEX IF NOT EXISTS uniq_email_send_log_auth_uid_idempotency_key
  ON public.email_send_log (auth_uid, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- Cleanup-pass support: allows the rate-limit RPC to efficiently sweep stale
-- 'pending' rows older than 15 minutes (orphaned by edge-function crashes
-- before finalize() could run). Also accelerates the rate-limit count which
-- filters by status IN ('sent', 'pending') AND ts > now() - 60min.
CREATE INDEX IF NOT EXISTS idx_email_send_log_status_ts
  ON public.email_send_log (status, ts);

ALTER TABLE public.email_send_log ENABLE ROW LEVEL SECURITY;

-- ADMIN can read; nobody else. Service role bypasses RLS automatically, so
-- the edge function (which uses the service-role key) is unaffected.
DROP POLICY IF EXISTS email_send_log_admin_select ON public.email_send_log;
CREATE POLICY email_send_log_admin_select ON public.email_send_log
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role = 'ADMIN'
    )
  );

-- No INSERT/UPDATE/DELETE policies → only service role can mutate.
-- The table is append-only by convention; finalize() does targeted UPDATEs
-- via SECURITY DEFINER RPC.

-- =========================================================================
-- B. app_config — singleton key/value table
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.app_config (
  key        TEXT PRIMARY KEY,
  value      JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed the kill switch (idempotent).
INSERT INTO public.app_config (key, value)
VALUES ('email_kill_switch', 'false'::jsonb)
ON CONFLICT (key) DO NOTHING;

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_config_admin_select ON public.app_config;
CREATE POLICY app_config_admin_select ON public.app_config
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role = 'ADMIN'
    )
  );

DROP POLICY IF EXISTS app_config_admin_update ON public.app_config;
CREATE POLICY app_config_admin_update ON public.app_config
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role = 'ADMIN'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role = 'ADMIN'
    )
  );

-- =========================================================================
-- C. email_quota_check_and_log() — atomic preflight
-- =========================================================================
-- Returns one row with:
--   decision        TEXT  — 'proceed' | 'replay' | 'rate_limited' |
--                           'rate_limited_ip' | 'rate_limited_global' |
--                           'blocked_kill_switch'
--   log_id          BIGINT — id of the newly inserted pending row when 'proceed'
--   prior_resend_id TEXT   — resend_id of the prior successful send when 'replay'
--
-- Decision precedence: kill_switch > replay > rate_limit (per-uid) >
--                      rate_limit_ip > rate_limit_global > proceed.
-- VOLATILE because it INSERTs.
CREATE OR REPLACE FUNCTION public.email_quota_check_and_log(
  p_auth_uid               UUID,
  p_user_id                INTEGER,
  p_driver_id              INTEGER,
  p_ip                     TEXT,
  p_origin                 TEXT,
  p_kind                   TEXT,
  p_recipient_count        INTEGER,
  p_attachment_count       INTEGER,
  p_attachment_total_bytes BIGINT,
  p_idempotency_key        TEXT,
  p_limit                  INTEGER DEFAULT 20,
  p_ip_limit               INTEGER DEFAULT 100,
  p_global_limit           INTEGER DEFAULT 1000
)
RETURNS TABLE (decision TEXT, log_id BIGINT, prior_resend_id TEXT)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_kill_switch     BOOLEAN;
  v_prior_status    TEXT;
  v_prior_id        TEXT;
  v_recent_count    INTEGER;
  v_recent_ip_count INTEGER;
  v_recent_global   INTEGER;
  v_new_id          BIGINT;
BEGIN
  -- 0. auth_uid is required. The edge function always passes caller.id; if a
  --    future internal caller needs to bypass, they can pass a synthetic UUID
  --    and we can branch on it here. We do NOT silently drop rate-limiting
  --    for NULL — that was the previous foot-gun.
  IF p_auth_uid IS NULL THEN
    RAISE EXCEPTION 'auth_uid required';
  END IF;

  -- 0b. Cleanup pass: any 'pending' rows older than 15 minutes are orphans
  --     (edge function crashed before finalize). Mark them stale so they
  --     don't permanently inflate rate-limit counts. Cheap with the
  --     (status, ts) index.
  UPDATE public.email_send_log
     SET status = 'rejected_stale_pending'
   WHERE status = 'pending'
     AND ts < now() - INTERVAL '15 minutes';

  -- 1. Kill switch (highest priority).
  --    Storage shape: app_config.value is JSONB. Seeded via 'false'::jsonb,
  --    which is the JSONB scalar boolean false (NOT the string "false"). The
  --    safe cast is value #>> '{}' (extracts as text) → ::boolean. A direct
  --    (value)::boolean works for jsonb-bool but is brittle if an admin ever
  --    writes the string "false" via the dashboard. Use the text-extract form.
  SELECT COALESCE((value #>> '{}')::boolean, false)
    INTO v_kill_switch
  FROM public.app_config
  WHERE key = 'email_kill_switch';

  IF COALESCE(v_kill_switch, false) THEN
    RETURN QUERY SELECT 'blocked_kill_switch'::TEXT, NULL::BIGINT, NULL::TEXT;
    RETURN;
  END IF;

  -- 2. Idempotency replay — same (auth_uid, key) in last 24h.
  --    Scoped by auth_uid to prevent cross-tenant collision: two different
  --    users generating the same key cannot leak each other's resend_id.
  --    If the prior row is 'pending' (race: same user retried while first
  --    request still in flight), surface as rate_limited so the client backs
  --    off rather than getting a misleading replay with NULL resend_id.
  IF p_idempotency_key IS NOT NULL THEN
    SELECT status, resend_id
      INTO v_prior_status, v_prior_id
    FROM public.email_send_log
    WHERE auth_uid = p_auth_uid
      AND idempotency_key = p_idempotency_key
      AND ts > now() - INTERVAL '24 hours'
    ORDER BY ts DESC
    LIMIT 1;

    IF v_prior_status = 'sent' THEN
      RETURN QUERY SELECT 'replay'::TEXT, NULL::BIGINT, v_prior_id;
      RETURN;
    ELSIF v_prior_status = 'pending' THEN
      -- In-flight duplicate; tell client to back off.
      RETURN QUERY SELECT 'rate_limited'::TEXT, NULL::BIGINT, NULL::TEXT;
      RETURN;
    END IF;
  END IF;

  -- 3. Per-auth_uid rate limit — count BOTH sent and pending in last 60min.
  --    Counting only 'sent' previously meant a burst of 100 concurrent
  --    requests would all see count=0 and bypass the limit until any of
  --    them flipped to terminal status.
  SELECT COUNT(*)::INTEGER
    INTO v_recent_count
  FROM public.email_send_log
  WHERE auth_uid = p_auth_uid
    AND status IN ('sent', 'pending')
    AND ts > now() - INTERVAL '60 minutes';

  IF v_recent_count >= COALESCE(p_limit, 20) THEN
    RETURN QUERY SELECT 'rate_limited'::TEXT, NULL::BIGINT, NULL::TEXT;
    RETURN;
  END IF;

  -- 3b. Per-IP rate limit. Default 100/hour. NULL or 'unknown' IPs still
  --     count toward this bucket; if attackers spoof to bypass per-uid they
  --     fall through to the global limit below.
  IF p_ip IS NOT NULL AND p_ip <> '' THEN
    SELECT COUNT(*)::INTEGER
      INTO v_recent_ip_count
    FROM public.email_send_log
    WHERE ip = p_ip
      AND status IN ('sent', 'pending')
      AND ts > now() - INTERVAL '60 minutes';

    IF v_recent_ip_count >= COALESCE(p_ip_limit, 100) THEN
      RETURN QUERY SELECT 'rate_limited_ip'::TEXT, NULL::BIGINT, NULL::TEXT;
      RETURN;
    END IF;
  END IF;

  -- 3c. Global rate limit. Default 1000/hour. Last-resort backstop against
  --     coordinated abuse from many auth_uids/IPs.
  SELECT COUNT(*)::INTEGER
    INTO v_recent_global
  FROM public.email_send_log
  WHERE status IN ('sent', 'pending')
    AND ts > now() - INTERVAL '60 minutes';

  IF v_recent_global >= COALESCE(p_global_limit, 1000) THEN
    RETURN QUERY SELECT 'rate_limited_global'::TEXT, NULL::BIGINT, NULL::TEXT;
    RETURN;
  END IF;

  -- 4. Proceed — insert pending row. ON CONFLICT handles the race where two
  --    concurrent requests share the same (auth_uid, idempotency_key): the
  --    second insert is a no-op, then we re-SELECT to learn the prior row's
  --    status and return the appropriate decision instead of raising.
  INSERT INTO public.email_send_log (
    auth_uid, user_id, driver_id, ip, origin, email_kind,
    recipient_count, attachment_count, attachment_total_bytes,
    status, idempotency_key
  ) VALUES (
    p_auth_uid, p_user_id, p_driver_id, p_ip, p_origin, p_kind,
    p_recipient_count, p_attachment_count, p_attachment_total_bytes,
    'pending', p_idempotency_key
  )
  ON CONFLICT (auth_uid, idempotency_key)
    WHERE idempotency_key IS NOT NULL
    DO NOTHING
  RETURNING id INTO v_new_id;

  IF v_new_id IS NULL THEN
    -- Conflict path: another concurrent insert won the race for this
    -- idempotency key. Re-read and translate.
    SELECT status, resend_id
      INTO v_prior_status, v_prior_id
    FROM public.email_send_log
    WHERE auth_uid = p_auth_uid
      AND idempotency_key = p_idempotency_key
    ORDER BY ts DESC
    LIMIT 1;

    IF v_prior_status = 'sent' THEN
      RETURN QUERY SELECT 'replay'::TEXT, NULL::BIGINT, v_prior_id;
      RETURN;
    ELSE
      -- 'pending' or any rejected_* — back off.
      RETURN QUERY SELECT 'rate_limited'::TEXT, NULL::BIGINT, NULL::TEXT;
      RETURN;
    END IF;
  END IF;

  RETURN QUERY SELECT 'proceed'::TEXT, v_new_id, NULL::TEXT;
END;
$$;

-- Lock down execution: only the service role (used by the edge function) may
-- call this RPC. Granting to `authenticated` would let any logged-in user
-- corrupt the audit log or bypass quota by calling it directly via PostgREST.
REVOKE EXECUTE ON FUNCTION public.email_quota_check_and_log(
  UUID, INTEGER, INTEGER, TEXT, TEXT, TEXT, INTEGER, INTEGER, BIGINT, TEXT, INTEGER, INTEGER, INTEGER
) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.email_quota_check_and_log(
  UUID, INTEGER, INTEGER, TEXT, TEXT, TEXT, INTEGER, INTEGER, BIGINT, TEXT, INTEGER, INTEGER, INTEGER
) FROM authenticated;
GRANT  EXECUTE ON FUNCTION public.email_quota_check_and_log(
  UUID, INTEGER, INTEGER, TEXT, TEXT, TEXT, INTEGER, INTEGER, BIGINT, TEXT, INTEGER, INTEGER, INTEGER
) TO service_role;

-- =========================================================================
-- D. email_quota_finalize() — mark pending row as sent or rejected
-- =========================================================================
-- Targeted UPDATE on a single log row by id. No-op if status is already
-- terminal (defensive: prevents double-finalize from inflating duration_ms).
CREATE OR REPLACE FUNCTION public.email_quota_finalize(
  p_log_id        BIGINT,
  p_status        TEXT,            -- 'sent' or 'rejected_<reason>'
  p_reject_reason TEXT,
  p_resend_id     TEXT,
  p_duration_ms   INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_log_id IS NULL THEN
    RETURN;
  END IF;

  UPDATE public.email_send_log
     SET status        = COALESCE(p_status, 'rejected_unknown'),
         reject_reason = p_reject_reason,
         resend_id     = p_resend_id,
         duration_ms   = p_duration_ms
   WHERE id = p_log_id
     AND status = 'pending';
END;
$$;

-- Lock down execution: service role only (same rationale as the preflight
-- RPC above — authenticated users must not be able to mutate audit rows).
REVOKE EXECUTE ON FUNCTION public.email_quota_finalize(BIGINT, TEXT, TEXT, TEXT, INTEGER) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.email_quota_finalize(BIGINT, TEXT, TEXT, TEXT, INTEGER) FROM authenticated;
GRANT  EXECUTE ON FUNCTION public.email_quota_finalize(BIGINT, TEXT, TEXT, TEXT, INTEGER) TO service_role;
