-- ============================================================================
-- Migration: 20260501160000_uship_code_orders_allow_list
-- ============================================================================
--
-- Context
-- -------
-- Phase 4 of the payments restructure (migration 20260501130000) added the
-- column `orders.uship_delivery_confirmation_code` so that the dispatcher can
-- read the uShip delivery code directly from the orders table without having
-- to join vehicle_inspections.
--
-- The driver app writes to that column in SupabaseService.saveInspectionUshipCode
-- via a PATCH on the orders row when payment_method = USHIP.
--
-- Bug surfaced
-- ------------
-- iOS build 202605011508 surfaced "Failed to save — please try again" on the
-- driver-side uShip code submission screen. Root cause: the trigger
-- block_orders_field_escalation (installed by migration 20260429200000) rejects
-- any driver-role PATCH that touches a column not in its hardcoded allow-list.
-- The Phase 4 column was added after that trigger was written and was never
-- included in the list, so every driver PATCH threw SQLSTATE 42501.
--
-- Fix
-- ---
-- Re-declare the function body with 'uship_delivery_confirmation_code' appended
-- to the allowed array. CREATE OR REPLACE FUNCTION updates the function in place;
-- the existing trigger (block_orders_field_escalation BEFORE UPDATE ON orders)
-- automatically picks up the new body without any trigger DDL changes.
--
-- Security rationale
-- ------------------
-- uship_delivery_confirmation_code is an opaque confirmation token set by the
-- driver at delivery time. It is not a privilege-bearing field. Allowing drivers
-- to write it poses no escalation risk beyond what the existing allow-list
-- already permits (e.g. delivery_status, driver_paid_amount).
--
-- Idempotency
-- -----------
-- CREATE OR REPLACE FUNCTION is naturally idempotent. Re-running this migration
-- is safe. Rollback is implicit: re-running the prior migration's function body
-- (20260429200000_rls_tier3.sql lines 221-279) restores the old allow-list.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Replace block_orders_field_escalation with the updated allow-list.
--    Only change vs 20260429200000: 'uship_delivery_confirmation_code' appended
--    after 'updated_at'.
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
-- 2. Defensive re-issue of the REVOKE. CREATE OR REPLACE preserves existing
--    grants, so this is a no-op if the grant state is already correct.
-- ---------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.block_orders_field_escalation() FROM PUBLIC;

COMMIT;
