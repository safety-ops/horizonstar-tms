-- ============================================================================
-- P0g: RLS Tier 4 — close the long-tail of unprotected / permissive tables
-- ============================================================================
--
-- Audit-driven follow-up to Tier 1/2/3. The closing-gate audits
-- (20260429210000 + 20260429220000) flagged a tail of public.* tables that
-- the original 21-table sweep missed — created via Studio rather than
-- migrations. CRITICAL: app_settings was leaking live Anthropic + Samsara
-- API keys to anonymous callers. This migration closes the leak; rotation
-- of the keys themselves is a SEPARATE required action — RLS does not
-- retroactively un-leak data that was already public.
--
-- Helpers consumed (deployed in 20260429140000, hardened in 20260429160000):
--   public.is_tms_staff(), is_dealer_user(), current_dealer_id(),
--   current_driver_id(), current_local_driver_id().
--
-- Pattern: for every table, 4 policies (SELECT/INSERT/UPDATE/DELETE) using
-- (SELECT public.is_tms_staff()) for SELECT/INSERT/UPDATE and inline
-- ADMIN-only EXISTS check for DELETE. No driver/dealer access on any of
-- these — investigation confirmed none of them have an iOS or dealer-portal
-- read path.
--
-- Investigation summary (recorded for auditor traceback):
--   chat_messages — staff-only team chat (user_id refs users.id, all live
--     rows are DISPATCHER/ADMIN role). Driver app uses driver_notifications.
--   notifications — staff @-mention notifications (user_id refs users.id).
--     Driver in-app notifications live in driver_notifications (Tier 1).
--   tasks — back-office task list. saveTask() at index.html:27170 sets
--     created_by = users.id, assigned_to = dispatchers.id. Drivers do not
--     interact with this table.
--   invitations — orphaned legacy table; zero references in repo. If
--     invite-acceptance is added later, ship a SECURITY DEFINER RPC
--     (P1 follow-up) — do NOT re-open SELECT.
--   app_settings — CRITICAL. Stores 'samsara' and 'anthropic' rows whose
--     `value` JSONB contained plaintext API keys readable to anon. RLS
--     closes the leak; rotation is REQUIRED separately.
-- ============================================================================

BEGIN;

-- ===========================================================================
-- GROUP A: tables with NO RLS — enable + create staff-only policies.
-- ===========================================================================

-- 1. activity_logs
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "al_select" ON public.activity_logs;
DROP POLICY IF EXISTS "al_insert" ON public.activity_logs;
DROP POLICY IF EXISTS "al_update" ON public.activity_logs;
DROP POLICY IF EXISTS "al_delete" ON public.activity_logs;
CREATE POLICY "al_select" ON public.activity_logs FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "al_insert" ON public.activity_logs FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "al_update" ON public.activity_logs FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "al_delete" ON public.activity_logs FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- 2. dispatchers
ALTER TABLE public.dispatchers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "disp_select" ON public.dispatchers;
DROP POLICY IF EXISTS "disp_insert" ON public.dispatchers;
DROP POLICY IF EXISTS "disp_update" ON public.dispatchers;
DROP POLICY IF EXISTS "disp_delete" ON public.dispatchers;
CREATE POLICY "disp_select" ON public.dispatchers FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "disp_insert" ON public.dispatchers FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "disp_update" ON public.dispatchers FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "disp_delete" ON public.dispatchers FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- 3. messages
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "msgs_select" ON public.messages;
DROP POLICY IF EXISTS "msgs_insert" ON public.messages;
DROP POLICY IF EXISTS "msgs_update" ON public.messages;
DROP POLICY IF EXISTS "msgs_delete" ON public.messages;
CREATE POLICY "msgs_select" ON public.messages FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "msgs_insert" ON public.messages FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "msgs_update" ON public.messages FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "msgs_delete" ON public.messages FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- 4. prepass_config
ALTER TABLE public.prepass_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "pc_select" ON public.prepass_config;
DROP POLICY IF EXISTS "pc_insert" ON public.prepass_config;
DROP POLICY IF EXISTS "pc_update" ON public.prepass_config;
DROP POLICY IF EXISTS "pc_delete" ON public.prepass_config;
CREATE POLICY "pc_select" ON public.prepass_config FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "pc_insert" ON public.prepass_config FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "pc_update" ON public.prepass_config FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "pc_delete" ON public.prepass_config FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- 5. toll_transactions
ALTER TABLE public.toll_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tt_select" ON public.toll_transactions;
DROP POLICY IF EXISTS "tt_insert" ON public.toll_transactions;
DROP POLICY IF EXISTS "tt_update" ON public.toll_transactions;
DROP POLICY IF EXISTS "tt_delete" ON public.toll_transactions;
CREATE POLICY "tt_select" ON public.toll_transactions FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "tt_insert" ON public.toll_transactions FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "tt_update" ON public.toll_transactions FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "tt_delete" ON public.toll_transactions FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- 6. transponder_mappings
ALTER TABLE public.transponder_mappings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tm_select" ON public.transponder_mappings;
DROP POLICY IF EXISTS "tm_insert" ON public.transponder_mappings;
DROP POLICY IF EXISTS "tm_update" ON public.transponder_mappings;
DROP POLICY IF EXISTS "tm_delete" ON public.transponder_mappings;
CREATE POLICY "tm_select" ON public.transponder_mappings FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "tm_insert" ON public.transponder_mappings FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "tm_update" ON public.transponder_mappings FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "tm_delete" ON public.transponder_mappings FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- ===========================================================================
-- GROUP B: tables with USING(true) permissive — replace with staff-only.
-- ===========================================================================

-- 7. chat_messages (LEAKING)
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "cm_select" ON public.chat_messages;
DROP POLICY IF EXISTS "cm_insert" ON public.chat_messages;
DROP POLICY IF EXISTS "cm_update" ON public.chat_messages;
DROP POLICY IF EXISTS "cm_delete" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_messages_select" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_messages_insert" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_messages_update" ON public.chat_messages;
DROP POLICY IF EXISTS "chat_messages_delete" ON public.chat_messages;
CREATE POLICY "cm_select" ON public.chat_messages FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "cm_insert" ON public.chat_messages FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "cm_update" ON public.chat_messages FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "cm_delete" ON public.chat_messages FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- 8. accidents
ALTER TABLE public.accidents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "acc_select" ON public.accidents;
DROP POLICY IF EXISTS "acc_insert" ON public.accidents;
DROP POLICY IF EXISTS "acc_update" ON public.accidents;
DROP POLICY IF EXISTS "acc_delete" ON public.accidents;
CREATE POLICY "acc_select" ON public.accidents FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "acc_insert" ON public.accidents FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "acc_update" ON public.accidents FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "acc_delete" ON public.accidents FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- 9. app_settings (LEAKING API KEYS — keys MUST be rotated separately)
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "as_select" ON public.app_settings;
DROP POLICY IF EXISTS "as_insert" ON public.app_settings;
DROP POLICY IF EXISTS "as_update" ON public.app_settings;
DROP POLICY IF EXISTS "as_delete" ON public.app_settings;
CREATE POLICY "as_select" ON public.app_settings FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "as_insert" ON public.app_settings FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "as_update" ON public.app_settings FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "as_delete" ON public.app_settings FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- 10. claim_files
ALTER TABLE public.claim_files ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "claimf_select" ON public.claim_files;
DROP POLICY IF EXISTS "claimf_insert" ON public.claim_files;
DROP POLICY IF EXISTS "claimf_update" ON public.claim_files;
DROP POLICY IF EXISTS "claimf_delete" ON public.claim_files;
CREATE POLICY "claimf_select" ON public.claim_files FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "claimf_insert" ON public.claim_files FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "claimf_update" ON public.claim_files FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "claimf_delete" ON public.claim_files FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- 11. compliance_tasks
ALTER TABLE public.compliance_tasks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ct_select" ON public.compliance_tasks;
DROP POLICY IF EXISTS "ct_insert" ON public.compliance_tasks;
DROP POLICY IF EXISTS "ct_update" ON public.compliance_tasks;
DROP POLICY IF EXISTS "ct_delete" ON public.compliance_tasks;
CREATE POLICY "ct_select" ON public.compliance_tasks FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "ct_insert" ON public.compliance_tasks FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "ct_update" ON public.compliance_tasks FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "ct_delete" ON public.compliance_tasks FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- 12. fleet_mileage
ALTER TABLE public.fleet_mileage ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "fm_select" ON public.fleet_mileage;
DROP POLICY IF EXISTS "fm_insert" ON public.fleet_mileage;
DROP POLICY IF EXISTS "fm_update" ON public.fleet_mileage;
DROP POLICY IF EXISTS "fm_delete" ON public.fleet_mileage;
CREATE POLICY "fm_select" ON public.fleet_mileage FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "fm_insert" ON public.fleet_mileage FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "fm_update" ON public.fleet_mileage FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "fm_delete" ON public.fleet_mileage FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- 13. invitations
ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "inv_select" ON public.invitations;
DROP POLICY IF EXISTS "inv_insert" ON public.invitations;
DROP POLICY IF EXISTS "inv_update" ON public.invitations;
DROP POLICY IF EXISTS "inv_delete" ON public.invitations;
CREATE POLICY "inv_select" ON public.invitations FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "inv_insert" ON public.invitations FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "inv_update" ON public.invitations FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "inv_delete" ON public.invitations FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- 14. notifications
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "notif_select" ON public.notifications;
DROP POLICY IF EXISTS "notif_insert" ON public.notifications;
DROP POLICY IF EXISTS "notif_update" ON public.notifications;
DROP POLICY IF EXISTS "notif_delete" ON public.notifications;
CREATE POLICY "notif_select" ON public.notifications FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "notif_insert" ON public.notifications FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "notif_update" ON public.notifications FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "notif_delete" ON public.notifications FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- 15. ticket_files
ALTER TABLE public.ticket_files ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tf_select" ON public.ticket_files;
DROP POLICY IF EXISTS "tf_insert" ON public.ticket_files;
DROP POLICY IF EXISTS "tf_update" ON public.ticket_files;
DROP POLICY IF EXISTS "tf_delete" ON public.ticket_files;
CREATE POLICY "tf_select" ON public.ticket_files FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "tf_insert" ON public.ticket_files FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "tf_update" ON public.ticket_files FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "tf_delete" ON public.ticket_files FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- 16. tickets
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tkt_select" ON public.tickets;
DROP POLICY IF EXISTS "tkt_insert" ON public.tickets;
DROP POLICY IF EXISTS "tkt_update" ON public.tickets;
DROP POLICY IF EXISTS "tkt_delete" ON public.tickets;
CREATE POLICY "tkt_select" ON public.tickets FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "tkt_insert" ON public.tickets FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "tkt_update" ON public.tickets FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "tkt_delete" ON public.tickets FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- 17. violation_files
ALTER TABLE public.violation_files ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "vf_select" ON public.violation_files;
DROP POLICY IF EXISTS "vf_insert" ON public.violation_files;
DROP POLICY IF EXISTS "vf_update" ON public.violation_files;
DROP POLICY IF EXISTS "vf_delete" ON public.violation_files;
CREATE POLICY "vf_select" ON public.violation_files FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "vf_insert" ON public.violation_files FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "vf_update" ON public.violation_files FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "vf_delete" ON public.violation_files FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- 18. violations
ALTER TABLE public.violations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "viol_select" ON public.violations;
DROP POLICY IF EXISTS "viol_insert" ON public.violations;
DROP POLICY IF EXISTS "viol_update" ON public.violations;
DROP POLICY IF EXISTS "viol_delete" ON public.violations;
CREATE POLICY "viol_select" ON public.violations FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "viol_insert" ON public.violations FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "viol_update" ON public.violations FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "viol_delete" ON public.violations FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- ===========================================================================
-- GROUP C: tasks — replace `auth.uid() IS NOT NULL` with staff-only.
-- ===========================================================================

-- 19. tasks
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "tasks_select" ON public.tasks;
DROP POLICY IF EXISTS "tasks_insert" ON public.tasks;
DROP POLICY IF EXISTS "tasks_update" ON public.tasks;
DROP POLICY IF EXISTS "tasks_delete" ON public.tasks;
CREATE POLICY "tasks_select" ON public.tasks FOR SELECT USING ((SELECT public.is_tms_staff()));
CREATE POLICY "tasks_insert" ON public.tasks FOR INSERT WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "tasks_update" ON public.tasks FOR UPDATE USING ((SELECT public.is_tms_staff())) WITH CHECK ((SELECT public.is_tms_staff()));
CREATE POLICY "tasks_delete" ON public.tasks FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.users u WHERE u.auth_id = auth.uid() AND COALESCE(u.is_active, true) = true AND u.role = 'ADMIN')
);

-- ---------------------------------------------------------------------------
-- Dedupe scrub: drop any policy on the touched tables whose name does NOT
-- match the tight `<prefix>_<crud>` form. Catches Studio-default names like
-- "Anyone can read X", "Allow all for authenticated users", etc.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  pol RECORD;
  expected_tables TEXT[] := ARRAY[
    'activity_logs','dispatchers','messages','prepass_config',
    'toll_transactions','transponder_mappings',
    'chat_messages','accidents','app_settings','claim_files',
    'compliance_tasks','fleet_mileage','invitations','notifications',
    'ticket_files','tickets','violation_files','violations',
    'tasks'
  ];
  ours_pattern TEXT :=
    '^(al|disp|msgs|pc|tt|tm|cm|acc|as|claimf|ct|fm|inv|notif|tf|tkt|vf|viol|tasks)_(select|insert|update|delete)$';
BEGIN
  FOR pol IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = ANY(expected_tables)
  LOOP
    IF pol.policyname ~ ours_pattern THEN
      RAISE NOTICE 'KEEP   %.% policy=%', pol.schemaname, pol.tablename, pol.policyname;
    ELSE
      RAISE NOTICE 'DROP   %.% policy=%', pol.schemaname, pol.tablename, pol.policyname;
      EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',
                     pol.policyname, pol.schemaname, pol.tablename);
    END IF;
  END LOOP;
END$$;

-- ---------------------------------------------------------------------------
-- Sanity counts.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  t TEXT;
  has_rls BOOLEAN;
  policy_count INTEGER;
  permissive_count INTEGER;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'activity_logs','dispatchers','messages','prepass_config',
    'toll_transactions','transponder_mappings',
    'chat_messages','accidents','app_settings','claim_files',
    'compliance_tasks','fleet_mileage','invitations','notifications',
    'ticket_files','tickets','violation_files','violations',
    'tasks'
  ]
  LOOP
    SELECT relrowsecurity INTO has_rls FROM pg_class
      WHERE relnamespace = 'public'::regnamespace AND relname = t;
    SELECT COUNT(*) INTO policy_count FROM pg_policies
      WHERE schemaname = 'public' AND tablename = t;
    SELECT COUNT(*) INTO permissive_count FROM pg_policies
      WHERE schemaname = 'public' AND tablename = t
        AND (qual = 'true' OR with_check = 'true');

    IF NOT COALESCE(has_rls, false) THEN
      RAISE WARNING 'P0g sanity: % does not have RLS enabled', t;
    END IF;
    IF policy_count = 0 THEN
      RAISE WARNING 'P0g sanity: % has zero policies', t;
    ELSIF policy_count <> 4 THEN
      RAISE WARNING 'P0g sanity: % has % policies (expected 4)', t, policy_count;
    ELSE
      RAISE NOTICE 'P0g sanity: % OK (% policies)', t, policy_count;
    END IF;
    IF permissive_count > 0 THEN
      RAISE WARNING 'P0g sanity: % still has % permissive policy(ies)', t, permissive_count;
    END IF;
  END LOOP;
END$$;

COMMIT;
