-- Add driver type field to distinguish Company Drivers from Owner-Operators
-- Owner-Operators pay a dispatch fee % and expenses are NOT deducted from their trips

ALTER TABLE drivers ADD COLUMN IF NOT EXISTS driver_type TEXT DEFAULT 'COMPANY';
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS dispatch_fee_percent NUMERIC(5,2);

-- Add check constraint for valid driver types
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'drivers_driver_type_check'
    ) THEN
        ALTER TABLE drivers ADD CONSTRAINT drivers_driver_type_check
        CHECK (driver_type IN ('COMPANY', 'OWNER_OP'));
    END IF;
END $$;

COMMENT ON COLUMN drivers.driver_type IS 'COMPANY = Company Driver (uses cut_percent), OWNER_OP = Owner-Operator (uses dispatch_fee_percent)';
COMMENT ON COLUMN drivers.dispatch_fee_percent IS 'Dispatch fee percentage charged to Owner-Operators (company profit)';
