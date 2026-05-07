-- ============================================================
-- Migration: 20260507203000_log_activity_rpc_revoke_anon.sql
-- Purpose:   Explicitly revoke EXECUTE on log_activity() from the
--            anon role.
--
-- Context:
--   Supabase pre-grants EXECUTE on all functions to anon and
--   authenticated at the database level, overriding the
--   REVOKE ALL FROM PUBLIC in the forward migration. A named
--   REVOKE directly targeting the anon role is required to
--   close the gap.
-- ============================================================

REVOKE EXECUTE ON FUNCTION public.log_activity(TEXT, JSONB) FROM anon;
