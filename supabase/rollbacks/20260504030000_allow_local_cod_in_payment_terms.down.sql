-- Rollback for 20260504030000_allow_local_cod_in_payment_terms.sql
-- WARNING: this will FAIL if any rows currently have payment_terms='LOCAL_COD'.
-- Backfill those to 'COD' or NULL before running this rollback.

BEGIN;

ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_terms_check;

ALTER TABLE public.orders ADD CONSTRAINT orders_payment_terms_check CHECK (
  payment_terms IS NULL OR payment_terms IN (
    'QUICKPAY','COMCHEK','COP','COD',
    'NET_5','NET_7','NET_10','NET_15','NET_20','NET_30'
  )
) NOT VALID;

COMMIT;
