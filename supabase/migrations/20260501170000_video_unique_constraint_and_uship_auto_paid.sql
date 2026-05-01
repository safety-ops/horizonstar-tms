-- ============================================================================
-- Migration: 20260501170000_video_unique_constraint_and_uship_auto_paid
-- ============================================================================
--
-- Two production bugs from device testing of build 202605011508:
--
-- Bug A — Video uploads silently fail to insert
-- ----------------------------------------------
-- iOS pipeline uploads video to inspection-media storage (succeeds), then
-- POSTs to inspection_videos with `on_conflict=client_media_id` and the
-- merge-duplicates Prefer header. PostgREST returns 42P10:
-- "no unique or exclusion constraint matching the ON CONFLICT specification"
-- because client_media_id was added in 20260211173600 without a UNIQUE index.
-- iOS catches the failure silently → row never lands → Web TMS shows photos
-- but no video. Storage has the .mov, DB has nothing.
--
-- Fix: add a UNIQUE index on inspection_videos.client_media_id (partial,
-- since legacy rows may have NULL — pre-2026-02-19 row 1 has client_media_id=NULL).
--
-- Bug B — Order payment_status not set when uShip code captured
-- --------------------------------------------------------------
-- When driver submits the uShip confirmation code at delivery, the code lands
-- in orders.uship_delivery_confirmation_code (Bug 1 fix from 20260501160000),
-- but payment_status stays UNINVOICED. uShip handles the payout via their
-- platform — once the driver has the confirmation code, the load is
-- effectively settled and the dispatcher should see it as paid.
--
-- Fix: trigger on orders that auto-fills payment_status='PAID' and
-- driver_paid_status='PAID' when uship_delivery_confirmation_code transitions
-- from NULL to non-NULL AND payment_method='USHIP'.

BEGIN;

-- ---------------------------------------------------------------------------
-- A. UNIQUE constraint for inspection_videos.client_media_id
-- ---------------------------------------------------------------------------

-- Partial unique: only enforces on non-NULL values, so legacy rows with NULL
-- client_media_id (the pre-Feb-2026 row) don't conflict with each other.
CREATE UNIQUE INDEX IF NOT EXISTS inspection_videos_client_media_id_uidx
  ON public.inspection_videos (client_media_id)
  WHERE client_media_id IS NOT NULL;

COMMENT ON INDEX public.inspection_videos_client_media_id_uidx IS
  'Required for PostgREST upsert with on_conflict=client_media_id. iOS app generates a UUID per video which is the natural idempotency key. Pre-2026-02 legacy rows with NULL client_media_id are excluded by the partial predicate.';

-- ---------------------------------------------------------------------------
-- B. Auto-mark order paid when uShip confirmation code captured
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

DROP TRIGGER IF EXISTS mark_order_paid_on_uship_code ON public.orders;
CREATE TRIGGER mark_order_paid_on_uship_code
  BEFORE UPDATE OF uship_delivery_confirmation_code ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.mark_order_paid_on_uship_code();

-- ---------------------------------------------------------------------------
-- B.1 Backfill: existing orders with uShip code captured but payment unset
-- ---------------------------------------------------------------------------
-- Inspection 54 already wrote the code via the (now fixed) Phase 4 flow but
-- before this trigger existed. Catch up those rows.
--
-- The block_orders_field_escalation trigger (RLS migration 20260429200000)
-- rejects writes to payment_status from non-staff/non-service-role callers.
-- Migrations run as the postgres role, which is_tms_staff() returns false for.
-- Disable the trigger for the duration of the backfill, re-enable before
-- COMMIT. Pattern established in 20260501130000_payment_method_terms_restructure.sql.
--
-- Backfill semantics intentionally match the trigger (forces driver_paid_status
-- to 'PAID' regardless of prior value), since uShip-code capture is the
-- definitive settlement signal in the dispatch model. Applies regardless of
-- driver active/inactive status — the load was settled at code-capture time,
-- the driver's current employment is irrelevant to that fact.

ALTER TABLE public.orders DISABLE TRIGGER block_orders_field_escalation;

UPDATE public.orders
SET payment_status = 'PAID',
    driver_paid_status = 'PAID',
    driver_paid_method = COALESCE(NULLIF(driver_paid_method, ''), 'USHIP')
WHERE uship_delivery_confirmation_code IS NOT NULL
  AND uship_delivery_confirmation_code <> ''
  AND UPPER(COALESCE(payment_method, '')) = 'USHIP'
  AND UPPER(COALESCE(payment_status, '')) NOT IN ('PAID', 'COLLECTED', 'INVOICED');

ALTER TABLE public.orders ENABLE TRIGGER block_orders_field_escalation;

COMMIT;

-- ROLLBACK (separate file in supabase/rollbacks/ if needed):
-- BEGIN;
-- DROP TRIGGER IF EXISTS mark_order_paid_on_uship_code ON public.orders;
-- DROP FUNCTION IF EXISTS public.mark_order_paid_on_uship_code();
-- DROP INDEX IF EXISTS public.inspection_videos_client_media_id_uidx;
-- COMMIT;
-- Note: the backfill UPDATE is one-way; rolling back this migration does NOT
-- revert payment_status changes on already-coded orders.
