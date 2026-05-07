-- P0-1 B-B: Server-side login rate-limiting via SECURITY DEFINER RPC.
--
-- Threat model: the existing client-side PIN lockout (localStorage
-- `login_attempts`) is trivially bypassed in DevTools — an attacker clears
-- storage and the counter resets. A server-side sliding-window counter is
-- the authoritative enforcement point: it cannot be cleared by the client,
-- persists across devices/browsers, and is evaluated before credentials
-- are verified.
--
-- Design:
--   • 5 consecutive failures within 15 minutes triggers a lockout.
--   • Window is computed fresh on every call — no "lock_until" column.
--     This means the lock is self-healing: once the oldest failure ages
--     out of the 15-minute window the counter drops below 5 automatically.
--   • All writes go through the SECURITY DEFINER RPC; the table itself
--     has no INSERT/UPDATE/DELETE RLS policies, so direct anon writes are
--     rejected by RLS while the SECURITY DEFINER path bypasses RLS as the
--     table owner.
--   • Callable by BOTH anon (pre-login check) and authenticated (post-login
--     success ping to record succeeded=true).
--
-- Helper dependency verified against 20260429140000_rls_helpers.sql:
--   public.is_tms_staff()  RETURNS BOOLEAN

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Table
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.auth_login_attempts (
    id            BIGSERIAL    PRIMARY KEY,
    email         TEXT         NOT NULL,
    ip            TEXT,                       -- best-effort; from x-forwarded-for
    attempted_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    succeeded     BOOLEAN      NOT NULL,
    user_agent    TEXT
);

-- Lower-case email in the index so WHERE lower(email) = lower(?) is a
-- true index scan rather than a sequential scan. At 5 req/s across many
-- users this table can accumulate millions of rows quickly; the index
-- keeps the 15-minute window lookup O(log n) on (email, time).
CREATE INDEX IF NOT EXISTS auth_login_attempts_email_attempted_idx
    ON public.auth_login_attempts (lower(email), attempted_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. RLS
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.auth_login_attempts ENABLE ROW LEVEL SECURITY;

-- Staff-only SELECT for audit purposes (e.g. investigating brute-force).
-- No INSERT/UPDATE/DELETE policies: all writes are funnelled through the
-- SECURITY DEFINER RPC below, which runs as the table owner and bypasses RLS.
CREATE POLICY auth_login_attempts_staff_select
    ON public.auth_login_attempts
    FOR SELECT
    TO authenticated
    USING (public.is_tms_staff());

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. RPC
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.record_login_attempt(
    p_email       TEXT,
    p_succeeded   BOOLEAN,
    p_user_agent  TEXT DEFAULT NULL
) RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public, pg_temp
AS $func$
DECLARE
    v_ip              TEXT;
    v_recent_failures BIGINT  := 0;
    v_locked          BOOLEAN := FALSE;
    v_retry           INT     := 0;
    v_oldest_failure  TIMESTAMPTZ;
BEGIN
    -- ── Input validation ─────────────────────────────────────────────────────
    IF p_email IS NULL OR length(trim(p_email)) = 0 THEN
        RETURN jsonb_build_object('locked', FALSE, 'error', 'Email required');
    END IF;

    -- ── Extract IP (best-effort) ──────────────────────────────────────────────
    -- Supabase forwards the client IP in x-forwarded-for. The header may
    -- contain a comma-separated list (proxies prepend); we take only the first
    -- value. current_setting returns NULL when the GUC is absent (true = no error).
    BEGIN
        v_ip := trim(
            split_part(
                (current_setting('request.headers', true)::jsonb ->> 'x-forwarded-for'),
                ',',
                1
            )
        );
        -- Coerce empty string to NULL for clean storage.
        IF v_ip = '' THEN v_ip := NULL; END IF;
    EXCEPTION WHEN OTHERS THEN
        v_ip := NULL;  -- header absent or not valid JSON — not a blocking error
    END;

    -- ── Count failures in the sliding window BEFORE inserting ─────────────────
    -- We count first so the threshold check reflects history, not the current
    -- attempt. This means a user on their 5th attempt sees locked=false (they
    -- are at 4 prior failures) but after inserting they will be locked on the
    -- next call. Alternatively counting after insert would lock on the 5th
    -- attempt itself — both are reasonable; pre-insert count was chosen to
    -- match the stated spec ("5 failures → lockout", i.e. the 6th call is
    -- blocked, not the 5th).
    SELECT COUNT(*) INTO v_recent_failures
    FROM public.auth_login_attempts
    WHERE lower(email) = lower(p_email)
      AND attempted_at >= NOW() - INTERVAL '15 minutes'
      AND NOT succeeded;

    v_locked := v_recent_failures >= 5;

    -- ── Insert the new attempt (always — we keep history even when locked) ────
    INSERT INTO public.auth_login_attempts (email, ip, attempted_at, succeeded, user_agent)
    VALUES (lower(trim(p_email)), v_ip, NOW(), p_succeeded, p_user_agent);

    -- ── Compute retry_after_seconds when locked ───────────────────────────────
    IF v_locked THEN
        SELECT MIN(attempted_at) INTO v_oldest_failure
        FROM public.auth_login_attempts
        WHERE lower(email) = lower(p_email)
          AND attempted_at >= NOW() - INTERVAL '15 minutes'
          AND NOT succeeded;

        v_retry := GREATEST(
            0,
            EXTRACT(EPOCH FROM (v_oldest_failure + INTERVAL '15 minutes' - NOW()))::INT
        );
    END IF;

    RETURN jsonb_build_object(
        'locked',              v_locked,
        'failures_in_window',  v_recent_failures,
        'retry_after_seconds', v_retry
    );

EXCEPTION WHEN OTHERS THEN
    -- Never block a login attempt due to a bug in the rate-limiter itself.
    -- Return a safe non-locked response with the error for logging.
    RETURN jsonb_build_object(
        'locked', FALSE,
        'error',  SQLERRM
    );
END;
$func$;

COMMENT ON FUNCTION public.record_login_attempt(TEXT, BOOLEAN, TEXT) IS
$$Records a login attempt and returns the current rate-limit state.

Return shape:
  { locked: bool,              -- true when >= 5 failures in last 15 minutes
    failures_in_window: int,   -- count of failures before this attempt
    retry_after_seconds: int } -- seconds until oldest failure ages out (0 when not locked)

On unexpected error:
  { locked: false, error: text }  -- non-blocking; error surfaced for logging only
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Grants
-- ─────────────────────────────────────────────────────────────────────────────

-- Revoke blanket public execute first, then grant explicitly.
REVOKE ALL ON FUNCTION public.record_login_attempt(TEXT, BOOLEAN, TEXT) FROM PUBLIC;

-- anon: pre-login check (called before credentials are verified).
-- authenticated: post-login success ping (record succeeded=true).
GRANT EXECUTE ON FUNCTION public.record_login_attempt(TEXT, BOOLEAN, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.record_login_attempt(TEXT, BOOLEAN, TEXT) TO authenticated;
