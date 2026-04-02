-- Add vehicles JSONB array to orders table for multi-vehicle support
-- Format: [{ "year": 2020, "make": "Chevy", "model": "Bolt", "vin": "...", "color": "...", "body_type": "...", "lot_number": "...", "buyer_number": "..." }]
-- The first vehicle is ALSO stored in the legacy fields (vehicle_year, vehicle_make, etc.) for backward compatibility
ALTER TABLE orders ADD COLUMN IF NOT EXISTS vehicles JSONB DEFAULT '[]';
