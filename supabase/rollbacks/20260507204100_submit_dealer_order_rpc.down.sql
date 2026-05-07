-- Rollback: 20260507204100_submit_dealer_order_rpc.down.sql
-- Drops the submit_dealer_order SECURITY DEFINER RPC.
-- Safe to run: the dealer-role INSERT policy on orders was not touched
-- in the forward migration, so rolling back only removes the RPC.

DROP FUNCTION IF EXISTS public.submit_dealer_order(JSONB);
