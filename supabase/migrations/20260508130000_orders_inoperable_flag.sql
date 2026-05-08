-- ============================================================================
-- Migration: orders — top-level inoperable shim for fast filtering / iOS read
-- Timestamp: 20260508130000
--
-- Per-vehicle truth lives in orders.vehicles[].is_inoperable (JSONB).
-- This top-level boolean is a shim kept in sync by importer + web TMS save
-- logic. true if ANY vehicle in the load is inoperable.
--
-- Drivers must see this before pickup so they can bring winch/ramps. iOS
-- reads this column directly (avoids decoding the vehicles[] array).
-- ============================================================================

ALTER TABLE public.orders
  ADD COLUMN has_inoperable_vehicle BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.orders.has_inoperable_vehicle IS
  'True if any item in orders.vehicles[] has is_inoperable=true. Top-level shim '
  'updated by client write logic in cd-load-importer/content.js (gatherFormData) '
  'and index.html order save paths. Per-vehicle truth lives in '
  'orders.vehicles[].is_inoperable. Drivers see this in iOS for the pickup banner.';
