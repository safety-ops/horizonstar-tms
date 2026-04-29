-- Rollback for 20260429150000_driver_login_rpc.sql.
-- After dropping, the iOS app's pre-auth lookup will fall back to the
-- direct GET /drivers query. That query will fail under any future RLS
-- on the drivers table, so this rollback is appropriate ONLY if RLS on
-- drivers has not yet been applied.

DROP FUNCTION IF EXISTS public.driver_can_login_by_email(TEXT);
