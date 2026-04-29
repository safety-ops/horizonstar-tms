-- ============================================================================
-- P0d: RLS Tier 1 — tighten the remaining wide-open / inline-checked tables
-- ============================================================================
--
-- Builds on:
--   - 20260429120000_driver_applications_ssn_protection.sql  (P0a)
--   - 20260429130000_rls_supporting_indexes.sql              (P0b indexes)
--   - 20260429140000_rls_helpers.sql                         (P0c helpers)
--
-- Helpers consumed (all SECURITY DEFINER STABLE PARALLEL SAFE, allow-list role
-- check `('ADMIN','MANAGER','DISPATCHER')` and `status = 'ACTIVE'`):
--   public.is_tms_staff()
--   public.is_dealer_user()
--   public.current_dealer_id()
--   public.current_driver_id()
--   public.current_local_driver_id()  -- not used here, listed for completeness
--
-- Scope of THIS migration (Tier 1):
--   1.  vehicle_inspections   — SELECT was USING(true); writes already scoped
--   2.  inspection_photos     — same
--   3.  inspection_videos     — same
--   4.  inspection_damages    — same
--   5.  trucks                — first-time RLS lock-down (no in-repo migration)
--   6.  brokers               — first-time RLS lock-down
--   7.  expenses              — scoped via trips.driver_id (no driver_id col)
--   8.  fuel_transactions     — scoped via truck_number → trucks → trips
--   9.  maintenance_records   — staff-only; drivers no access
--  10.  driver_notifications  — replace inline checks with helper-based
--  11.  company_files         — staff-only; dealers/drivers no access
--  12.  dealers               — staff full; dealer can read own row
--  13.  dealer_order_messages — dealer can read+write own dealer's messages
--  14.  order_status_history  — drivers/dealers SELECT scoped by order
--  15.  order_change_requests — dealer can SELECT/INSERT/UPDATE own
--
-- OUT OF SCOPE (deliberately untouched):
--   - payroll_records       — already correct per 20260306000000
--   - driver_applications   — already locked in 20260429120000 (P0a)
--   - drivers / orders / trips / users — Tier 2 (separate migration)
--   - storage.objects       — handled in 20260211173600 / 20260212000100
--
-- Constraints respected:
--   * Allow-list staff roles (ADMIN/MANAGER/DISPATCHER); deny by default.
--   * No `USING (true)` policies anywhere.
--   * INSERT WITH CHECK mirrors or is tighter than SELECT USING.
--   * Drivers cannot DELETE on any table they have INSERT access to (FMCSA
--     §391.51 / §390.31 record retention).
--   * No CONCURRENTLY index DDL — Supabase migrations run inside a transaction.
--
-- Schema notes from investigation (in case auditors retrace this):
--   - expenses has trip_id only, NO driver_id column
--     (confirmed at index.html:21787-21795 ExpenseCreate save block, and
--      Horizon Star LLC Driver App/.../Models.swift:235-244 Expense struct).
--     Driver scoping flows through trips.driver_id.
--   - fuel_transactions has truck_number (text) + driver_name (text), NO FKs
--     (confirmed at index.html:26442-26483 saveFuelTransactions). Driver
--     scoping flows through trucks.truck_number → trips.truck_id → driver_id.
--   - brokers attaches to orders via orders.broker_id (index.html:18104,
--     billing_workspace migration 20260306010000:26 has same FK). Driver
--     scoping mirrors the order_attachments policy pattern from
--     20260212000100_auth_storage_hardening.sql:46-54.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 0. Dual-role collapse hardening (FIX 3)
--   If a single auth.uid() has both `users.role='DEALER'` AND a matching
--   `drivers.auth_user_id` (or `local_drivers.auth_user_id`), the policy
--   chains `OR (driver scope) OR (dealer scope)` would union both views.
--   Re-define the driver-scope helpers to short-circuit to NULL when the
--   caller is a dealer-portal user — dealer scope still applies via
--   is_dealer_user() / current_dealer_id(); driver scope returns NULL so
--   the driver branches of every policy below evaluate FALSE.
--
--   Helper attributes preserved exactly: STABLE PARALLEL SAFE
--   SECURITY DEFINER, SET search_path = public, pg_temp.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_driver_id() RETURNS INTEGER
  LANGUAGE sql STABLE PARALLEL SAFE SECURITY DEFINER
  SET search_path = public, pg_temp AS $$
  SELECT id FROM public.drivers
  WHERE auth_user_id = auth.uid()
    AND status = 'ACTIVE'
    AND NOT public.is_dealer_user()
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.current_local_driver_id() RETURNS INTEGER
  LANGUAGE sql STABLE PARALLEL SAFE SECURITY DEFINER
  SET search_path = public, pg_temp AS $$
  SELECT id FROM public.local_drivers
  WHERE auth_user_id = auth.uid()
    AND status = 'ACTIVE'
    AND NOT public.is_dealer_user()
  LIMIT 1;
$$;

-- ---------------------------------------------------------------------------
-- 1. vehicle_inspections
--   Existing state:
--     - "Enable read access for all users"  SELECT USING (true)
--         (from 20260103000000_fix_inspection_rls.sql:20-21)
--     - "Drivers can insert/update/delete own inspections"
--         (from 20260211173600_inspection_media_hardening.sql:213-260)
--   Replace SELECT with staff+driver-scoped; preserve driver writes via
--   helper rewrite so future status changes (e.g. 'SUSPENDED') auto-revoke.
-- ---------------------------------------------------------------------------
ALTER TABLE public.vehicle_inspections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "Enable update for all users" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "Authenticated users can view inspections" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "Authenticated users can insert inspections" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "Authenticated users can update inspections" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "Drivers can insert own inspections" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "Drivers can update own inspections" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "Drivers can delete own inspections" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "vi_select" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "vi_insert" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "vi_update" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "vi_delete" ON public.vehicle_inspections;

CREATE POLICY "vi_select" ON public.vehicle_inspections
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND (
        vehicle_inspections.driver_id = (SELECT public.current_driver_id())
        OR EXISTS (
          SELECT 1 FROM public.trips t
          WHERE t.id = vehicle_inspections.trip_id
            AND t.driver_id = (SELECT public.current_driver_id())
        )
      )
    )
  );

-- FIX 1: WITH CHECK additionally requires trip ownership when trip_id is
-- non-null. Closes scope-escalation where a driver could attach their own
-- driver_id to an inspection row pointing at someone else's trip.
CREATE POLICY "vi_insert" ON public.vehicle_inspections
  FOR INSERT WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND vehicle_inspections.driver_id = (SELECT public.current_driver_id())
      AND (
        vehicle_inspections.trip_id IS NULL
        OR EXISTS (
          SELECT 1 FROM public.trips t
          WHERE t.id = vehicle_inspections.trip_id
            AND t.driver_id = (SELECT public.current_driver_id())
        )
      )
    )
  );

CREATE POLICY "vi_update" ON public.vehicle_inspections
  FOR UPDATE USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND vehicle_inspections.driver_id = (SELECT public.current_driver_id())
    )
  ) WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND vehicle_inspections.driver_id = (SELECT public.current_driver_id())
      AND (
        vehicle_inspections.trip_id IS NULL
        OR EXISTS (
          SELECT 1 FROM public.trips t
          WHERE t.id = vehicle_inspections.trip_id
            AND t.driver_id = (SELECT public.current_driver_id())
        )
      )
    )
  );

-- DELETE: staff only — drivers must not erase their own DVIR audit trail
-- (FMCSA §396.11 retention).
CREATE POLICY "vi_delete" ON public.vehicle_inspections
  FOR DELETE USING ((SELECT public.is_tms_staff()));

-- ---------------------------------------------------------------------------
-- 2. inspection_photos
-- ---------------------------------------------------------------------------
ALTER TABLE public.inspection_photos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.inspection_photos;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.inspection_photos;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.inspection_photos;
DROP POLICY IF EXISTS "Authenticated users can view inspection photos" ON public.inspection_photos;
DROP POLICY IF EXISTS "Authenticated users can insert inspection photos" ON public.inspection_photos;
DROP POLICY IF EXISTS "Authenticated users can delete inspection photos" ON public.inspection_photos;
DROP POLICY IF EXISTS "Drivers can insert own inspection photos" ON public.inspection_photos;
DROP POLICY IF EXISTS "Drivers can delete own inspection photos" ON public.inspection_photos;
DROP POLICY IF EXISTS "ip_select" ON public.inspection_photos;
DROP POLICY IF EXISTS "ip_insert" ON public.inspection_photos;
DROP POLICY IF EXISTS "ip_update" ON public.inspection_photos;
DROP POLICY IF EXISTS "ip_delete" ON public.inspection_photos;

CREATE POLICY "ip_select" ON public.inspection_photos
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.vehicle_inspections vi
        LEFT JOIN public.trips t ON t.id = vi.trip_id
        WHERE vi.id = inspection_photos.inspection_id
          AND (
            vi.driver_id = (SELECT public.current_driver_id())
            OR t.driver_id = (SELECT public.current_driver_id())
          )
      )
    )
  );

-- FIX 1: WITH CHECK requires the parent inspection's trip ownership too,
-- not just driver_id match.
CREATE POLICY "ip_insert" ON public.inspection_photos
  FOR INSERT WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.vehicle_inspections vi
        WHERE vi.id = inspection_photos.inspection_id
          AND vi.driver_id = (SELECT public.current_driver_id())
          AND (
            vi.trip_id IS NULL
            OR EXISTS (
              SELECT 1 FROM public.trips t
              WHERE t.id = vi.trip_id
                AND t.driver_id = (SELECT public.current_driver_id())
            )
          )
      )
    )
  );

CREATE POLICY "ip_update" ON public.inspection_photos
  FOR UPDATE USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.vehicle_inspections vi
        WHERE vi.id = inspection_photos.inspection_id
          AND vi.driver_id = (SELECT public.current_driver_id())
      )
    )
  ) WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.vehicle_inspections vi
        WHERE vi.id = inspection_photos.inspection_id
          AND vi.driver_id = (SELECT public.current_driver_id())
          AND (
            vi.trip_id IS NULL
            OR EXISTS (
              SELECT 1 FROM public.trips t
              WHERE t.id = vi.trip_id
                AND t.driver_id = (SELECT public.current_driver_id())
            )
          )
      )
    )
  );

CREATE POLICY "ip_delete" ON public.inspection_photos
  FOR DELETE USING ((SELECT public.is_tms_staff()));

-- ---------------------------------------------------------------------------
-- 3. inspection_videos
-- ---------------------------------------------------------------------------
ALTER TABLE public.inspection_videos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.inspection_videos;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.inspection_videos;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.inspection_videos;
DROP POLICY IF EXISTS "Authenticated users can view inspection videos" ON public.inspection_videos;
DROP POLICY IF EXISTS "Authenticated users can insert inspection videos" ON public.inspection_videos;
DROP POLICY IF EXISTS "Authenticated users can delete inspection videos" ON public.inspection_videos;
DROP POLICY IF EXISTS "Drivers can insert own inspection videos" ON public.inspection_videos;
DROP POLICY IF EXISTS "Drivers can delete own inspection videos" ON public.inspection_videos;
DROP POLICY IF EXISTS "iv_select" ON public.inspection_videos;
DROP POLICY IF EXISTS "iv_insert" ON public.inspection_videos;
DROP POLICY IF EXISTS "iv_update" ON public.inspection_videos;
DROP POLICY IF EXISTS "iv_delete" ON public.inspection_videos;

CREATE POLICY "iv_select" ON public.inspection_videos
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.vehicle_inspections vi
        LEFT JOIN public.trips t ON t.id = vi.trip_id
        WHERE vi.id = inspection_videos.inspection_id
          AND (
            vi.driver_id = (SELECT public.current_driver_id())
            OR t.driver_id = (SELECT public.current_driver_id())
          )
      )
    )
  );

-- FIX 1: WITH CHECK requires parent inspection's trip ownership.
CREATE POLICY "iv_insert" ON public.inspection_videos
  FOR INSERT WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.vehicle_inspections vi
        WHERE vi.id = inspection_videos.inspection_id
          AND vi.driver_id = (SELECT public.current_driver_id())
          AND (
            vi.trip_id IS NULL
            OR EXISTS (
              SELECT 1 FROM public.trips t
              WHERE t.id = vi.trip_id
                AND t.driver_id = (SELECT public.current_driver_id())
            )
          )
      )
    )
  );

CREATE POLICY "iv_update" ON public.inspection_videos
  FOR UPDATE USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.vehicle_inspections vi
        WHERE vi.id = inspection_videos.inspection_id
          AND vi.driver_id = (SELECT public.current_driver_id())
      )
    )
  ) WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.vehicle_inspections vi
        WHERE vi.id = inspection_videos.inspection_id
          AND vi.driver_id = (SELECT public.current_driver_id())
          AND (
            vi.trip_id IS NULL
            OR EXISTS (
              SELECT 1 FROM public.trips t
              WHERE t.id = vi.trip_id
                AND t.driver_id = (SELECT public.current_driver_id())
            )
          )
      )
    )
  );

CREATE POLICY "iv_delete" ON public.inspection_videos
  FOR DELETE USING ((SELECT public.is_tms_staff()));

-- ---------------------------------------------------------------------------
-- 4. inspection_damages
-- ---------------------------------------------------------------------------
ALTER TABLE public.inspection_damages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.inspection_damages;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.inspection_damages;
DROP POLICY IF EXISTS "Enable update for all users" ON public.inspection_damages;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.inspection_damages;
DROP POLICY IF EXISTS "Authenticated users can view inspection damages" ON public.inspection_damages;
DROP POLICY IF EXISTS "Authenticated users can insert inspection damages" ON public.inspection_damages;
DROP POLICY IF EXISTS "Authenticated users can update inspection damages" ON public.inspection_damages;
DROP POLICY IF EXISTS "Authenticated users can delete inspection damages" ON public.inspection_damages;
DROP POLICY IF EXISTS "Drivers can insert own inspection damages" ON public.inspection_damages;
DROP POLICY IF EXISTS "Drivers can update own inspection damages" ON public.inspection_damages;
DROP POLICY IF EXISTS "Drivers can delete own inspection damages" ON public.inspection_damages;
DROP POLICY IF EXISTS "id_select" ON public.inspection_damages;
DROP POLICY IF EXISTS "id_insert" ON public.inspection_damages;
DROP POLICY IF EXISTS "id_update" ON public.inspection_damages;
DROP POLICY IF EXISTS "id_delete" ON public.inspection_damages;

CREATE POLICY "id_select" ON public.inspection_damages
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.vehicle_inspections vi
        LEFT JOIN public.trips t ON t.id = vi.trip_id
        WHERE vi.id = inspection_damages.inspection_id
          AND (
            vi.driver_id = (SELECT public.current_driver_id())
            OR t.driver_id = (SELECT public.current_driver_id())
          )
      )
    )
  );

-- FIX 1: WITH CHECK requires parent inspection's trip ownership.
CREATE POLICY "id_insert" ON public.inspection_damages
  FOR INSERT WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.vehicle_inspections vi
        WHERE vi.id = inspection_damages.inspection_id
          AND vi.driver_id = (SELECT public.current_driver_id())
          AND (
            vi.trip_id IS NULL
            OR EXISTS (
              SELECT 1 FROM public.trips t
              WHERE t.id = vi.trip_id
                AND t.driver_id = (SELECT public.current_driver_id())
            )
          )
      )
    )
  );

CREATE POLICY "id_update" ON public.inspection_damages
  FOR UPDATE USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.vehicle_inspections vi
        WHERE vi.id = inspection_damages.inspection_id
          AND vi.driver_id = (SELECT public.current_driver_id())
      )
    )
  ) WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.vehicle_inspections vi
        WHERE vi.id = inspection_damages.inspection_id
          AND vi.driver_id = (SELECT public.current_driver_id())
          AND (
            vi.trip_id IS NULL
            OR EXISTS (
              SELECT 1 FROM public.trips t
              WHERE t.id = vi.trip_id
                AND t.driver_id = (SELECT public.current_driver_id())
            )
          )
      )
    )
  );

CREATE POLICY "id_delete" ON public.inspection_damages
  FOR DELETE USING ((SELECT public.is_tms_staff()));

-- ---------------------------------------------------------------------------
-- 5. trucks
--   No in-repo CREATE TABLE migration for trucks (created in legacy prod
--   schema). Confirmed columns from app code: id, truck_number, status,
--   truck_type, assigned_trailer_id (20260118000000_truck_trailer_assignment).
--   Driver SELECT scope: trucks they're currently or recently assigned to via
--   trips.truck_id. We don't time-window "recently" — trips never deleted, so
--   any historical trip is acceptable for SELECT visibility.
-- ---------------------------------------------------------------------------
ALTER TABLE public.trucks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.trucks;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.trucks;
DROP POLICY IF EXISTS "Enable update for all users" ON public.trucks;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.trucks;
DROP POLICY IF EXISTS "Authenticated users can view trucks" ON public.trucks;
DROP POLICY IF EXISTS "Authenticated users can insert trucks" ON public.trucks;
DROP POLICY IF EXISTS "Authenticated users can update trucks" ON public.trucks;
DROP POLICY IF EXISTS "Authenticated users can delete trucks" ON public.trucks;
DROP POLICY IF EXISTS "trucks_select" ON public.trucks;
DROP POLICY IF EXISTS "trucks_insert" ON public.trucks;
DROP POLICY IF EXISTS "trucks_update" ON public.trucks;
DROP POLICY IF EXISTS "trucks_delete" ON public.trucks;

-- FIX 2: Time-window driver SELECT to recent (180-day) trips so a former
-- driver does not retain visibility of every truck they ever touched.
CREATE POLICY "trucks_select" ON public.trucks
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.trips t
        WHERE t.truck_id = trucks.id
          AND t.driver_id = (SELECT public.current_driver_id())
          AND t.created_at > now() - interval '180 days'
      )
    )
  );

CREATE POLICY "trucks_insert" ON public.trucks
  FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));

CREATE POLICY "trucks_update" ON public.trucks
  FOR UPDATE USING ((SELECT public.is_tms_staff()))
  WITH CHECK ((SELECT public.is_tms_staff()));

CREATE POLICY "trucks_delete" ON public.trucks
  FOR DELETE USING ((SELECT public.is_tms_staff()));

-- ---------------------------------------------------------------------------
-- 6. brokers
--   No in-repo CREATE TABLE migration. Columns from app code (index.html
--   :24818-24830): id, name, contact_name, email, phone, address, city,
--   state, zip, payment_terms. orders.broker_id FK confirmed in
--   20260306010000_billing_workspace.sql:26.
--   Driver SELECT: brokers tied to orders the driver has handled (via
--   orders.driver_id OR orders.trip_id → trips.driver_id). Same shape as
--   the order_attachments policy in 20260212000100_auth_storage_hardening.
-- ---------------------------------------------------------------------------
ALTER TABLE public.brokers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.brokers;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.brokers;
DROP POLICY IF EXISTS "Enable update for all users" ON public.brokers;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.brokers;
DROP POLICY IF EXISTS "Authenticated users can view brokers" ON public.brokers;
DROP POLICY IF EXISTS "Authenticated users can insert brokers" ON public.brokers;
DROP POLICY IF EXISTS "Authenticated users can update brokers" ON public.brokers;
DROP POLICY IF EXISTS "Authenticated users can delete brokers" ON public.brokers;
DROP POLICY IF EXISTS "brokers_select" ON public.brokers;
DROP POLICY IF EXISTS "brokers_insert" ON public.brokers;
DROP POLICY IF EXISTS "brokers_update" ON public.brokers;
DROP POLICY IF EXISTS "brokers_delete" ON public.brokers;

-- FIX 2: Time-window driver SELECT to recent (180-day) orders so a driver
-- does not retain lifetime PII visibility on every broker they ever worked.
CREATE POLICY "brokers_select" ON public.brokers
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.orders o
        LEFT JOIN public.trips t ON t.id = o.trip_id
        WHERE o.broker_id = brokers.id
          AND o.created_at > now() - interval '180 days'
          AND (
            o.driver_id = (SELECT public.current_driver_id())
            OR t.driver_id = (SELECT public.current_driver_id())
          )
      )
    )
  );

CREATE POLICY "brokers_insert" ON public.brokers
  FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));

CREATE POLICY "brokers_update" ON public.brokers
  FOR UPDATE USING ((SELECT public.is_tms_staff()))
  WITH CHECK ((SELECT public.is_tms_staff()));

CREATE POLICY "brokers_delete" ON public.brokers
  FOR DELETE USING ((SELECT public.is_tms_staff()));

-- ---------------------------------------------------------------------------
-- 7. expenses
--   IMPORTANT: expenses has trip_id only — NO driver_id column. The brief
--   stated otherwise; verified at index.html:21787-21795 and at
--   Horizon Star LLC Driver App/.../Models.swift:235-244 (Expense / ExpenseCreate).
--   So driver scoping is via trips.driver_id.
--
--   Drivers MAY SELECT/INSERT/UPDATE on expenses for trips they own.
--   Drivers MAY NOT DELETE expenses (FMCSA §390.31(c) cost-records retention
--   discipline; expenses feed payroll snapshots).
-- ---------------------------------------------------------------------------
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.expenses;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.expenses;
DROP POLICY IF EXISTS "Enable update for all users" ON public.expenses;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.expenses;
DROP POLICY IF EXISTS "Authenticated users can view expenses" ON public.expenses;
DROP POLICY IF EXISTS "Authenticated users can insert expenses" ON public.expenses;
DROP POLICY IF EXISTS "Authenticated users can update expenses" ON public.expenses;
DROP POLICY IF EXISTS "Authenticated users can delete expenses" ON public.expenses;
DROP POLICY IF EXISTS "expenses_select" ON public.expenses;
DROP POLICY IF EXISTS "expenses_insert" ON public.expenses;
DROP POLICY IF EXISTS "expenses_update" ON public.expenses;
DROP POLICY IF EXISTS "expenses_delete" ON public.expenses;

CREATE POLICY "expenses_select" ON public.expenses
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.trips t
        WHERE t.id = expenses.trip_id
          AND t.driver_id = (SELECT public.current_driver_id())
      )
    )
  );

CREATE POLICY "expenses_insert" ON public.expenses
  FOR INSERT WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.trips t
        WHERE t.id = expenses.trip_id
          AND t.driver_id = (SELECT public.current_driver_id())
      )
    )
  );

CREATE POLICY "expenses_update" ON public.expenses
  FOR UPDATE USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.trips t
        WHERE t.id = expenses.trip_id
          AND t.driver_id = (SELECT public.current_driver_id())
      )
    )
  ) WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.trips t
        WHERE t.id = expenses.trip_id
          AND t.driver_id = (SELECT public.current_driver_id())
      )
    )
  );

CREATE POLICY "expenses_delete" ON public.expenses
  FOR DELETE USING ((SELECT public.is_tms_staff()));

-- ---------------------------------------------------------------------------
-- 8. fuel_transactions
--   Columns (from index.html:26442-26458 saveFuelTransactions): txn_number,
--   truck_number (TEXT, not FK), card_number, driver_name (TEXT, not FK),
--   transaction_date, city, state, location, product, gallons, retail_amount,
--   amount, savings.
--
--   Driver scoping path: fuel_transactions.truck_number → trucks.truck_number
--     → trucks.id → trips.truck_id → trips.driver_id = current_driver_id().
--
--   Writes are import-only (PDF parser in TMS); drivers do not insert. Staff
--   only for INSERT/UPDATE/DELETE.
-- ---------------------------------------------------------------------------
ALTER TABLE public.fuel_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.fuel_transactions;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.fuel_transactions;
DROP POLICY IF EXISTS "Enable update for all users" ON public.fuel_transactions;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.fuel_transactions;
DROP POLICY IF EXISTS "Authenticated users can view fuel_transactions" ON public.fuel_transactions;
DROP POLICY IF EXISTS "Authenticated users can insert fuel_transactions" ON public.fuel_transactions;
DROP POLICY IF EXISTS "Authenticated users can update fuel_transactions" ON public.fuel_transactions;
DROP POLICY IF EXISTS "Authenticated users can delete fuel_transactions" ON public.fuel_transactions;
DROP POLICY IF EXISTS "fuel_select" ON public.fuel_transactions;
DROP POLICY IF EXISTS "fuel_insert" ON public.fuel_transactions;
DROP POLICY IF EXISTS "fuel_update" ON public.fuel_transactions;
DROP POLICY IF EXISTS "fuel_delete" ON public.fuel_transactions;

CREATE POLICY "fuel_select" ON public.fuel_transactions
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM public.trucks tr
        JOIN public.trips tp ON tp.truck_id = tr.id
        WHERE tr.truck_number = fuel_transactions.truck_number
          AND tp.driver_id = (SELECT public.current_driver_id())
      )
    )
  );

CREATE POLICY "fuel_insert" ON public.fuel_transactions
  FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));

CREATE POLICY "fuel_update" ON public.fuel_transactions
  FOR UPDATE USING ((SELECT public.is_tms_staff()))
  WITH CHECK ((SELECT public.is_tms_staff()));

CREATE POLICY "fuel_delete" ON public.fuel_transactions
  FOR DELETE USING ((SELECT public.is_tms_staff()));

-- Index supporting the fuel_select driver-scope predicate. Without it the
-- USING clause Seq-Scans trucks (~50 rows) and trips (~10K+) per fuel row.
CREATE INDEX IF NOT EXISTS idx_trucks_truck_number
  ON public.trucks(truck_number);

-- ---------------------------------------------------------------------------
-- 9. maintenance_records
--   Columns (from index.html:28524-28560): id, truck_id, service_type,
--   service_date, total_cost, shop_name, notes, invoice_file, invoice_filename.
--   No driver linkage — staff-only by design.
-- ---------------------------------------------------------------------------
ALTER TABLE public.maintenance_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.maintenance_records;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.maintenance_records;
DROP POLICY IF EXISTS "Enable update for all users" ON public.maintenance_records;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.maintenance_records;
DROP POLICY IF EXISTS "Authenticated users can view maintenance_records" ON public.maintenance_records;
DROP POLICY IF EXISTS "Authenticated users can insert maintenance_records" ON public.maintenance_records;
DROP POLICY IF EXISTS "Authenticated users can update maintenance_records" ON public.maintenance_records;
DROP POLICY IF EXISTS "Authenticated users can delete maintenance_records" ON public.maintenance_records;
DROP POLICY IF EXISTS "maint_select" ON public.maintenance_records;
DROP POLICY IF EXISTS "maint_insert" ON public.maintenance_records;
DROP POLICY IF EXISTS "maint_update" ON public.maintenance_records;
DROP POLICY IF EXISTS "maint_delete" ON public.maintenance_records;

CREATE POLICY "maint_select" ON public.maintenance_records
  FOR SELECT USING ((SELECT public.is_tms_staff()));

CREATE POLICY "maint_insert" ON public.maintenance_records
  FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));

CREATE POLICY "maint_update" ON public.maintenance_records
  FOR UPDATE USING ((SELECT public.is_tms_staff()))
  WITH CHECK ((SELECT public.is_tms_staff()));

CREATE POLICY "maint_delete" ON public.maintenance_records
  FOR DELETE USING ((SELECT public.is_tms_staff()));

-- ---------------------------------------------------------------------------
-- 10. driver_notifications
--   Existing state: 8 inline-checked policies from
--     20260212000100_auth_storage_hardening.sql:356-465.
--   Replace with helper-based equivalents so role/status changes auto-revoke.
--   Staff: full. Driver: SELECT/UPDATE on own. ADMIN-only DELETE.
-- ---------------------------------------------------------------------------
ALTER TABLE public.driver_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.driver_notifications;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.driver_notifications;
DROP POLICY IF EXISTS "Enable update for all users" ON public.driver_notifications;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.driver_notifications;
DROP POLICY IF EXISTS "Authenticated users can view notifications" ON public.driver_notifications;
DROP POLICY IF EXISTS "Authenticated users can insert notifications" ON public.driver_notifications;
DROP POLICY IF EXISTS "Authenticated users can update notifications" ON public.driver_notifications;
DROP POLICY IF EXISTS "Authenticated users can delete notifications" ON public.driver_notifications;
DROP POLICY IF EXISTS "TMS users can read notifications" ON public.driver_notifications;
DROP POLICY IF EXISTS "TMS users can insert notifications" ON public.driver_notifications;
DROP POLICY IF EXISTS "TMS users can update notifications" ON public.driver_notifications;
DROP POLICY IF EXISTS "TMS users can delete notifications" ON public.driver_notifications;
DROP POLICY IF EXISTS "Drivers can read own notifications" ON public.driver_notifications;
DROP POLICY IF EXISTS "Drivers can insert own notifications" ON public.driver_notifications;
DROP POLICY IF EXISTS "Drivers can update own notifications" ON public.driver_notifications;
DROP POLICY IF EXISTS "Drivers can delete own notifications" ON public.driver_notifications;
DROP POLICY IF EXISTS "dn_select" ON public.driver_notifications;
DROP POLICY IF EXISTS "dn_insert" ON public.driver_notifications;
DROP POLICY IF EXISTS "dn_update" ON public.driver_notifications;
DROP POLICY IF EXISTS "dn_delete" ON public.driver_notifications;

CREATE POLICY "dn_select" ON public.driver_notifications
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND driver_notifications.driver_id = (SELECT public.current_driver_id())
    )
  );

-- INSERT: staff create push notifications. Drivers do NOT insert (server
-- side or staff only) — closes Security H1 driver-INSERT scope-escalation.
CREATE POLICY "dn_insert" ON public.driver_notifications
  FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));

-- UPDATE: staff full; driver only on own row, only to flip is_read et al.
-- (Column-level restrictions are not enforced by RLS — application layer.)
CREATE POLICY "dn_update" ON public.driver_notifications
  FOR UPDATE USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND driver_notifications.driver_id = (SELECT public.current_driver_id())
    )
  ) WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND driver_notifications.driver_id = (SELECT public.current_driver_id())
    )
  );

-- DELETE: ADMIN only — preserves notification audit trail for FMCSA disputes.
CREATE POLICY "dn_delete" ON public.driver_notifications
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role = 'ADMIN'
    )
  );

-- ---------------------------------------------------------------------------
-- 11. company_files
--   Existing: USING (true) on all 4 ops from 20260121000000_company_files.sql.
--   Compliance documents (qualification, insurance, IFTA decals). Staff only.
-- ---------------------------------------------------------------------------
ALTER TABLE public.company_files ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for all users" ON public.company_files;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.company_files;
DROP POLICY IF EXISTS "Enable update for all users" ON public.company_files;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.company_files;
DROP POLICY IF EXISTS "cf_select" ON public.company_files;
DROP POLICY IF EXISTS "cf_insert" ON public.company_files;
DROP POLICY IF EXISTS "cf_update" ON public.company_files;
DROP POLICY IF EXISTS "cf_delete" ON public.company_files;

CREATE POLICY "cf_select" ON public.company_files
  FOR SELECT USING ((SELECT public.is_tms_staff()));

CREATE POLICY "cf_insert" ON public.company_files
  FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));

CREATE POLICY "cf_update" ON public.company_files
  FOR UPDATE USING ((SELECT public.is_tms_staff()))
  WITH CHECK ((SELECT public.is_tms_staff()));

CREATE POLICY "cf_delete" ON public.company_files
  FOR DELETE USING ((SELECT public.is_tms_staff()));

-- ---------------------------------------------------------------------------
-- 12. dealers
--   Existing: USING (true) on all 4 ops from 20260123000000_dealer_portal.sql:29-33.
--   Staff: full. Dealer: SELECT only own row. Driver: NO access.
--   uniq_dealers_user_id (created in 20260429140000) makes current_dealer_id
--   deterministic.
-- ---------------------------------------------------------------------------
ALTER TABLE public.dealers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read for all authenticated" ON public.dealers;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.dealers;
DROP POLICY IF EXISTS "Enable update for all users" ON public.dealers;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.dealers;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.dealers;
DROP POLICY IF EXISTS "dealers_select" ON public.dealers;
DROP POLICY IF EXISTS "dealers_insert" ON public.dealers;
DROP POLICY IF EXISTS "dealers_update" ON public.dealers;
DROP POLICY IF EXISTS "dealers_delete" ON public.dealers;

CREATE POLICY "dealers_select" ON public.dealers
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.is_dealer_user())
      AND dealers.id = (SELECT public.current_dealer_id())
    )
  );

-- Dealer rows are provisioned by staff after dealer_applications approval —
-- dealers cannot self-register a row.
CREATE POLICY "dealers_insert" ON public.dealers
  FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));

-- Dealer self-edit on contact info is allowed (TMS staff still has full).
CREATE POLICY "dealers_update" ON public.dealers
  FOR UPDATE USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.is_dealer_user())
      AND dealers.id = (SELECT public.current_dealer_id())
    )
  ) WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.is_dealer_user())
      AND dealers.id = (SELECT public.current_dealer_id())
    )
  );

CREATE POLICY "dealers_delete" ON public.dealers
  FOR DELETE USING ((SELECT public.is_tms_staff()));

-- ---------------------------------------------------------------------------
-- 13. dealer_order_messages
--   Existing: USING (true) per 20260313000300_dealer_portal_overhaul.sql:32-35.
--   Staff: full. Dealer: SELECT/INSERT only on own dealer_id rows. Driver: no.
--   No DELETE at all (audit trail preserved).
-- ---------------------------------------------------------------------------
ALTER TABLE public.dealer_order_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "dom_select" ON public.dealer_order_messages;
DROP POLICY IF EXISTS "dom_insert" ON public.dealer_order_messages;
DROP POLICY IF EXISTS "dom_update" ON public.dealer_order_messages;
DROP POLICY IF EXISTS "dom_delete" ON public.dealer_order_messages;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.dealer_order_messages;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.dealer_order_messages;
DROP POLICY IF EXISTS "Enable update for all users" ON public.dealer_order_messages;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.dealer_order_messages;

CREATE POLICY "dom_select" ON public.dealer_order_messages
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.is_dealer_user())
      AND dealer_order_messages.dealer_id = (SELECT public.current_dealer_id())
    )
  );

-- Dealers may post messages but only as sender_type='dealer' on their own
-- dealer_id. Staff posts as 'dispatcher'. RLS cannot enforce sender_type
-- shape — schema CHECK constraint already does (20260313000300:23).
-- FIX 5: Additionally require that the order_id belongs to an order owned
-- by the dealer's tenant — closes cross-tenant write where a dealer could
-- post into another dealer's order thread.
CREATE POLICY "dom_insert" ON public.dealer_order_messages
  FOR INSERT WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.is_dealer_user())
      AND dealer_order_messages.dealer_id = (SELECT public.current_dealer_id())
      AND dealer_order_messages.sender_type = 'dealer'
      AND EXISTS (
        SELECT 1 FROM public.orders o
        WHERE o.id = dealer_order_messages.order_id
          AND o.dealer_id = (SELECT public.current_dealer_id())
      )
    )
  );

-- UPDATE: staff only — typically used to mark is_read=true server-side.
-- Dealers re-mark via separate RPC if needed; tightening here closes
-- message-tampering vector.
CREATE POLICY "dom_update" ON public.dealer_order_messages
  FOR UPDATE USING ((SELECT public.is_tms_staff()))
  WITH CHECK ((SELECT public.is_tms_staff()));

-- DELETE: deny entirely. Audit trail. Staff who need to redact use UPDATE
-- to overwrite the message column via the application.
CREATE POLICY "dom_delete" ON public.dealer_order_messages
  FOR DELETE USING (false);

-- ---------------------------------------------------------------------------
-- 14. order_status_history
--   Existing: USING (true) per 20260313000300_dealer_portal_overhaul.sql:14-16.
--   Staff: full. Driver: SELECT on rows tied to assigned trips. Dealer: SELECT
--   on rows tied to their own orders.
--   No driver/dealer INSERT — status changes happen via app code with staff
--   credentials, or via dealer-side change-request flow that the app stamps.
-- ---------------------------------------------------------------------------
ALTER TABLE public.order_status_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "osh_select" ON public.order_status_history;
DROP POLICY IF EXISTS "osh_insert" ON public.order_status_history;
DROP POLICY IF EXISTS "osh_update" ON public.order_status_history;
DROP POLICY IF EXISTS "osh_delete" ON public.order_status_history;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.order_status_history;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.order_status_history;
DROP POLICY IF EXISTS "Enable update for all users" ON public.order_status_history;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.order_status_history;

CREATE POLICY "osh_select" ON public.order_status_history
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.current_driver_id()) IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.orders o
        LEFT JOIN public.trips t ON t.id = o.trip_id
        WHERE o.id = order_status_history.order_id
          AND (
            o.driver_id = (SELECT public.current_driver_id())
            OR t.driver_id = (SELECT public.current_driver_id())
          )
      )
    )
    OR (
      (SELECT public.is_dealer_user())
      AND EXISTS (
        SELECT 1 FROM public.orders o
        WHERE o.id = order_status_history.order_id
          AND o.dealer_id = (SELECT public.current_dealer_id())
      )
    )
  );

-- INSERT: staff only. Drivers and dealers must NOT write history rows
-- directly — closes Security H1 (driver INSERT into orders/related). Driver
-- status updates flow through app-server-mediated RPC that runs as staff.
CREATE POLICY "osh_insert" ON public.order_status_history
  FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));

-- UPDATE: deny entirely — history is append-only.
CREATE POLICY "osh_update" ON public.order_status_history
  FOR UPDATE USING (false) WITH CHECK (false);

CREATE POLICY "osh_delete" ON public.order_status_history
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role = 'ADMIN'
    )
  );

-- ---------------------------------------------------------------------------
-- 15. order_change_requests
--   Existing: USING (true) per 20260313000300_dealer_portal_overhaul.sql:55-58.
--   Dealer: SELECT/INSERT/UPDATE on own dealer_id rows. Staff: full.
--   Driver: NO access (the dealer/staff workflow only).
-- ---------------------------------------------------------------------------
ALTER TABLE public.order_change_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ocr_select" ON public.order_change_requests;
DROP POLICY IF EXISTS "ocr_insert" ON public.order_change_requests;
DROP POLICY IF EXISTS "ocr_update" ON public.order_change_requests;
DROP POLICY IF EXISTS "ocr_delete" ON public.order_change_requests;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.order_change_requests;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.order_change_requests;
DROP POLICY IF EXISTS "Enable update for all users" ON public.order_change_requests;
DROP POLICY IF EXISTS "Enable delete for all users" ON public.order_change_requests;

CREATE POLICY "ocr_select" ON public.order_change_requests
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.is_dealer_user())
      AND order_change_requests.dealer_id = (SELECT public.current_dealer_id())
    )
  );

CREATE POLICY "ocr_insert" ON public.order_change_requests
  FOR INSERT WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.is_dealer_user())
      AND order_change_requests.dealer_id = (SELECT public.current_dealer_id())
      -- Dealers may only create 'pending' requests; status transitions
      -- (approved/rejected) require staff via UPDATE policy below.
      AND order_change_requests.status = 'pending'
    )
  );

-- UPDATE split: dealer can edit their pending request (e.g. revise reason);
-- only staff can transition status to approved/rejected. We can't enforce
-- the status transition column-by-column in RLS, so we mirror SELECT/INSERT
-- predicate and rely on application code + reviewed_by/reviewed_at integrity.
CREATE POLICY "ocr_update" ON public.order_change_requests
  FOR UPDATE USING (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.is_dealer_user())
      AND order_change_requests.dealer_id = (SELECT public.current_dealer_id())
      AND order_change_requests.status = 'pending'
    )
  ) WITH CHECK (
    (SELECT public.is_tms_staff())
    OR (
      (SELECT public.is_dealer_user())
      AND order_change_requests.dealer_id = (SELECT public.current_dealer_id())
      -- Dealer cannot self-approve: WITH CHECK forbids transitioning out of
      -- 'pending' from the dealer side.
      AND order_change_requests.status = 'pending'
    )
  );

CREATE POLICY "ocr_delete" ON public.order_change_requests
  FOR DELETE USING ((SELECT public.is_tms_staff()));

-- ---------------------------------------------------------------------------
-- Sanity: verify every table we touched has RLS enabled and at least one
-- policy. Raises NOTICE only — does not fail the migration.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t TEXT;
  has_rls BOOLEAN;
  policy_count INTEGER;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'vehicle_inspections', 'inspection_photos', 'inspection_videos',
    'inspection_damages', 'trucks', 'brokers', 'expenses',
    'fuel_transactions', 'maintenance_records', 'driver_notifications',
    'company_files', 'dealers', 'dealer_order_messages',
    'order_status_history', 'order_change_requests'
  ]
  LOOP
    SELECT relrowsecurity INTO has_rls
    FROM pg_class
    WHERE relnamespace = 'public'::regnamespace
      AND relname = t;

    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = t;

    IF NOT COALESCE(has_rls, false) THEN
      RAISE WARNING 'P0d sanity: % does not have RLS enabled', t;
    END IF;

    IF policy_count = 0 THEN
      RAISE WARNING 'P0d sanity: % has zero policies (table is now inaccessible)', t;
    ELSE
      RAISE NOTICE 'P0d sanity: % OK (% policies)', t, policy_count;
    END IF;
  END LOOP;
END$$;

COMMIT;
