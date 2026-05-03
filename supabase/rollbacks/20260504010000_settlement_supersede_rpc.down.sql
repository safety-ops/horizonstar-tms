-- Rollback for 20260504010000_settlement_supersede_rpc.sql
--
-- Drops the SECURITY DEFINER RPC used for atomic settlement supersession.
-- Revokes grants explicitly first; DROP FUNCTION removes them anyway, but
-- being explicit makes the rollback safe to run partially.
--
-- This file lives in supabase/rollbacks/ (NOT supabase/migrations/) so the
-- Supabase CLI does not auto-apply it. Run manually via:
--
--   psql "$DATABASE_URL" -f \
--     supabase/rollbacks/20260504010000_settlement_supersede_rpc.down.sql

REVOKE EXECUTE ON FUNCTION public.supersede_and_create_settlement_revision(INT, JSONB)
  FROM authenticated;

DROP FUNCTION IF EXISTS public.supersede_and_create_settlement_revision(INT, JSONB);
