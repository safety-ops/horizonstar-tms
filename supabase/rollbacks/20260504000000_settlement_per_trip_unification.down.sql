-- Rollback for 20260504000000_settlement_per_trip_unification.sql
--
-- Reverses the forward migration in dependency order:
--   1. Drop indexes that reference the new columns.
--   2. Drop the columns themselves (FKs auto-drop with the columns).
--
-- All statements use IF EXISTS so the rollback is safe to re-run.
-- This file lives in supabase/rollbacks/ on purpose: anything in
-- supabase/migrations/ would be auto-applied by `supabase db push --linked`.

-- ---------------------------------------------------------------------------
-- 1. Drop indexes first
-- ---------------------------------------------------------------------------

DROP INDEX IF EXISTS uniq_active_settlement_per_trip;
DROP INDEX IF EXISTS idx_payroll_records_trip_id;

-- ---------------------------------------------------------------------------
-- 2. Drop columns
-- ---------------------------------------------------------------------------
-- Dropping a column with a FOREIGN KEY constraint also drops the constraint,
-- so no separate DROP CONSTRAINT is required.

ALTER TABLE payroll_records DROP COLUMN IF EXISTS edit_audit;
ALTER TABLE payroll_records DROP COLUMN IF EXISTS superseded_by;
ALTER TABLE payroll_records DROP COLUMN IF EXISTS revision;
ALTER TABLE payroll_records DROP COLUMN IF EXISTS trip_id;
