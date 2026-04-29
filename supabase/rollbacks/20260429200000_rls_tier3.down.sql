-- Rollback for 20260429200000_rls_tier3.sql.
--
-- Restores the pre-Tier-3 posture for `orders` and `trips`.
-- Use ONLY if the Tier 3 lock-down causes a production outage.
--
-- !! SECURITY WARNING !!
-- The pre-Tier-3 state on these tables was "RLS disabled, anon-readable"
-- (verified live 2026-04-29: anon could SELECT customer_name,
-- customer_address, broker_fee, total_paid, total_invoiced, payment_status,
-- driver_cut_percent, miles, and every other column on the highest-
-- concurrency table in the system). This rollback re-exposes that data
-- AND drops the column-level field-escalation triggers, restoring the
-- prior posture where drivers/dealers could PATCH driver_id, dealer_id,
-- broker_fee, total_paid, payment_status etc. on rows they own at the
-- row level.
--
-- DO NOT execute unless you are actively triaging a P1 outage and have
-- authorization. Prefer a forward-fix that loosens specific policies or
-- adds entries to the trigger allow-list rather than re-disabling RLS.

BEGIN;

DROP TRIGGER IF EXISTS block_orders_field_escalation ON public.orders;
DROP TRIGGER IF EXISTS block_trips_field_escalation ON public.trips;

DROP FUNCTION IF EXISTS public.block_orders_field_escalation();
DROP FUNCTION IF EXISTS public.block_trips_field_escalation();

DROP POLICY IF EXISTS "orders_select" ON public.orders;
DROP POLICY IF EXISTS "orders_insert" ON public.orders;
DROP POLICY IF EXISTS "orders_update" ON public.orders;
DROP POLICY IF EXISTS "orders_delete" ON public.orders;
ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "trips_select" ON public.trips;
DROP POLICY IF EXISTS "trips_insert" ON public.trips;
DROP POLICY IF EXISTS "trips_update" ON public.trips;
DROP POLICY IF EXISTS "trips_delete" ON public.trips;
ALTER TABLE public.trips DISABLE ROW LEVEL SECURITY;

COMMIT;
