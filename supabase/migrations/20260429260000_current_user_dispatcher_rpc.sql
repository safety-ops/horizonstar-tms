-- Resolve the dispatcher row associated with the currently-authenticated
-- user, via the 2-hop link auth.uid() → users.auth_id → users.id →
-- dispatchers.user_id. Used by the Chrome extension importer to set
-- orders.dispatcher_id automatically without a manual dropdown.
--
-- Pattern matches the helpers in 20260429140000_rls_helpers.sql:
-- SECURITY DEFINER + STABLE PARALLEL SAFE + locked search_path + tight
-- grants (REVOKE PUBLIC/anon; GRANT authenticated). Must be SECURITY
-- DEFINER because Tier 2 RLS prevents most callers from SELECTing users
-- directly, and PostgREST cannot easily express the 2-hop join via a
-- standard authenticated query.

CREATE OR REPLACE FUNCTION public.current_user_dispatcher()
RETURNS jsonb
LANGUAGE sql STABLE PARALLEL SAFE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
  SELECT to_jsonb(t)
  FROM (
    SELECT d.id, d.name, d.code
    FROM public.dispatchers d
    JOIN public.users u ON u.id = d.user_id
    WHERE u.auth_id = auth.uid()
      AND COALESCE(u.is_active, true) = true
      AND COALESCE(d.is_active, true) = true
    LIMIT 1
  ) t;
$$;

REVOKE EXECUTE ON FUNCTION public.current_user_dispatcher() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.current_user_dispatcher() FROM anon;
GRANT EXECUTE ON FUNCTION public.current_user_dispatcher() TO authenticated;
