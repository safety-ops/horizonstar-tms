-- Rollback for 20260507200000_order_number_sequence.sql
-- WARNING: dropping the sequence resets numbering. Coordinate with any code
-- that calls next_order_number() before running this in production.

DROP FUNCTION IF EXISTS public.next_order_number(TEXT, TEXT);
DROP SEQUENCE IF EXISTS public.order_number_seq;
