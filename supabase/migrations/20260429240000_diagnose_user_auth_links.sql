-- Diagnostic: check whether public.users rows have valid auth_id links to
-- auth.users. If a TMS user signs in but their public.users.auth_id is NULL
-- (or doesn't match the auth.uid() the JWT carries), is_tms_staff() returns
-- false and every RLS-protected query fails — looks identical to a broken
-- session from the client's perspective.
--
-- NOTICE-only. No schema or data changes.

DO $$
DECLARE
  total_users INTEGER;
  null_auth INTEGER;
  active_with_auth INTEGER;
  rec RECORD;
BEGIN
  SELECT COUNT(*) INTO total_users FROM public.users;
  SELECT COUNT(*) INTO null_auth FROM public.users WHERE auth_id IS NULL;
  SELECT COUNT(*) INTO active_with_auth
  FROM public.users
  WHERE auth_id IS NOT NULL AND COALESCE(is_active, true) = true;

  RAISE NOTICE 'USERS-DIAG: total=% null_auth_id=% active_with_auth=%',
    total_users, null_auth, active_with_auth;

  -- Per-user line: id, role, is_active, has-auth-link, auth_users-id-match.
  FOR rec IN
    SELECT
      u.id,
      u.role,
      COALESCE(u.is_active, true) AS active,
      u.auth_id IS NOT NULL AS has_auth_id,
      EXISTS (SELECT 1 FROM auth.users au WHERE au.id = u.auth_id) AS auth_user_exists,
      u.email
    FROM public.users u
    ORDER BY u.id
  LOOP
    RAISE NOTICE 'USER id=% role=% active=% has_auth_id=% auth_user_exists=% email=%',
      rec.id, rec.role, rec.active, rec.has_auth_id, rec.auth_user_exists,
      -- mask the local-part of the email so this audit row is less PII-sensitive
      regexp_replace(rec.email, '^.+(@.+)$', '***\1');
  END LOOP;

  -- Cross-check: auth.users without a public.users row.
  FOR rec IN
    SELECT au.id, au.email, au.created_at
    FROM auth.users au
    LEFT JOIN public.users pu ON pu.auth_id = au.id
    WHERE pu.id IS NULL
    ORDER BY au.created_at DESC
    LIMIT 10
  LOOP
    RAISE NOTICE 'ORPHAN-AUTH-USER auth.id=% email=%',
      rec.id, regexp_replace(COALESCE(rec.email,''), '^.+(@.+)$', '***\1');
  END LOOP;
END$$;
