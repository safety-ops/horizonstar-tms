-- Inspection media reliability + scale hardening
-- Policy target:
-- 1) Never-block inspection flow with queued media metadata support
-- 2) Private inspection media bucket consumed via signed URLs
-- 3) Driver-auth-scoped writes on inspection tables/storage

BEGIN;

-- -----------------------------------------------------------------------------
-- Vehicle inspection sync status
-- -----------------------------------------------------------------------------
ALTER TABLE vehicle_inspections
  ADD COLUMN IF NOT EXISTS media_sync_status TEXT NOT NULL DEFAULT 'synced';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'vehicle_inspections_media_sync_status_check'
  ) THEN
    ALTER TABLE vehicle_inspections
      ADD CONSTRAINT vehicle_inspections_media_sync_status_check
      CHECK (media_sync_status IN ('synced', 'pending', 'failed'));
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- Inspection photo/video metadata hardening
-- -----------------------------------------------------------------------------
ALTER TABLE inspection_photos
  ADD COLUMN IF NOT EXISTS storage_path TEXT,
  ADD COLUMN IF NOT EXISTS mime_type TEXT,
  ADD COLUMN IF NOT EXISTS file_size BIGINT,
  ADD COLUMN IF NOT EXISTS client_media_id TEXT,
  ADD COLUMN IF NOT EXISTS upload_state TEXT,
  ADD COLUMN IF NOT EXISTS last_error TEXT;

ALTER TABLE inspection_videos
  ADD COLUMN IF NOT EXISTS storage_path TEXT,
  ADD COLUMN IF NOT EXISTS mime_type TEXT,
  ADD COLUMN IF NOT EXISTS file_size BIGINT,
  ADD COLUMN IF NOT EXISTS client_media_id TEXT,
  ADD COLUMN IF NOT EXISTS upload_state TEXT,
  ADD COLUMN IF NOT EXISTS last_error TEXT;

UPDATE inspection_photos
SET upload_state = COALESCE(upload_state, 'uploaded');

UPDATE inspection_videos
SET upload_state = COALESCE(upload_state, 'uploaded');

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'inspection_photos_photo_type_allowed'
  ) THEN
    ALTER TABLE inspection_photos
      ADD CONSTRAINT inspection_photos_photo_type_allowed
      CHECK (
        photo_type IN (
          'odometer', 'left', 'front', 'right', 'rear', 'top', 'key',
          'extra_1', 'extra_2', 'extra_3', 'extra_4', 'extra_5'
        )
      );
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'inspection_videos_duration_seconds_check'
  ) THEN
    ALTER TABLE inspection_videos
      ADD CONSTRAINT inspection_videos_duration_seconds_check
      CHECK (duration_seconds IS NULL OR (duration_seconds BETWEEN 1 AND 35));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'inspection_photos_upload_state_check'
  ) THEN
    ALTER TABLE inspection_photos
      ADD CONSTRAINT inspection_photos_upload_state_check
      CHECK (upload_state IN ('pending', 'uploading', 'uploaded', 'failed'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'inspection_videos_upload_state_check'
  ) THEN
    ALTER TABLE inspection_videos
      ADD CONSTRAINT inspection_videos_upload_state_check
      CHECK (upload_state IN ('pending', 'uploading', 'uploaded', 'failed'));
  END IF;
END $$;

-- Deduplicate legacy rows before adding unique constraints.
WITH ranked_photos AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY inspection_id, photo_type
      ORDER BY captured_at DESC NULLS LAST, id DESC
    ) AS rn
  FROM inspection_photos
)
DELETE FROM inspection_photos p
USING ranked_photos rp
WHERE p.id = rp.id
  AND rp.rn > 1;

WITH ranked_videos AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY inspection_id
      ORDER BY captured_at DESC NULLS LAST, id DESC
    ) AS rn
  FROM inspection_videos
)
DELETE FROM inspection_videos v
USING ranked_videos rv
WHERE v.id = rv.id
  AND rv.rn > 1;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'inspection_photos_inspection_id_photo_type_key'
  ) THEN
    ALTER TABLE inspection_photos
      ADD CONSTRAINT inspection_photos_inspection_id_photo_type_key
      UNIQUE (inspection_id, photo_type);
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'inspection_videos_inspection_id_key'
  ) THEN
    ALTER TABLE inspection_videos
      ADD CONSTRAINT inspection_videos_inspection_id_key
      UNIQUE (inspection_id);
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- Backfill storage paths from legacy URLs and mark irreparable rows failed
-- -----------------------------------------------------------------------------
UPDATE inspection_photos
SET storage_path = CASE
  WHEN storage_path IS NOT NULL AND btrim(storage_path) <> '' THEN storage_path
  WHEN photo_url ~* '/storage/v1/object/public/inspection-media/' THEN split_part(regexp_replace(photo_url, '^.*?/storage/v1/object/public/inspection-media/', ''), '?', 1)
  WHEN photo_url ~* '/storage/v1/object/sign/inspection-media/' THEN split_part(regexp_replace(photo_url, '^.*?/storage/v1/object/sign/inspection-media/', ''), '?', 1)
  WHEN photo_url ~* '/storage/v1/object/inspection-media/' THEN split_part(regexp_replace(photo_url, '^.*?/storage/v1/object/inspection-media/', ''), '?', 1)
  WHEN photo_url LIKE 'inspection-media/%' THEN substr(photo_url, length('inspection-media/') + 1)
  ELSE NULL
END
WHERE storage_path IS NULL OR btrim(storage_path) = '';

UPDATE inspection_videos
SET storage_path = CASE
  WHEN storage_path IS NOT NULL AND btrim(storage_path) <> '' THEN storage_path
  WHEN video_url ~* '/storage/v1/object/public/inspection-media/' THEN split_part(regexp_replace(video_url, '^.*?/storage/v1/object/public/inspection-media/', ''), '?', 1)
  WHEN video_url ~* '/storage/v1/object/sign/inspection-media/' THEN split_part(regexp_replace(video_url, '^.*?/storage/v1/object/sign/inspection-media/', ''), '?', 1)
  WHEN video_url ~* '/storage/v1/object/inspection-media/' THEN split_part(regexp_replace(video_url, '^.*?/storage/v1/object/inspection-media/', ''), '?', 1)
  WHEN video_url LIKE 'inspection-media/%' THEN substr(video_url, length('inspection-media/') + 1)
  ELSE NULL
END
WHERE storage_path IS NULL OR btrim(storage_path) = '';

UPDATE inspection_photos
SET
  upload_state = CASE
    WHEN storage_path IS NULL OR btrim(storage_path) = '' THEN 'failed'
    ELSE COALESCE(upload_state, 'uploaded')
  END,
  last_error = CASE
    WHEN (storage_path IS NULL OR btrim(storage_path) = '') AND (last_error IS NULL OR btrim(last_error) = '')
      THEN 'storage_path_backfill_failed'
    ELSE last_error
  END;

UPDATE inspection_videos
SET
  upload_state = CASE
    WHEN storage_path IS NULL OR btrim(storage_path) = '' THEN 'failed'
    ELSE COALESCE(upload_state, 'uploaded')
  END,
  last_error = CASE
    WHEN (storage_path IS NULL OR btrim(storage_path) = '') AND (last_error IS NULL OR btrim(last_error) = '')
      THEN 'storage_path_backfill_failed'
    ELSE last_error
  END;

-- -----------------------------------------------------------------------------
-- Query performance
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_vehicle_inspections_order_type_created_at
  ON vehicle_inspections(order_id, inspection_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_attachments_order_uploaded_at
  ON order_attachments(order_id, uploaded_at DESC);

-- -----------------------------------------------------------------------------
-- RLS hardening (writes scoped to authenticated driver ownership)
-- Keep read policy compatible for web/TMS (SELECT remains permissive where already used).
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Enable insert for all users" ON vehicle_inspections;
DROP POLICY IF EXISTS "Enable update for all users" ON vehicle_inspections;
DROP POLICY IF EXISTS "Enable delete for all users" ON vehicle_inspections;

DROP POLICY IF EXISTS "Enable insert for all users" ON inspection_photos;
DROP POLICY IF EXISTS "Enable delete for all users" ON inspection_photos;

DROP POLICY IF EXISTS "Enable insert for all users" ON inspection_videos;
DROP POLICY IF EXISTS "Enable delete for all users" ON inspection_videos;

DROP POLICY IF EXISTS "Enable insert for all users" ON inspection_damages;
DROP POLICY IF EXISTS "Enable update for all users" ON inspection_damages;
DROP POLICY IF EXISTS "Enable delete for all users" ON inspection_damages;

DROP POLICY IF EXISTS "Drivers can insert own inspections" ON vehicle_inspections;
DROP POLICY IF EXISTS "Drivers can update own inspections" ON vehicle_inspections;
DROP POLICY IF EXISTS "Drivers can delete own inspections" ON vehicle_inspections;

DROP POLICY IF EXISTS "Drivers can insert own inspection photos" ON inspection_photos;
DROP POLICY IF EXISTS "Drivers can delete own inspection photos" ON inspection_photos;

DROP POLICY IF EXISTS "Drivers can insert own inspection videos" ON inspection_videos;
DROP POLICY IF EXISTS "Drivers can delete own inspection videos" ON inspection_videos;

DROP POLICY IF EXISTS "Drivers can insert own inspection damages" ON inspection_damages;
DROP POLICY IF EXISTS "Drivers can update own inspection damages" ON inspection_damages;
DROP POLICY IF EXISTS "Drivers can delete own inspection damages" ON inspection_damages;

CREATE POLICY "Drivers can insert own inspections" ON vehicle_inspections
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM drivers d
      WHERE d.id = vehicle_inspections.driver_id
        AND d.auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Drivers can update own inspections" ON vehicle_inspections
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM drivers d
      WHERE d.id = vehicle_inspections.driver_id
        AND d.auth_user_id = auth.uid()
    )
  )
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM drivers d
      WHERE d.id = vehicle_inspections.driver_id
        AND d.auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Drivers can delete own inspections" ON vehicle_inspections
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM drivers d
      WHERE d.id = vehicle_inspections.driver_id
        AND d.auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Drivers can insert own inspection photos" ON inspection_photos
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM vehicle_inspections vi
      JOIN drivers d ON d.id = vi.driver_id
      WHERE vi.id = inspection_photos.inspection_id
        AND d.auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Drivers can delete own inspection photos" ON inspection_photos
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM vehicle_inspections vi
      JOIN drivers d ON d.id = vi.driver_id
      WHERE vi.id = inspection_photos.inspection_id
        AND d.auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Drivers can insert own inspection videos" ON inspection_videos
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM vehicle_inspections vi
      JOIN drivers d ON d.id = vi.driver_id
      WHERE vi.id = inspection_videos.inspection_id
        AND d.auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Drivers can delete own inspection videos" ON inspection_videos
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM vehicle_inspections vi
      JOIN drivers d ON d.id = vi.driver_id
      WHERE vi.id = inspection_videos.inspection_id
        AND d.auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Drivers can insert own inspection damages" ON inspection_damages
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM vehicle_inspections vi
      JOIN drivers d ON d.id = vi.driver_id
      WHERE vi.id = inspection_damages.inspection_id
        AND d.auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Drivers can update own inspection damages" ON inspection_damages
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM vehicle_inspections vi
      JOIN drivers d ON d.id = vi.driver_id
      WHERE vi.id = inspection_damages.inspection_id
        AND d.auth_user_id = auth.uid()
    )
  )
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM vehicle_inspections vi
      JOIN drivers d ON d.id = vi.driver_id
      WHERE vi.id = inspection_damages.inspection_id
        AND d.auth_user_id = auth.uid()
    )
  );

CREATE POLICY "Drivers can delete own inspection damages" ON inspection_damages
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM vehicle_inspections vi
      JOIN drivers d ON d.id = vi.driver_id
      WHERE vi.id = inspection_damages.inspection_id
        AND d.auth_user_id = auth.uid()
    )
  );

-- -----------------------------------------------------------------------------
-- Storage guardrails
-- -----------------------------------------------------------------------------
UPDATE storage.buckets
SET
  public = false,
  file_size_limit = 52428800, -- 50 MB
  allowed_mime_types = ARRAY[
    'image/jpeg',
    'image/heic',
    'image/heif',
    'video/mp4',
    'video/quicktime',
    'video/x-m4v',
    'application/pdf'
  ]
WHERE id = 'inspection-media';

UPDATE storage.buckets
SET
  file_size_limit = 52428800, -- 50 MB
  allowed_mime_types = ARRAY[
    'image/jpeg',
    'image/heic',
    'image/heif',
    'video/mp4',
    'video/quicktime',
    'video/x-m4v',
    'application/pdf'
  ]
WHERE id = 'order-attachments';

DROP POLICY IF EXISTS "Authenticated users can upload inspection media" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can view inspection media" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete inspection media" ON storage.objects;

DROP POLICY IF EXISTS "Drivers can upload own inspection media" ON storage.objects;
DROP POLICY IF EXISTS "Drivers can read own inspection media" ON storage.objects;
DROP POLICY IF EXISTS "Drivers can delete own inspection media" ON storage.objects;

CREATE POLICY "Drivers can upload own inspection media" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'inspection-media'
    AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM drivers d
      WHERE d.auth_user_id = auth.uid()
        AND d.id::text = (storage.foldername(name))[1]
    )
  );

CREATE POLICY "Drivers can read own inspection media" ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'inspection-media'
    AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM drivers d
      WHERE d.auth_user_id = auth.uid()
        AND d.id::text = (storage.foldername(name))[1]
    )
  );

CREATE POLICY "Drivers can delete own inspection media" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'inspection-media'
    AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM drivers d
      WHERE d.auth_user_id = auth.uid()
        AND d.id::text = (storage.foldername(name))[1]
    )
  );

COMMIT;
