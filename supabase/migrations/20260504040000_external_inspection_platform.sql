-- ============================================================================
-- Migration: 20260504040000_external_inspection_platform
-- ============================================================================
--
-- Context
-- -------
-- Drivers currently perform vehicle inspections in three different broker apps
-- depending on which platform sourced the load:
--   * Central Dispatch
--   * SuperDispatch
--   * Ship.cars
-- Plus the in-house native flow for direct loads.
--
-- The TMS will tag each order with which platform it came from so the driver
-- app can render a deep-link button into the broker's app for the inspection.
-- After the driver returns to TMS, a "Did you complete the inspection in
-- [Platform]?" Yes/No modal records a confirmation timestamp and toggles the
-- order's pickup/delivery status. This is purely an audit-trail bridge — we
-- do NOT ingest broker inspection payloads, photos, or any structured data.
-- The only signal stored is "the driver attested they finished in the broker
-- app at this timestamp."
--
-- Schema additions
-- ----------------
-- 5 new columns on public.orders:
--
--   1. order_source_platform                          text  (CHECK-constrained)
--      Which broker platform the order originated from. NULL for legacy /
--      pre-feature rows; the driver app falls back to the native inspection
--      flow when this is NULL, so no backfill is required.
--
--   2. external_order_id                              text
--      Opaque identifier supplied by the broker platform (uShip ID, CD load
--      ID, SD shipment ID, etc.). Free-text — each platform's format differs.
--
--   3. external_order_url                             text
--      Deep-link URL the driver button opens to jump into the broker app.
--      Stored at import time by the dispatcher / Chrome importer.
--
--   4. external_inspection_pickup_confirmed_at        timestamptz
--      Set by the driver app the moment the driver taps "Yes, I completed it"
--      in the post-pickup confirmation modal.
--
--   5. external_inspection_delivery_confirmed_at      timestamptz
--      Same, but for the delivery-side confirmation.
--
-- Driver write permissions
-- ------------------------
-- Drivers (anon role, not is_tms_staff) must be able to write the two
-- confirmation timestamps from the iOS app. They must NOT be able to write
-- order_source_platform / external_order_id / external_order_url — those are
-- set by dispatchers / the Chrome load importer and changing them client-side
-- would let a driver redirect future inspection traffic to the wrong platform
-- or impersonate a different external order.
--
-- The block_orders_field_escalation trigger (installed in
-- 20260429200000_rls_tier3.sql, last touched in
-- 20260501160000_uship_code_orders_allow_list.sql) is the gatekeeper. We
-- re-issue its body via CREATE OR REPLACE FUNCTION with two new entries
-- appended to the `allowed` array:
--
--   'external_inspection_pickup_confirmed_at'
--   'external_inspection_delivery_confirmed_at'
--
-- The three importer-owned columns are deliberately omitted from the allow-
-- list so any driver-role PATCH that touches them fails with SQLSTATE 42501.
--
-- No backfill / no indexes
-- ------------------------
-- Existing rows stay order_source_platform = NULL on purpose — the driver app
-- routes NULL through the existing native inspection flow, so the feature is
-- opt-in per-order without a data migration. We are not adding an index on
-- order_source_platform: the orders table is small enough today that a seq
-- scan with a status filter is cheaper than maintaining another B-tree, and
-- per-order lookups already hit the existing primary key on id. Revisit if
-- platform-filtered grid queries become a hot path.
--
-- RLS / policies
-- --------------
-- No RLS policy changes. The existing orders_update / orders_select policies
-- already permit driver and TMS-staff access at the row level; the trigger
-- enforces column-level write restrictions on top of that.
--
-- Idempotency
-- -----------
--   * ADD COLUMN IF NOT EXISTS — safe to re-run.
--   * CHECK constraint is declared inline on the column add, so it only
--     attaches the first time. (Re-running won't try to add a duplicate
--     constraint because the column add itself is skipped.)
--   * CREATE OR REPLACE FUNCTION — naturally idempotent.
--   * COMMENT ON COLUMN — overwrites cleanly.
--
-- Rollback
-- --------
-- supabase/rollbacks/20260504040000_external_inspection_platform.down.sql
-- drops the 5 columns and restores the trigger body to the prior 18-entry
-- allow-list (the state set by 20260501160000_uship_code_orders_allow_list).
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Add the 5 new columns to public.orders.
--    All nullable: legacy rows must remain valid without a backfill.
-- ---------------------------------------------------------------------------
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS order_source_platform text
    CHECK (
      order_source_platform IS NULL
      OR order_source_platform IN ('central_dispatch','super_dispatch','ship_cars','direct')
    );

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS external_order_id text;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS external_order_url text;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS external_inspection_pickup_confirmed_at timestamptz;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS external_inspection_delivery_confirmed_at timestamptz;

COMMENT ON COLUMN public.orders.order_source_platform IS
  'Broker platform the order originated from. One of central_dispatch / super_dispatch / ship_cars / direct, or NULL for legacy rows that use the native inspection flow. Set by dispatcher / Chrome load importer; drivers cannot write this (block_orders_field_escalation).';

COMMENT ON COLUMN public.orders.external_order_id IS
  'Opaque identifier from the source broker platform (e.g. CD load ID, SD shipment ID). Free-text — each platform formats differently. Importer-owned; not driver-writable.';

COMMENT ON COLUMN public.orders.external_order_url IS
  'Deep-link URL the driver app opens to launch the broker''s app for inspection. Importer-owned; not driver-writable.';

COMMENT ON COLUMN public.orders.external_inspection_pickup_confirmed_at IS
  'Driver-set timestamp recorded when the driver confirms in TMS that they completed the pickup-side inspection inside the broker app. Driver-writable via block_orders_field_escalation allow-list. NULL means not yet confirmed.';

COMMENT ON COLUMN public.orders.external_inspection_delivery_confirmed_at IS
  'Driver-set timestamp recorded when the driver confirms in TMS that they completed the delivery-side inspection inside the broker app. Driver-writable via block_orders_field_escalation allow-list. NULL means not yet confirmed.';

-- ---------------------------------------------------------------------------
-- 2. Replace block_orders_field_escalation with the updated allow-list.
--    Only change vs 20260501160000: two new entries appended after
--    'uship_delivery_confirmation_code'. Body, search_path, security model,
--    service_role early-return, is_tms_staff() check, and error message all
--    preserved verbatim from the prior migration.
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
    'uship_delivery_confirmation_code',
    'external_inspection_pickup_confirmed_at',
    'external_inspection_delivery_confirmed_at'
  ];
  old_stripped JSONB;
  new_stripped JSONB;
  k TEXT;
BEGIN
  -- service_role connections (edge functions, scheduled jobs) bypass — they
  -- have no users.role row, so is_tms_staff() returns false; without this
  -- early return, every server-side UPDATE on protected columns would fail.
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

-- ---------------------------------------------------------------------------
-- 3. Defensive re-issue of the REVOKE. CREATE OR REPLACE preserves existing
--    grants, so this is a no-op if the grant state is already correct.
-- ---------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.block_orders_field_escalation() FROM PUBLIC;

COMMIT;

-- Rollback lives at supabase/rollbacks/20260504040000_external_inspection_platform.down.sql.
