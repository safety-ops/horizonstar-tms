-- Rollback for 20260429160000_rls_tier1.sql.
--
-- Restores the pre-Tier-1 policies for the 15 tables touched by that
-- migration. Drops the helper-based policies, then recreates the loose
-- pre-existing policies that were in place before P0d. Use ONLY if the
-- Tier 1 lock-down causes a production outage.
--
-- Order of operations:
--   1. DROP every helper-based policy this migration created.
--   2. Re-create the prior permissive policies for tables that had them.
--   3. Leave RLS ENABLED on tables that were freshly turned on (trucks,
--      brokers, expenses, fuel_transactions, maintenance_records) but
--      add `Enable * for all users` policies so the app keeps functioning
--      while we triage. RLS+open-policies = pre-Tier-1 effective state.
--
-- The fuel_transactions truck_number index is left in place — it's a
-- pure read-perf win unrelated to the policies.

BEGIN;

-- 0. Restore the helper functions to their pre-Tier-1 definitions
--    (without the dual-role NOT is_dealer_user() guard added by FIX 3).
--    Sources: supabase/migrations/20260429140000_rls_helpers.sql
CREATE OR REPLACE FUNCTION public.current_driver_id() RETURNS INTEGER
  LANGUAGE sql STABLE PARALLEL SAFE SECURITY DEFINER
  SET search_path = public, pg_temp AS $$
  SELECT id FROM public.drivers
  WHERE auth_user_id = auth.uid()
    AND status = 'ACTIVE'
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.current_local_driver_id() RETURNS INTEGER
  LANGUAGE sql STABLE PARALLEL SAFE SECURITY DEFINER
  SET search_path = public, pg_temp AS $$
  SELECT id FROM public.local_drivers
  WHERE auth_user_id = auth.uid()
    AND status = 'ACTIVE'
  LIMIT 1;
$$;

-- 1. vehicle_inspections
DROP POLICY IF EXISTS "vi_select" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "vi_insert" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "vi_update" ON public.vehicle_inspections;
DROP POLICY IF EXISTS "vi_delete" ON public.vehicle_inspections;

CREATE POLICY "Enable read access for all users" ON public.vehicle_inspections
  FOR SELECT USING (true);
-- Restore the driver-scoped writes from 20260211173600 (the closest
-- pre-Tier-1 state — they were not removed, just superseded).
CREATE POLICY "Drivers can insert own inspections" ON public.vehicle_inspections
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.id = vehicle_inspections.driver_id
        AND d.auth_user_id = auth.uid()
    )
  );
CREATE POLICY "Drivers can update own inspections" ON public.vehicle_inspections
  FOR UPDATE USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.id = vehicle_inspections.driver_id
        AND d.auth_user_id = auth.uid()
    )
  ) WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.id = vehicle_inspections.driver_id
        AND d.auth_user_id = auth.uid()
    )
  );
CREATE POLICY "Drivers can delete own inspections" ON public.vehicle_inspections
  FOR DELETE USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.id = vehicle_inspections.driver_id
        AND d.auth_user_id = auth.uid()
    )
  );

-- 2. inspection_photos
DROP POLICY IF EXISTS "ip_select" ON public.inspection_photos;
DROP POLICY IF EXISTS "ip_insert" ON public.inspection_photos;
DROP POLICY IF EXISTS "ip_update" ON public.inspection_photos;
DROP POLICY IF EXISTS "ip_delete" ON public.inspection_photos;

CREATE POLICY "Enable read access for all users" ON public.inspection_photos
  FOR SELECT USING (true);
CREATE POLICY "Drivers can insert own inspection photos" ON public.inspection_photos
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.vehicle_inspections vi
      JOIN public.drivers d ON d.id = vi.driver_id
      WHERE vi.id = inspection_photos.inspection_id
        AND d.auth_user_id = auth.uid()
    )
  );
CREATE POLICY "Drivers can delete own inspection photos" ON public.inspection_photos
  FOR DELETE USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.vehicle_inspections vi
      JOIN public.drivers d ON d.id = vi.driver_id
      WHERE vi.id = inspection_photos.inspection_id
        AND d.auth_user_id = auth.uid()
    )
  );

-- 3. inspection_videos
DROP POLICY IF EXISTS "iv_select" ON public.inspection_videos;
DROP POLICY IF EXISTS "iv_insert" ON public.inspection_videos;
DROP POLICY IF EXISTS "iv_update" ON public.inspection_videos;
DROP POLICY IF EXISTS "iv_delete" ON public.inspection_videos;

CREATE POLICY "Enable read access for all users" ON public.inspection_videos
  FOR SELECT USING (true);
CREATE POLICY "Drivers can insert own inspection videos" ON public.inspection_videos
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.vehicle_inspections vi
      JOIN public.drivers d ON d.id = vi.driver_id
      WHERE vi.id = inspection_videos.inspection_id
        AND d.auth_user_id = auth.uid()
    )
  );
CREATE POLICY "Drivers can delete own inspection videos" ON public.inspection_videos
  FOR DELETE USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.vehicle_inspections vi
      JOIN public.drivers d ON d.id = vi.driver_id
      WHERE vi.id = inspection_videos.inspection_id
        AND d.auth_user_id = auth.uid()
    )
  );

-- 4. inspection_damages
DROP POLICY IF EXISTS "id_select" ON public.inspection_damages;
DROP POLICY IF EXISTS "id_insert" ON public.inspection_damages;
DROP POLICY IF EXISTS "id_update" ON public.inspection_damages;
DROP POLICY IF EXISTS "id_delete" ON public.inspection_damages;

CREATE POLICY "Enable read access for all users" ON public.inspection_damages
  FOR SELECT USING (true);
CREATE POLICY "Drivers can insert own inspection damages" ON public.inspection_damages
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.vehicle_inspections vi
      JOIN public.drivers d ON d.id = vi.driver_id
      WHERE vi.id = inspection_damages.inspection_id
        AND d.auth_user_id = auth.uid()
    )
  );
CREATE POLICY "Drivers can update own inspection damages" ON public.inspection_damages
  FOR UPDATE USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.vehicle_inspections vi
      JOIN public.drivers d ON d.id = vi.driver_id
      WHERE vi.id = inspection_damages.inspection_id
        AND d.auth_user_id = auth.uid()
    )
  ) WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.vehicle_inspections vi
      JOIN public.drivers d ON d.id = vi.driver_id
      WHERE vi.id = inspection_damages.inspection_id
        AND d.auth_user_id = auth.uid()
    )
  );
CREATE POLICY "Drivers can delete own inspection damages" ON public.inspection_damages
  FOR DELETE USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.vehicle_inspections vi
      JOIN public.drivers d ON d.id = vi.driver_id
      WHERE vi.id = inspection_damages.inspection_id
        AND d.auth_user_id = auth.uid()
    )
  );

-- 5. trucks  (no in-repo prior policies — RLS was OFF entirely. Disable it
--    to truly restore pre-Tier-1 state. FIX 7.)
DROP POLICY IF EXISTS "trucks_select" ON public.trucks;
DROP POLICY IF EXISTS "trucks_insert" ON public.trucks;
DROP POLICY IF EXISTS "trucks_update" ON public.trucks;
DROP POLICY IF EXISTS "trucks_delete" ON public.trucks;
ALTER TABLE public.trucks DISABLE ROW LEVEL SECURITY;

-- 6. brokers  (RLS was OFF pre-Tier-1; disable. FIX 7.)
DROP POLICY IF EXISTS "brokers_select" ON public.brokers;
DROP POLICY IF EXISTS "brokers_insert" ON public.brokers;
DROP POLICY IF EXISTS "brokers_update" ON public.brokers;
DROP POLICY IF EXISTS "brokers_delete" ON public.brokers;
ALTER TABLE public.brokers DISABLE ROW LEVEL SECURITY;

-- 7. expenses  (RLS was nominally enabled by app convention but with no
--    policies. Restore the prior open-policy posture so app keeps working.)
DROP POLICY IF EXISTS "expenses_select" ON public.expenses;
DROP POLICY IF EXISTS "expenses_insert" ON public.expenses;
DROP POLICY IF EXISTS "expenses_update" ON public.expenses;
DROP POLICY IF EXISTS "expenses_delete" ON public.expenses;
CREATE POLICY "Enable read access for all users" ON public.expenses FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON public.expenses FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON public.expenses FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON public.expenses FOR DELETE USING (true);

-- 8. fuel_transactions  (RLS was OFF pre-Tier-1; disable. FIX 7.)
DROP POLICY IF EXISTS "fuel_select" ON public.fuel_transactions;
DROP POLICY IF EXISTS "fuel_insert" ON public.fuel_transactions;
DROP POLICY IF EXISTS "fuel_update" ON public.fuel_transactions;
DROP POLICY IF EXISTS "fuel_delete" ON public.fuel_transactions;
ALTER TABLE public.fuel_transactions DISABLE ROW LEVEL SECURITY;

-- 9. maintenance_records  (RLS was OFF pre-Tier-1; disable. FIX 7.)
DROP POLICY IF EXISTS "maint_select" ON public.maintenance_records;
DROP POLICY IF EXISTS "maint_insert" ON public.maintenance_records;
DROP POLICY IF EXISTS "maint_update" ON public.maintenance_records;
DROP POLICY IF EXISTS "maint_delete" ON public.maintenance_records;
ALTER TABLE public.maintenance_records DISABLE ROW LEVEL SECURITY;

-- 10. driver_notifications  (restore the 20260212000100 inline-checked policies)
DROP POLICY IF EXISTS "dn_select" ON public.driver_notifications;
DROP POLICY IF EXISTS "dn_insert" ON public.driver_notifications;
DROP POLICY IF EXISTS "dn_update" ON public.driver_notifications;
DROP POLICY IF EXISTS "dn_delete" ON public.driver_notifications;

CREATE POLICY "TMS users can read notifications" ON public.driver_notifications
  FOR SELECT USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true
    )
  );
CREATE POLICY "TMS users can insert notifications" ON public.driver_notifications
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true
    )
  );
CREATE POLICY "TMS users can update notifications" ON public.driver_notifications
  FOR UPDATE USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true
    )
  ) WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true
    )
  );
CREATE POLICY "TMS users can delete notifications" ON public.driver_notifications
  FOR DELETE USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true
    )
  );
CREATE POLICY "Drivers can read own notifications" ON public.driver_notifications
  FOR SELECT USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.auth_user_id = auth.uid()
        AND d.id = driver_notifications.driver_id
    )
  );
CREATE POLICY "Drivers can insert own notifications" ON public.driver_notifications
  FOR INSERT WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.auth_user_id = auth.uid()
        AND d.id = driver_notifications.driver_id
    )
  );
CREATE POLICY "Drivers can update own notifications" ON public.driver_notifications
  FOR UPDATE USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.auth_user_id = auth.uid()
        AND d.id = driver_notifications.driver_id
    )
  ) WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.auth_user_id = auth.uid()
        AND d.id = driver_notifications.driver_id
    )
  );
CREATE POLICY "Drivers can delete own notifications" ON public.driver_notifications
  FOR DELETE USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.drivers d
      WHERE d.auth_user_id = auth.uid()
        AND d.id = driver_notifications.driver_id
    )
  );

-- 11. company_files
DROP POLICY IF EXISTS "cf_select" ON public.company_files;
DROP POLICY IF EXISTS "cf_insert" ON public.company_files;
DROP POLICY IF EXISTS "cf_update" ON public.company_files;
DROP POLICY IF EXISTS "cf_delete" ON public.company_files;
CREATE POLICY "Enable read access for all users" ON public.company_files FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON public.company_files FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON public.company_files FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON public.company_files FOR DELETE USING (true);

-- 12. dealers
DROP POLICY IF EXISTS "dealers_select" ON public.dealers;
DROP POLICY IF EXISTS "dealers_insert" ON public.dealers;
DROP POLICY IF EXISTS "dealers_update" ON public.dealers;
DROP POLICY IF EXISTS "dealers_delete" ON public.dealers;
CREATE POLICY "Enable read for all authenticated" ON public.dealers FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON public.dealers FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON public.dealers FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON public.dealers FOR DELETE USING (true);

-- 13. dealer_order_messages  (FIX 7: include DELETE policy so rollback
--     produces a fully-open posture; the original 20260313000300 had no
--     DELETE policy because RLS was effectively wide-open at the time.)
DROP POLICY IF EXISTS "dom_select" ON public.dealer_order_messages;
DROP POLICY IF EXISTS "dom_insert" ON public.dealer_order_messages;
DROP POLICY IF EXISTS "dom_update" ON public.dealer_order_messages;
DROP POLICY IF EXISTS "dom_delete" ON public.dealer_order_messages;
CREATE POLICY "dom_select" ON public.dealer_order_messages FOR SELECT USING (true);
CREATE POLICY "dom_insert" ON public.dealer_order_messages FOR INSERT WITH CHECK (true);
CREATE POLICY "dom_update" ON public.dealer_order_messages FOR UPDATE USING (true);
CREATE POLICY "dom_delete" ON public.dealer_order_messages FOR DELETE USING (true);

-- 14. order_status_history  (FIX 7: include DELETE policy.)
DROP POLICY IF EXISTS "osh_select" ON public.order_status_history;
DROP POLICY IF EXISTS "osh_insert" ON public.order_status_history;
DROP POLICY IF EXISTS "osh_update" ON public.order_status_history;
DROP POLICY IF EXISTS "osh_delete" ON public.order_status_history;
CREATE POLICY "osh_select" ON public.order_status_history FOR SELECT USING (true);
CREATE POLICY "osh_insert" ON public.order_status_history FOR INSERT WITH CHECK (true);
CREATE POLICY "osh_delete" ON public.order_status_history FOR DELETE USING (true);

-- 15. order_change_requests  (FIX 7: include DELETE policy.)
DROP POLICY IF EXISTS "ocr_select" ON public.order_change_requests;
DROP POLICY IF EXISTS "ocr_insert" ON public.order_change_requests;
DROP POLICY IF EXISTS "ocr_update" ON public.order_change_requests;
DROP POLICY IF EXISTS "ocr_delete" ON public.order_change_requests;
CREATE POLICY "ocr_select" ON public.order_change_requests FOR SELECT USING (true);
CREATE POLICY "ocr_insert" ON public.order_change_requests FOR INSERT WITH CHECK (true);
CREATE POLICY "ocr_update" ON public.order_change_requests FOR UPDATE USING (true);
CREATE POLICY "ocr_delete" ON public.order_change_requests FOR DELETE USING (true);

-- The idx_trucks_truck_number index is intentionally retained — it is a
-- read-perf win that does not depend on any policy.

COMMIT;
