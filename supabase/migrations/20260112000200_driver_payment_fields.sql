-- Add payment information fields to drivers table
-- These fields allow drivers to specify alternate payment details (Pay to name, address, company)

ALTER TABLE drivers ADD COLUMN IF NOT EXISTS pay_to_name TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS pay_to_address TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS pay_to_company TEXT;

-- Add comments for documentation
COMMENT ON COLUMN drivers.pay_to_name IS 'Alternate name for payment (if different from driver name)';
COMMENT ON COLUMN drivers.pay_to_address IS 'Address for payment';
COMMENT ON COLUMN drivers.pay_to_company IS 'Company name if driver wants to be paid as a company';
