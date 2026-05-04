-- ============================================================================
-- Rollback: 20260502020000_orphan_inspection_cleanup
-- Purpose:  Remove the nightly cron schedule and the cleanup function.
--
-- NOTE: Data deleted by cleanup_abandoned_inspections() is NOT restored.
--       This rollback is forward-only on data, per project convention.
-- ============================================================================

BEGIN;

-- 1. Remove the pg_cron schedule if pg_cron is present.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    PERFORM cron.unschedule('cleanup_abandoned_inspections_nightly');
    RAISE NOTICE 'pg_cron job "cleanup_abandoned_inspections_nightly" removed.';
  ELSE
    RAISE NOTICE 'pg_cron not present — no schedule to remove.';
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Could not unschedule cleanup job: %', SQLERRM;
END;
$$;

-- 2. Drop the cleanup function.
DROP FUNCTION IF EXISTS public.cleanup_abandoned_inspections();

COMMIT;
