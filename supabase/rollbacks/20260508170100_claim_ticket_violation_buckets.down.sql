-- Rollback for 20260508170100_claim_ticket_violation_buckets.sql
-- Drops the storage object policies created by the forward migration.
-- DOES NOT delete the buckets themselves — bucket deletion is destructive
-- (would cascade to all uploaded objects). If buckets must also be removed,
-- do it manually via Supabase Dashboard after copying objects elsewhere.

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
