-- Rollback for 20260429190000_rls_tier2.sql.
--
-- Restores the pre-Tier-2 posture for `drivers`, `users`, `local_drivers`.
-- Use ONLY if the Tier 2 lock-down causes a production outage.
--
-- !! SECURITY WARNING !!
-- The pre-Tier-2 state on these tables was "RLS disabled, anon-readable"
-- (verified live 2026-04-29: anon could SELECT SSN, bank account/routing,
-- DOB, PIN, plaintext `users.password`). This rollback re-exposes that
-- data. DO NOT execute unless you are actively triaging a P1 outage and
-- have authorization. Prefer a forward-fix that loosens specific policies
-- rather than re-disabling RLS.
--
-- Order of operations:
--   1. DROP every policy created in 20260429190000.
--   2. DISABLE RLS on all three tables (matches pre-migration state — RLS
--      was never enabled in repo on these tables).

BEGIN;

-- 1. drivers — drop tight policies, disable RLS.
DROP POLICY IF EXISTS "drivers_select" ON public.drivers;
DROP POLICY IF EXISTS "drivers_insert" ON public.drivers;
DROP POLICY IF EXISTS "drivers_update" ON public.drivers;
DROP POLICY IF EXISTS "drivers_delete" ON public.drivers;
ALTER TABLE public.drivers DISABLE ROW LEVEL SECURITY;

-- 2. users — drop tight policies, disable RLS.
DROP POLICY IF EXISTS "users_select" ON public.users;
DROP POLICY IF EXISTS "users_insert" ON public.users;
DROP POLICY IF EXISTS "users_update" ON public.users;
DROP POLICY IF EXISTS "users_delete" ON public.users;
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;

-- 3. local_drivers — drop tight policies, disable RLS.
DROP POLICY IF EXISTS "local_drivers_select" ON public.local_drivers;
DROP POLICY IF EXISTS "local_drivers_insert" ON public.local_drivers;
DROP POLICY IF EXISTS "local_drivers_update" ON public.local_drivers;
DROP POLICY IF EXISTS "local_drivers_delete" ON public.local_drivers;
ALTER TABLE public.local_drivers DISABLE ROW LEVEL SECURITY;

-- The drivers.auth_user_id and local_drivers.auth_user_id indexes from
-- 20260429130000 are intentionally retained — they're pure read-perf wins
-- unrelated to policies. Same for the helper functions in 20260429140000.

COMMIT;
