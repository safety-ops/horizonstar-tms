-- Add vehicle_vin and vehicle_color columns to orders table
-- These fields are used to store vehicle identification from Central Dispatch imports

ALTER TABLE orders ADD COLUMN IF NOT EXISTS vehicle_vin TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS vehicle_color TEXT;

-- Create index for VIN lookups (useful for finding orders by VIN)
CREATE INDEX IF NOT EXISTS idx_orders_vehicle_vin ON orders(vehicle_vin);

-- Note: delivery_date column already exists in orders table
