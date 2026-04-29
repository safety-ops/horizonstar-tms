-- Rollback for 20260429120000_driver_applications_ssn_protection.sql
-- Restores the pre-fix permissive policies. Use ONLY if the tightened policies
-- break a critical staff workflow and we need to revert immediately. Note that
-- restoring the open SELECT re-exposes SSN/DOB/license — keep the rollback
-- window short and pair with a follow-up fix.

DROP POLICY IF EXISTS "TMS staff can view applications" ON driver_applications;
DROP POLICY IF EXISTS "TMS staff can update applications" ON driver_applications;
DROP POLICY IF EXISTS "Admins can delete applications" ON driver_applications;
DROP POLICY IF EXISTS "TMS staff can view application files" ON storage.objects;

CREATE POLICY "Authenticated users can view applications" ON driver_applications
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update applications" ON driver_applications
  FOR UPDATE USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated can view application files" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'driver-applications' AND
    auth.uid() IS NOT NULL
  );

-- The idx_users_auth_id_active index is left in place — it's a pure
-- performance addition that doesn't affect behavior on rollback.
