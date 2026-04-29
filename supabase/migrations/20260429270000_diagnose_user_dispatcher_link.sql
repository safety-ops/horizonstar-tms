-- Diagnostic: for every users row with role='DISPATCHER', is there a
-- matching dispatchers row linking back via dispatchers.user_id? If not,
-- the auto-resolve RPC current_user_dispatcher() returns null and the
-- popup falls back to the manual dropdown — which is what the user is
-- seeing.

DO $$
DECLARE
  rec RECORD;
  staff_with_dispatcher INT := 0;
  staff_without_dispatcher INT := 0;
  orphan_dispatcher INT := 0;
BEGIN
  RAISE NOTICE '--- users.role=DISPATCHER (or ADMIN/MANAGER) vs dispatchers.user_id ---';
  FOR rec IN
    SELECT
      u.id AS user_id,
      u.role,
      regexp_replace(u.email, '^.+(@.+)$', '***\1') AS masked_email,
      u.auth_id IS NOT NULL AS has_auth,
      d.id AS dispatcher_id,
      d.name AS dispatcher_name,
      d.code AS dispatcher_code,
      COALESCE(d.is_active, true) AS dispatcher_active
    FROM public.users u
    LEFT JOIN public.dispatchers d ON d.user_id = u.id
    WHERE u.role IN ('ADMIN', 'MANAGER', 'DISPATCHER')
      AND COALESCE(u.is_active, true) = true
    ORDER BY u.id
  LOOP
    IF rec.dispatcher_id IS NULL THEN
      RAISE NOTICE 'NO-DISPATCHER user_id=% role=% email=% has_auth=%',
        rec.user_id, rec.role, rec.masked_email, rec.has_auth;
      staff_without_dispatcher := staff_without_dispatcher + 1;
    ELSE
      RAISE NOTICE 'OK user_id=% role=% dispatcher_id=% name=% code=% active=%',
        rec.user_id, rec.role, rec.dispatcher_id, rec.dispatcher_name,
        rec.dispatcher_code, rec.dispatcher_active;
      staff_with_dispatcher := staff_with_dispatcher + 1;
    END IF;
  END LOOP;

  RAISE NOTICE '--- dispatchers rows with NO matching users row (orphans) ---';
  FOR rec IN
    SELECT d.id, d.name, d.code, d.user_id
    FROM public.dispatchers d
    LEFT JOIN public.users u ON u.id = d.user_id
    WHERE u.id IS NULL OR d.user_id IS NULL
    ORDER BY d.id
  LOOP
    RAISE NOTICE 'ORPHAN dispatcher_id=% name=% code=% user_id=%',
      rec.id, rec.name, rec.code, COALESCE(rec.user_id::text, 'NULL');
    orphan_dispatcher := orphan_dispatcher + 1;
  END LOOP;

  RAISE NOTICE 'SUMMARY: staff_with_dispatcher=% staff_without_dispatcher=% orphan_dispatcher=%',
    staff_with_dispatcher, staff_without_dispatcher, orphan_dispatcher;
END$$;
