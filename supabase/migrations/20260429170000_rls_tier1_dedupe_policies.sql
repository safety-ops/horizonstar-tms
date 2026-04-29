-- Diagnostic + cleanup: Tier 1 left some legacy permissive policies in place
-- (visible in the sanity counts: brokers=7, expenses=5, fuel/maintenance=8 per
-- post-push NOTICE block). Live anon reads confirm `brokers` and `expenses`
-- still return rows. PostgreSQL OR-combines permissive policies, so any
-- leftover `USING (true)` short-circuits the new tight policies.
--
-- This migration:
--   1. Logs the surviving policies on each Tier-1 table for the audit trail.
--   2. Drops any policy that is NOT one of the tight names we created in
--      20260429160000 (the `<prefix>_<select|insert|update|delete>` form).
--   3. Re-runs the sanity check.

DO $$
DECLARE
  pol RECORD;
  expected_tables TEXT[] := ARRAY[
    'vehicle_inspections','inspection_photos','inspection_videos','inspection_damages',
    'trucks','brokers','expenses','fuel_transactions','maintenance_records',
    'driver_notifications','company_files','dealers','dealer_order_messages',
    'order_status_history','order_change_requests'
  ];
  -- The tight policy names we own (per table prefix). Anything else is legacy.
  -- Per-table prefix mapping inferred from the migration:
  --   vehicle_inspections    → vi_*
  --   inspection_photos      → ip_*
  --   inspection_videos      → iv_*
  --   inspection_damages     → id_*
  --   trucks                 → trucks_*
  --   brokers                → brokers_*
  --   expenses               → expenses_*
  --   fuel_transactions      → fuel_*
  --   maintenance_records    → maint_*
  --   driver_notifications   → dn_*
  --   company_files          → cf_*
  --   dealers                → dealers_*
  --   dealer_order_messages  → dom_*
  --   order_status_history   → osh_*
  --   order_change_requests  → ocr_*
  ours_pattern TEXT := '^(vi|ip|iv|id|trucks|brokers|expenses|fuel|maint|dn|cf|dealers|dom|osh|ocr)_(select|insert|update|delete)$';
BEGIN
  FOR pol IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = ANY(expected_tables)
  LOOP
    IF pol.policyname ~ ours_pattern THEN
      RAISE NOTICE 'KEEP   %.% policy=%', pol.schemaname, pol.tablename, pol.policyname;
    ELSE
      RAISE NOTICE 'DROP   %.% policy=%', pol.schemaname, pol.tablename, pol.policyname;
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',
                     pol.policyname, pol.schemaname, pol.tablename);
    END IF;
  END LOOP;

  -- Final sanity counts after dedupe.
  FOR pol IN
    SELECT tablename, COUNT(*) AS n
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = ANY(expected_tables)
    GROUP BY tablename
    ORDER BY tablename
  LOOP
    RAISE NOTICE 'POST   %.% (% policies)', 'public', pol.tablename, pol.n;
  END LOOP;
END$$;
