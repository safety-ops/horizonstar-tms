-- ============================================================
-- Migration: 20260507203100_log_activity_details_size_cap.sql
-- Purpose:   Cap p_details JSONB payload size at 10 KB in log_activity().
--
-- Threat model:
--   log_activity() (added in 20260507202900) accepts an unbounded JSONB
--   payload. An authenticated attacker could submit a 100 MB blob — once,
--   or many times — to exhaust activity_log storage. This cap MUST land
--   before the public INSERT policy on activity_log is dropped, otherwise
--   the RPC becomes the new flood vector identified by C1's security
--   review.
--
-- Behaviour:
--   - p_details NULL or empty → unchanged (no size to check).
--   - octet_length(p_details::text) <= 10240 → unchanged.
--   - octet_length(p_details::text) >  10240 → RAISE EXCEPTION SQLSTATE 22001.
--
-- Rollback:  supabase/rollbacks/20260507203100_log_activity_details_size_cap.down.sql
--   (Restores the prior CREATE OR REPLACE without the cap.)
-- ============================================================

CREATE OR REPLACE FUNCTION public.log_activity(
    p_action  TEXT,
    p_details JSONB DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid        UUID;
    v_user_id    BIGINT;
    v_user_email TEXT;
    v_user_name  TEXT;
    v_ip         TEXT;
    v_new_id     BIGINT;
BEGIN
    -- ── 1. Validate action ──────────────────────────────────────
    IF p_action IS NULL OR trim(p_action) = '' THEN
        RAISE EXCEPTION 'Action required'
            USING ERRCODE = '22023';
    END IF;

    IF char_length(p_action) > 50 THEN
        RAISE EXCEPTION 'Action value too long (max 50 chars): %', p_action
            USING ERRCODE = '22001';
    END IF;

    -- ── 1b. Cap details size (NEW — 10 KB ceiling) ──────────────
    IF p_details IS NOT NULL AND octet_length(p_details::text) > 10240 THEN
        RAISE EXCEPTION 'Details payload too large (max 10240 bytes)'
            USING ERRCODE = '22001';
    END IF;

    -- ── 2. Auth gate ────────────────────────────────────────────
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated audit attempt'
            USING ERRCODE = '42501';
    END IF;

    -- ── 3. Resolve identity from public.users ───────────────────
    SELECT
        u.id::BIGINT,
        u.email::TEXT,
        NULLIF(trim(coalesce(u.first_name, '') || ' ' || coalesce(u.last_name, '')), '')
    INTO
        v_user_id,
        v_user_email,
        v_user_name
    FROM public.users u
    WHERE u.auth_id = v_uid
    LIMIT 1;

    -- ── 4. Dealer / no-users-row fallback ───────────────────────
    IF v_user_id IS NULL THEN
        SELECT au.email::TEXT
        INTO   v_user_email
        FROM   auth.users au
        WHERE  au.id = v_uid
        LIMIT  1;

        IF v_user_email IS NULL THEN
            v_user_email := 'auth:' || v_uid::TEXT;
        END IF;

        v_user_name := NULL;
    END IF;

    -- ── 5. Capture request IP ───────────────────────────────────
    BEGIN
        v_ip := trim(
            split_part(
                (current_setting('request.headers', true)::jsonb ->> 'x-forwarded-for'),
                ',',
                1
            )
        );
    EXCEPTION WHEN OTHERS THEN
        v_ip := NULL;
    END;

    IF v_ip IS NULL OR v_ip = '' THEN
        v_ip := 'rpc';
    END IF;

    IF char_length(v_ip) > 50 THEN
        v_ip := left(v_ip, 50);
    END IF;

    -- ── 6. Insert audit row ─────────────────────────────────────
    INSERT INTO public.activity_log (
        user_id,
        user_email,
        user_name,
        action,
        details,
        ip_address,
        created_at
    ) VALUES (
        v_user_id,
        v_user_email,
        v_user_name,
        p_action,
        p_details,
        v_ip,
        NOW()
    )
    RETURNING id INTO v_new_id;

    RETURN v_new_id;

EXCEPTION
    WHEN SQLSTATE '22023' THEN RAISE;
    WHEN SQLSTATE '42501' THEN RAISE;
    WHEN SQLSTATE '22001' THEN RAISE;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'log_activity failed (action=%): % (%)',
            p_action, SQLERRM, SQLSTATE;
END;
$$;

-- Grants must be re-asserted after CREATE OR REPLACE (PostgreSQL preserves
-- them, but we re-state for clarity and idempotence).
REVOKE ALL ON FUNCTION public.log_activity(TEXT, JSONB) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.log_activity(TEXT, JSONB) FROM anon;
GRANT  EXECUTE ON FUNCTION public.log_activity(TEXT, JSONB) TO authenticated;

COMMENT ON FUNCTION public.log_activity(TEXT, JSONB) IS
'SECURITY DEFINER audit-log writer. Derives user_id / user_email / user_name '
'from auth.uid(). Captures x-forwarded-for IP. Authenticated only; anon → 42501. '
'Caps p_details at 10 KB (octet_length of JSONB::text) → 22001 if exceeded. '
'Returns BIGINT id of inserted row.';
