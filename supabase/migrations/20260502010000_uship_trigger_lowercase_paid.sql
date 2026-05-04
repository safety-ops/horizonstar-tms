-- ============================================================================
-- Migration: 20260502010000_uship_trigger_lowercase_paid
-- ============================================================================
--
-- Bug: uShip-triggered orders display as "Unpaid" in the web TMS orders grid.
--
-- Root cause
-- ----------
-- The trigger function mark_order_paid_on_uship_code() (installed in
-- 20260501170000) writes uppercase 'PAID' to orders.payment_status. The web
-- TMS orders grid badge at index.html:16531 uses strict-equality === 'paid'
-- (lowercase). Any order whose payment_status was set by the uShip trigger
-- therefore fails the equality check and renders as "Unpaid" in the grid even
-- though the DB row is correctly flagged paid.
--
-- The same casing requirement was identified and fixed for the driver-paid sync
-- path in 20260502000000. This migration closes the same gap for the uShip
-- confirmation-code path.
--
-- Fix
-- ---
-- 1. Replace mark_order_paid_on_uship_code() via CREATE OR REPLACE so the
--    existing trigger binding is preserved. Only change: payment_status is now
--    assigned lowercase 'paid' instead of uppercase 'PAID'. All other logic
--    (terminal-state guards, driver_paid_status/driver_paid_method assignments,
--    SECURITY DEFINER, search_path) is identical to the predecessor.
--
-- 2. Backfill: convert any existing rows where payment_status = 'PAID'
--    (uppercase, written by the old trigger or the old B.1 backfill in
--    20260501170000) to lowercase 'paid'. Uses the same
--    disable/enable block_orders_field_escalation pattern as 20260501130000,
--    20260501170000, and 20260502000000.
--
-- Scope
-- -----
-- Only 'PAID' → 'paid' normalization is performed. Other terminal states
-- ('COLLECTED', 'INVOICED') are NOT touched — the grid does not display them
-- via the same lowercase check and broader normalization risks unintended side
-- effects. Stay tight to the confirmed bug.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Replace trigger function — lowercase 'paid' assignment
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.mark_order_paid_on_uship_code()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- Only act when uship_delivery_confirmation_code transitions NULL → non-NULL
  -- AND the order was already configured as a USHIP-method load. This guards
  -- against accidental writes flipping payment status on non-uShip orders.
  IF NEW.uship_delivery_confirmation_code IS NOT NULL
     AND (OLD.uship_delivery_confirmation_code IS NULL
          OR OLD.uship_delivery_confirmation_code = '')
     AND UPPER(COALESCE(NEW.payment_method, '')) = 'USHIP'
  THEN
    -- Only set payment_status if it's not already in a terminal state.
    -- A dispatcher who already marked it paid/collected/invoiced manually
    -- shouldn't be overwritten. Check both casings defensively.
    IF LOWER(COALESCE(NEW.payment_status, '')) NOT IN ('paid', 'collected', 'invoiced')
       AND UPPER(COALESCE(NEW.payment_status, '')) NOT IN ('PAID', 'COLLECTED', 'INVOICED')
    THEN
      -- Lowercase 'paid' is required: web TMS grid badge at index.html:16531
      -- uses strict-equality === 'paid'.
      NEW.payment_status := 'paid';
    END IF;

    -- Mark the driver-paid leg as PAID with method=USHIP. uShip pays the
    -- carrier via their marketplace, so once the code is collected the
    -- driver has been "paid" in the dispatch sense.
    -- driver_paid_status uppercase 'PAID' is intentional — that field is not
    -- read by the grid's lowercase strict-equality check.
    IF UPPER(COALESCE(NEW.driver_paid_status, '')) != 'PAID' THEN
      NEW.driver_paid_status := 'PAID';
    END IF;

    IF NEW.driver_paid_method IS NULL OR NEW.driver_paid_method = '' THEN
      NEW.driver_paid_method := 'USHIP';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_order_paid_on_uship_code() FROM PUBLIC;

-- The trigger itself (mark_order_paid_on_uship_code ON public.orders) was
-- created by 20260501170000 and is still bound to the function via its name.
-- CREATE OR REPLACE above replaces the function body in-place; no need to
-- drop/recreate the trigger.

-- ---------------------------------------------------------------------------
-- 2. Backfill: normalize uppercase 'PAID' → lowercase 'paid'
-- ---------------------------------------------------------------------------
-- Rows written by the old trigger body or the B.1 backfill in 20260501170000
-- have payment_status = 'PAID' (uppercase). Convert them so the grid badge
-- equality check === 'paid' matches.
--
-- The block_orders_field_escalation trigger rejects payment_status writes from
-- non-staff callers. Migrations run as the postgres role, which
-- is_tms_staff() returns false for, so disable it for the duration — the same
-- pattern used in 20260501130000, 20260501170000, and 20260502000000.

ALTER TABLE public.orders DISABLE TRIGGER block_orders_field_escalation;

UPDATE public.orders
SET payment_status = 'paid'
WHERE payment_status = 'PAID';

ALTER TABLE public.orders ENABLE TRIGGER block_orders_field_escalation;

COMMIT;

-- ROLLBACK (separate file):
-- supabase/rollbacks/20260502010000_uship_trigger_lowercase_paid.down.sql
