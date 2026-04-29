-- Rollback for 20260429130000_rls_supporting_indexes.sql.
--
-- WARNING: this does NOT restore the duplicate auth_user_id link that was
-- NULLed on driver id=2. That correction is intentional and should not be
-- reverted. If id=2 needs driver-app login again, provision a fresh
-- auth.users row for them and link manually.

DROP INDEX IF EXISTS public.idx_trips_driver_id;
DROP INDEX IF EXISTS public.idx_orders_trip_id;
DROP INDEX IF EXISTS public.idx_orders_driver_id;
DROP INDEX IF EXISTS public.uniq_local_drivers_auth_user_id;
DROP INDEX IF EXISTS public.uniq_drivers_auth_user_id;
