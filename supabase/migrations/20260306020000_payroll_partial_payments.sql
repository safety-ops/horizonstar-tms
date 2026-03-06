-- Add amount_paid column to payroll_records for partial payment tracking
ALTER TABLE payroll_records
  ADD COLUMN IF NOT EXISTS amount_paid NUMERIC(12,2) DEFAULT 0;

COMMENT ON COLUMN payroll_records.amount_paid IS 'Total amount paid so far (supports partial payments)';
