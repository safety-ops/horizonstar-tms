-- Restore LOCAL_COD as a valid payment_terms value.
--
-- Background
-- ----------
-- 20260501130000_payment_method_terms_restructure.sql collapsed the legacy
-- payment_type='LOCAL_COD' bucket into payment_terms='COD', losing the
-- distinction between regular driver-collected COD and locally-collected COD
-- (the latter is routed to the local driver, not the trip driver).
--
-- The web TMS calc code at index.html:12022, :12210-12214, :12358 still
-- treats payment_type='LOCAL_COD' as a meaningful signal — financial reports
-- show a separate "Local COD" line and totals are routed to the local driver.
-- After the V2 dropdown rollout, users could no longer pick LOCAL_COD when
-- creating a non-split order, so new local-COD orders couldn't be flagged.
--
-- Fix: add LOCAL_COD to the orders_payment_terms_check allow-list. The same
-- value is now an option in the V2 dropdown (PAYMENT_TERMS_OPTIONS_V2 in
-- index.html). brokers/dealers also have a payment_terms column with the
-- same shape but no CHECK constraint — no change needed there.

BEGIN;

ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_terms_check;

ALTER TABLE public.orders ADD CONSTRAINT orders_payment_terms_check CHECK (
  payment_terms IS NULL OR payment_terms IN (
    'QUICKPAY','COMCHEK','COP','COD','LOCAL_COD',
    'NET_5','NET_7','NET_10','NET_15','NET_20','NET_30'
  )
) NOT VALID;

COMMENT ON CONSTRAINT orders_payment_terms_check ON public.orders IS
  'Payment terms allow-list. LOCAL_COD added 2026-05-04 to restore the local-driver-collected COD distinction lost in 20260501130000.';

COMMIT;
