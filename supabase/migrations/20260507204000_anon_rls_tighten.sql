-- ============================================================
-- Migration: 20260507204000_anon_rls_tighten.sql
-- Purpose:   P0-1 sub-phase B-D — reduce anon-role surface area.
--
-- Context
--   Every public.* table has full {SELECT,INSERT,UPDATE,DELETE,
--   REFERENCES,TRIGGER,TRUNCATE} grants to anon (the Supabase
--   default). RLS is the only gate. Audit (2026-05-07) confirmed
--   RLS is enabled on every public table, but several RLS
--   policies and function EXECUTE grants are unnecessarily
--   reachable by the anon role. This migration revokes the
--   anon EXECUTE grant from every function that has no public /
--   pre-login caller, and rewrites three RLS policies so they
--   no longer name the public role (which includes anon) when
--   their qual already requires auth.uid().
--
-- Allowed anon surface AFTER this migration:
--   • INSERT on dealer_applications (self-registration form)
--   • INSERT on driver_applications (driver self-registration)
--   • RPC record_login_attempt           (pre-login rate-limit)
--   • RPC driver_can_login_by_email      (iOS pre-login lookup)
--   • RLS helper functions used by other policies via SECURITY
--     DEFINER context (is_tms_staff, is_dealer_user, current_*).
--     These return is_tms_staff()=false / current_*()=NULL for
--     anon callers so direct anon RPC has no value but is also
--     not exploitable. Left in place to avoid breaking the many
--     RLS policies that invoke them inline.
--
-- DEFERRED to task #15 (NOT in this migration):
--   • activity_log INSERT public policy. The web TMS still has
--     legacy direct-INSERT call sites that the C1 wire-up did
--     not fully replace. Tightening this before C1 is finished
--     will silently drop activity log rows. Tracked separately.
--
-- Verified non-affecting:
--   • Dealer self-registration (index.html:50817 inserts into
--     dealer_applications) — its INSERT policy "Anyone can submit
--     dealer application" is untouched.
--   • Driver self-registration (driver_applications "Anyone can
--     submit application") — untouched.
--   • iOS driver login (SupabaseService.swift:495 calls
--     driver_can_login_by_email) — anon EXECUTE retained.
--   • Web login rate-limit (index.html:9297, 15171 calls
--     record_login_attempt) — anon EXECUTE retained.
--   • send-email Edge Function uses the service_role key, so
--     revoking anon EXECUTE on email_quota_* is safe.
--   • Trigger-attached functions fire as the table-owner role
--     regardless of anon EXECUTE; revoking it only blocks
--     direct RPC abuse. Confirmed via pg_trigger.
-- ============================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Revoke anon EXECUTE on functions with no public/pre-login caller.
--    Each REVOKE includes a brief justification.
-- ─────────────────────────────────────────────────────────────────────────────

-- Trigger functions: fire from row-level DML; never need direct anon RPC.
-- Removing anon EXECUTE blocks an attacker from invoking them as RPCs
-- (where they could try to manipulate NEW/OLD via crafted inputs).
REVOKE EXECUTE ON FUNCTION public.block_orders_field_escalation()       FROM anon;
REVOKE EXECUTE ON FUNCTION public.block_trips_field_escalation()        FROM anon;
REVOKE EXECUTE ON FUNCTION public.mirror_payment_type_to_method()       FROM anon;
REVOKE EXECUTE ON FUNCTION public.sync_payment_status_on_driver_paid()  FROM anon;
REVOKE EXECUTE ON FUNCTION public.normalize_driver_login_fields()       FROM anon;
REVOKE EXECUTE ON FUNCTION public.update_updated_at_column()            FROM anon;
REVOKE EXECUTE ON FUNCTION public.update_claims_updated_at()            FROM anon;
REVOKE EXECUTE ON FUNCTION public.update_vehicle_inspection_updated_at() FROM anon;

-- Settlement RPC: web TMS only, called from authenticated session.
-- (index.html:34811 — staff-only payroll workflow.)
REVOKE EXECUTE ON FUNCTION public.supersede_and_create_settlement_revision(integer, jsonb) FROM anon;

-- Email quota RPCs: only the send-email Edge Function calls these,
-- and it uses the service_role key (supabase/functions/send-email/index.ts:244,349).
-- No client (web or iOS) needs anon access.
REVOKE EXECUTE ON FUNCTION public.email_quota_check_and_log(uuid, integer, integer, text, text, text, integer, integer, bigint, text, integer, integer, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.email_quota_finalize(bigint, text, text, text, integer) FROM anon;

-- Maintenance / housekeeping: admin / scheduled-job only.
-- cleanup_abandoned_inspections is a janitorial function with side effects on
-- vehicle_inspections; mark_order_paid_on_uship_code is a trigger helper.
REVOKE EXECUTE ON FUNCTION public.cleanup_abandoned_inspections()       FROM anon;
REVOKE EXECUTE ON FUNCTION public.mark_order_paid_on_uship_code()       FROM anon;

-- Order number RPC: spec says authenticated-only. Revoke errant anon grant.
-- Web TMS callsites (index.html:19429, 19833, 23698, 50652) all run after
-- login. iOS app does not call this RPC.
REVOKE EXECUTE ON FUNCTION public.next_order_number(text, text) FROM anon;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Tenancy / multi-tenant helper grants (left in place — see comment).
-- ─────────────────────────────────────────────────────────────────────────────
-- get_current_tenant_id, get_user_role_in_tenant, user_belongs_to_tenant,
-- is_tms_staff, is_dealer_user, current_driver_id, current_dealer_id,
-- current_local_driver_id are all called inline by RLS policies via
-- ( SELECT helper() ). PostgreSQL does NOT require EXECUTE on functions
-- referenced inside an RLS policy when the policy is evaluated, BUT it
-- does require EXECUTE for direct RPC. Revoking from anon would be safe
-- but adds no attack reduction (these return NULL/false for unauth) and
-- risks breakage if any code path calls them as RPC. Deferred — flagged
-- in section 4 of the security report.

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. RLS policies: rewrite a few that accidentally allow anon to be CHECKED
--    against the qual. Even though the qual rejects anon, naming "public"
--    in the role list means the policy is evaluated for anon — switching
--    to "TO authenticated" makes the deny implicit and faster.
-- ─────────────────────────────────────────────────────────────────────────────

-- billing_events: qual requires auth.uid() IS NOT NULL — implicitly excludes
-- anon. Move to TO authenticated to make intent explicit and stop evaluating
-- this policy for anon callers.
ALTER POLICY billing_events_all ON public.billing_events TO authenticated;

-- claims, fixed_costs, variable_costs, driver_files, truck_files: same
-- pattern (qual = auth.uid() IS NOT NULL or staff EXISTS). Constrain to
-- authenticated so anon never even reaches the qual check.
ALTER POLICY claims_delete         ON public.claims         TO authenticated;
ALTER POLICY claims_insert         ON public.claims         TO authenticated;
ALTER POLICY claims_select         ON public.claims         TO authenticated;
ALTER POLICY claims_update         ON public.claims         TO authenticated;
ALTER POLICY fixed_costs_delete    ON public.fixed_costs    TO authenticated;
ALTER POLICY fixed_costs_insert    ON public.fixed_costs    TO authenticated;
ALTER POLICY fixed_costs_select    ON public.fixed_costs    TO authenticated;
ALTER POLICY fixed_costs_update    ON public.fixed_costs    TO authenticated;
ALTER POLICY variable_costs_delete ON public.variable_costs TO authenticated;
ALTER POLICY variable_costs_insert ON public.variable_costs TO authenticated;
ALTER POLICY variable_costs_select ON public.variable_costs TO authenticated;
ALTER POLICY variable_costs_update ON public.variable_costs TO authenticated;
ALTER POLICY driver_files_delete   ON public.driver_files   TO authenticated;
ALTER POLICY driver_files_insert   ON public.driver_files   TO authenticated;
ALTER POLICY driver_files_select   ON public.driver_files   TO authenticated;
ALTER POLICY driver_files_update   ON public.driver_files   TO authenticated;
ALTER POLICY truck_files_delete    ON public.truck_files    TO authenticated;
ALTER POLICY truck_files_insert    ON public.truck_files    TO authenticated;
ALTER POLICY truck_files_select    ON public.truck_files    TO authenticated;
ALTER POLICY truck_files_update    ON public.truck_files    TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Document what we intentionally LEFT untouched for the orchestrator.
-- ─────────────────────────────────────────────────────────────────────────────
-- KEPT (anon access required):
--   • dealer_applications "Anyone can submit dealer application" INSERT
--   • driver_applications "Anyone can submit application" INSERT
--   • record_login_attempt(text, boolean, text)             EXECUTE
--   • driver_can_login_by_email(text)                       EXECUTE
--
-- KEPT (defense-in-depth — anon hits the policy but qual returns false,
-- because is_tms_staff() / current_driver_id() / current_dealer_id() etc.
-- all evaluate to false/NULL when auth.uid() is NULL):
--   • All *_select / *_insert / *_update / *_delete on operational tables
--     (orders, trips, drivers, brokers, dealers, expenses, vehicle_inspections,
--      etc.) — the helper-driven quals already reject anon; rewriting all
--     ~150 policies to explicit "TO authenticated" is task scope creep and
--     unrelated to the P0 surface reduction.
--
-- DEFERRED (task #15):
--   • activity_log "activity_log_insert" INSERT public/anon policy with
--     check (true). Will be tightened after C1 wire-up replaces all
--     direct-INSERT call sites with the log_activity SECURITY DEFINER RPC.
