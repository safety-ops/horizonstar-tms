-- Orders and broker detail completeness fields (idempotent)
-- Adds split address and vehicle lot/buyer fields on orders,
-- and full profile fields on brokers for master sync.

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS vehicle_lot_number text,
  ADD COLUMN IF NOT EXISTS vehicle_buyer_number text,
  ADD COLUMN IF NOT EXISTS pickup_address text,
  ADD COLUMN IF NOT EXISTS pickup_city text,
  ADD COLUMN IF NOT EXISTS pickup_state text,
  ADD COLUMN IF NOT EXISTS pickup_zip text,
  ADD COLUMN IF NOT EXISTS delivery_address text,
  ADD COLUMN IF NOT EXISTS delivery_city text,
  ADD COLUMN IF NOT EXISTS delivery_state text,
  ADD COLUMN IF NOT EXISTS delivery_zip text;
ALTER TABLE public.brokers
  ADD COLUMN IF NOT EXISTS email text,
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS state text,
  ADD COLUMN IF NOT EXISTS zip text,
  ADD COLUMN IF NOT EXISTS contact_name text;
