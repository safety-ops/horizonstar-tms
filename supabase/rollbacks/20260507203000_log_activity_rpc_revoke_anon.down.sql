-- Rollback: 20260507203000_log_activity_rpc_revoke_anon.down.sql
-- Re-grants anon EXECUTE (restores Supabase default state for this function).
-- Only needed if rolling back to before the anon-revoke was applied.

GRANT EXECUTE ON FUNCTION public.log_activity(TEXT, JSONB) TO anon;
