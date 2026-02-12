BEGIN;

-- Compatibility patch for environments where orders.notes was never created.
ALTER TABLE IF EXISTS orders
  ADD COLUMN IF NOT EXISTS notes TEXT;

-- Keep dispatcher/internal notes contract stable across all environments.
ALTER TABLE IF EXISTS orders
  ADD COLUMN IF NOT EXISTS dispatcher_notes TEXT;

-- Force PostgREST schema refresh so newly added columns are immediately visible.
DO $$
BEGIN
  PERFORM pg_notify('pgrst', 'reload schema');
EXCEPTION WHEN OTHERS THEN
  -- Safe no-op if notify is not permitted in current execution context.
  NULL;
END $$;

COMMIT;
