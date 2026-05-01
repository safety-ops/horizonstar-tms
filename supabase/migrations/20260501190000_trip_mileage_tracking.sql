-- ============================================================================
-- Migration: 20260501190000_trip_mileage_tracking
-- ============================================================================
--
-- Phase A of the per-trip Samsara mileage tracking feature.
-- Reference: .claude/plans/hey-i-notcied-cozy-waterfall.md
--
-- New columns added in this migration:
--
--   trucks.samsara_vehicle_id  (TEXT)
--     Persists the truck → Samsara vehicle mapping to the DB. Previously this
--     mapping lived in localStorage only, which is fragile. The Web TMS
--     manageTruckSamsaraLinks() function will be updated (Phase A web work,
--     separate commit) to write here in addition to localStorage.
--
--   trips.trip_started_at  (TIMESTAMPTZ)
--   trips.trip_ended_at    (TIMESTAMPTZ)
--   trips.start_odometer   (NUMERIC)
--   trips.end_odometer     (NUMERIC)
--   trips.miles_driven     (NUMERIC, generated)
--   trips.mileage_source   (TEXT)
--   trips.mileage_error    (TEXT)
--
-- miles_driven is a GENERATED ALWAYS AS ... STORED column. Postgres
-- auto-computes it as (end_odometer - start_odometer) any time either
-- operand is updated. When either side is NULL (trip not yet started or
-- not yet ended), the expression evaluates to NULL — which is the desired
-- semantics. No application code needs to maintain this value.
--
-- The unique index on trucks.samsara_vehicle_id is partial (excludes NULL)
-- so trucks without a Samsara mapping do not conflict with each other.
-- The fleet is 100% Samsara-equipped per the plan (Q1=A), but the partial
-- predicate is defensive against the transitional window while the
-- localStorage → DB migration runs — some trucks will temporarily have
-- samsara_vehicle_id = NULL and must not collide.
--
-- mileage_source is free-text TEXT with no CHECK constraint. Current
-- value will always be 'samsara'. A future 'manual' value will be written
-- without requiring a schema change.
--
-- Idempotency: ADD COLUMN IF NOT EXISTS and CREATE UNIQUE INDEX IF NOT EXISTS
-- are both naturally idempotent. This migration is safe to re-run.
--
-- No rollback file is provided. Rolling back ADD COLUMN requires DROP COLUMN,
-- which is destructive (discards captured odometer data). If a rollback is
-- needed after data has been written, it must be hand-authored. An empty
-- rollback placeholder would be misleading.

BEGIN;

-- ---------------------------------------------------------------------------
-- A. trucks: Samsara vehicle ID column + partial unique index
-- ---------------------------------------------------------------------------

ALTER TABLE trucks ADD COLUMN IF NOT EXISTS samsara_vehicle_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS trucks_samsara_vehicle_id_uidx
  ON trucks (samsara_vehicle_id)
  WHERE samsara_vehicle_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- B. trips: timestamps, odometers, generated miles, source, error
-- ---------------------------------------------------------------------------

ALTER TABLE trips ADD COLUMN IF NOT EXISTS trip_started_at TIMESTAMPTZ;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS trip_ended_at   TIMESTAMPTZ;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS start_odometer  NUMERIC;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS end_odometer    NUMERIC;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS miles_driven    NUMERIC
  GENERATED ALWAYS AS (end_odometer - start_odometer) STORED;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS mileage_source  TEXT;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS mileage_error   TEXT;

-- ---------------------------------------------------------------------------
-- C. Column documentation
-- ---------------------------------------------------------------------------

COMMENT ON COLUMN trucks.samsara_vehicle_id IS
  'Samsara API vehicle ID for this truck. Populated by the Web TMS truck-link tool. NULL if not yet linked.';

COMMENT ON COLUMN trips.trip_started_at IS
  'Set when driver presses "Start Trip" in iOS. UTC timestamp.';

COMMENT ON COLUMN trips.trip_ended_at IS
  'Set when driver presses "End Trip" in iOS.';

COMMENT ON COLUMN trips.start_odometer IS
  'Truck odometer reading in miles at trip start, fetched from Samsara obdOdometerMeters.';

COMMENT ON COLUMN trips.end_odometer IS
  'Truck odometer reading in miles at trip end, fetched from Samsara.';

COMMENT ON COLUMN trips.miles_driven IS
  'Auto-computed: end_odometer - start_odometer. NULL until both are set.';

COMMENT ON COLUMN trips.mileage_source IS
  'Source of the odometer values. Currently always "samsara"; future "manual" possible.';

COMMENT ON COLUMN trips.mileage_error IS
  'Last Samsara fetch error message if any. NULL on success. Set when driver started/ended a trip but the Samsara API call failed.';

COMMIT;

-- ROLLBACK (hand-author if ever needed — see header note above):
-- BEGIN;
-- ALTER TABLE trips DROP COLUMN IF EXISTS mileage_error;
-- ALTER TABLE trips DROP COLUMN IF EXISTS mileage_source;
-- ALTER TABLE trips DROP COLUMN IF EXISTS miles_driven;
-- ALTER TABLE trips DROP COLUMN IF EXISTS end_odometer;
-- ALTER TABLE trips DROP COLUMN IF EXISTS start_odometer;
-- ALTER TABLE trips DROP COLUMN IF EXISTS trip_ended_at;
-- ALTER TABLE trips DROP COLUMN IF EXISTS trip_started_at;
-- DROP INDEX IF EXISTS trucks_samsara_vehicle_id_uidx;
-- ALTER TABLE trucks DROP COLUMN IF EXISTS samsara_vehicle_id;
-- COMMIT;
-- WARNING: DROP COLUMN is irreversible if rows with odometer data exist.
-- Do not run the rollback after any trips have captured start/end odometer values.
