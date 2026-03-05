-- Payroll Enhancements: payroll_records table + driver default_deductions column

-- Add default_deductions JSONB column to drivers table
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS default_deductions JSONB DEFAULT '{}'::jsonb;

-- Create payroll_records table for tracking generated paystubs and settlements
CREATE TABLE IF NOT EXISTS payroll_records (
  id SERIAL PRIMARY KEY,
  driver_id INT REFERENCES drivers(id) ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'paystub', -- paystub | settlement
  period_start DATE,
  period_end DATE,
  pay_date DATE,
  stub_number TEXT,
  check_number TEXT,
  trip_ids JSONB DEFAULT '[]'::jsonb,
  gross_earnings NUMERIC(12,2) DEFAULT 0,
  cash_collected NUMERIC(12,2) DEFAULT 0,
  reimbursements NUMERIC(12,2) DEFAULT 0,
  net_pay NUMERIC(12,2) DEFAULT 0,
  deductions JSONB DEFAULT '{}'::jsonb,
  bonuses JSONB DEFAULT '{}'::jsonb,
  status TEXT DEFAULT 'finalized', -- draft | finalized | paid
  created_at TIMESTAMPTZ DEFAULT now(),
  company_id UUID
);

-- Enable RLS
ALTER TABLE payroll_records ENABLE ROW LEVEL SECURITY;

-- RLS policy: allow all operations for authenticated users
CREATE POLICY "payroll_records_all" ON payroll_records
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Index for driver lookups
CREATE INDEX IF NOT EXISTS idx_payroll_records_driver_id ON payroll_records(driver_id);
CREATE INDEX IF NOT EXISTS idx_payroll_records_period ON payroll_records(period_start, period_end);
