-- ============================================================================
-- Rollback: 20260502010000_uship_trigger_lowercase_paid
-- ============================================================================
--
-- Restores mark_order_paid_on_uship_code() to the pre-fix body that writes
-- uppercase 'PAID' to payment_status (the original 20260501170000 behavior).
--
-- NOTE: The backfill UPDATE in the forward migration (payment_status 'PAID' →
-- 'paid') is intentionally NOT reverted here. The casing change on historical
-- rows is a forward-only data fix — reverting it would re-introduce the display
-- bug for those rows without any operational benefit. Only the trigger function
-- is restored so that future uShip-code captures again write uppercase 'PAID'.
-- If a full data revert is needed, run separately:
--   UPDATE public.orders SET payment_status = 'PAID' WHERE payment_status = 'paid';
-- (with block_orders_field_escalation disabled)

BEGIN;

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
    -- Only set payment_status to PAID if it's not already in a terminal state
    -- (PAID, COLLECTED, etc.). A dispatcher who already marked it paid manually
    -- shouldn't be overwritten.
    IF UPPER(COALESCE(NEW.payment_status, '')) NOT IN ('PAID', 'COLLECTED', 'INVOICED') THEN
      NEW.payment_status := 'PAID';
    END IF;

    -- Mark the driver-paid leg as PAID with method=USHIP. uShip pays the
    -- carrier via their marketplace, so once the code is collected the
    -- driver has been "paid" in the dispatch sense.
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

COMMIT;
