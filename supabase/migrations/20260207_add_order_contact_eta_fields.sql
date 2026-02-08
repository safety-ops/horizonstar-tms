-- Phase 0: Add contact info, ETA, and vehicle fields to orders table
-- Required for Driver App v3 features (ETA submission, contact display)

ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_contact_name TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_contact_phone TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_contact_name TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_contact_phone TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_eta TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_eta TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS vehicle_color TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS vehicle_body_type TEXT;

-- Add updated_at to additional tables for conflict detection
ALTER TABLE expenses ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE brokers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE maintenance_records ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE fuel_transactions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Create triggers for auto-updating updated_at on new tables
DROP TRIGGER IF EXISTS expenses_updated_at ON expenses;
CREATE TRIGGER expenses_updated_at
  BEFORE UPDATE ON expenses
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS brokers_updated_at ON brokers;
CREATE TRIGGER brokers_updated_at
  BEFORE UPDATE ON brokers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS maintenance_records_updated_at ON maintenance_records;
CREATE TRIGGER maintenance_records_updated_at
  BEFORE UPDATE ON maintenance_records
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS fuel_transactions_updated_at ON fuel_transactions;
CREATE TRIGGER fuel_transactions_updated_at
  BEFORE UPDATE ON fuel_transactions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
