-- Payroll record snapshots + scoped RLS

ALTER TABLE public.payroll_records
  ADD COLUMN IF NOT EXISTS record_number TEXT,
  ADD COLUMN IF NOT EXISTS formula_version TEXT DEFAULT 'payroll_v2',
  ADD COLUMN IF NOT EXISTS line_items JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS totals JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS emailed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS pdf_storage_path TEXT;

UPDATE public.payroll_records
SET
  record_number = COALESCE(record_number, stub_number, check_number, 'PR-' || id::text),
  formula_version = COALESCE(formula_version, 'payroll_v2'),
  totals = CASE
    WHEN totals IS NULL OR totals = '{}'::jsonb THEN
      jsonb_strip_nulls(
        jsonb_build_object(
          'grossEarnings', COALESCE(gross_earnings, 0),
          'cashCollected', COALESCE(cash_collected, 0),
          'reimbursements', COALESCE(reimbursements, 0),
          'netPay', COALESCE(net_pay, 0),
          'deductions', COALESCE(
            (
              SELECT COALESCE(SUM(
                CASE
                  WHEN jsonb_typeof(value) = 'number' THEN (value::text)::numeric
                  WHEN jsonb_typeof(value) = 'string'
                    AND trim(both '"' from value::text) ~ '^-?[0-9]+(\\.[0-9]+)?$'
                    THEN trim(both '"' from value::text)::numeric
                  WHEN jsonb_typeof(value) = 'object'
                    AND COALESCE(value->>'amount', '') ~ '^-?[0-9]+(\\.[0-9]+)?$'
                    THEN (value->>'amount')::numeric
                  ELSE 0
                END
              ), 0)
              FROM jsonb_each(COALESCE(deductions, '{}'::jsonb))
            ),
            0
          ),
          'bonuses', COALESCE(
            (
              SELECT COALESCE(SUM(
                CASE
                  WHEN jsonb_typeof(value) = 'number' THEN (value::text)::numeric
                  WHEN jsonb_typeof(value) = 'string'
                    AND trim(both '"' from value::text) ~ '^-?[0-9]+(\\.[0-9]+)?$'
                    THEN trim(both '"' from value::text)::numeric
                  WHEN jsonb_typeof(value) = 'object'
                    AND COALESCE(value->>'amount', '') ~ '^-?[0-9]+(\\.[0-9]+)?$'
                    THEN (value->>'amount')::numeric
                  ELSE 0
                END
              ), 0)
              FROM jsonb_each(COALESCE(bonuses, '{}'::jsonb))
            ),
            0
          )
        )
      )
    ELSE totals
  END,
  paid_at = CASE
    WHEN status = 'paid' AND paid_at IS NULL THEN COALESCE(created_at, now())
    ELSE paid_at
  END;

CREATE INDEX IF NOT EXISTS idx_payroll_records_record_number
  ON public.payroll_records(record_number);

CREATE INDEX IF NOT EXISTS idx_payroll_records_status
  ON public.payroll_records(status);

DROP POLICY IF EXISTS "payroll_records_all" ON public.payroll_records;

CREATE POLICY "TMS users can read payroll records" ON public.payroll_records
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  );

CREATE POLICY "Drivers can read own payroll records" ON public.payroll_records
  FOR SELECT
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.drivers d
      WHERE d.id = payroll_records.driver_id
        AND d.auth_user_id = auth.uid()
    )
  );

CREATE POLICY "TMS users can insert payroll records" ON public.payroll_records
  FOR INSERT
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  );

CREATE POLICY "TMS users can update payroll records" ON public.payroll_records
  FOR UPDATE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  )
  WITH CHECK (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  );

CREATE POLICY "TMS users can delete payroll records" ON public.payroll_records
  FOR DELETE
  USING (
    auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.users u
      WHERE u.auth_id = auth.uid()
        AND COALESCE(u.is_active, true) = true
    )
  );
