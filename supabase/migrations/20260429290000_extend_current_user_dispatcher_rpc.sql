-- Extend current_user_dispatcher() to include the user's role and id, so
-- the importer popup can decide whether to show admin-only UI (Supabase
-- URL + anon-key inputs).
--
-- Backward-compatible response shape: existing callers checking `data.id`
-- continue to work (non-null when a dispatcher row exists). New fields:
--   role        — users.role for the caller (ADMIN/MANAGER/DISPATCHER/DEALER)
--   user_id     — public.users.id, for any future caller that needs it
--
-- If no public.users row matches auth.uid(), the function returns null.

CREATE OR REPLACE FUNCTION public.current_user_dispatcher()
RETURNS jsonb
LANGUAGE sql STABLE PARALLEL SAFE SECURITY DEFINER
SET search_path = public, pg_temp AS $$
  SELECT to_jsonb(t)
  FROM (
    SELECT
      d.id,
      d.name,
      d.code,
      u.id   AS user_id,
      u.role AS role
    FROM public.users u
    LEFT JOIN public.dispatchers d
      ON d.user_id = u.id
     AND COALESCE(d.is_active, true) = true
    WHERE u.auth_id = auth.uid()
      AND COALESCE(u.is_active, true) = true
    LIMIT 1
  ) t;
$$;

-- Re-affirm grants (CREATE OR REPLACE preserves them, but explicit is safer
-- if the function was ever dropped + recreated).
REVOKE EXECUTE ON FUNCTION public.current_user_dispatcher() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.current_user_dispatcher() FROM anon;
GRANT EXECUTE ON FUNCTION public.current_user_dispatcher() TO authenticated;
