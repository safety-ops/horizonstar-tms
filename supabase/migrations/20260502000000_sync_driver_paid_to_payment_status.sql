-- ============================================================================
-- Migration: 20260502000000_sync_driver_paid_to_payment_status
-- ============================================================================
--
-- Bug: Payment status mismatch — web TMS orders grid shows "Unpaid" even
-- after a driver marks payment collected in the iOS app.
--
-- Root cause
-- ----------
-- Two columns track payment on the orders table:
--
--   driver_paid_status  — written by iOS SupabaseService.updatePaymentStatus()
--                         (SupabaseService.swift:1061-1091) with value 'PAID'
--                         when a driver collects cash/check/Zelle/COD in the
--                         field at delivery.
--
--   payment_status      — read by the web TMS orders grid badge at
--                         index.html:16531 with strict-equality === 'paid'
--                         (lowercase).
--
-- For non-uShip orders nothing copies driver_paid_status over to
-- payment_status, so the grid badge stays "Unpaid" indefinitely even though
-- the driver did the right thing in the app.
--
-- The block_orders_field_escalation trigger (added in 20260429200000) rejects
-- direct writes to payment_status from non-staff callers, so the iOS app
-- cannot simply write both columns. The fix must be server-side.
--
-- Fix
-- ---
-- BEFORE UPDATE trigger (SECURITY DEFINER) that mirrors the pattern
-- established for uShip auto-pay in 20260501170000. When driver_paid_status
-- transitions into 'PAID' on any non-uShip order, the trigger sets
-- payment_status = 'paid' (lowercase — required for strict-equality grid
-- badge) and stamps payment_date if not already set.
--
-- Casing note: the web grid does === 'paid' (lowercase). The existing uShip
-- trigger writes uppercase 'PAID'; that is a separate latent bug flagged as a
-- follow-up. This new trigger explicitly writes lowercase 'paid'.
--
-- Backfill: after installing the trigger, existing orders whose
-- driver_paid_status is already 'PAID' but payment_status is still unset are
-- caught up using the same disable/enable pattern as 20260501130000 and
-- 20260501170000.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Trigger function
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.sync_payment_status_on_driver_paid()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Act only when driver_paid_status transitions from non-PAID into 'PAID'.
  -- Guarded by UPPER() so 'paid', 'Paid', 'PAID' all count as the new state,
  -- and the old-state guard prevents re-firing on subsequent updates to the
  -- same already-PAID order.
  IF UPPER(COALESCE(NEW.driver_paid_status, '')) = 'PAID'
     AND UPPER(COALESCE(OLD.driver_paid_status, '')) <> 'PAID'
  THEN
    -- Only advance payment_status if it is not already in a terminal state.
    -- A dispatcher who manually marked the order paid/collected/invoiced
    -- beforehand should not be overwritten. Check both casings defensively.
    IF LOWER(COALESCE(NEW.payment_status, '')) NOT IN ('paid', 'collected', 'invoiced')
       AND UPPER(COALESCE(NEW.payment_status, '')) NOT IN ('PAID', 'COLLECTED', 'INVOICED')
    THEN
      -- Lowercase 'paid' is required: web TMS grid badge at index.html:16531
      -- uses strict-equality === 'paid'.
      NEW.payment_status := 'paid';
    END IF;

    -- Stamp the payment date on first collection. If a dispatcher already set
    -- a payment_date leave it alone.
    IF NEW.payment_date IS NULL THEN
      NEW.payment_date := NOW();
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.sync_payment_status_on_driver_paid() FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 2. Trigger
-- ---------------------------------------------------------------------------

DROP TRIGGER IF EXISTS sync_payment_status_on_driver_paid ON public.orders;

CREATE TRIGGER sync_payment_status_on_driver_paid
  BEFORE UPDATE OF driver_paid_status ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_payment_status_on_driver_paid();

-- ---------------------------------------------------------------------------
-- 3. Backfill: catch up historical orders already marked PAID by drivers
-- ---------------------------------------------------------------------------
-- Orders created before this trigger existed may have driver_paid_status='PAID'
-- (any casing) but payment_status still in an unset / non-terminal state.
-- Bring them in sync now.
--
-- The block_orders_field_escalation trigger rejects payment_status writes from
-- non-staff callers. Migrations run as the postgres role, which
-- is_tms_staff() returns false for, so we must disable that trigger for the
-- duration of the backfill — the same pattern used in 20260501130000 and
-- 20260501170000.

ALTER TABLE public.orders DISABLE TRIGGER block_orders_field_escalation;

UPDATE public.orders
SET
  payment_status = 'paid',
  payment_date   = COALESCE(payment_date, NOW())
WHERE UPPER(COALESCE(driver_paid_status, '')) = 'PAID'
  AND LOWER(COALESCE(payment_status, '')) NOT IN ('paid', 'collected', 'invoiced')
  AND UPPER(COALESCE(payment_status, '')) NOT IN ('PAID', 'COLLECTED', 'INVOICED');

ALTER TABLE public.orders ENABLE TRIGGER block_orders_field_escalation;

COMMIT;

-- ROLLBACK (separate file): supabase/rollbacks/20260502000000_sync_driver_paid_to_payment_status.down.sql
