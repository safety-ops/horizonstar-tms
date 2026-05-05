-- Migration: 20260505033100_extend_platform_vinlocity_carsarrive
--
-- Context
-- -------
-- The orders.order_source_platform column was introduced by
-- 20260504040000_external_inspection_platform.sql with a CHECK constraint
-- restricting values to ('central_dispatch','super_dispatch','ship_cars','direct')
-- or NULL. The operator is rolling out support for two additional broker
-- platforms used by drivers:
--
--   - 'vinlocity'   — Vinlocity Carrier (ACERTUS), driver app "Vinlocity Driver"
--   - 'carsarrive'  — CarsArrive Plus (OPENLANE), driver app "CarsArrive Plus"
--
-- Both have the same UX shape as Central Dispatch: no AASA file, so iOS
-- Universal Links cannot fire. The driver app shows the App Store fallback
-- alert ("Open <App>" → App Store entry → tap Open in App Store → broker app
-- launches). Same security model — drivers still cannot write
-- order_source_platform; only dispatchers and the importer can.
--
-- Schema change
-- -------------
-- Postgres does not allow editing a CHECK constraint in place. Pattern: drop
-- the existing constraint, then re-add with the extended IN list.
--
-- Constraint name: orders_order_source_platform_check (Postgres auto-naming
-- on the inline CHECK created in 20260504040000_external_inspection_platform.sql).
--
-- Driver write permissions
-- ------------------------
-- The block_orders_field_escalation trigger (allow-list) is intentionally
-- NOT touched. Drivers' write permissions are unchanged: they can still
-- write the two external_inspection_*_confirmed_at timestamps, and they
-- still cannot write order_source_platform / external_order_id /
-- external_order_url. Adding new allowed enum values does not change who
-- can set them.
--
-- Backfill
-- --------
-- None. Existing orders keep their current order_source_platform value
-- (or NULL for legacy rows). New imports / dispatcher edits can use the
-- new values from the moment this migration is applied.
--
-- Idempotency
-- -----------
-- DROP CONSTRAINT IF EXISTS + named ADD CONSTRAINT — re-runnable. If the
-- constraint was already updated by a prior partial apply, the DROP is a
-- no-op and the ADD will fail loudly with a duplicate-name error rather
-- than silently mismatching.
--
-- Rollback
-- --------
-- Lives at supabase/rollbacks/20260505033100_extend_platform_vinlocity_carsarrive.down.sql
-- (NOT under supabase/migrations/, so the CLI doesn't auto-apply it).
-- WARNING: rollback FAILS if any existing rows hold the new values
-- ('vinlocity', 'carsarrive') — those would have to be remapped first.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Drop the existing 4-value CHECK and replace with a 6-value version.
-- ---------------------------------------------------------------------------
ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_order_source_platform_check;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_order_source_platform_check
    CHECK (
      order_source_platform IS NULL
      OR order_source_platform IN (
        'central_dispatch',
        'super_dispatch',
        'ship_cars',
        'vinlocity',
        'carsarrive',
        'direct'
      )
    );

-- ---------------------------------------------------------------------------
-- 2. Refresh the column comment so future operators see the current vocabulary
--    when they run \d+ orders or read schema dumps.
-- ---------------------------------------------------------------------------
COMMENT ON COLUMN public.orders.order_source_platform IS
  'Broker platform the order originated from. One of central_dispatch / super_dispatch / ship_cars / vinlocity / carsarrive / direct, or NULL for legacy rows that use the native inspection flow. Set by dispatcher / Chrome load importer; drivers cannot write this (block_orders_field_escalation).';

COMMIT;

-- Rollback lives at supabase/rollbacks/20260505033100_extend_platform_vinlocity_carsarrive.down.sql.
