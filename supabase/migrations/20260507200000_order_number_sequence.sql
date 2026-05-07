-- Server-side sequential order numbers via SECURITY DEFINER RPC.
--
-- Replaces client-generated numbers (Date.now().toString().slice(-4|-6)) which
-- have measurable collision risk: ORD-XXXX is 1-in-10K. Production likely
-- already has dupes; the sequence-backed RPC is collision-proof by construction.
--
-- Authorization model:
--   • TMS staff (ADMIN/MANAGER/DISPATCHER) may mint any prefix (ORD, IMP, DLR).
--   • Dealer-portal users may only mint DLR-<their_own_code>-<seq>.
--   • anon: no execute grant. Drivers and other authenticated users fall to the
--     "Unauthorized order number request" path because they fail both gates.
--
-- Helper signatures verified against 20260429140000_rls_helpers.sql:
--   public.is_tms_staff()      RETURNS BOOLEAN
--   public.current_dealer_id() RETURNS INTEGER  -- returns dealers.id
--
-- The dealer_code lives on public.dealers (per 20260123000000_dealer_portal.sql
-- line 9). It is NOT on dealer_applications, so we authorize against dealers.

-- 1. Sequence. Start at 100000 so the first issued numbers are already 6
-- digits (no leading-zero ambiguity in CSV exports). Rolls to 7 digits
-- naturally after ~900k orders.
CREATE SEQUENCE IF NOT EXISTS public.order_number_seq
    AS BIGINT
    START WITH 100000
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

-- Lock the sequence: only the SECURITY DEFINER RPC below may advance it.
REVOKE ALL ON SEQUENCE public.order_number_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE public.order_number_seq FROM anon;
REVOKE ALL ON SEQUENCE public.order_number_seq FROM authenticated;

-- 2. RPC. SECURITY DEFINER + locked search_path per Supabase guidance.
CREATE OR REPLACE FUNCTION public.next_order_number(
    p_prefix      TEXT DEFAULT 'ORD',
    p_dealer_code TEXT DEFAULT NULL
) RETURNS TEXT
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public, pg_temp
AS $func$
DECLARE
    v_is_staff      BOOLEAN := public.is_tms_staff();
    v_dealer_id     INTEGER := public.current_dealer_id();
    v_dealer_match  BOOLEAN := FALSE;
    v_seq_text      TEXT;
BEGIN
    -- Authorization gate. Staff: any prefix. Dealer: DLR + their own code only.
    IF NOT v_is_staff THEN
        IF p_prefix = 'DLR'
           AND v_dealer_id IS NOT NULL
           AND p_dealer_code IS NOT NULL
        THEN
            -- defer dealer-code ownership check until validation block below
            NULL;
        ELSE
            RAISE EXCEPTION 'Unauthorized order number request'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    IF p_prefix = 'DLR' THEN
        IF p_dealer_code IS NULL OR length(p_dealer_code) = 0 THEN
            RAISE EXCEPTION 'Dealer code required for DLR prefix'
                USING ERRCODE = '22023';
        ELSIF p_dealer_code !~ '^[A-Z0-9]{2,12}$' THEN
            RAISE EXCEPTION 'Invalid dealer code format'
                USING ERRCODE = '22023';
        END IF;

        -- Non-staff dealers must be claiming their own dealer_code. Staff are
        -- exempt from the ownership check (they can mint on a dealer's behalf).
        IF NOT v_is_staff THEN
            SELECT EXISTS (
                SELECT 1 FROM public.dealers
                WHERE id = v_dealer_id
                  AND dealer_code = p_dealer_code
            ) INTO v_dealer_match;

            IF NOT v_dealer_match THEN
                RAISE EXCEPTION 'Unauthorized order number request'
                    USING ERRCODE = '42501';
            END IF;
        END IF;

        v_seq_text := lpad(nextval('public.order_number_seq')::TEXT, 6, '0');
        RETURN 'DLR-' || p_dealer_code || '-' || v_seq_text;

    ELSIF p_prefix IN ('ORD', 'IMP') THEN
        v_seq_text := lpad(nextval('public.order_number_seq')::TEXT, 6, '0');
        RETURN p_prefix || '-' || v_seq_text;

    ELSE
        RAISE EXCEPTION 'Unsupported prefix'
            USING ERRCODE = '22023';
    END IF;
END;
$func$;

-- 3. Grants. The function gates internally; expose to authenticated only.
REVOKE ALL ON FUNCTION public.next_order_number(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.next_order_number(TEXT, TEXT) TO authenticated;
-- Intentionally NOT granted to anon: anonymous users cannot create orders.
