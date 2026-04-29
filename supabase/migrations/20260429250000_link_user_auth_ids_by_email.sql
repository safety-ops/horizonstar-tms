-- Link public.users rows that have NULL auth_id to their matching auth.users
-- record by email (case-insensitive). This fixes a class of RLS failure where
-- a TMS user can sign in successfully (auth.users record exists) but every
-- protected query returns [] because is_tms_staff() can't find their
-- public.users row by auth.uid().
--
-- Diagnosed live by 20260429240000_diagnose_user_auth_links.sql which found
-- 3 users (1 DISPATCHER on @gmail.com, 1 DISPATCHER on @horizonstartransport.com,
-- 1 DEALER on @gmail.com) with NULL auth_id.
--
-- The match is one-to-one because Supabase Auth enforces email uniqueness on
-- auth.users. The CTE below skips ambiguous matches defensively (any email
-- with >1 auth.users row is left as-is and reported via NOTICE).

DO $$
DECLARE
  rec RECORD;
  linked_count INTEGER := 0;
  ambiguous_count INTEGER := 0;
  unmatched_count INTEGER := 0;
BEGIN
  FOR rec IN
    SELECT u.id, u.email, u.role
    FROM public.users u
    WHERE u.auth_id IS NULL
      AND COALESCE(u.is_active, true) = true
  LOOP
    DECLARE
      candidates UUID[];
    BEGIN
      SELECT array_agg(au.id)
        INTO candidates
        FROM auth.users au
        WHERE lower(au.email) = lower(rec.email);

      IF candidates IS NULL OR array_length(candidates, 1) IS NULL THEN
        RAISE NOTICE 'NO-MATCH: users.id=% role=% has no auth.users row with email=%',
          rec.id, rec.role, regexp_replace(rec.email, '^.+(@.+)$', '***\1');
        unmatched_count := unmatched_count + 1;
      ELSIF array_length(candidates, 1) > 1 THEN
        RAISE NOTICE 'AMBIGUOUS: users.id=% role=% matches % auth.users rows — manual fix required',
          rec.id, rec.role, array_length(candidates, 1);
        ambiguous_count := ambiguous_count + 1;
      ELSE
        UPDATE public.users
          SET auth_id = candidates[1]
          WHERE id = rec.id;
        RAISE NOTICE 'LINKED: users.id=% role=% → auth.uid=%',
          rec.id, rec.role, candidates[1];
        linked_count := linked_count + 1;
      END IF;
    END;
  END LOOP;

  RAISE NOTICE 'LINK-SUMMARY: linked=% ambiguous=% unmatched=%',
    linked_count, ambiguous_count, unmatched_count;
END$$;

-- Post-link verification: surface any remaining users with NULL auth_id
-- so the controller can decide whether to provision auth.users rows or
-- mark them inactive.
DO $$
DECLARE
  rec RECORD;
  remaining INTEGER;
BEGIN
  SELECT COUNT(*) INTO remaining
  FROM public.users
  WHERE auth_id IS NULL AND COALESCE(is_active, true) = true;

  IF remaining = 0 THEN
    RAISE NOTICE 'POST-LINK: all active users now have auth_id set ✓';
  ELSE
    RAISE WARNING 'POST-LINK: % active user(s) still have NULL auth_id', remaining;
    FOR rec IN
      SELECT id, role, regexp_replace(email, '^.+(@.+)$', '***\1') AS masked_email
      FROM public.users
      WHERE auth_id IS NULL AND COALESCE(is_active, true) = true
      ORDER BY id
    LOOP
      RAISE WARNING '  unlinked users.id=% role=% email=%', rec.id, rec.role, rec.masked_email;
    END LOOP;
  END IF;
END$$;
