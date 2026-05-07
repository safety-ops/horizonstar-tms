-- Rollback for 20260507190000_orders_trip_id_restrict_delete.sql
--
-- Restores the original ON DELETE SET NULL behavior on orders.trip_id
-- (confdeltype = 'n' as observed in the live DB on 2026-05-05).
--
-- NOT auto-applied. Run manually via Supabase SQL editor or psql if the
-- forward migration needs to be reverted.

BEGIN;

ALTER TABLE public.orders
  DROP CONSTRAINT orders_trip_id_fkey;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_trip_id_fkey
  FOREIGN KEY (trip_id)
  REFERENCES public.trips(id)
  ON DELETE SET NULL;

COMMIT;
