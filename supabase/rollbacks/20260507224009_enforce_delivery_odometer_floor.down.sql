-- ============================================================================
-- Rollback: 20260507224009_enforce_delivery_odometer_floor.down.sql
-- ============================================================================
--
-- When to apply
-- -------------
-- Apply this rollback ONLY if the
-- 20260507224009_enforce_delivery_odometer_floor migration needs to be
-- reverted in production (e.g., the trigger is producing false positives
-- against legitimate write paths, or it conflicts with a different invariant
-- being introduced in a subsequent migration).
--
-- This file lives in supabase/rollbacks/ — NOT in supabase/migrations/ —
-- precisely so that `supabase db push --linked` does NOT auto-apply it
-- alongside forward migrations. To run it, copy the SQL into the Supabase
-- Dashboard SQL Editor or run via psql against the linked database.
--
-- Effect
-- ------
-- Drops:
--   * Trigger enforce_delivery_odometer_floor_trigger on public.vehicle_inspections
--   * Function public.enforce_delivery_odometer_floor()
--
-- After this runs, the database no longer enforces that delivery.odometer >=
-- pickup.odometer for the same order. The iOS Driver App's client-side check
-- (Phase 10) still applies, but is not backed by a server-side guarantee.
-- ============================================================================

BEGIN;

DROP TRIGGER IF EXISTS enforce_delivery_odometer_floor_trigger ON public.vehicle_inspections;

DROP FUNCTION IF EXISTS public.enforce_delivery_odometer_floor();

COMMIT;
