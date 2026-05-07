-- ============================================================================
-- Migration: 20260507224009_enforce_delivery_odometer_floor
-- ============================================================================
--
-- Context
-- -------
-- Phase 11 — defense-in-depth for vehicle inspection odometer integrity.
-- Phase 10 shipped client-side validation in the iOS Driver App that prevents
-- a delivery inspection's odometer reading from being recorded below the
-- matching pickup inspection's odometer reading. This migration is the
-- server-side guarantee for the same invariant: even if a client (a future
-- web/admin form, a back-fill script, an external API caller, or a misbehaving
-- build of the driver app) bypasses the iOS check, the database refuses
-- to persist a delivery row whose odometer reading is below the pickup
-- floor for the same order.
--
-- Schema change
-- -------------
-- Adds:
--   * Function public.enforce_delivery_odometer_floor() — looks up the pickup
--     odometer for NEW.order_id and raises a check_violation (SQLSTATE 23514)
--     if the incoming delivery odometer is below it.
--   * Trigger enforce_delivery_odometer_floor_trigger on
--     public.vehicle_inspections — fires BEFORE INSERT OR UPDATE OF odometer.
--     The OF odometer clause means UPDATEs of unrelated columns (notes,
--     status, photos, signed_at, etc.) skip the trigger entirely.
--
-- service_role bypass
-- -------------------
-- The function early-returns when current_user = 'service_role'. This mirrors
-- the established block_orders_field_escalation pattern: trusted server-side
-- code paths (edge functions, migrations, back-fills, sync jobs) need to be
-- able to insert/update inspection rows without being subject to per-row
-- application-level invariants — the invariant exists to constrain end users,
-- not the platform itself. End-user requests authenticated as anon, authenticated,
-- or any other Postgres role still pass through the check.
--
-- What this does NOT validate
-- ---------------------------
-- The symmetric case — a UPDATE on the *pickup* row that raises pickup.odometer
-- above the existing delivery.odometer — is intentionally out of scope for
-- this migration. Pickup odometer is recorded first by definition, and the
-- iOS app does not allow editing the pickup odometer after a delivery has been
-- created. If a future requirement needs that guarantee, add a second trigger
-- at that time rather than expanding this one.
--
-- Idempotency
-- -----------
-- * Function uses CREATE OR REPLACE — safe to re-run.
-- * Trigger uses DROP TRIGGER IF EXISTS + CREATE TRIGGER — safe to re-run.
--
-- Rollback
-- --------
-- See supabase/rollbacks/20260507224009_enforce_delivery_odometer_floor.down.sql
-- (rollbacks live outside supabase/migrations/ so the CLI does not auto-apply
-- them on `supabase db push`).
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.enforce_delivery_odometer_floor()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  pickup_odometer INTEGER;
BEGIN
  -- Trusted server-side roles bypass the check (mirrors
  -- block_orders_field_escalation pattern).
  IF current_user = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- Only constrain delivery rows with a non-NULL odometer reading. Pickup
  -- rows, and rows with no odometer recorded yet, are out of scope.
  IF NEW.inspection_type IS DISTINCT FROM 'delivery' OR NEW.odometer IS NULL THEN
    RETURN NEW;
  END IF;

  -- Lookup the pickup odometer for the same order. The composite of
  -- idx_vehicle_inspections_order_id + idx_vehicle_inspections_type makes
  -- this an indexed lookup.
  SELECT odometer
    INTO pickup_odometer
    FROM public.vehicle_inspections
   WHERE order_id = NEW.order_id
     AND inspection_type = 'pickup'
   LIMIT 1;

  -- No pickup recorded yet, or pickup recorded without an odometer reading
  -- — nothing to compare against, allow the write.
  IF pickup_odometer IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.odometer < pickup_odometer THEN
    RAISE EXCEPTION
      'Delivery odometer (%) cannot be less than pickup odometer (%) for order %',
      NEW.odometer, pickup_odometer, NEW.order_id
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_delivery_odometer_floor_trigger ON public.vehicle_inspections;

CREATE TRIGGER enforce_delivery_odometer_floor_trigger
  BEFORE INSERT OR UPDATE OF odometer ON public.vehicle_inspections
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_delivery_odometer_floor();

COMMIT;
