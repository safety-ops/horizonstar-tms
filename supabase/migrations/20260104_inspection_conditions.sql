-- Add inspection conditions and customer email columns
ALTER TABLE vehicle_inspections
ADD COLUMN IF NOT EXISTS condition_dark BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS condition_snow BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS condition_rain BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS condition_dirty_vehicle BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS customer_email TEXT;
