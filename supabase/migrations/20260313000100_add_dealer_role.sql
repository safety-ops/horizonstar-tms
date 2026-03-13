-- Add DEALER to the users role check constraint
-- The dealer portal requires role = 'DEALER' but the constraint only allows DISPATCHER, MANAGER, ADMIN

ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('DISPATCHER', 'MANAGER', 'ADMIN', 'DEALER'));
