-- P0c: SECURITY DEFINER STABLE helpers used by the upcoming RLS policies.
-- All helpers:
--   • SECURITY DEFINER  — bypass RLS on the lookup tables themselves
--   • STABLE            — planner caches result for the duration of a statement
--   • PARALLEL SAFE     — no side effects, allows parallel scans
--   • SET search_path   — locks against search_path injection
--   • REVOKE FROM PUBLIC then GRANT TO authenticated — least privilege
--
-- Roles ground truth (from 20260313000100_add_dealer_role.sql):
--   users.role IN ('DISPATCHER', 'MANAGER', 'ADMIN', 'DEALER')
--
-- Dealer link (from 20260123000000_dealer_portal.sql):
--   dealers.user_id INTEGER REFERENCES users(id)
--   users.auth_id   UUID    references auth.users(id)
--   So dealer = auth.uid() → users.auth_id → users.id → dealers.user_id
--
-- Status filtering uses an allow-list (status = 'ACTIVE') rather than a
-- deny-list. New status values default to "no access" — fail-closed.

-- 1. Enforce 1-to-1 dealer↔user mapping. No live duplicates as of 2026-04-29
--    (verified via REST). Mirrors the drivers.auth_user_id partial-unique
--    pattern from 20260429130000.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_dealers_user_id
  ON public.dealers(user_id)
  WHERE user_id IS NOT NULL;

-- 2. is_tms_staff() — allow-list, NOT deny-list. New roles default to non-staff.
CREATE OR REPLACE FUNCTION public.is_tms_staff() RETURNS BOOLEAN
  LANGUAGE sql STABLE PARALLEL SAFE SECURITY DEFINER
  SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.auth_id = auth.uid()
      AND COALESCE(u.is_active, true) = true
      AND u.role IN ('ADMIN', 'MANAGER', 'DISPATCHER')
  );
$$;

-- 3. is_dealer_user() — caller is an active dealer-portal user.
CREATE OR REPLACE FUNCTION public.is_dealer_user() RETURNS BOOLEAN
  LANGUAGE sql STABLE PARALLEL SAFE SECURITY DEFINER
  SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.auth_id = auth.uid()
      AND COALESCE(u.is_active, true) = true
      AND u.role = 'DEALER'
  );
$$;

-- 4. current_dealer_id() — caller's dealer row id, via the 2-hop link.
--    UNIQUE(user_id) above guarantees determinism; ORDER BY d.id is a
--    belt-and-suspenders fallback against a future schema change.
CREATE OR REPLACE FUNCTION public.current_dealer_id() RETURNS INTEGER
  LANGUAGE sql STABLE PARALLEL SAFE SECURITY DEFINER
  SET search_path = public, pg_temp AS $$
  SELECT d.id
  FROM public.dealers d
  JOIN public.users u ON u.id = d.user_id
  WHERE u.auth_id = auth.uid()
    AND COALESCE(u.is_active, true) = true
    AND COALESCE(d.is_active, true) = true
  ORDER BY d.id
  LIMIT 1;
$$;

-- 5. current_driver_id() — caller's driver row id (drivers.auth_user_id is
--    UNIQUE per 20260429130000, so the result is deterministic).
CREATE OR REPLACE FUNCTION public.current_driver_id() RETURNS INTEGER
  LANGUAGE sql STABLE PARALLEL SAFE SECURITY DEFINER
  SET search_path = public, pg_temp AS $$
  SELECT id FROM public.drivers
  WHERE auth_user_id = auth.uid()
    AND status = 'ACTIVE'
  LIMIT 1;
$$;

-- 6. current_local_driver_id() — caller's local-driver row id.
CREATE OR REPLACE FUNCTION public.current_local_driver_id() RETURNS INTEGER
  LANGUAGE sql STABLE PARALLEL SAFE SECURITY DEFINER
  SET search_path = public, pg_temp AS $$
  SELECT id FROM public.local_drivers
  WHERE auth_user_id = auth.uid()
    AND status = 'ACTIVE'
  LIMIT 1;
$$;

-- Lock down execution: only authenticated callers, never anon or PUBLIC.
REVOKE EXECUTE ON FUNCTION public.is_tms_staff()           FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.is_dealer_user()         FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.current_dealer_id()      FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.current_driver_id()      FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.current_local_driver_id() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.is_tms_staff()           TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_dealer_user()         TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_dealer_id()      TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_driver_id()      TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_local_driver_id() TO authenticated;
