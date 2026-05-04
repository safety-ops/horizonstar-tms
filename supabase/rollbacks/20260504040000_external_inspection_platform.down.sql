-- ============================================================================
-- Rollback: 20260504040000_external_inspection_platform
-- ============================================================================
--
-- Symmetric rollback for migration 20260504040000_external_inspection_platform.
--
-- Effect
-- ------
--   1. Drop the 5 columns added to public.orders:
--        order_source_platform
--        external_order_id
--        external_order_url
--        external_inspection_pickup_confirmed_at
--        external_inspection_delivery_confirmed_at
--      DROP COLUMN cascades to the inline CHECK constraint on
--      order_source_platform automatically — no separate DROP CONSTRAINT
--      needed.
--
--   2. Restore public.block_orders_field_escalation() to the body installed by
--      20260501160000_uship_code_orders_allow_list.sql (the 18-entry allow-
--      list, ending in 'uship_delivery_confirmation_code'). The two
--      external_inspection_*_confirmed_at entries are removed because the
--      columns they protect no longer exist after step 1.
--
-- How to apply manually
-- ---------------------
-- This file lives in supabase/rollbacks/ — NOT in supabase/migrations/ — so
-- the Supabase CLI will never auto-apply it during `supabase db push`. To run
-- it intentionally:
--
--   psql "$DATABASE_URL" \
--     -f supabase/rollbacks/20260504040000_external_inspection_platform.down.sql
--
-- or, against the linked project:
--
--   supabase db execute --linked \
--     --file supabase/rollbacks/20260504040000_external_inspection_platform.down.sql
--
-- After rollback, also remove the migration row from supabase_migrations.schema_migrations
-- so a subsequent `supabase db push` does not see the up-migration as already applied:
--
--   DELETE FROM supabase_migrations.schema_migrations WHERE version = '20260504040000';
--
-- Safety
-- ------
-- DROP COLUMN is destructive — any data written into the 5 columns is lost.
-- That is acceptable here because the columns are an audit-trail bridge
-- (driver attestation timestamps, importer metadata) and not a source of
-- truth for any downstream financial or compliance record.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Drop the 5 columns. Order doesn't matter; no FK dependencies.
-- ---------------------------------------------------------------------------
ALTER TABLE public.orders DROP COLUMN IF EXISTS external_inspection_delivery_confirmed_at;
ALTER TABLE public.orders DROP COLUMN IF EXISTS external_inspection_pickup_confirmed_at;
ALTER TABLE public.orders DROP COLUMN IF EXISTS external_order_url;
ALTER TABLE public.orders DROP COLUMN IF EXISTS external_order_id;
ALTER TABLE public.orders DROP COLUMN IF EXISTS order_source_platform;

-- ---------------------------------------------------------------------------
-- 2. Restore block_orders_field_escalation to the pre-migration body, i.e.
--    the version installed by 20260501160000_uship_code_orders_allow_list.sql.
--    Allow-list ends at 'uship_delivery_confirmation_code'; the two
--    external_inspection_*_confirmed_at entries are removed because their
--    underlying columns were just dropped.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.block_orders_field_escalation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  allowed TEXT[] := ARRAY[
    'delivery_status',
    'local_delivery_status',
    'local_driver_id',
    'local_delivery_type',
    'local_assigned_date',
    'local_confirmation_status',
    'actual_pickup_date',
    'actual_delivery_date',
    'pickup_eta',
    'delivery_eta',
    'driver_paid_status',
    'driver_paid_amount',
    'driver_paid_method',
    'dispatcher_notes',
    'notes',
    'local_notes',
    'updated_at',
    'uship_delivery_confirmation_code'
  ];
  old_stripped JSONB;
  new_stripped JSONB;
  k TEXT;
BEGIN
  IF current_user = 'service_role' THEN
    RETURN NEW;
  END IF;

  IF public.is_tms_staff() THEN
    RETURN NEW;
  END IF;

  old_stripped := to_jsonb(OLD);
  new_stripped := to_jsonb(NEW);

  FOREACH k IN ARRAY allowed LOOP
    old_stripped := old_stripped - k;
    new_stripped := new_stripped - k;
  END LOOP;

  IF old_stripped IS DISTINCT FROM new_stripped THEN
    RAISE EXCEPTION
      'Drivers/dealers cannot modify protected fields on orders (allowed: %)',
      array_to_string(allowed, ', ')
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.block_orders_field_escalation() FROM PUBLIC;

COMMIT;
