-- Migration: 20260507204100_submit_dealer_order_rpc.sql
-- Purpose : SECURITY DEFINER RPC for dealer-submitted orders (P1-4 / Wave C2).
--           Replaces the direct client-side INSERT into orders for dealer callers.
--           Force-sets dealer_id (anti-spoofing) and status='PENDING' (workflow guard).
--           Mints order_number via next_order_number('DLR', dealer_code).
--           Writes audit row via log_activity('DEALER_ORDER_SUBMITTED', ...).
--           Returns new orders.id (BIGINT cast from INTEGER serial).
--
-- NOTE: The dealer-role direct INSERT policy (orders_insert, currently staff-only anyway
--       — see below) is intentionally NOT dropped here. Drop it in a follow-up migration
--       after the client is migrated to call this RPC. Same deferred pattern as C1.
--
-- Current orders_insert policy:
--   policyname: orders_insert
--   cmd:        INSERT
--   with_check: (SELECT is_tms_staff())
-- This policy already restricts direct INSERT to TMS staff only — dealers cannot
-- currently INSERT directly via REST (the check would fail). The RPC bypasses RLS
-- via SECURITY DEFINER, so no policy change is needed to make the RPC work today.

CREATE OR REPLACE FUNCTION public.submit_dealer_order(
    p_payload JSONB
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $func$
DECLARE
    v_dealer_id   INTEGER;
    v_dealer_code TEXT;
    v_is_staff    BOOLEAN;
    v_order_num   TEXT;
    v_new_id      BIGINT;
BEGIN
    -- 1. Auth gate: caller must be TMS staff OR a verified dealer.
    v_is_staff  := public.is_tms_staff();
    v_dealer_id := public.current_dealer_id();

    IF NOT v_is_staff AND v_dealer_id IS NULL THEN
        RAISE EXCEPTION 'Only dealers or TMS staff may submit dealer orders'
            USING ERRCODE = '42501';  -- insufficient_privilege
    END IF;

    -- 2. Determine the canonical dealer_id.
    --    Dealer callers: their own id from current_dealer_id().
    --    TMS staff submitting on behalf of a dealer: must supply dealer_id in payload.
    IF v_is_staff AND v_dealer_id IS NULL THEN
        v_dealer_id := NULLIF(p_payload->>'dealer_id', '')::INTEGER;
        IF v_dealer_id IS NULL THEN
            RAISE EXCEPTION 'Staff caller must include dealer_id in payload'
                USING ERRCODE = '22023';  -- invalid_parameter_value
        END IF;
    END IF;

    -- 3. Resolve dealer_code (needed for order number prefix).
    SELECT dealer_code INTO v_dealer_code
    FROM public.dealers
    WHERE id = v_dealer_id;

    IF v_dealer_code IS NULL THEN
        RAISE EXCEPTION 'Dealer % not found or has no dealer_code', v_dealer_id
            USING ERRCODE = '42704';  -- undefined_object
    END IF;

    -- 4. Mint order number via the existing locked RPC.
    v_order_num := public.next_order_number('DLR', v_dealer_code);

    -- 5. INSERT the order.
    --    dealer_id  — force from server-side auth (anti-spoofing).
    --    status     — force to 'PENDING' (no client workflow override).
    --    All other fields pulled from p_payload with NULL defaults.
    --
    --    Column mapping notes vs. the spec template:
    --      * pickup_street / delivery_street do NOT exist in DB. The live schema uses
    --        pickup_address / delivery_address for the street line. Mapped accordingly.
    --      * origin / destination are legacy free-text address fields still present in
    --        the schema. The client populates them as pickup_location / delivery_location
    --        (single strings). Mapped from p_payload->>'pickup_location' and
    --        p_payload->>'delivery_location'.
    --      * payment_amount does NOT exist as a column. The client uses revenue for the
    --        transport fee. Mapped to revenue. payment_terms maps directly.
    --      * created_by_dealer does NOT exist as a column. The order_source_platform
    --        column serves the equivalent semantic; we set it to 'dealer'. Omitted the
    --        non-existent created_by_dealer column entirely.
    --      * vehicles (JSONB) is populated as a single-element array mirroring what
    --        the client currently builds in submitDealerOrder().
    --      * delivery_status is set to 'pending' (lowercase) to match client behavior.
    --      * pickup_date / dropoff_date mapped from p_payload->>'pickup_date' /
    --        p_payload->>'delivery_date' (matching client payload key names).
    INSERT INTO public.orders (
        order_number,
        dealer_id,
        status,
        delivery_status,
        order_source_platform,
        vehicle_year,
        vehicle_make,
        vehicle_model,
        vehicle_vin,
        vehicle_color,
        vehicle_body_type,
        vehicle_lot_number,
        vehicle_buyer_number,
        vehicles,
        origin,
        destination,
        pickup_address,
        pickup_city,
        pickup_state,
        pickup_zip,
        pickup_contact_name,
        pickup_contact_phone,
        delivery_address,
        delivery_city,
        delivery_state,
        delivery_zip,
        delivery_contact_name,
        delivery_contact_phone,
        pickup_date,
        dropoff_date,
        revenue,
        payment_type,
        payment_terms,
        dispatcher_notes,
        notes,
        created_at
    ) VALUES (
        v_order_num,
        v_dealer_id,
        'PENDING',                                          -- force-set; no client override
        'pending',                                          -- delivery_status initial value
        'dealer',                                           -- order_source_platform sentinel
        NULLIF(p_payload->>'vehicle_year', '')::INTEGER,
        p_payload->>'vehicle_make',
        p_payload->>'vehicle_model',
        p_payload->>'vehicle_vin',
        p_payload->>'vehicle_color',
        p_payload->>'vehicle_body_type',
        p_payload->>'vehicle_lot_number',
        p_payload->>'vehicle_buyer_number',
        -- Build vehicles JSONB array to match client submitDealerOrder() structure.
        jsonb_build_array(
            jsonb_build_object(
                'year',         NULLIF(p_payload->>'vehicle_year', '')::INTEGER,
                'make',         COALESCE(p_payload->>'vehicle_make', ''),
                'model',        COALESCE(p_payload->>'vehicle_model', ''),
                'vin',          p_payload->>'vehicle_vin',
                'color',        p_payload->>'vehicle_color',
                'lot_number',   p_payload->>'vehicle_lot_number',
                'buyer_number', p_payload->>'vehicle_buyer_number'
            )
        ),
        -- origin/destination: legacy free-text fields populated from pickup/delivery location strings.
        p_payload->>'pickup_location',
        p_payload->>'delivery_location',
        -- Granular address fields (pickup).
        p_payload->>'pickup_address',
        p_payload->>'pickup_city',
        p_payload->>'pickup_state',
        p_payload->>'pickup_zip',
        p_payload->>'pickup_contact_name',
        p_payload->>'pickup_contact_phone',
        -- Granular address fields (delivery).
        p_payload->>'delivery_address',
        p_payload->>'delivery_city',
        p_payload->>'delivery_state',
        p_payload->>'delivery_zip',
        p_payload->>'delivery_contact_name',
        p_payload->>'delivery_contact_phone',
        -- Dates.
        NULLIF(p_payload->>'pickup_date', '')::DATE,
        NULLIF(p_payload->>'delivery_date', '')::DATE,
        -- Financials.
        NULLIF(p_payload->>'payment_amount', '')::NUMERIC,
        p_payload->>'payment_type',
        p_payload->>'payment_terms',
        -- Notes: client sends notes as dispatcher_notes; mirror both columns.
        p_payload->>'notes',
        p_payload->>'notes',
        NOW()
    )
    RETURNING id INTO v_new_id;

    -- 6. Audit row via the existing SECURITY DEFINER RPC.
    PERFORM public.log_activity(
        'DEALER_ORDER_SUBMITTED',
        jsonb_build_object(
            'order_id',          v_new_id,
            'order_number',      v_order_num,
            'dealer_id',         v_dealer_id,
            'submitted_by_staff', v_is_staff
        )
    );

    RETURN v_new_id;
END;
$func$;

-- Revoke from PUBLIC and anon; grant only to authenticated.
REVOKE ALL     ON FUNCTION public.submit_dealer_order(JSONB) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.submit_dealer_order(JSONB) FROM anon;
GRANT  EXECUTE ON FUNCTION public.submit_dealer_order(JSONB) TO authenticated;

COMMENT ON FUNCTION public.submit_dealer_order(JSONB) IS
'SECURITY DEFINER dealer-order INSERT (P1-4 / Wave C2).
Force-sets dealer_id from current_dealer_id() (or p_payload->dealer_id for
TMS staff acting on behalf). Force-sets status=PENDING and delivery_status=pending.
Mints order_number via next_order_number(''DLR'', dealer_code). Writes
DEALER_ORDER_SUBMITTED audit row via log_activity. Returns new orders.id.
Callable by authenticated role only; anon is explicitly revoked.

Payload keys (all optional except vehicle_make, vehicle_model):
  vehicle_year, vehicle_make, vehicle_model, vehicle_vin, vehicle_color,
  vehicle_body_type, vehicle_lot_number, vehicle_buyer_number,
  pickup_location, delivery_location,
  pickup_address, pickup_city, pickup_state, pickup_zip,
  pickup_contact_name, pickup_contact_phone,
  delivery_address, delivery_city, delivery_state, delivery_zip,
  delivery_contact_name, delivery_contact_phone,
  pickup_date, delivery_date,
  payment_amount, payment_type, payment_terms, notes,
  dealer_id (staff-only override).';
