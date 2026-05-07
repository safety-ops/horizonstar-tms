-- Rollback: 20260507204300_drop_activity_log_public_insert.sql
-- Re-creates the public INSERT policy on activity_log.

CREATE POLICY activity_log_insert ON public.activity_log
    FOR INSERT
    TO public
    WITH CHECK (true);
