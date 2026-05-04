-- Settlement Supersession RPC
--
-- Adds a SECURITY DEFINER function that performs an atomic
-- "supersede + create new revision" operation against payroll_records.
--
-- Why this function exists
-- ------------------------
-- Migration 20260504000000_settlement_per_trip_unification.sql added the
-- partial unique index:
--
--   uniq_active_settlement_per_trip
--     ON payroll_records (driver_id, trip_id, type)
--     WHERE trip_id IS NOT NULL AND superseded_by IS NULL
--
-- When the TMS edits a settlement that's already in 'paid' status it must
-- (a) INSERT a new revision row with superseded_by IS NULL and
-- (b) UPDATE the old row's superseded_by to point at the new id.
--
-- Done as two REST round-trips, both rows transiently satisfy
-- "superseded_by IS NULL" -> the partial unique index throws and the second
-- write rolls back. Inside a single SQL statement (a data-modifying CTE),
-- PostgreSQL evaluates both sub-statements against the same snapshot and
-- defers unique-constraint enforcement to end-of-statement, so the index
-- only ever sees the post-statement state: one active row per
-- (driver_id, trip_id, type).
--
-- Authorization
-- -------------
-- The function is SECURITY DEFINER so it can write past per-row RLS, but
-- the body re-asserts the same auth predicate used by the existing INSERT
-- policy from 20260306000000_payroll_record_snapshots_and_rls.sql:
--
--   auth.uid() IS NOT NULL
--   AND EXISTS (SELECT 1 FROM users u
--                WHERE u.auth_id = auth.uid()
--                  AND COALESCE(u.is_active, true) = true)
--
-- search_path is pinned to (public, pg_temp) to block search-path hijack.

CREATE OR REPLACE FUNCTION public.supersede_and_create_settlement_revision(
  p_old_record_id INT,
  p_new_record    JSONB
) RETURNS public.payroll_records
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_authorized BOOLEAN;
  v_old        public.payroll_records%ROWTYPE;
  v_new        public.payroll_records%ROWTYPE;
BEGIN
  -- ---------------------------------------------------------------------
  -- 1. Authorization gate (mirrors the INSERT RLS policy)
  -- ---------------------------------------------------------------------
  SELECT
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
        FROM public.users u
       WHERE u.auth_id = auth.uid()
         AND COALESCE(u.is_active, true) = true
    )
  INTO v_authorized;

  IF NOT v_authorized THEN
    RAISE EXCEPTION 'insufficient_privilege'
      USING HINT = 'Only active TMS users may supersede settlements.',
            ERRCODE = '42501';
  END IF;

  -- ---------------------------------------------------------------------
  -- 2. Lock the old record (FOR UPDATE serializes concurrent supersedes)
  -- ---------------------------------------------------------------------
  SELECT *
    INTO v_old
    FROM public.payroll_records
   WHERE id = p_old_record_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'old_record_not_found: payroll_records.id=%', p_old_record_id
      USING ERRCODE = 'P0002';
  END IF;

  -- ---------------------------------------------------------------------
  -- 3. Validate the old row is eligible to be superseded
  --    Only paid per-trip settlements should ever take this path.
  -- ---------------------------------------------------------------------
  IF v_old.superseded_by IS NOT NULL THEN
    RAISE EXCEPTION
      'old_record_already_superseded: payroll_records.id=% is already superseded by id=%',
      v_old.id, v_old.superseded_by
      USING ERRCODE = '22023';
  END IF;

  IF v_old.trip_id IS NULL THEN
    RAISE EXCEPTION
      'old_record_not_per_trip: payroll_records.id=% has trip_id IS NULL (multi-trip paystub); supersession RPC only handles per-trip settlements',
      v_old.id
      USING ERRCODE = '22023';
  END IF;

  IF COALESCE(v_old.status, '') <> 'paid' THEN
    RAISE EXCEPTION
      'old_record_not_paid: payroll_records.id=% has status=%; supersession RPC is only for paid records (use a normal UPDATE for draft/finalized)',
      v_old.id, COALESCE(v_old.status, '<null>')
      USING ERRCODE = '22023';
  END IF;

  -- ---------------------------------------------------------------------
  -- 4. Atomic INSERT new revision + UPDATE old.superseded_by
  --
  -- The INSERT pulls payload columns out of p_new_record JSONB, but
  -- driver_id, trip_id, type, revision, superseded_by, and created_at
  -- are FORCED from the locked old row (and server clock) so the caller
  -- cannot reassign the driver, move the revision to a different trip,
  -- switch type, fast-forward the revision counter, or pre-supersede
  -- the new row. Anything else in p_new_record (gross_earnings, net_pay,
  -- deductions, bonuses, line_items, totals, edit_audit, status,
  -- pay_date, stub_number, record_number, check_number, formula_version,
  -- period_start, period_end, trip_ids, cash_collected, reimbursements,
  -- amount_paid, paid_at, emailed_at, pdf_storage_path, company_id) is
  -- caller-supplied.
  --
  -- Both writes are inside a single statement, so the partial unique
  -- index is checked once at end-of-statement and sees only the new row
  -- with superseded_by IS NULL.
  -- ---------------------------------------------------------------------
  WITH new_row AS (
    INSERT INTO public.payroll_records (
      -- forced server-side fields
      driver_id,
      trip_id,
      type,
      revision,
      superseded_by,
      created_at,
      -- caller-supplied payload fields
      period_start,
      period_end,
      pay_date,
      stub_number,
      check_number,
      record_number,
      trip_ids,
      gross_earnings,
      cash_collected,
      reimbursements,
      net_pay,
      amount_paid,
      deductions,
      bonuses,
      line_items,
      totals,
      edit_audit,
      status,
      formula_version,
      paid_at,
      emailed_at,
      pdf_storage_path,
      company_id
    ) VALUES (
      -- forced
      v_old.driver_id,
      v_old.trip_id,
      v_old.type,
      COALESCE(v_old.revision, 1) + 1,
      NULL,
      now(),
      -- caller-supplied (NULL-safe casts; missing keys -> column default/NULL)
      NULLIF(p_new_record->>'period_start', '')::DATE,
      NULLIF(p_new_record->>'period_end', '')::DATE,
      NULLIF(p_new_record->>'pay_date', '')::DATE,
      p_new_record->>'stub_number',
      p_new_record->>'check_number',
      p_new_record->>'record_number',
      COALESCE(p_new_record->'trip_ids', '[]'::jsonb),
      COALESCE((p_new_record->>'gross_earnings')::NUMERIC, 0),
      COALESCE((p_new_record->>'cash_collected')::NUMERIC, 0),
      COALESCE((p_new_record->>'reimbursements')::NUMERIC, 0),
      COALESCE((p_new_record->>'net_pay')::NUMERIC, 0),
      COALESCE((p_new_record->>'amount_paid')::NUMERIC, 0),
      COALESCE(p_new_record->'deductions', '{}'::jsonb),
      COALESCE(p_new_record->'bonuses', '{}'::jsonb),
      COALESCE(p_new_record->'line_items', '{}'::jsonb),
      COALESCE(p_new_record->'totals', '{}'::jsonb),
      COALESCE(p_new_record->'edit_audit', '[]'::jsonb),
      COALESCE(p_new_record->>'status', 'paid'),
      COALESCE(p_new_record->>'formula_version', 'payroll_v2'),
      NULLIF(p_new_record->>'paid_at', '')::TIMESTAMPTZ,
      NULLIF(p_new_record->>'emailed_at', '')::TIMESTAMPTZ,
      p_new_record->>'pdf_storage_path',
      NULLIF(p_new_record->>'company_id', '')::UUID
    )
    RETURNING *
  ),
  superseded AS (
    UPDATE public.payroll_records
       SET superseded_by = (SELECT id FROM new_row)
     WHERE id = p_old_record_id
    RETURNING id
  )
  SELECT *
    INTO v_new
    FROM new_row;

  -- If the INSERT or UPDATE violated any constraint (including the partial
  -- unique index), control never reaches here -- PostgreSQL aborts the
  -- whole function and the transaction rolls back automatically.

  RETURN v_new;
END;
$$;

COMMENT ON FUNCTION public.supersede_and_create_settlement_revision(INT, JSONB) IS
  'Atomically supersedes a paid per-trip payroll_records row and inserts the next revision in a single statement so the partial unique index uniq_active_settlement_per_trip is satisfied. Caller must be an active TMS user. driver_id/trip_id/type/revision/superseded_by/created_at are forced server-side; all other columns come from p_new_record JSONB.';

-- Lock down default PUBLIC EXECUTE, then grant to authenticated callers.
REVOKE ALL ON FUNCTION public.supersede_and_create_settlement_revision(INT, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.supersede_and_create_settlement_revision(INT, JSONB) TO authenticated;
