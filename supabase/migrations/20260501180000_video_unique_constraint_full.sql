-- ============================================================================
-- Migration: 20260501180000_video_unique_constraint_full
-- ============================================================================
--
-- Bug: video upload still fails after 20260501170000 because the partial
-- UNIQUE index `inspection_videos_client_media_id_uidx` (created with
-- `WHERE client_media_id IS NOT NULL`) does NOT satisfy PostgREST's
-- `on_conflict=client_media_id` inference. PostgREST sends a bare
-- `ON CONFLICT (client_media_id) DO UPDATE` to Postgres, which requires a
-- non-partial unique constraint on the column to match. Verified by storage
-- showing a fresh video upload at inspection 55 / 20:28 UTC, but no row
-- landed in `inspection_videos` for that inspection.
--
-- Fix: backfill the single legacy row with NULL client_media_id (inspection 38,
-- pre-2026-02-19), drop the partial index, recreate as a full UNIQUE index.
-- The synthetic UUID for the legacy row is stable (uses gen_random_uuid()
-- once and stores it) and audit-correct insofar as it documents "this row
-- predates client-side idempotency keys."

BEGIN;

-- 1. Backfill the legacy NULL row(s). There's exactly one such row today
--    (inspection 38), but use a generic UPDATE in case more crept in.
UPDATE public.inspection_videos
SET client_media_id = 'legacy-' || gen_random_uuid()::text
WHERE client_media_id IS NULL;

-- 2. Drop the partial index. CONCURRENTLY would be safer but cannot run
--    inside a transaction; for this small table the brief lock is fine.
DROP INDEX IF EXISTS public.inspection_videos_client_media_id_uidx;

-- 3. Create a full UNIQUE index. PostgREST's bare `ON CONFLICT (column)`
--    will now correctly infer this index as the conflict arbitrator.
CREATE UNIQUE INDEX inspection_videos_client_media_id_uidx
  ON public.inspection_videos (client_media_id);

COMMENT ON INDEX public.inspection_videos_client_media_id_uidx IS
  'Full UNIQUE index for PostgREST upsert (on_conflict=client_media_id). '
  'Partial index from 20260501170000 was insufficient — PostgREST does not '
  'forward the partial predicate. Legacy NULL rows were backfilled with '
  'synthetic ''legacy-<uuid>'' values to allow the constraint to apply '
  'globally.';

COMMIT;

-- ROLLBACK (if needed):
--   DROP INDEX IF EXISTS public.inspection_videos_client_media_id_uidx;
--   CREATE UNIQUE INDEX inspection_videos_client_media_id_uidx
--     ON public.inspection_videos (client_media_id)
--     WHERE client_media_id IS NOT NULL;
--   UPDATE public.inspection_videos SET client_media_id = NULL
--     WHERE client_media_id LIKE 'legacy-%';
