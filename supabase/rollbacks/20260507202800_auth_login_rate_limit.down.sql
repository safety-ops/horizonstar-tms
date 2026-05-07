-- Rollback for 20260507202800_auth_login_rate_limit.sql
-- Drops the RPC first (no dependents), then the table.

DROP FUNCTION IF EXISTS public.record_login_attempt(TEXT, BOOLEAN, TEXT);
DROP TABLE IF EXISTS public.auth_login_attempts CASCADE;
