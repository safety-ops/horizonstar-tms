-- ============================================================================
-- Migration: 20260502020000_orphan_inspection_cleanup
-- Purpose:   Delete abandoned vehicle_inspections rows (status = 'in_progress',
--            older than 14 days, no signatures, not completed) and schedule
--            nightly maintenance via pg_cron.
--
-- Status values verified from 20260103000200_vehicle_inspections.sql line 32:
--   CHECK (status IN ('in_progress', 'completed'))
--   'draft' does NOT exist — only 'in_progress' qualifies.
--
-- Child table cascade verified from same migration lines 41, 50, 59:
--   inspection_photos, inspection_videos, inspection_damages all carry
--   ON DELETE CASCADE — no explicit child DELETEs required.
--
-- pg_cron: not previously installed in any migration; CREATE EXTENSION added
--   conditionally below.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Install pg_cron if not already present.
--    Supabase Free + Pro tiers ship pg_cron in the shared_preload_libraries.
--    The DO block silences the error gracefully on projects where it's absent
--    so the rest of the migration still succeeds.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  CREATE EXTENSION IF NOT EXISTS pg_cron;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'pg_cron extension could not be created (%). Nightly schedule will be skipped.', SQLERRM;
END;
$$;

-- ---------------------------------------------------------------------------
-- 2. Cleanup function
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cleanup_abandoned_inspections()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_deleted INTEGER;
BEGIN
  -- Delete abandoned inspections. Child rows in inspection_photos,
  -- inspection_videos, and inspection_damages are removed automatically
  -- via ON DELETE CASCADE (verified in 20260103000200_vehicle_inspections.sql).
  DELETE FROM public.vehicle_inspections
  WHERE status = 'in_progress'
    AND created_at < NOW() - INTERVAL '14 days'
    AND customer_signature IS NULL
    AND driver_signature IS NULL
    AND completed_at IS NULL;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

-- Restrict direct invocation to privileged roles only; pg_cron runs as
-- the superuser so it is unaffected by this revocation.
REVOKE EXECUTE ON FUNCTION public.cleanup_abandoned_inspections() FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- 3. Schedule nightly at 03:00 UTC via pg_cron.
--    Wrapped in a DO block so that if pg_cron was not installed above (rare),
--    the schedule registration failure is treated as a warning rather than
--    aborting the entire migration.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  -- Remove any prior schedule with this name (idempotent re-run safety).
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    PERFORM cron.unschedule('cleanup_abandoned_inspections_nightly');
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL; -- job did not exist yet; ignore
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    PERFORM cron.schedule(
      'cleanup_abandoned_inspections_nightly',
      '0 3 * * *',                                    -- 03:00 UTC every night
      'SELECT public.cleanup_abandoned_inspections()'
    );
    RAISE NOTICE 'pg_cron job "cleanup_abandoned_inspections_nightly" scheduled at 03:00 UTC.';
  ELSE
    RAISE WARNING 'pg_cron not available — nightly cleanup job was NOT scheduled. Run public.cleanup_abandoned_inspections() manually or via an external cron.';
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- 4. One-shot backfill: purge existing zombie rows created before this deploy.
--    The RAISE NOTICE is visible in supabase db push output for auditability.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  v_rows INTEGER;
BEGIN
  SELECT public.cleanup_abandoned_inspections() INTO v_rows;
  RAISE NOTICE 'Backfill cleanup deleted % abandoned inspection rows.', v_rows;
END;
$$;

COMMIT;
