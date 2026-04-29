-- ============================================================================
-- P0e: RLS Tier 2 — lock down the last critical anon-readable tables
-- ============================================================================
--
-- Builds on:
--   - 20260429120000_driver_applications_ssn_protection.sql  (P0a)
--   - 20260429130000_rls_supporting_indexes.sql              (P0b indexes)
--   - 20260429140000_rls_helpers.sql                         (P0c helpers)
--   - 20260429160000_rls_tier1.sql                           (P0d tables)
--   - 20260429170000_rls_tier1_dedupe_policies.sql           (P0d cleanup)
--
-- Helpers consumed (defined in 20260429140000, hardened in 20260429160000):
--   public.is_tms_staff()           — role IN ('ADMIN','MANAGER','DISPATCHER')
--   public.is_dealer_user()         — role = 'DEALER'
--   public.current_dealer_id()      — caller's dealers.id via 2-hop link
--   public.current_driver_id()      — caller's drivers.id, NOT a dealer
--   public.current_local_driver_id()— caller's local_drivers.id, NOT a dealer
--
-- Scope of THIS migration (Tier 2):
--   1.  drivers       — first-time RLS lock-down. Anon was reading SSN, bank
--                       account/routing, DOB, PIN, CDL #, address (verified
--                       live 2026-04-29). iOS now uses driver_can_login_by_email
--                       RPC (TestFlight build 33), so client-side anon SELECT
--                       on drivers is no longer required.
--   2.  users         — first-time RLS lock-down. Anon was reading the legacy
--                       plaintext `password` column plus email/role.
--   3.  local_drivers — first-time RLS lock-down. Empty today, but same anon
--                       posture as the other two once populated.
--
-- OUT OF SCOPE (handled elsewhere or already correct):
--   - All Tier 1 tables (vehicle_inspections, trucks, brokers, expenses, …).
--   - payroll_records          — already correct per 20260306000000.
--   - driver_applications      — already locked in 20260429120000 (P0a).
--   - orders / trips           — Tier 3 (separate migration).
--
-- Constraints respected:
--   * (SELECT public.helper()) wrapper for InitPlan caching.
--   * Allow-list staff roles; deny by default.
--   * No `USING (true)` policies anywhere.
--   * INSERT WITH CHECK mirrors or is tighter than SELECT USING.
--   * DELETE on drivers / users / local_drivers is ADMIN-only — preserves the
--     FMCSA §391.51 driver-qualification-file 3-year retention obligation
--     and prevents non-admin staff from purging audit subjects.
--
-- Schema notes from investigation (auditor retrace):
--   * drivers (verified live 2026-04-29 + 20260210000000_driver_auth_email_otp.sql):
--       id, first_name, last_name, phone, email, default_truck_id, cut_percent,
--       status, created_at, pin_code, date_of_birth, ssn_ein, hire_date,
--       termination_date, cdl_number, cdl_state, cdl_endorsements,
--       cdl_restrictions, bank_name, account_number, routing_number,
--       pay_to_name, pay_to_address, pay_to_company, pay_to_company_ein,
--       auth_user_id (UNIQUE per 20260429130000).
--   * users (verified live + 20260313000100_add_dealer_role.sql):
--       id, email, password (legacy plaintext — Supabase Auth is source of
--       truth; column still populated by app), first_name, last_name,
--       role IN ('DISPATCHER','MANAGER','ADMIN','DEALER'), is_active,
--       created_at, auth_id (uuid → auth.users.id).
--   * local_drivers (per 20260216120000_local_driver_auth_and_local_flow_sync.sql):
--       id (bigserial), name, phone, service_area, notes, email, status,
--       auth_user_id, linked_driver_id, app_access_enabled,
--       created_at, updated_at.
--   * NO existing RLS policies were ever defined in repo on these three
--     tables (verified by `grep -nE "POLICY.*ON\s+(public\.)?(drivers|users
--     |local_drivers)\b"` returning empty). RLS was disabled — anon could
--     read everything. The end-of-file dedupe DO block catches anything a
--     human created in Studio that we don't know about.
--
-- Field-level scoping note (drivers self-UPDATE):
--   Pure RLS cannot scope which columns a row-owner may UPDATE — only which
--   rows. Driver self-UPDATE is therefore intentionally permitted at the
--   row level and the application enforces field-level scoping (e.g. the
--   driver may NOT change ssn_ein, cdl_number, cut_percent, status,
--   auth_user_id, hire_date, termination_date). Tightening this to a
--   column-level grant + trigger is tracked as a P1 task.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. drivers
--   First-time RLS. Live anon was reading SSN, bank, DOB, PIN, CDL, address.
--   - Staff: full SELECT/INSERT/UPDATE; DELETE restricted to role='ADMIN'.
--   - Driver self: SELECT + UPDATE own row only (field-level enforcement at
--     app layer, see header note).
--   - Dealer / local_driver / anon: NO access.
-- ---------------------------------------------------------------------------
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;

-- Defensive drops (no in-repo policies, but Studio-created ones may exist
-- in the live DB; the end-of-file dedupe DO block catches any others).
DROP POLICY IF EXISTS "drivers_select" ON public.drivers;
DROP POLICY IF EXISTS "drivers_insert" ON public.drivers;
DROP POLICY IF EXISTS "drivers_update" ON public.drivers;
DROP POLICY IF EXISTS "drivers_delete" ON public.drivers;

CREATE POLICY "drivers_select" ON public.drivers
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND drivers.id = (SELECT public.current_driver_id())
    )
  );

-- INSERT: staff only. Drivers are onboarded by dispatch/management; the
-- mobile app's first-touch path uses the SECURITY DEFINER
-- driver_can_login_by_email RPC, never a direct INSERT.
CREATE POLICY "drivers_insert" ON public.drivers
  FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));

-- UPDATE: staff only. Drivers cannot self-PATCH their row, period.
-- Rationale (Security Engineer review, 2026-04-29):
--   Without column-level enforcement, a driver self-update would let them
--   change cut_percent (payroll fraud), bank_name/account_number/routing_number
--   (ACH redirection), ssn_ein/cdl_number/date_of_birth (identity falsification),
--   pin_code, status, or auth_user_id. iOS verified: no driver-self PATCH paths
--   exist today (drivers GET only). Web TMS has no driver login. So denying
--   driver UPDATE costs nothing and closes a CRITICAL fraud vector.
--   If a future feature legitimately needs driver-self profile edits, add a
--   BEFORE UPDATE trigger that whitelists safe fields (phone/email/pay_to_*).
CREATE POLICY "drivers_update" ON public.drivers
  FOR UPDATE USING ((SELECT public.is_tms_staff()))
  WITH CHECK ((SELECT public.is_tms_staff()));

-- DELETE: ADMIN only — protects the FMCSA §391.51 driver-qualification-file
-- 3-year retention obligation. MANAGER/DISPATCHER must use status field for
-- terminations, never DELETE.
CREATE POLICY "drivers_delete" ON public.drivers
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role = 'ADMIN'
    )
  );

-- ---------------------------------------------------------------------------
-- 2. users
--   First-time RLS. Live anon was reading the legacy plaintext `password`
--   column plus email/role.
--   - Staff (TMS): full SELECT/INSERT/UPDATE; DELETE ADMIN-only.
--   - Dealer self (auth_id = auth.uid() AND role='DEALER'): SELECT + UPDATE
--     own row (profile management). Cannot escalate via WITH CHECK guard
--     keeping role='DEALER' — privilege change requires staff.
--   - Driver: NO access (driver identity lives in `drivers`).
--   - Anon: NO access.
-- ---------------------------------------------------------------------------
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_select" ON public.users;
DROP POLICY IF EXISTS "users_insert" ON public.users;
DROP POLICY IF EXISTS "users_update" ON public.users;
DROP POLICY IF EXISTS "users_delete" ON public.users;

CREATE POLICY "users_select" ON public.users
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.is_dealer_user())
      AND users.auth_id = auth.uid()
      AND users.role = 'DEALER'
    )
  );

-- INSERT: staff only. Auth.users → public.users provisioning is handled by
-- the on-signup trigger (20260211000000_fix_auth_signup_trigger.sql) which
-- runs as the trigger owner, not the calling role, so it bypasses RLS.
CREATE POLICY "users_insert" ON public.users
  FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));

-- UPDATE: staff full; dealer can edit own row but cannot self-promote
-- (WITH CHECK keeps role='DEALER' and auth_id pinned to caller).
CREATE POLICY "users_update" ON public.users
  FOR UPDATE USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.is_dealer_user())
      AND users.auth_id = auth.uid()
      AND users.role = 'DEALER'
    )
  ) WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.is_dealer_user())
      AND users.auth_id = auth.uid()
      AND users.role = 'DEALER'
    )
  );

-- DELETE: ADMIN only. Same retention reasoning as drivers — and dealer
-- self-deletion would orphan the auth.users row + dealers FK.
CREATE POLICY "users_delete" ON public.users
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role = 'ADMIN'
    )
  );

-- ---------------------------------------------------------------------------
-- 3. local_drivers
--   First-time RLS. Empty today but same anon-readable posture once rows
--   exist (email, phone, status, linked_driver_id, auth_user_id).
--   - Staff: full SELECT/INSERT/UPDATE; DELETE ADMIN-only.
--   - Local driver self (current_local_driver_id() = local_drivers.id):
--     SELECT + UPDATE own row.
--   - Driver / Dealer / anon: NO access.
-- ---------------------------------------------------------------------------
ALTER TABLE public.local_drivers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "local_drivers_select" ON public.local_drivers;
DROP POLICY IF EXISTS "local_drivers_insert" ON public.local_drivers;
DROP POLICY IF EXISTS "local_drivers_update" ON public.local_drivers;
DROP POLICY IF EXISTS "local_drivers_delete" ON public.local_drivers;

CREATE POLICY "local_drivers_select" ON public.local_drivers
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_local_driver_id()) IS NOT NULL
      AND local_drivers.id = (SELECT public.current_local_driver_id())
    )
  );

CREATE POLICY "local_drivers_insert" ON public.local_drivers
  FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));

-- UPDATE: staff only. Same rationale as drivers_update — local drivers
-- cannot self-PATCH (table currently empty; field-level enforcement
-- deferred to a trigger if future flows need it).
CREATE POLICY "local_drivers_update" ON public.local_drivers
  FOR UPDATE USING ((SELECT public.is_tms_staff()))
  WITH CHECK ((SELECT public.is_tms_staff()));

CREATE POLICY "local_drivers_delete" ON public.local_drivers
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role = 'ADMIN'
    )
  );

-- ---------------------------------------------------------------------------
-- Dedupe pass: drop any legacy / Studio-created policies on these three
-- tables that aren't one of the tight names above. Mirrors the pattern in
-- 20260429170000_rls_tier1_dedupe_policies.sql.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  pol RECORD;
  expected_tables TEXT[] := ARRAY['drivers', 'users', 'local_drivers'];
  ours_pattern TEXT := '^(drivers|users|local_drivers)_(select|insert|update|delete)$';
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
-- Sanity: verify every table we touched has RLS enabled and at least one
-- policy. NOTICE only — does not fail the migration.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t TEXT;
  has_rls BOOLEAN;
  policy_count INTEGER;
BEGIN
  FOREACH t IN ARRAY ARRAY['drivers', 'users', 'local_drivers']
  LOOP
    SELECT relrowsecurity INTO has_rls
    FROM pg_class
    WHERE relnamespace = 'public'::regnamespace
      AND relname = t;

    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = t;

    IF NOT COALESCE(has_rls, false) THEN
      RAISE WARNING 'P0e sanity: % does not have RLS enabled', t;
    END IF;

    IF policy_count = 0 THEN
      RAISE WARNING 'P0e sanity: % has zero policies (table is now inaccessible)', t;
    ELSE
      RAISE NOTICE 'P0e sanity: % OK (% policies)', t, policy_count;
    END IF;
  END LOOP;
END$$;

COMMIT;
