-- Add Company EIN field to drivers table for drivers paid as a company

ALTER TABLE drivers ADD COLUMN IF NOT EXISTS pay_to_company_ein TEXT;

COMMENT ON COLUMN drivers.pay_to_company_ein IS 'Company EIN number if driver is paid as a company';
