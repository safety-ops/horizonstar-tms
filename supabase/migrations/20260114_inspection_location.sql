-- Add location fields to vehicle_inspections table
-- This allows capturing GPS coordinates and address when inspection is performed

ALTER TABLE vehicle_inspections
ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8),
ADD COLUMN IF NOT EXISTS longitude DECIMAL(11, 8),
ADD COLUMN IF NOT EXISTS location_address TEXT;

-- Add index for location queries
CREATE INDEX IF NOT EXISTS idx_vehicle_inspections_location
ON vehicle_inspections(latitude, longitude)
WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
