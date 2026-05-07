-- P0: tighten public.activity_log RLS so SELECT is restricted to TMS staff.
--
-- Pre-existing live policies on public.activity_log (confirmed against the
-- linked project via pg_policies):
--   activity_log_insert  INSERT  with_check = true             (public)
--   activity_log_select  SELECT  qual       = (auth.uid() IS NOT NULL)
--
-- Problem: the SELECT predicate (auth.uid() IS NOT NULL) lets ANY
-- authenticated user — drivers, local drivers, dealers, dealer applicants —
-- read every activity_log row. Activity log entries contain operational PII
-- (which user edited which order, dispatched which trip, marked which COD
-- collection paid, etc.) and must be staff-only.
--
-- Fix: drop the over-permissive SELECT policy and replace it with one that
-- defers to the public.is_tms_staff() helper from
--   supabase/migrations/20260429140000_rls_helpers.sql
-- (allow-list: ADMIN, MANAGER, DISPATCHER).
--
-- INSERT is INTENTIONALLY left untouched. The web TMS (index.html) currently
-- runs as anon (per audit-5 finding) and writes activity rows client-side via
--   dbInsert('activity_log', { ... })   -- index.html:9811
-- A P1 follow-up will move audit-log writes server-side behind a SECURITY
-- DEFINER RPC, at which point INSERT can be tightened too. For now, locking
-- INSERT here would break the entire web audit-logging path.
--
-- DELETE/UPDATE: the live drill-down only returned two policies (INSERT +
-- SELECT). With RLS enabled and no DELETE/UPDATE policies, neither is
-- permitted via the API for any role — service-role-only via psql. That is
-- the existing posture and is preserved here (append-only by design). We
-- deliberately do NOT add DELETE/UPDATE policies; doing so would be a
-- behavioral change.
--
-- Mirrors the structure of the parallel migration written today:
--   supabase/migrations/20260507180000_dealer_applications_staff_only.sql
-- but only touches SELECT.
--
-- There is no CREATE TABLE for public.activity_log in supabase/migrations/
-- (grep confirmed: the singular activity_log table was created out-of-band
-- via the dashboard or an early ad-hoc deploy; the unrelated, plural
-- public.activity_logs table is a separate table covered by
-- 20260429230000_rls_tier4_long_tail.sql:45-54). We deliberately do NOT add
-- a CREATE TABLE — only ALTER POLICY work — to avoid drifting from the live
-- schema.

BEGIN;

-- 1. Drop the over-permissive any-authenticated-user SELECT policy.
DROP POLICY IF EXISTS "activity_log_select" ON public.activity_log;

-- 2. Staff-only SELECT.
CREATE POLICY "activity_log_select" ON public.activity_log
  FOR SELECT USING (
    (SELECT public.is_tms_staff())
  );

-- INSERT policy "activity_log_insert" (with_check = true) is preserved
-- unchanged: web TMS audit logging currently runs as anon and depends on it.
-- See P1 follow-up to move audit writes server-side.

COMMIT;
