-- Rollback for 20260507180000_dealer_applications_staff_only.sql
-- Restores the permissive authenticated-any-user SELECT/UPDATE policies that
-- were originally defined in 20260313000000_dealer_applications.sql:31,34.
--
-- WARNING: applying this rollback re-exposes dealer_applications PII
-- (contact info, addresses, payment terms, the plaintext registration
-- password from 20260313000200_dealer_app_password.sql) to every
-- authenticated user — drivers, dealers, dispatchers, anyone with a session.
-- Use only if a downstream caller is found to have assumed
-- authenticated-any-user access and cannot be migrated to a staff-only path
-- in the time available.

BEGIN;

-- 1. Drop the staff-only policies installed by the forward migration.
DROP POLICY IF EXISTS "TMS staff can view dealer applications" ON public.dealer_applications;
DROP POLICY IF EXISTS "TMS staff can update dealer applications" ON public.dealer_applications;
DROP POLICY IF EXISTS "Admins can delete dealer applications" ON public.dealer_applications;

-- 2. Restore the original permissive policies verbatim from
--    20260313000000_dealer_applications.sql.
DROP POLICY IF EXISTS "Authenticated users can view dealer applications" ON public.dealer_applications;
DROP POLICY IF EXISTS "Authenticated users can update dealer applications" ON public.dealer_applications;

CREATE POLICY "Authenticated users can view dealer applications" ON public.dealer_applications
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update dealer applications" ON public.dealer_applications
  FOR UPDATE USING (auth.uid() IS NOT NULL);

-- The INSERT policy ("Anyone can submit dealer application") was never
-- modified by the forward migration, so nothing to restore there.

COMMIT;
