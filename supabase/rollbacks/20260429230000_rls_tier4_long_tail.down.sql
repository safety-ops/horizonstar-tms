-- Rollback for 20260429230000_rls_tier4_long_tail.sql.
--
-- !! SECURITY WARNING !!
-- The pre-Tier-4 state on these 19 tables included anon-readable internal
-- team chat (chat_messages), live API keys (app_settings — Anthropic +
-- Samsara), FMCSA records (accidents/violations/tickets/compliance_tasks),
-- staff PII (dispatchers), and any-authenticated read on tasks. This
-- rollback re-exposes all of it.
--
-- Note: rolling back does NOT un-leak any secret already harvested while
-- the migration was live. Anthropic and Samsara API keys must be rotated
-- regardless of this migration.

BEGIN;

-- Group A: had NO RLS pre-Tier-4 → drop policies + DISABLE RLS.
DROP POLICY IF EXISTS "al_select" ON public.activity_logs;
DROP POLICY IF EXISTS "al_insert" ON public.activity_logs;
DROP POLICY IF EXISTS "al_update" ON public.activity_logs;
DROP POLICY IF EXISTS "al_delete" ON public.activity_logs;
ALTER TABLE public.activity_logs DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "disp_select" ON public.dispatchers;
DROP POLICY IF EXISTS "disp_insert" ON public.dispatchers;
DROP POLICY IF EXISTS "disp_update" ON public.dispatchers;
DROP POLICY IF EXISTS "disp_delete" ON public.dispatchers;
ALTER TABLE public.dispatchers DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "msgs_select" ON public.messages;
DROP POLICY IF EXISTS "msgs_insert" ON public.messages;
DROP POLICY IF EXISTS "msgs_update" ON public.messages;
DROP POLICY IF EXISTS "msgs_delete" ON public.messages;
ALTER TABLE public.messages DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pc_select" ON public.prepass_config;
DROP POLICY IF EXISTS "pc_insert" ON public.prepass_config;
DROP POLICY IF EXISTS "pc_update" ON public.prepass_config;
DROP POLICY IF EXISTS "pc_delete" ON public.prepass_config;
ALTER TABLE public.prepass_config DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tt_select" ON public.toll_transactions;
DROP POLICY IF EXISTS "tt_insert" ON public.toll_transactions;
DROP POLICY IF EXISTS "tt_update" ON public.toll_transactions;
DROP POLICY IF EXISTS "tt_delete" ON public.toll_transactions;
ALTER TABLE public.toll_transactions DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tm_select" ON public.transponder_mappings;
DROP POLICY IF EXISTS "tm_insert" ON public.transponder_mappings;
DROP POLICY IF EXISTS "tm_update" ON public.transponder_mappings;
DROP POLICY IF EXISTS "tm_delete" ON public.transponder_mappings;
ALTER TABLE public.transponder_mappings DISABLE ROW LEVEL SECURITY;

-- Group B: had USING(true) — drop tight policies. RLS stays on; the
-- original permissive policies are NOT recreated (they were the bug).
DROP POLICY IF EXISTS "cm_select" ON public.chat_messages;
DROP POLICY IF EXISTS "cm_insert" ON public.chat_messages;
DROP POLICY IF EXISTS "cm_update" ON public.chat_messages;
DROP POLICY IF EXISTS "cm_delete" ON public.chat_messages;

DROP POLICY IF EXISTS "acc_select" ON public.accidents;
DROP POLICY IF EXISTS "acc_insert" ON public.accidents;
DROP POLICY IF EXISTS "acc_update" ON public.accidents;
DROP POLICY IF EXISTS "acc_delete" ON public.accidents;

DROP POLICY IF EXISTS "as_select" ON public.app_settings;
DROP POLICY IF EXISTS "as_insert" ON public.app_settings;
DROP POLICY IF EXISTS "as_update" ON public.app_settings;
DROP POLICY IF EXISTS "as_delete" ON public.app_settings;

DROP POLICY IF EXISTS "claimf_select" ON public.claim_files;
DROP POLICY IF EXISTS "claimf_insert" ON public.claim_files;
DROP POLICY IF EXISTS "claimf_update" ON public.claim_files;
DROP POLICY IF EXISTS "claimf_delete" ON public.claim_files;

DROP POLICY IF EXISTS "ct_select" ON public.compliance_tasks;
DROP POLICY IF EXISTS "ct_insert" ON public.compliance_tasks;
DROP POLICY IF EXISTS "ct_update" ON public.compliance_tasks;
DROP POLICY IF EXISTS "ct_delete" ON public.compliance_tasks;

DROP POLICY IF EXISTS "fm_select" ON public.fleet_mileage;
DROP POLICY IF EXISTS "fm_insert" ON public.fleet_mileage;
DROP POLICY IF EXISTS "fm_update" ON public.fleet_mileage;
DROP POLICY IF EXISTS "fm_delete" ON public.fleet_mileage;

DROP POLICY IF EXISTS "inv_select" ON public.invitations;
DROP POLICY IF EXISTS "inv_insert" ON public.invitations;
DROP POLICY IF EXISTS "inv_update" ON public.invitations;
DROP POLICY IF EXISTS "inv_delete" ON public.invitations;

DROP POLICY IF EXISTS "notif_select" ON public.notifications;
DROP POLICY IF EXISTS "notif_insert" ON public.notifications;
DROP POLICY IF EXISTS "notif_update" ON public.notifications;
DROP POLICY IF EXISTS "notif_delete" ON public.notifications;

DROP POLICY IF EXISTS "tf_select" ON public.ticket_files;
DROP POLICY IF EXISTS "tf_insert" ON public.ticket_files;
DROP POLICY IF EXISTS "tf_update" ON public.ticket_files;
DROP POLICY IF EXISTS "tf_delete" ON public.ticket_files;

DROP POLICY IF EXISTS "tkt_select" ON public.tickets;
DROP POLICY IF EXISTS "tkt_insert" ON public.tickets;
DROP POLICY IF EXISTS "tkt_update" ON public.tickets;
DROP POLICY IF EXISTS "tkt_delete" ON public.tickets;

DROP POLICY IF EXISTS "vf_select" ON public.violation_files;
DROP POLICY IF EXISTS "vf_insert" ON public.violation_files;
DROP POLICY IF EXISTS "vf_update" ON public.violation_files;
DROP POLICY IF EXISTS "vf_delete" ON public.violation_files;

DROP POLICY IF EXISTS "viol_select" ON public.violations;
DROP POLICY IF EXISTS "viol_insert" ON public.violations;
DROP POLICY IF EXISTS "viol_update" ON public.violations;
DROP POLICY IF EXISTS "viol_delete" ON public.violations;

DROP POLICY IF EXISTS "tasks_select" ON public.tasks;
DROP POLICY IF EXISTS "tasks_insert" ON public.tasks;
DROP POLICY IF EXISTS "tasks_update" ON public.tasks;
DROP POLICY IF EXISTS "tasks_delete" ON public.tasks;

COMMIT;
