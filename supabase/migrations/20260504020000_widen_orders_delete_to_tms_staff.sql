-- Widen orders DELETE policy from ADMIN-only to all TMS staff.
--
-- Background
-- ----------
-- 20260429200000_rls_tier3.sql created an ADMIN-only DELETE policy on orders
-- with the following rationale (preserved from that migration):
--   "DELETE on orders/trips is ADMIN-only — preserves FMCSA §390.31 (3-year
--    general operations record) + §391.51 retention obligations and protects
--    financial records (invoices, payments)."
--
-- This migration relaxes that policy to allow any active TMS staff user
-- (admin, manager, dispatcher, accountant) to delete orders. Decision made
-- 2026-05-04 by the operator: dispatchers need to remove cancelled / mistakenly
-- imported loads without an admin escalation. The compliance trade-off is
-- accepted explicitly — the audit trail for this loosening lives in the commit
-- message and this migration's leading comment.
--
-- Future safer alternative: introduce a soft-delete column (orders.deleted_at)
-- so historical records are preserved for FMCSA retention while still hiding
-- "deleted" rows from the active grid. Out of scope for this fix.
--
-- The corresponding orders_insert / orders_update / orders_select policies
-- already allow TMS staff (see 20260429200000_rls_tier3.sql), so this brings
-- DELETE in line with the rest of the policy family.

BEGIN;

DROP POLICY IF EXISTS "orders_delete" ON public.orders;

CREATE POLICY "orders_delete" ON public.orders
  FOR DELETE
  USING ((SELECT public.is_tms_staff()));

COMMENT ON POLICY "orders_delete" ON public.orders IS
  'Widened 2026-05-04 from admin-only to all active TMS staff. Compliance trade-off accepted by the operator. See migration 20260504020000.';

COMMIT;

-- Rollback lives at supabase/rollbacks/20260504020000_widen_orders_delete_to_tms_staff.down.sql.
