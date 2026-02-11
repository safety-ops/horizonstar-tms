-- Add updated_at column to tables that need conflict detection
-- This migration adds updated_at columns to trips, orders, drivers, and trucks tables

-- Add updated_at to trips table
ALTER TABLE trips ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add updated_at to orders table (if not exists)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add updated_at to drivers table (if not exists)
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Add updated_at to trucks table (if not exists)
ALTER TABLE trucks ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Create function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for auto-updating updated_at on each table
DROP TRIGGER IF EXISTS trips_updated_at ON trips;
CREATE TRIGGER trips_updated_at
  BEFORE UPDATE ON trips
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS orders_updated_at ON orders;
CREATE TRIGGER orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS drivers_updated_at ON drivers;
CREATE TRIGGER drivers_updated_at
  BEFORE UPDATE ON drivers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trucks_updated_at ON trucks;
CREATE TRIGGER trucks_updated_at
  BEFORE UPDATE ON trucks
  FOR EACH ROW
  
  EXECUTE FUNCTION update_updated_at_column();

-- Update existing rows to have a timestamp
UPDATE trips SET updated_at = COALESCE(updated_at, NOW()) WHERE updated_at IS NULL;
UPDATE orders SET updated_at = COALESCE(updated_at, NOW()) WHERE updated_at IS NULL;
UPDATE drivers SET updated_at = COALESCE(updated_at, NOW()) WHERE updated_at IS NULL;
UPDATE trucks SET updated_at = COALESCE(updated_at, NOW()) WHERE updated_at IS NULL;
