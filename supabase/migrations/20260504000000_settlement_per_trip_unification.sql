-- Settlement Per-Trip Unification
--
-- Adds scalar trip_id, revision tracking, supersession chain, and edit audit
-- to payroll_records so that each (driver, trip) settlement has at most one
-- active row. Multi-trip paystubs (type='paystub') keep trip_id NULL and
-- continue to use the existing trip_ids JSONB array.
--
-- Schema notes:
--   - trips.id is INTEGER (verified via existing FKs in
--     20260103000200_vehicle_inspections.sql), so trip_id matches as INT.
--   - payroll_records.id is SERIAL (INT), so superseded_by matches as INT.
--   - All ADD COLUMN / CREATE INDEX statements use IF NOT EXISTS for
--     idempotency. RLS policies are inherited from the existing table —
--     no policy changes needed.

-- ---------------------------------------------------------------------------
-- 1. New columns
-- ---------------------------------------------------------------------------

ALTER TABLE payroll_records
  ADD COLUMN IF NOT EXISTS trip_id INT REFERENCES trips(id) ON DELETE SET NULL;

ALTER TABLE payroll_records
  ADD COLUMN IF NOT EXISTS revision INT NOT NULL DEFAULT 1;

ALTER TABLE payroll_records
  ADD COLUMN IF NOT EXISTS superseded_by INT REFERENCES payroll_records(id) ON DELETE SET NULL;

ALTER TABLE payroll_records
  ADD COLUMN IF NOT EXISTS edit_audit JSONB NOT NULL DEFAULT '[]'::jsonb;

-- ---------------------------------------------------------------------------
-- 2. Column comments
-- ---------------------------------------------------------------------------

COMMENT ON COLUMN payroll_records.trip_id IS
  'Scalar trip reference for single-trip settlement records. Multi-trip paystubs leave this NULL and rely on trip_ids JSONB array. Enforced unique-active by uniq_active_settlement_per_trip.';

COMMENT ON COLUMN payroll_records.revision IS
  'Monotonically increasing revision number for this (driver_id, trip_id) settlement chain. Starts at 1; each supersession increments.';

COMMENT ON COLUMN payroll_records.superseded_by IS
  'If non-NULL, this row has been replaced by the referenced payroll_records.id. Active rows have superseded_by IS NULL.';

COMMENT ON COLUMN payroll_records.edit_audit IS
  'Append-only audit trail. Format: [{at: ISO8601, by_user_id: uuid|int, by_user_name: text, field_changes: {field: {from: value, to: value}}}].';

-- ---------------------------------------------------------------------------
-- 3. Backfill trip_id from trip_ids[0] for single-trip settlement records
-- ---------------------------------------------------------------------------
-- Only settlement records with exactly one entry in trip_ids get the scalar.
-- Paystubs (multi-trip) intentionally keep trip_id NULL.
-- Cast is defensive: strip wrapping quotes, trim whitespace, NULL on empty,
-- then cast to INT. Anything that fails to cast cleanly is skipped.

DO $$
BEGIN
  UPDATE payroll_records
     SET trip_id = NULLIF(btrim(btrim(trip_ids->>0), '"'), '')::INT
   WHERE type = 'settlement'
     AND trip_id IS NULL
     AND trip_ids IS NOT NULL
     AND jsonb_array_length(trip_ids) = 1
     AND NULLIF(btrim(btrim(trip_ids->>0), '"'), '') ~ '^[0-9]+$';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Backfill of payroll_records.trip_id encountered an error: %', SQLERRM;
END$$;

-- ---------------------------------------------------------------------------
-- 4. Pre-flight duplicate resolution
-- ---------------------------------------------------------------------------
-- If the backfill produced multiple active rows for the same
-- (driver_id, trip_id, type), the partial unique index below will fail.
-- Resolve by keeping the most recent (highest id) active and marking older
-- rows as superseded by it. Logs every dedupe action via RAISE NOTICE.

DO $$
DECLARE
  dup_record RECORD;
  dup_count  INT := 0;
BEGIN
  FOR dup_record IN
    WITH dupes AS (
      SELECT driver_id, trip_id, type, COUNT(*) AS cnt
        FROM payroll_records
       WHERE trip_id IS NOT NULL
         AND superseded_by IS NULL
       GROUP BY driver_id, trip_id, type
      HAVING COUNT(*) > 1
    ),
    ranked AS (
      SELECT pr.id,
             pr.driver_id,
             pr.trip_id,
             pr.type,
             ROW_NUMBER() OVER (
               PARTITION BY pr.driver_id, pr.trip_id, pr.type
               ORDER BY pr.id DESC
             ) AS rn,
             FIRST_VALUE(pr.id) OVER (
               PARTITION BY pr.driver_id, pr.trip_id, pr.type
               ORDER BY pr.id DESC
             ) AS keeper_id
        FROM payroll_records pr
        JOIN dupes d
          ON d.driver_id = pr.driver_id
         AND d.trip_id   = pr.trip_id
         AND d.type      = pr.type
       WHERE pr.superseded_by IS NULL
    )
    SELECT id, driver_id, trip_id, type, keeper_id
      FROM ranked
     WHERE rn > 1
  LOOP
    RAISE NOTICE
      'Deduping payroll_records: marking id=% (driver=%, trip=%, type=%) as superseded_by=%',
      dup_record.id, dup_record.driver_id, dup_record.trip_id,
      dup_record.type, dup_record.keeper_id;

    UPDATE payroll_records
       SET superseded_by = dup_record.keeper_id
     WHERE id = dup_record.id;

    dup_count := dup_count + 1;
  END LOOP;

  IF dup_count > 0 THEN
    RAISE NOTICE 'Settlement-per-trip dedupe: superseded % older row(s) so the partial unique index can be created.', dup_count;
  END IF;
END$$;

-- ---------------------------------------------------------------------------
-- 5. Indexes
-- ---------------------------------------------------------------------------
-- Partial unique index: at most one active (non-superseded) record per
-- (driver_id, trip_id, type). NULL trip_id rows are excluded so multi-trip
-- paystubs are unaffected.

CREATE UNIQUE INDEX IF NOT EXISTS uniq_active_settlement_per_trip
  ON payroll_records (driver_id, trip_id, type)
  WHERE trip_id IS NOT NULL AND superseded_by IS NULL;

CREATE INDEX IF NOT EXISTS idx_payroll_records_trip_id
  ON payroll_records (trip_id);
