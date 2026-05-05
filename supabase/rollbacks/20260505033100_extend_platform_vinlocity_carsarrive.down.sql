-- Rollback: 20260505033100_extend_platform_vinlocity_carsarrive
--
-- Reverts the CHECK constraint on orders.order_source_platform from the 6-value
-- vocabulary back to the original 4 values shipped by
-- 20260504040000_external_inspection_platform.sql.
--
-- WARNING — read before running
-- -----------------------------
-- This rollback FAILS if any existing rows hold the values 'vinlocity' or
-- 'carsarrive'. Postgres will reject the new constraint as soon as it tries
-- to validate against current data. Before applying, run:
--
--   SELECT id, order_number, order_source_platform
--     FROM public.orders
--    WHERE order_source_platform IN ('vinlocity', 'carsarrive');
--
-- and either remap those rows to a supported value (e.g., 'direct' to fall
-- back to the native flow) or set order_source_platform = NULL on them.
--
-- This file lives under supabase/rollbacks/ (NOT supabase/migrations/) on
-- purpose: the CLI auto-applies anything in migrations/, and rollbacks are
-- meant to be run manually.
--
-- Manual application:
--   psql "$SUPABASE_DB_URL" -f supabase/rollbacks/20260505033100_extend_platform_vinlocity_carsarrive.down.sql
-- or via the CLI:
--   supabase db execute --linked --file supabase/rollbacks/20260505033100_extend_platform_vinlocity_carsarrive.down.sql
--
-- After running, also delete the migration row so a subsequent
-- `supabase db push` doesn't re-apply the up migration:
--   DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260505033100';
-- (Intentionally left as documentation, not executed inside the transaction.)
-- ============================================================================

BEGIN;

ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_order_source_platform_check;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_order_source_platform_check
    CHECK (
      order_source_platform IS NULL
      OR order_source_platform IN ('central_dispatch','super_dispatch','ship_cars','direct')
    );

COMMENT ON COLUMN public.orders.order_source_platform IS
  'Broker platform the order originated from. One of central_dispatch / super_dispatch / ship_cars / direct, or NULL for legacy rows that use the native inspection flow. Set by dispatcher / Chrome load importer; drivers cannot write this (block_orders_field_escalation).';

COMMIT;
