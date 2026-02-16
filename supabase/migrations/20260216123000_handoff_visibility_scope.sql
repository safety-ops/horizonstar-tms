-- Local handoff visibility scope for vehicle inspections
-- Internal handoff media should not be exposed to external channels.

ALTER TABLE vehicle_inspections
  ADD COLUMN IF NOT EXISTS workflow_stage TEXT NOT NULL DEFAULT 'STANDARD';

ALTER TABLE vehicle_inspections
  ADD COLUMN IF NOT EXISTS visibility_scope TEXT NOT NULL DEFAULT 'EXTERNAL_ALLOWED';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'vehicle_inspections_workflow_stage_check'
  ) THEN
    ALTER TABLE vehicle_inspections
      ADD CONSTRAINT vehicle_inspections_workflow_stage_check
      CHECK (workflow_stage IN ('STANDARD', 'TERMINAL_HANDOFF'));
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'vehicle_inspections_visibility_scope_check'
  ) THEN
    ALTER TABLE vehicle_inspections
      ADD CONSTRAINT vehicle_inspections_visibility_scope_check
      CHECK (visibility_scope IN ('EXTERNAL_ALLOWED', 'INTERNAL_ONLY'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_vehicle_inspections_order_type_stage_created_at
  ON vehicle_inspections(order_id, inspection_type, workflow_stage, created_at DESC);
