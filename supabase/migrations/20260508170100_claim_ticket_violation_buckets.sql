-- ============================================================
-- Migration: 20260508170100_claim_ticket_violation_buckets.sql
-- Purpose:   Create claim-files / ticket-files / violation-files
--            storage buckets and their access policies if they
--            do not already exist. Idempotent — safe to run
--            against an environment where the buckets were
--            created manually via the Supabase Dashboard.
--
-- Background
--   Web TMS uploadClaimFile / uploadTicketFile / uploadViolationFile
--   write to these buckets. No prior migration created them in
--   the repo (audit 2026-05-08). Either they exist remote-only
--   (manual dashboard setup, undocumented) or they don't exist
--   and uploads have been failing silently. Either way, this
--   migration brings the source of truth into the repo and
--   guarantees correct policies.
--
-- Bucket configuration
--   • Private (public = false) — same as order-attachments.
--   • 50 MB file size limit.
--   • Common compliance/document MIME types (PDF, image, doc).
--
-- Storage object policies (per bucket)
--   • TMS staff: full SELECT / INSERT / UPDATE / DELETE.
--   • Drivers / dealers / brokers / anon: blocked.
--
-- These mirror the table-level RLS already in place on
-- claim_files / ticket_files / violation_files (see
-- 20260429230000_rls_tier4_long_tail.sql).
--
-- Rollback
--   See supabase/rollbacks/20260508170100_claim_ticket_violation_buckets.down.sql
-- ============================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Create the buckets (idempotent)
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('claim-files',     'claim-files',     false, 52428800,
    ARRAY['image/jpeg','image/png','image/heic','image/heif','application/pdf',
          'application/msword',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'application/vnd.ms-excel',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']),
  ('ticket-files',    'ticket-files',    false, 52428800,
    ARRAY['image/jpeg','image/png','image/heic','image/heif','application/pdf',
          'application/msword',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'application/vnd.ms-excel',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']),
  ('violation-files', 'violation-files', false, 52428800,
    ARRAY['image/jpeg','image/png','image/heic','image/heif','application/pdf',
          'application/msword',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'application/vnd.ms-excel',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'])
ON CONFLICT (id) DO UPDATE
SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Storage object policies — TMS staff only for all three buckets
-- ─────────────────────────────────────────────────────────────────────────────
-- Drop any prior versions to keep this migration idempotent.
DROP POLICY IF EXISTS "TMS staff can read claim files"      ON storage.objects;
DROP POLICY IF EXISTS "TMS staff can upload claim files"    ON storage.objects;
DROP POLICY IF EXISTS "TMS staff can update claim files"    ON storage.objects;
DROP POLICY IF EXISTS "TMS staff can delete claim files"    ON storage.objects;

DROP POLICY IF EXISTS "TMS staff can read ticket files"     ON storage.objects;
DROP POLICY IF EXISTS "TMS staff can upload ticket files"   ON storage.objects;
DROP POLICY IF EXISTS "TMS staff can update ticket files"   ON storage.objects;
DROP POLICY IF EXISTS "TMS staff can delete ticket files"   ON storage.objects;

DROP POLICY IF EXISTS "TMS staff can read violation files"   ON storage.objects;
DROP POLICY IF EXISTS "TMS staff can upload violation files" ON storage.objects;
DROP POLICY IF EXISTS "TMS staff can update violation files" ON storage.objects;
DROP POLICY IF EXISTS "TMS staff can delete violation files" ON storage.objects;

-- claim-files
CREATE POLICY "TMS staff can read claim files"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'claim-files' AND public.is_tms_staff());

CREATE POLICY "TMS staff can upload claim files"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'claim-files' AND public.is_tms_staff());

CREATE POLICY "TMS staff can update claim files"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'claim-files' AND public.is_tms_staff())
  WITH CHECK (bucket_id = 'claim-files' AND public.is_tms_staff());

CREATE POLICY "TMS staff can delete claim files"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'claim-files' AND public.is_tms_staff());

-- ticket-files
CREATE POLICY "TMS staff can read ticket files"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'ticket-files' AND public.is_tms_staff());

CREATE POLICY "TMS staff can upload ticket files"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'ticket-files' AND public.is_tms_staff());

CREATE POLICY "TMS staff can update ticket files"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'ticket-files' AND public.is_tms_staff())
  WITH CHECK (bucket_id = 'ticket-files' AND public.is_tms_staff());

CREATE POLICY "TMS staff can delete ticket files"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'ticket-files' AND public.is_tms_staff());

-- violation-files
CREATE POLICY "TMS staff can read violation files"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'violation-files' AND public.is_tms_staff());

CREATE POLICY "TMS staff can upload violation files"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'violation-files' AND public.is_tms_staff());

CREATE POLICY "TMS staff can update violation files"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'violation-files' AND public.is_tms_staff())
  WITH CHECK (bucket_id = 'violation-files' AND public.is_tms_staff());

CREATE POLICY "TMS staff can delete violation files"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'violation-files' AND public.is_tms_staff());
