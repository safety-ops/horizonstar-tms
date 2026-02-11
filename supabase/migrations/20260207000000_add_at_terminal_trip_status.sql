-- Add AT_TERMINAL to the trips status CHECK constraint
-- This allows trips to be marked as "at terminal" without being fully completed

-- Drop the existing status constraint (try common naming patterns)
DO $$
BEGIN
  -- Try dropping by common constraint names
  BEGIN
    ALTER TABLE trips DROP CONSTRAINT IF EXISTS trips_status_check;
  EXCEPTION WHEN others THEN NULL;
  END;
  BEGIN
    ALTER TABLE trips DROP CONSTRAINT IF EXISTS trips_status_check1;
  EXCEPTION WHEN others THEN NULL;
  END;
  BEGIN
    ALTER TABLE trips DROP CONSTRAINT IF EXISTS check_status;
  EXCEPTION WHEN others THEN NULL;
  END;
END $$;

-- Also drop any unnamed check constraints on the status column
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'trips'::regclass
    AND contype = 'c'
    AND pg_get_constraintdef(oid) LIKE '%status%'
  LOOP
    EXECUTE 'ALTER TABLE trips DROP CONSTRAINT ' || quote_ident(r.conname);
  END LOOP;
END $$;

-- Re-add the constraint with AT_TERMINAL included
ALTER TABLE trips ADD CONSTRAINT trips_status_check
  CHECK (status IN ('PLANNED', 'DISPATCHED', 'IN_TRANSIT', 'AT_TERMINAL', 'COMPLETED', 'CANCELLED'));
