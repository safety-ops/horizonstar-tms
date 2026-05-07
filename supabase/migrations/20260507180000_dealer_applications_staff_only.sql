-- P0: tighten dealer_applications RLS to staff-only for SELECT/UPDATE/DELETE.
--
-- Supersedes the permissive policies created at:
--   supabase/migrations/20260313000000_dealer_applications.sql:28-34
--
-- Pre-existing state (from 20260313000000_dealer_applications.sql):
--   SELECT/UPDATE policies allow ANY authenticated user (auth.uid() IS NOT NULL),
--   so every driver, dealer, dispatcher could read and modify every dealer
--   applicant's company name, contact details, address, payment terms, and the
--   plaintext registration password stored alongside the application
--   (added in 20260313000200_dealer_app_password.sql).
--
-- Fix: only TMS staff (ADMIN, MANAGER, DISPATCHER) read/update applications.
-- Only ADMIN may delete (preserves an audit trail of approve/reject decisions
-- against the dealer onboarding pipeline). DEALER role is explicitly excluded
-- by the allow-list. INSERT stays public — the application form is
-- unauthenticated by design.
--
-- Mirrors the structure of:
--   supabase/migrations/20260429120000_driver_applications_ssn_protection.sql
-- but uses the public.is_tms_staff() helper from
--   supabase/migrations/20260429140000_rls_helpers.sql
-- for the SELECT/UPDATE predicates (same allow-list, encapsulated).
--
-- No storage bucket exists for dealer-applications uploads (verified via
-- grep across supabase/), so no storage.objects policies are touched.

BEGIN;

-- 1. Drop the over-permissive authenticated-any-user policies.
DROP POLICY IF EXISTS "Authenticated users can view dealer applications" ON public.dealer_applications;
DROP POLICY IF EXISTS "Authenticated users can update dealer applications" ON public.dealer_applications;

-- Idempotency: if this migration is re-run, drop the new policies before
-- recreating them.
DROP POLICY IF EXISTS "TMS staff can view dealer applications" ON public.dealer_applications;
DROP POLICY IF EXISTS "TMS staff can update dealer applications" ON public.dealer_applications;
DROP POLICY IF EXISTS "Admins can delete dealer applications" ON public.dealer_applications;

-- 2. Staff-only SELECT.
CREATE POLICY "TMS staff can view dealer applications" ON public.dealer_applications
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
  );

-- 3. Staff-only UPDATE (USING + WITH CHECK so a staff user cannot mutate a
--    row out from under themselves into a state they can't see).
CREATE POLICY "TMS staff can update dealer applications" ON public.dealer_applications
  FOR UPDATE USING (
    (SELECT public.is_tms_staff())
  ) WITH CHECK (
    (SELECT public.is_tms_staff())
  );

-- 4. Admin-only DELETE. Inline EXISTS predicate (no helper for ADMIN-only
--    exists yet) — same pattern as the driver_applications migration.
CREATE POLICY "Admins can delete dealer applications" ON public.dealer_applications
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role = 'ADMIN'
    )
  );

-- "Anyone can submit dealer application" INSERT policy is preserved unchanged:
-- the public registration form must continue to work for unauthenticated
-- visitors (anon role).

COMMIT;
