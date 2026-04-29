-- P0c: pre-auth driver login eligibility RPC.
--
-- Replaces the anon-keyed `GET /drivers?email=ilike...` lookup at
-- Horizon Star LLC Driver App/LuckyCabbage Driver App/SupabaseService.swift:413-422.
-- After RLS lands on `drivers`, that direct lookup returns []. This RPC runs
-- with SECURITY DEFINER so it can read drivers/local_drivers without RLS,
-- and returns ONLY a single boolean — no PII, no enumeration of active vs.
-- inactive vs. nonexistent.
--
-- Anti-enumeration:
--   • length-cap input at RFC 5321 (254 chars)
--   • normalize via lower(btrim(...))
--   • single-bool return — caller cannot distinguish nonexistent from inactive
--   • status = 'ACTIVE' allow-list (fail-closed on new status values)
--   • SECURITY DEFINER + GRANT EXECUTE TO anon ONLY (revoked from authenticated
--     so a compromised post-auth session cannot reuse it for cheap probing)
--
-- Rate limiting on this RPC is deferred to P1 (`auth_attempt_log` + CAPTCHA
-- on N failures from same IP). Today this just closes the RLS-induced gap.

CREATE OR REPLACE FUNCTION public.driver_can_login_by_email(p_email TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE PARALLEL SAFE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
DECLARE
  v_email TEXT;
BEGIN
  IF p_email IS NULL OR length(p_email) > 254 THEN
    RETURN FALSE;
  END IF;
  v_email := lower(btrim(p_email));
  IF length(v_email) = 0 THEN
    RETURN FALSE;
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM public.drivers
    WHERE lower(email) = v_email
      AND status = 'ACTIVE'
  ) OR EXISTS (
    SELECT 1 FROM public.local_drivers
    WHERE lower(email) = v_email
      AND status = 'ACTIVE'
  );
END$$;

REVOKE EXECUTE ON FUNCTION public.driver_can_login_by_email(TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.driver_can_login_by_email(TEXT) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.driver_can_login_by_email(TEXT) TO anon;
