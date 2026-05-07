-- ============================================================
-- Rollback: 20260507204000_anon_rls_tighten.down.sql
-- Restores the anon-role grants and policy role-lists removed
-- by 20260507204000_anon_rls_tighten.sql.
-- ============================================================

-- 1. Restore anon EXECUTE on the revoked functions.
GRANT EXECUTE ON FUNCTION public.block_orders_field_escalation()        TO anon;
GRANT EXECUTE ON FUNCTION public.block_trips_field_escalation()         TO anon;
GRANT EXECUTE ON FUNCTION public.mirror_payment_type_to_method()        TO anon;
GRANT EXECUTE ON FUNCTION public.sync_payment_status_on_driver_paid()   TO anon;
GRANT EXECUTE ON FUNCTION public.normalize_driver_login_fields()        TO anon;
GRANT EXECUTE ON FUNCTION public.update_updated_at_column()             TO anon;
GRANT EXECUTE ON FUNCTION public.update_claims_updated_at()             TO anon;
GRANT EXECUTE ON FUNCTION public.update_vehicle_inspection_updated_at() TO anon;
GRANT EXECUTE ON FUNCTION public.supersede_and_create_settlement_revision(integer, jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.email_quota_check_and_log(uuid, integer, integer, text, text, text, integer, integer, bigint, text, integer, integer, integer) TO anon;
GRANT EXECUTE ON FUNCTION public.email_quota_finalize(bigint, text, text, text, integer) TO anon;
GRANT EXECUTE ON FUNCTION public.cleanup_abandoned_inspections()        TO anon;
GRANT EXECUTE ON FUNCTION public.mark_order_paid_on_uship_code()        TO anon;
GRANT EXECUTE ON FUNCTION public.next_order_number(text, text)          TO anon;

-- 2. Restore policy role-lists to PUBLIC (which includes anon).
ALTER POLICY billing_events_all    ON public.billing_events TO PUBLIC;
ALTER POLICY claims_delete         ON public.claims         TO PUBLIC;
ALTER POLICY claims_insert         ON public.claims         TO PUBLIC;
ALTER POLICY claims_select         ON public.claims         TO PUBLIC;
ALTER POLICY claims_update         ON public.claims         TO PUBLIC;
ALTER POLICY fixed_costs_delete    ON public.fixed_costs    TO PUBLIC;
ALTER POLICY fixed_costs_insert    ON public.fixed_costs    TO PUBLIC;
ALTER POLICY fixed_costs_select    ON public.fixed_costs    TO PUBLIC;
ALTER POLICY fixed_costs_update    ON public.fixed_costs    TO PUBLIC;
ALTER POLICY variable_costs_delete ON public.variable_costs TO PUBLIC;
ALTER POLICY variable_costs_insert ON public.variable_costs TO PUBLIC;
ALTER POLICY variable_costs_select ON public.variable_costs TO PUBLIC;
ALTER POLICY variable_costs_update ON public.variable_costs TO PUBLIC;
ALTER POLICY driver_files_delete   ON public.driver_files   TO PUBLIC;
ALTER POLICY driver_files_insert   ON public.driver_files   TO PUBLIC;
ALTER POLICY driver_files_select   ON public.driver_files   TO PUBLIC;
ALTER POLICY driver_files_update   ON public.driver_files   TO PUBLIC;
ALTER POLICY truck_files_delete    ON public.truck_files    TO PUBLIC;
ALTER POLICY truck_files_insert    ON public.truck_files    TO PUBLIC;
ALTER POLICY truck_files_select    ON public.truck_files    TO PUBLIC;
ALTER POLICY truck_files_update    ON public.truck_files    TO PUBLIC;
