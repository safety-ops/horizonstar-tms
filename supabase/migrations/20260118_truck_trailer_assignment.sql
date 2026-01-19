-- Add assigned_trailer_id column to trucks table for trailer-to-truck assignment
-- A truck can have one trailer assigned, and a trailer can only be assigned to one truck (exclusive)

ALTER TABLE trucks
ADD COLUMN IF NOT EXISTS assigned_trailer_id INTEGER REFERENCES trucks(id);

-- Index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_trucks_assigned_trailer ON trucks(assigned_trailer_id);

-- Comment for documentation
COMMENT ON COLUMN trucks.assigned_trailer_id IS 'Reference to trailer assigned to this truck. Only trucks (vehicle_type=TRUCK) should have this set.';
