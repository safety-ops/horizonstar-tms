-- ============================================================
-- Migration: 20260508170000_driver_truck_files_rls_tighten.sql
-- Purpose:   Replace permissive driver_files / truck_files RLS
--            policies (qual = `auth.uid() IS NOT NULL`) with
--            principal-scoped quals so authenticated drivers,
--            brokers, dealers cannot read/write each other's
--            (or company-only) compliance documents.
--
-- Background
--   driver_files holds driver license, medical card, W-9,
--   background check, and other PII-bearing compliance docs
--   stored as base64 in `file_data TEXT`.
--   truck_files holds truck registration, insurance, and
--   inspection paperwork — company assets.
--
--   Audit (2026-05-08) confirmed the existing policies
--   driver_files_{select,insert,update,delete} and
--   truck_files_{select,insert,update,delete} all evaluate
--   `auth.uid() IS NOT NULL` — i.e., every logged-in driver,
--   broker, dealer, or staff member can read every other
--   driver's license + medical card. Severity P0.
--
-- New behavior
--   driver_files:
--     SELECT: is_tms_staff()  OR  driver_id = current_driver_id()
--     INSERT: is_tms_staff()  OR  driver_id = current_driver_id()
--     UPDATE: is_tms_staff()                    (immutable after submit for drivers)
--     DELETE: is_tms_staff()                    (admin retention only)
--
--   truck_files (company assets — TMS staff only):
--     SELECT/INSERT/UPDATE/DELETE: is_tms_staff()
--
-- Helper functions used
--   public.is_tms_staff()        — defined in 20260429140000_rls_helpers.sql
--   public.current_driver_id()   — defined in 20260429140000_rls_helpers.sql
--
-- Rollback
--   See supabase/rollbacks/20260508170000_driver_truck_files_rls_tighten.down.sql
-- ============================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- driver_files — drop permissive, recreate principal-scoped
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS driver_files_select ON public.driver_files;
DROP POLICY IF EXISTS driver_files_insert ON public.driver_files;
DROP POLICY IF EXISTS driver_files_update ON public.driver_files;
DROP POLICY IF EXISTS driver_files_delete ON public.driver_files;

CREATE POLICY driver_files_select
  ON public.driver_files
  FOR SELECT
  TO authenticated
  USING (
    public.is_tms_staff()
    OR driver_id = public.current_driver_id()
  );

CREATE POLICY driver_files_insert
  ON public.driver_files
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_tms_staff()
    OR driver_id = public.current_driver_id()
  );

CREATE POLICY driver_files_update
  ON public.driver_files
  FOR UPDATE
  TO authenticated
  USING (public.is_tms_staff())
  WITH CHECK (public.is_tms_staff());

CREATE POLICY driver_files_delete
  ON public.driver_files
  FOR DELETE
  TO authenticated
  USING (public.is_tms_staff());

-- ─────────────────────────────────────────────────────────────────────────────
-- truck_files — TMS staff only (company assets)
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS truck_files_select ON public.truck_files;
DROP POLICY IF EXISTS truck_files_insert ON public.truck_files;
DROP POLICY IF EXISTS truck_files_update ON public.truck_files;
DROP POLICY IF EXISTS truck_files_delete ON public.truck_files;

CREATE POLICY truck_files_select
  ON public.truck_files
  FOR SELECT
  TO authenticated
  USING (public.is_tms_staff());

CREATE POLICY truck_files_insert
  ON public.truck_files
  FOR INSERT
  TO authenticated
  WITH CHECK (public.is_tms_staff());

CREATE POLICY truck_files_update
  ON public.truck_files
  FOR UPDATE
  TO authenticated
  USING (public.is_tms_staff())
  WITH CHECK (public.is_tms_staff());

CREATE POLICY truck_files_delete
  ON public.truck_files
  FOR DELETE
  TO authenticated
  USING (public.is_tms_staff());

-- ─────────────────────────────────────────────────────────────────────────────
-- Verify RLS is still enabled (defensive — should be no-op).
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.driver_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.truck_files  ENABLE ROW LEVEL SECURITY;
