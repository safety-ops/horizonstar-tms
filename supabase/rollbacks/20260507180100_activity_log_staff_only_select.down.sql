-- Rollback for:
--   supabase/migrations/20260507180100_activity_log_staff_only_select.sql
--
-- Restores the prior over-permissive SELECT predicate on public.activity_log
-- (any authenticated user can read every row). Use ONLY if the staff-only
-- SELECT policy is causing a regression in the web TMS or driver app and a
-- fix cannot ship within the rollback window.
--
-- Not auto-applied (lives under supabase/rollbacks/, not supabase/migrations/).
-- Apply manually via Supabase Dashboard SQL Editor or psql with service-role
-- credentials.

BEGIN;

DROP POLICY IF EXISTS "activity_log_select" ON public.activity_log;

CREATE POLICY "activity_log_select" ON public.activity_log
  FOR SELECT USING (
    auth.uid() IS NOT NULL
  );

COMMIT;
