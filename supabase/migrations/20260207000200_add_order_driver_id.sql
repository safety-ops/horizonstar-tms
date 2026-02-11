-- Add driver_id column to orders for direct driver assignment
ALTER TABLE orders ADD COLUMN IF NOT EXISTS driver_id INTEGER;
