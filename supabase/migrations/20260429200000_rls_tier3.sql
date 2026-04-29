-- ============================================================================
-- P0f: RLS Tier 3 — close the last anon-readable tables (orders + trips)
-- ============================================================================
--
-- Builds on:
--   - 20260429120000_driver_applications_ssn_protection.sql  (P0a)
--   - 20260429130000_rls_supporting_indexes.sql              (P0b indexes
--       — already created idx_orders_driver_id, idx_orders_trip_id,
--       idx_trips_driver_id; this migration relies on them)
--   - 20260429140000_rls_helpers.sql                         (P0c helpers)
--   - 20260429160000_rls_tier1.sql                           (P0d Tier 1)
--   - 20260429170000_rls_tier1_dedupe_policies.sql           (P0d cleanup)
--   - 20260429190000_rls_tier2.sql                           (P0e Tier 2)
--
-- Helpers consumed (defined in 20260429140000, hardened in 20260429160000
-- with the dual-role NOT is_dealer_user() guard for driver-scope helpers):
--   public.is_tms_staff()            — role IN ('ADMIN','MANAGER','DISPATCHER')
--   public.is_dealer_user()          — role = 'DEALER'
--   public.current_dealer_id()       — caller's dealers.id via 2-hop link
--   public.current_driver_id()       — caller's drivers.id, NULL if dealer
--   public.current_local_driver_id() — caller's local_drivers.id, NULL if dealer
--
-- All helpers are wrapped in `(SELECT public.fn())` to keep the InitPlan
-- caching behaviour Postgres uses for STABLE function calls in policies.
--
-- Field-level enforcement is handled by BEFORE UPDATE triggers
-- (block_orders_field_escalation / block_trips_field_escalation). RLS alone
-- cannot constrain WHICH columns a row-owner may UPDATE — without these
-- triggers a driver/dealer could PATCH driver_id (re-assignment), dealer_id
-- (cross-tenant), broker_fee/total_paid (financial fraud), or any other
-- protected column on rows they own at the row level.
--
-- The triggers use an ALLOW-LIST (fail-closed): a future column addition
-- defaults to "protected" until explicitly listed. Allow-list members are
-- derived from the actual driver-app PATCH paths in
-- `Horizon Star LLC Driver App/LuckyCabbage Driver App/SupabaseService.swift`
-- (verified 2026-04-29 on branch p0-reliability):
--
--   orders allow-list (driver + dealer self-update):
--     • delivery_status, local_delivery_status — driver workflow
--     • local_driver_id, local_delivery_type, local_assigned_date,
--       local_confirmation_status — local handoff TO_TERMINAL flow
--     • actual_pickup_date, actual_delivery_date — inspection completion
--     • pickup_eta, delivery_eta — driver ETA submission
--     • driver_paid_status, driver_paid_amount, driver_paid_method — driver
--       payment receipt logging
--     • dispatcher_notes, notes, local_notes — context notes (existing flow)
--     • updated_at — auto-stamp / client-side bookkeeping
--
--   trips allow-list (driver self-update only — dealers have no trips access):
--     • status — startTrip / endTrip transitions
--     • period_start_date, period_end_date — startTrip backfill / endTrip stamp
--     • notes — driver context notes
--     • updated_at — auto-stamp
--
-- Everything else is PROTECTED — staff-only.
--
-- Constraints respected:
--   * (SELECT public.helper()) wrapper for InitPlan caching.
--   * Allow-list staff roles; deny by default.
--   * No `USING (true)` policies anywhere.
--   * INSERT WITH CHECK is staff-only (drivers/dealers cannot create rows).
--   * DELETE on orders/trips is ADMIN-only — preserves FMCSA §390.31
--     (3-year general operations record) + §391.51 retention obligations
--     and protects financial records (invoices, payments).
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. orders
-- ---------------------------------------------------------------------------
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "orders_select" ON public.orders;
DROP POLICY IF EXISTS "orders_insert" ON public.orders;
DROP POLICY IF EXISTS "orders_update" ON public.orders;
DROP POLICY IF EXISTS "orders_delete" ON public.orders;

CREATE POLICY "orders_select" ON public.orders
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND (
        orders.driver_id = (SELECT public.current_driver_id())
        OR EXISTS (
          SELECT 1 FROM public.trips t
          WHERE t.id = orders.trip_id
            AND t.driver_id = (SELECT public.current_driver_id())
        )
      )
    )
    OR (
      (SELECT public.current_local_driver_id()) IS NOT NULL
      AND orders.local_driver_id = (SELECT public.current_local_driver_id())
    )
    OR (
      (SELECT public.is_dealer_user())
      AND orders.dealer_id = (SELECT public.current_dealer_id())
    )
  );

CREATE POLICY "orders_insert" ON public.orders
  FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));

CREATE POLICY "orders_update" ON public.orders
  FOR UPDATE USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND (
        orders.driver_id = (SELECT public.current_driver_id())
        OR EXISTS (
          SELECT 1 FROM public.trips t
          WHERE t.id = orders.trip_id
            AND t.driver_id = (SELECT public.current_driver_id())
        )
      )
    )
    OR (
      (SELECT public.current_local_driver_id()) IS NOT NULL
      AND orders.local_driver_id = (SELECT public.current_local_driver_id())
    )
    OR (
      (SELECT public.is_dealer_user())
      AND orders.dealer_id = (SELECT public.current_dealer_id())
    )
  ) WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND (
        orders.driver_id = (SELECT public.current_driver_id())
        OR EXISTS (
          SELECT 1 FROM public.trips t
          WHERE t.id = orders.trip_id
            AND t.driver_id = (SELECT public.current_driver_id())
        )
      )
    )
    OR (
      (SELECT public.current_local_driver_id()) IS NOT NULL
      AND orders.local_driver_id = (SELECT public.current_local_driver_id())
    )
    OR (
      -- TO_TERMINAL handoff: a local driver clears their own assignment,
      -- leaving local_driver_id IS NULL. The USING clause guarantees they
      -- could only have selected the row when local_driver_id was theirs;
      -- this OR branch lets the post-update NULL state pass WITH CHECK.
      -- Cannot point local_driver_id at someone ELSE's id (NULL only).
      (SELECT public.current_local_driver_id()) IS NOT NULL
      AND orders.local_driver_id IS NULL
    )
    OR (
      (SELECT public.is_dealer_user())
      AND orders.dealer_id = (SELECT public.current_dealer_id())
    )
  );

CREATE POLICY "orders_delete" ON public.orders
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role = 'ADMIN'
    )
  );

-- ---------------------------------------------------------------------------
-- 2. trips
-- ---------------------------------------------------------------------------
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "trips_select" ON public.trips;
DROP POLICY IF EXISTS "trips_insert" ON public.trips;
DROP POLICY IF EXISTS "trips_update" ON public.trips;
DROP POLICY IF EXISTS "trips_delete" ON public.trips;

CREATE POLICY "trips_select" ON public.trips
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND trips.driver_id = (SELECT public.current_driver_id())
    )
  );

CREATE POLICY "trips_insert" ON public.trips
  FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));

CREATE POLICY "trips_update" ON public.trips
  FOR UPDATE USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND trips.driver_id = (SELECT public.current_driver_id())
    )
  ) WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND trips.driver_id = (SELECT public.current_driver_id())
    )
  );

CREATE POLICY "trips_delete" ON public.trips
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role = 'ADMIN'
    )
  );

-- ---------------------------------------------------------------------------
-- 3. block_orders_field_escalation()
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.block_orders_field_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  allowed TEXT[] := ARRAY[
    'delivery_status',
    'local_delivery_status',
    'local_driver_id',
    'local_delivery_type',
    'local_assigned_date',
    'local_confirmation_status',
    'actual_pickup_date',
    'actual_delivery_date',
    'pickup_eta',
    'delivery_eta',
    'driver_paid_status',
    'driver_paid_amount',
    'driver_paid_method',
    'dispatcher_notes',
    'notes',
    'local_notes',
    'updated_at'
  ];
  old_stripped JSONB;
  new_stripped JSONB;
  k TEXT;
BEGIN
  -- service_role connections (edge functions, scheduled jobs) bypass — they
  -- have no users.role row, so is_tms_staff() returns false; without this
  -- early return, every server-side UPDATE on protected columns would fail.
  IF current_user = 'service_role' THEN
    RETURN NEW;
  END IF;

  IF public.is_tms_staff() THEN
    RETURN NEW;
  END IF;

  old_stripped := to_jsonb(OLD);
  new_stripped := to_jsonb(NEW);

  FOREACH k IN ARRAY allowed LOOP
    old_stripped := old_stripped - k;
    new_stripped := new_stripped - k;
  END LOOP;

  IF old_stripped IS DISTINCT FROM new_stripped THEN
    RAISE EXCEPTION
      'Drivers/dealers cannot modify protected fields on orders (allowed: %)',
      array_to_string(allowed, ', ')
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.block_orders_field_escalation() FROM PUBLIC;

DROP TRIGGER IF EXISTS block_orders_field_escalation ON public.orders;
CREATE TRIGGER block_orders_field_escalation
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.block_orders_field_escalation();

-- ---------------------------------------------------------------------------
-- 4. block_trips_field_escalation()
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.block_trips_field_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  allowed TEXT[] := ARRAY[
    'status',
    'period_start_date',
    'period_end_date',
    'notes',
    'updated_at'
  ];
  old_stripped JSONB;
  new_stripped JSONB;
  k TEXT;
BEGIN
  -- service_role connections (edge functions, scheduled jobs) bypass — they
  -- have no users.role row, so is_tms_staff() returns false; without this
  -- early return, every server-side UPDATE on protected columns would fail.
  IF current_user = 'service_role' THEN
    RETURN NEW;
  END IF;

  IF public.is_tms_staff() THEN
    RETURN NEW;
  END IF;

  old_stripped := to_jsonb(OLD);
  new_stripped := to_jsonb(NEW);

  FOREACH k IN ARRAY allowed LOOP
    old_stripped := old_stripped - k;
    new_stripped := new_stripped - k;
  END LOOP;

  IF old_stripped IS DISTINCT FROM new_stripped THEN
    RAISE EXCEPTION
      'Drivers cannot modify protected fields on trips (allowed: %)',
      array_to_string(allowed, ', ')
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.block_trips_field_escalation() FROM PUBLIC;

DROP TRIGGER IF EXISTS block_trips_field_escalation ON public.trips;
CREATE TRIGGER block_trips_field_escalation
  BEFORE UPDATE ON public.trips
  FOR EACH ROW
  EXECUTE FUNCTION public.block_trips_field_escalation();

-- ---------------------------------------------------------------------------
-- Dedupe pass (mirrors Tier 1 / Tier 2 inline dedupe).
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  pol RECORD;
  expected_tables TEXT[] := ARRAY['orders', 'trips'];
  ours_pattern TEXT := '^(orders|trips)_(select|insert|update|delete)$';
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
END$$;

-- ---------------------------------------------------------------------------
-- Sanity counts.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t TEXT;
  has_rls BOOLEAN;
  policy_count INTEGER;
  trigger_count INTEGER;
BEGIN
  FOREACH t IN ARRAY ARRAY['orders', 'trips']
  LOOP
    SELECT relrowsecurity INTO has_rls
    FROM pg_class
    WHERE relnamespace = 'public'::regnamespace
      AND relname = t;

    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = t;

    SELECT COUNT(*) INTO trigger_count
    FROM pg_trigger tg
    JOIN pg_class c ON c.oid = tg.tgrelid
    WHERE c.relnamespace = 'public'::regnamespace
      AND c.relname = t
      AND tg.tgname = 'block_' || t || '_field_escalation'
      AND NOT tg.tgisinternal;

    IF NOT COALESCE(has_rls, false) THEN
      RAISE WARNING 'P0f sanity: % does not have RLS enabled', t;
    END IF;

    IF policy_count = 0 THEN
      RAISE WARNING 'P0f sanity: % has zero policies (table is now inaccessible)', t;
    ELSE
      RAISE NOTICE 'P0f sanity: % OK (% policies)', t, policy_count;
    END IF;

    IF trigger_count = 0 THEN
      RAISE WARNING 'P0f sanity: % missing block_%_field_escalation trigger', t, t;
    ELSE
      RAISE NOTICE 'P0f sanity: % field-escalation trigger attached', t;
    END IF;
  END LOOP;
END$$;

COMMIT;
