-- Rollback for 20260429140000_rls_helpers.sql.
-- Run only if a downstream policy migration creates problems and we need
-- to remove the helpers entirely.
--
-- IMPORTANT: any policy that calls these helpers must be dropped first —
-- Postgres will refuse the DROP FUNCTION with `ERROR: cannot drop function
-- ... because other objects depend on it`. Drop policies, then run this.

DROP FUNCTION IF EXISTS public.current_local_driver_id();
DROP FUNCTION IF EXISTS public.current_driver_id();
DROP FUNCTION IF EXISTS public.current_dealer_id();
DROP FUNCTION IF EXISTS public.is_dealer_user();
DROP FUNCTION IF EXISTS public.is_tms_staff();

-- The UNIQUE index on dealers(user_id) is intentionally retained — it's a
-- pure data-integrity guard that doesn't depend on the helpers.
