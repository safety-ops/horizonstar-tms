-- Add password column to dealer_applications so dealers set their password during registration
ALTER TABLE dealer_applications ADD COLUMN IF NOT EXISTS password TEXT;
