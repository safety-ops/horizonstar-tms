-- Seed dispatchers rows for active staff users (ADMIN/MANAGER/DISPATCHER)
-- that don't yet have one. Without a dispatchers row, the importer's
-- current_user_dispatcher() RPC returns null and orders.dispatcher_id
-- can't be auto-set — the importer falls back to the manual dropdown.
--
-- Diagnosed by 20260429270000: 2 staff users without dispatchers rows
-- (id=1 ADMIN, id=3 DISPATCHER levanisbx@gmail.com).
--
-- Generates a dispatcher code from the user's role and id; the user can
-- edit name/code later via the web TMS Dispatchers admin page.
-- Idempotent: skips users that already have a dispatchers row.

DO $$
DECLARE
  rec RECORD;
  inserted_count INT := 0;
  next_code_num INT;
  proposed_code TEXT;
BEGIN
  FOR rec IN
    SELECT u.id AS user_id, u.role, u.first_name, u.last_name, u.email
    FROM public.users u
    LEFT JOIN public.dispatchers d ON d.user_id = u.id
    WHERE u.role IN ('ADMIN', 'MANAGER', 'DISPATCHER')
      AND COALESCE(u.is_active, true) = true
      AND d.id IS NULL
    ORDER BY u.id
  LOOP
    -- Pick the next free D## code so it doesn't collide with existing
    -- dispatcher codes (D1, D2, D3, D4, D5, D6 already in use per
    -- diagnostic).
    SELECT COALESCE(MAX(NULLIF(regexp_replace(code, '^D', ''), '')::INT), 0) + 1
      INTO next_code_num
      FROM public.dispatchers
      WHERE code ~ '^D[0-9]+$';
    proposed_code := 'D' || next_code_num;

    INSERT INTO public.dispatchers (user_id, name, code, is_active)
    VALUES (
      rec.user_id,
      btrim(COALESCE(rec.first_name, '') || ' ' || COALESCE(rec.last_name, '')),
      proposed_code,
      true
    );
    RAISE NOTICE 'SEEDED dispatchers row for user_id=% role=% name=% code=%',
      rec.user_id, rec.role, btrim(COALESCE(rec.first_name,'') || ' ' || COALESCE(rec.last_name,'')),
      proposed_code;
    inserted_count := inserted_count + 1;
  END LOOP;
  RAISE NOTICE 'SEED-SUMMARY: inserted=% rows', inserted_count;
END$$;
