-- Rollback: 20260507202900_log_activity_rpc.down.sql
-- Drops the log_activity RPC added in the forward migration.
-- The public INSERT policy on activity_log is unaffected (it was never touched).

DROP FUNCTION IF EXISTS public.log_activity(TEXT, JSONB);
