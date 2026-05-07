-- P2-2: Enforce ON DELETE RESTRICT on orders.trip_id
--
-- Audit (2026-05-05) found the live FK orders_trip_id_fkey is currently
-- ON DELETE SET NULL (pg_constraint.confdeltype = 'n'). That means deleting
-- a trip silently disconnects every order pointing at it: rows survive but
-- lose their trip association — an orphan-by-nulling bug that hides data
-- loss from operators.
--
-- Fix: drop the existing FK and recreate with ON DELETE RESTRICT so a trip
-- cannot be deleted while orders still reference it. The TMS UI / API must
-- reassign or unassign those orders explicitly before the trip can be
-- removed. This makes the destructive action visible.
--
-- Pre-flight: at audit time orphan_count = 0 (no orders referencing
-- non-existent trips), so RESTRICT will install cleanly. We re-check inside
-- the transaction in case state drifts before push.

BEGIN;

-- Pre-flight: fail loud if orphan orders exist. RESTRICT cannot be added
-- while dangling references exist; better to abort with a clear message
-- than let Postgres complain about an unrelated-looking FK violation.
DO $$
DECLARE
  orphan_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO orphan_count
  FROM public.orders o
  WHERE o.trip_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.trips t WHERE t.id = o.trip_id);

  IF orphan_count > 0 THEN
    RAISE EXCEPTION
      'Cannot add ON DELETE RESTRICT to orders.trip_id: % orphan order(s) reference non-existent trips. Backfill required (UPDATE orders SET trip_id = NULL WHERE trip_id NOT IN (SELECT id FROM trips);) before re-running this migration.',
      orphan_count;
  END IF;
END$$;

-- Drop the existing SET NULL FK and recreate with RESTRICT.
ALTER TABLE public.orders
  DROP CONSTRAINT orders_trip_id_fkey;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_trip_id_fkey
  FOREIGN KEY (trip_id)
  REFERENCES public.trips(id)
  ON DELETE RESTRICT;

COMMIT;
