-- P0 critical: tighten driver_applications RLS.
--
-- Supersedes the permissive policies created at:
--   supabase/migrations/20260103000100_driver_applications.sql:108-112,133-136
--
-- Pre-existing state (from 20260103000100_driver_applications.sql):
--   SELECT/UPDATE policies allow ANY authenticated user — so every driver,
--   dealer, dispatcher could read every applicant's SSN, DOB, license,
--   drug-test history, employment record, license images, medical card.
--
-- Fix: only TMS staff (ADMIN, MANAGER, DISPATCHER) read/update applications.
-- Only ADMIN may delete (preserves FMCSA §391.51 driver-qualification-file
-- retention discipline). DEALER role is explicitly excluded by the allow-list.
-- INSERT stays public — the application form is unauthenticated.

-- 1. Replace permissive SELECT/UPDATE policies with role-scoped ones.
DROP POLICY IF EXISTS "Authenticated users can view applications" ON driver_applications;
DROP POLICY IF EXISTS "Authenticated users can update applications" ON driver_applications;
DROP POLICY IF EXISTS "TMS staff can view applications" ON driver_applications;
DROP POLICY IF EXISTS "TMS staff can update applications" ON driver_applications;
DROP POLICY IF EXISTS "Admins can delete applications" ON driver_applications;

CREATE POLICY "TMS staff can view applications" ON driver_applications
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role IN ('ADMIN', 'MANAGER', 'DISPATCHER')
    )
  );

CREATE POLICY "TMS staff can update applications" ON driver_applications
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role IN ('ADMIN', 'MANAGER', 'DISPATCHER')
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role IN ('ADMIN', 'MANAGER', 'DISPATCHER')
    )
  );

CREATE POLICY "Admins can delete applications" ON driver_applications
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role = 'ADMIN'
    )
  );

-- "Anyone can submit application" INSERT policy is preserved unchanged.

-- 2. Tighten the storage bucket the same way — license images, medical cards,
--    and any other uploads are equally sensitive.
DROP POLICY IF EXISTS "Authenticated can view application files" ON storage.objects;
DROP POLICY IF EXISTS "TMS staff can view application files" ON storage.objects;

CREATE POLICY "TMS staff can view application files" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'driver-applications' AND
    EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
        AND u.role IN ('ADMIN', 'MANAGER', 'DISPATCHER')
    )
  );

-- "Anyone can upload application files" INSERT policy is preserved unchanged.

-- 3. Supporting index for the role-check predicate. Without this every
--    SELECT on driver_applications triggers a Seq Scan of users. Plain
--    CREATE INDEX (not CONCURRENTLY) — safe inside a migration transaction
--    on the small users table.
CREATE INDEX IF NOT EXISTS idx_users_auth_id_active
  ON public.users(auth_id)
  WHERE COALESCE(is_active, true) = true;
