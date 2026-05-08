-- ============================================================================
-- Rollback for: 20260508130000_orders_inoperable_flag.sql
--
-- Drops the has_inoperable_vehicle column. Per-vehicle data in
-- orders.vehicles[].is_inoperable JSONB is preserved.
--
-- Run manually (not auto-applied by `supabase db push`).
-- ============================================================================

ALTER TABLE public.orders DROP COLUMN IF EXISTS has_inoperable_vehicle;
