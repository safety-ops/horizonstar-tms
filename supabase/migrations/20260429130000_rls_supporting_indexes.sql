-- P0: indexes the upcoming RLS policies depend on, plus UNIQUE enforcement
-- on driver auth links. From design review:
--   - Database Optimizer: orders(driver_id), orders(trip_id), trips(driver_id)
--     are missing — every per-row RLS predicate would Seq-Scan without them.
--   - Security Engineer (C2): drivers.auth_user_id and local_drivers.auth_user_id
--     are not UNIQUE, allowing scope-escalation via deliberate duplicates.
--     Confirmed in live data: driver id=2 (GIORGI DOLIDZE) and driver id=18
--     (Levani Grigolia) share auth_user_id 2f679700-cab3-431f-8b8f-340213b244c1.
--
-- Fix order:
--   1. Resolve the existing duplicate by NULLing the older row's auth_user_id.
--      The newer driver id=18 keeps its auth link; the older id=2 retains its
--      FMCSA-required record but loses driver-app OTP login until a fresh
--      auth.users row is provisioned for them.
--   2. Add UNIQUE (partial) on drivers.auth_user_id and local_drivers.auth_user_id.
--   3. Add the three RLS-supporting indexes.
--
-- All operations use IF NOT EXISTS / explicit predicates so re-running is safe.
-- Plain CREATE INDEX (not CONCURRENTLY) — Supabase migrations run inside a
-- transaction, and the affected tables are small enough (<200 rows each)
-- that the brief lock is acceptable.

-- 1. Resolve existing duplicate. Targeting id=2 specifically rather than a
--    generic "older row" predicate so the change is auditable and idempotent.
UPDATE public.drivers
SET auth_user_id = NULL
WHERE id = 2
  AND auth_user_id = '2f679700-cab3-431f-8b8f-340213b244c1';

-- Defense-in-depth: catch any other duplicates that might exist in less
-- obvious form. NULLs the auth link on the row with the lowest id for any
-- duplicated auth_user_id. Logs a NOTICE so the human reviewer can see it.
DO $$
DECLARE
  dupe RECORD;
BEGIN
  FOR dupe IN
    SELECT auth_user_id
    FROM public.drivers
    WHERE auth_user_id IS NOT NULL
    GROUP BY auth_user_id
    HAVING COUNT(*) > 1
  LOOP
    -- Clear ALL but the newest (highest id) row sharing this auth_user_id.
    -- Using `id <> MAX(id)` (not `id = MIN(id)`) handles the 3+-row case
    -- correctly — code-reviewer caught this before push.
    UPDATE public.drivers
    SET auth_user_id = NULL
    WHERE auth_user_id = dupe.auth_user_id
      AND id <> (
        SELECT MAX(id) FROM public.drivers WHERE auth_user_id = dupe.auth_user_id
      );
    RAISE NOTICE 'Cleared duplicate auth_user_id % on all but newest drivers row', dupe.auth_user_id;
  END LOOP;
END$$;

-- 2. UNIQUE (partial) — enforces 1-to-1 between auth.users and driver row,
--    while permitting unlimited driver rows with auth_user_id = NULL.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_drivers_auth_user_id
  ON public.drivers(auth_user_id)
  WHERE auth_user_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_local_drivers_auth_user_id
  ON public.local_drivers(auth_user_id)
  WHERE auth_user_id IS NOT NULL;

-- 3. RLS-supporting indexes for orders/trips driver-scope predicates.
CREATE INDEX IF NOT EXISTS idx_orders_driver_id
  ON public.orders(driver_id)
  WHERE driver_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_orders_trip_id
  ON public.orders(trip_id)
  WHERE trip_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_trips_driver_id
  ON public.trips(driver_id)
  WHERE driver_id IS NOT NULL;
