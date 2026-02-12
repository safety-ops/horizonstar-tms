BEGIN;

-- -----------------------------------------------------------------------------
-- order_attachments metadata and RLS hardening
-- -----------------------------------------------------------------------------
ALTER TABLE order_attachments
  ADD COLUMN IF NOT EXISTS storage_path TEXT;

UPDATE order_attachments
SET storage_path = CASE
  WHEN storage_path IS NOT NULL AND btrim(storage_path) <> '' THEN storage_path
  WHEN file_url ~* '/storage/v1/object/public/order-attachments/' THEN split_part(regexp_replace(file_url, '^.*?/storage/v1/object/public/order-attachments/', ''), '?', 1)
  WHEN file_url ~* '/storage/v1/object/sign/order-attachments/' THEN split_part(regexp_replace(file_url, '^.*?/storage/v1/object/sign/order-attachments/', ''), '?', 1)
  WHEN file_url ~* '/storage/v1/object/order-attachments/' THEN split_part(regexp_replace(file_url, '^.*?/storage/v1/object/order-attachments/', ''), '?', 1)
  WHEN file_url LIKE 'order-attachments/%' THEN substr(file_url, length('order-attachments/') + 1)
  ELSE NULL
END
WHERE storage_path IS NULL OR btrim(storage_path) = '';

CREATE INDEX IF NOT EXISTS idx_order_attachments_order_uploaded_at
  ON order_attachments(order_id, uploaded_at DESC);

ALTER TABLE order_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for all users" ON order_attachments;
DROP POLICY IF EXISTS "Enable insert for all users" ON order_attachments;
DROP POLICY IF EXISTS "Enable update for all users" ON order_attachments;
DROP POLICY IF EXISTS "Enable delete for all users" ON order_attachments;
DROP POLICY IF EXISTS "TMS users can read order attachments" ON order_attachments;
DROP POLICY IF EXISTS "Drivers can read assigned order attachments" ON order_attachments;
DROP POLICY IF EXISTS "TMS users can insert order attachments" ON order_attachments;
DROP POLICY IF EXISTS "Drivers can insert assigned order attachments" ON order_attachments;
DROP POLICY IF EXISTS "TMS users can update order attachments" ON order_attachments;
DROP POLICY IF EXISTS "Drivers can update assigned order attachments" ON order_attachments;
DROP POLICY IF EXISTS "TMS users can delete order attachments" ON order_attachments;
DROP POLICY IF EXISTS "Drivers can delete assigned order attachments" ON order_attachments;

CREATE POLICY "TMS users can read order attachments" ON order_attachments
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  );

CREATE POLICY "Drivers can read assigned order attachments" ON order_attachments
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM drivers d
      JOIN orders o ON o.id = order_attachments.order_id
      LEFT JOIN trips t ON t.id = o.trip_id
      WHERE d.auth_user_id = auth.uid()
        AND (o.driver_id = d.id OR t.driver_id = d.id)
    )
  );

CREATE POLICY "TMS users can insert order attachments" ON order_attachments
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  );

CREATE POLICY "Drivers can insert assigned order attachments" ON order_attachments
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM drivers d
      JOIN orders o ON o.id = order_attachments.order_id
      LEFT JOIN trips t ON t.id = o.trip_id
      WHERE d.auth_user_id = auth.uid()
        AND (o.driver_id = d.id OR t.driver_id = d.id)
    )
  );

CREATE POLICY "TMS users can update order attachments" ON order_attachments
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  )
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  );

CREATE POLICY "Drivers can update assigned order attachments" ON order_attachments
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM drivers d
      JOIN orders o ON o.id = order_attachments.order_id
      LEFT JOIN trips t ON t.id = o.trip_id
      WHERE d.auth_user_id = auth.uid()
        AND (o.driver_id = d.id OR t.driver_id = d.id)
    )
  )
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM drivers d
      JOIN orders o ON o.id = order_attachments.order_id
      LEFT JOIN trips t ON t.id = o.trip_id
      WHERE d.auth_user_id = auth.uid()
        AND (o.driver_id = d.id OR t.driver_id = d.id)
    )
  );

CREATE POLICY "TMS users can delete order attachments" ON order_attachments
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  );

CREATE POLICY "Drivers can delete assigned order attachments" ON order_attachments
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM drivers d
      JOIN orders o ON o.id = order_attachments.order_id
      LEFT JOIN trips t ON t.id = o.trip_id
      WHERE d.auth_user_id = auth.uid()
        AND (o.driver_id = d.id OR t.driver_id = d.id)
    )
  );

-- -----------------------------------------------------------------------------
-- inspection_damages media metadata upgrade
-- -----------------------------------------------------------------------------
ALTER TABLE inspection_damages
  ADD COLUMN IF NOT EXISTS storage_path TEXT,
  ADD COLUMN IF NOT EXISTS mime_type TEXT,
  ADD COLUMN IF NOT EXISTS file_size BIGINT,
  ADD COLUMN IF NOT EXISTS upload_state TEXT DEFAULT 'synced',
  ADD COLUMN IF NOT EXISTS last_error TEXT;

UPDATE inspection_damages
SET storage_path = CASE
  WHEN storage_path IS NOT NULL AND btrim(storage_path) <> '' THEN storage_path
  WHEN photo_url ~* '/storage/v1/object/public/inspection-media/' THEN split_part(regexp_replace(photo_url, '^.*?/storage/v1/object/public/inspection-media/', ''), '?', 1)
  WHEN photo_url ~* '/storage/v1/object/sign/inspection-media/' THEN split_part(regexp_replace(photo_url, '^.*?/storage/v1/object/sign/inspection-media/', ''), '?', 1)
  WHEN photo_url ~* '/storage/v1/object/inspection-media/' THEN split_part(regexp_replace(photo_url, '^.*?/storage/v1/object/inspection-media/', ''), '?', 1)
  WHEN photo_url LIKE 'inspection-media/%' THEN substr(photo_url, length('inspection-media/') + 1)
  ELSE NULL
END
WHERE storage_path IS NULL OR btrim(storage_path) = '';

UPDATE inspection_damages
SET upload_state = CASE
  WHEN COALESCE(storage_path, '') = '' AND COALESCE(photo_url, '') <> '' THEN 'failed'
  WHEN COALESCE(upload_state, '') = '' THEN 'synced'
  ELSE upload_state
END;

CREATE INDEX IF NOT EXISTS idx_inspection_damages_storage_path
  ON inspection_damages(storage_path);

-- -----------------------------------------------------------------------------
-- Storage buckets and object policies (core ops scope)
-- -----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'order-attachments',
  'order-attachments',
  false,
  52428800,
  ARRAY[
    'image/jpeg',
    'image/heic',
    'image/heif',
    'video/mp4',
    'video/quicktime',
    'video/x-m4v',
    'application/pdf'
  ]
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'chatfiles',
  'chatfiles',
  false,
  52428800,
  ARRAY[
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif',
    'application/pdf',
    'text/plain',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ]
)
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Anyone can upload order attachments" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view order attachments" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can delete order attachments" ON storage.objects;
DROP POLICY IF EXISTS "TMS users can upload order attachments" ON storage.objects;
DROP POLICY IF EXISTS "TMS users can read order attachments objects" ON storage.objects;
DROP POLICY IF EXISTS "TMS users can delete order attachments objects" ON storage.objects;
DROP POLICY IF EXISTS "Drivers can upload own order attachments" ON storage.objects;
DROP POLICY IF EXISTS "Drivers can read own order attachments" ON storage.objects;
DROP POLICY IF EXISTS "Drivers can delete own order attachments" ON storage.objects;
DROP POLICY IF EXISTS "TMS users can upload chatfiles" ON storage.objects;
DROP POLICY IF EXISTS "TMS users can read chatfiles" ON storage.objects;
DROP POLICY IF EXISTS "TMS users can delete chatfiles" ON storage.objects;

CREATE POLICY "TMS users can upload order attachments" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'order-attachments'
    AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  );

CREATE POLICY "TMS users can read order attachments objects" ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'order-attachments'
    AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  );

CREATE POLICY "TMS users can delete order attachments objects" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'order-attachments'
    AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  );

CREATE POLICY "Drivers can upload own order attachments" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'order-attachments'
    AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM drivers d
      WHERE d.auth_user_id = auth.uid()
        AND d.id::text = (storage.foldername(name))[1]
    )
  );

CREATE POLICY "Drivers can read own order attachments" ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'order-attachments'
    AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM drivers d
      WHERE d.auth_user_id = auth.uid()
        AND d.id::text = (storage.foldername(name))[1]
    )
  );

CREATE POLICY "Drivers can delete own order attachments" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'order-attachments'
    AND auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM drivers d
      WHERE d.auth_user_id = auth.uid()
        AND d.id::text = (storage.foldername(name))[1]
    )
  );

CREATE POLICY "TMS users can upload chatfiles" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'chatfiles'
    AND auth.uid() IS NOT NULL
    AND (
      EXISTS (
        SELECT 1 FROM users u
        WHERE u.auth_id = auth.uid()
          AND COALESCE(u.is_active, true) = true
      )
      OR EXISTS (
        SELECT 1 FROM drivers d
        WHERE d.auth_user_id = auth.uid()
          AND COALESCE(d.status, 'ACTIVE') <> 'INACTIVE'
      )
    )
  );

CREATE POLICY "TMS users can read chatfiles" ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'chatfiles'
    AND auth.uid() IS NOT NULL
    AND (
      EXISTS (
        SELECT 1 FROM users u
        WHERE u.auth_id = auth.uid()
          AND COALESCE(u.is_active, true) = true
      )
      OR EXISTS (
        SELECT 1 FROM drivers d
        WHERE d.auth_user_id = auth.uid()
          AND COALESCE(d.status, 'ACTIVE') <> 'INACTIVE'
      )
    )
  );

CREATE POLICY "TMS users can delete chatfiles" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'chatfiles'
    AND auth.uid() IS NOT NULL
    AND (
      EXISTS (
        SELECT 1 FROM users u
        WHERE u.auth_id = auth.uid()
          AND COALESCE(u.is_active, true) = true
      )
      OR EXISTS (
        SELECT 1 FROM drivers d
        WHERE d.auth_user_id = auth.uid()
          AND COALESCE(d.status, 'ACTIVE') <> 'INACTIVE'
      )
    )
  );

-- -----------------------------------------------------------------------------
-- driver_notifications RLS cleanup (remove USING(true))
-- -----------------------------------------------------------------------------
ALTER TABLE driver_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Enable read access for all users" ON driver_notifications;
DROP POLICY IF EXISTS "Enable insert for all users" ON driver_notifications;
DROP POLICY IF EXISTS "Enable update for all users" ON driver_notifications;
DROP POLICY IF EXISTS "Enable delete for all users" ON driver_notifications;
DROP POLICY IF EXISTS "TMS users can read notifications" ON driver_notifications;
DROP POLICY IF EXISTS "TMS users can insert notifications" ON driver_notifications;
DROP POLICY IF EXISTS "TMS users can update notifications" ON driver_notifications;
DROP POLICY IF EXISTS "TMS users can delete notifications" ON driver_notifications;
DROP POLICY IF EXISTS "Drivers can read own notifications" ON driver_notifications;
DROP POLICY IF EXISTS "Drivers can insert own notifications" ON driver_notifications;
DROP POLICY IF EXISTS "Drivers can update own notifications" ON driver_notifications;
DROP POLICY IF EXISTS "Drivers can delete own notifications" ON driver_notifications;

CREATE POLICY "TMS users can read notifications" ON driver_notifications
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  );

CREATE POLICY "TMS users can insert notifications" ON driver_notifications
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  );

CREATE POLICY "TMS users can update notifications" ON driver_notifications
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  )
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  );

CREATE POLICY "TMS users can delete notifications" ON driver_notifications
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  );

CREATE POLICY "Drivers can read own notifications" ON driver_notifications
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM drivers d
      WHERE d.auth_user_id = auth.uid()
        AND d.id = driver_notifications.driver_id
    )
  );

CREATE POLICY "Drivers can insert own notifications" ON driver_notifications
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM drivers d
      WHERE d.auth_user_id = auth.uid()
        AND d.id = driver_notifications.driver_id
    )
  );

CREATE POLICY "Drivers can update own notifications" ON driver_notifications
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM drivers d
      WHERE d.auth_user_id = auth.uid()
        AND d.id = driver_notifications.driver_id
    )
  )
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM drivers d
      WHERE d.auth_user_id = auth.uid()
        AND d.id = driver_notifications.driver_id
    )
  );

CREATE POLICY "Drivers can delete own notifications" ON driver_notifications
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM drivers d
      WHERE d.auth_user_id = auth.uid()
        AND d.id = driver_notifications.driver_id
    )
  );

COMMIT;
