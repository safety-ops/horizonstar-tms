-- ============================================================
-- Migration: 20260507202900_log_activity_rpc.sql
-- Purpose:   Add SECURITY DEFINER RPC public.log_activity()
--
-- Threat model:
--   The activity_log table has a public INSERT policy (WITH CHECK true),
--   meaning any caller who holds the anon key can write arbitrary rows —
--   including spoofing user_email / user_id to impersonate any user.
--   This RPC closes that gap by deriving all identity fields server-side
--   from auth.uid(), making the audit trail tamper-resistant.
--
--   The public INSERT policy is intentionally NOT dropped here. It will be
--   removed in a follow-up migration once all 40+ index.html call sites
--   have been migrated from dbInsert('activity_log') → sb.rpc('log_activity').
--
-- Rollback:  supabase/rollbacks/20260507202900_log_activity_rpc.down.sql
-- ============================================================

-- ----------------------------------------------------------------
-- 1. RPC: public.log_activity
--    Parameters:
--      p_action  TEXT        — required, max 50 chars (matches column)
--      p_details JSONB       — optional audit payload
--    Returns:
--      BIGINT — the id of the newly inserted activity_log row
-- ----------------------------------------------------------------
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

    -- Enforce column width early so the error is meaningful.
    IF char_length(p_action) > 50 THEN
        RAISE EXCEPTION 'Action value too long (max 50 chars): %', p_action
            USING ERRCODE = '22001';
    END IF;

    -- ── 2. Auth gate ────────────────────────────────────────────
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated audit attempt'
            USING ERRCODE = '42501';
    END IF;

    -- ── 3. Resolve identity from public.users ───────────────────
    --    users.id is INTEGER; activity_log.user_id is BIGINT — implicit widening cast is safe.
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
    --    auth.uid() resolved (non-null) but there is no matching row in
    --    public.users. This happens for dealer accounts whose identity
    --    lives in dealer_applications / dealers, not users.
    --    We pull the email from auth.users directly and leave user_id NULL.
    IF v_user_id IS NULL THEN
        SELECT au.email::TEXT
        INTO   v_user_email
        FROM   auth.users au
        WHERE  au.id = v_uid
        LIMIT  1;

        -- If for any reason even auth.users has no row, record a sentinel.
        IF v_user_email IS NULL THEN
            v_user_email := 'auth:' || v_uid::TEXT;
        END IF;

        v_user_name := NULL; -- no name available for dealer path
    END IF;

    -- ── 5. Capture request IP ───────────────────────────────────
    --    PostgREST surfaces request headers via current_setting('request.headers').
    --    x-forwarded-for may be a comma-list; trim to the first (client) value.
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

    -- ip_address column is varchar(50); clamp silently to avoid insert failure.
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
    -- Re-raise anything that is NOT our own explicit exceptions so callers
    -- get a real error signal rather than a silent null return.
    WHEN SQLSTATE '22023' THEN RAISE; -- 'Action required'
    WHEN SQLSTATE '42501' THEN RAISE; -- 'Unauthenticated audit attempt'
    WHEN SQLSTATE '22001' THEN RAISE; -- 'Action value too long'
    WHEN OTHERS THEN
        RAISE EXCEPTION 'log_activity failed (action=%): % (%)',
            p_action, SQLERRM, SQLSTATE;
END;
$$;

COMMENT ON FUNCTION public.log_activity(TEXT, JSONB) IS
'SECURITY DEFINER audit-log writer. Derives user_id / user_email / user_name '
'from auth.uid() (anti-spoofing). Captures x-forwarded-for IP. '
'Callable by authenticated role only. Returns BIGINT id of the inserted row. '
'Anon callers receive SQLSTATE 42501. '
'The companion public INSERT policy on activity_log is intentionally left in '
'place until all index.html call sites are migrated to this RPC.';

-- ----------------------------------------------------------------
-- 2. Grants — authenticated only; anon explicitly excluded
-- ----------------------------------------------------------------
REVOKE ALL ON FUNCTION public.log_activity(TEXT, JSONB) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.log_activity(TEXT, JSONB) TO authenticated;
