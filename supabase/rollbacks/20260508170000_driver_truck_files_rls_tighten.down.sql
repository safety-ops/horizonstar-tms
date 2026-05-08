-- Rollback for 20260508170000_driver_truck_files_rls_tighten.sql
-- Reverts driver_files / truck_files to the permissive policies
-- that existed BEFORE the tighten (qual: auth.uid() IS NOT NULL).
--
-- WARNING: applying this rollback re-exposes driver licenses,
-- medical cards, W-9s, and truck paperwork to every authenticated
-- principal (drivers, brokers, dealers). Only run if a regression
-- in the iOS driver app or the dealer portal is traced to this
-- migration AND a forward-fix is being prepared.

DROP POLICY IF EXISTS driver_files_select ON public.driver_files;
DROP POLICY IF EXISTS driver_files_insert ON public.driver_files;
DROP POLICY IF EXISTS driver_files_update ON public.driver_files;
DROP POLICY IF EXISTS driver_files_delete ON public.driver_files;

CREATE POLICY driver_files_select
  ON public.driver_files
  FOR SELECT
  TO authenticated
  USING (auth.uid() IS NOT NULL);

CREATE POLICY driver_files_insert
  ON public.driver_files
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY driver_files_update
  ON public.driver_files
  FOR UPDATE
  TO authenticated
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY driver_files_delete
  ON public.driver_files
  FOR DELETE
  TO authenticated
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS truck_files_select ON public.truck_files;
DROP POLICY IF EXISTS truck_files_insert ON public.truck_files;
DROP POLICY IF EXISTS truck_files_update ON public.truck_files;
DROP POLICY IF EXISTS truck_files_delete ON public.truck_files;

CREATE POLICY truck_files_select
  ON public.truck_files
  FOR SELECT
  TO authenticated
  USING (auth.uid() IS NOT NULL);

CREATE POLICY truck_files_insert
  ON public.truck_files
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY truck_files_update
  ON public.truck_files
  FOR UPDATE
  TO authenticated
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY truck_files_delete
  ON public.truck_files
  FOR DELETE
  TO authenticated
  USING (auth.uid() IS NOT NULL);
