-- ============================================================================
-- Rollback: 20260502000000_sync_driver_paid_to_payment_status
-- ============================================================================
--
-- Drops the trigger and trigger function installed by the forward migration.
--
-- NOTE: Backfilled rows (payment_status flipped to 'paid' for pre-existing
-- PAID driver-paid orders) are NOT reverted. Those rows are now correct;
-- reverting them would re-introduce the "Unpaid" display bug for historical
-- orders. If a full data revert is needed, it must be done manually after
-- careful audit.

BEGIN;

DROP TRIGGER IF EXISTS sync_payment_status_on_driver_paid ON public.orders;

DROP FUNCTION IF EXISTS public.sync_payment_status_on_driver_paid();

COMMIT;
