-- Split pay_to_address into separate fields for better formatting

ALTER TABLE drivers ADD COLUMN IF NOT EXISTS pay_to_street TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS pay_to_city TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS pay_to_state TEXT;
ALTER TABLE drivers ADD COLUMN IF NOT EXISTS pay_to_zip TEXT;

-- Keep pay_to_address for backward compatibility (can be removed later)
