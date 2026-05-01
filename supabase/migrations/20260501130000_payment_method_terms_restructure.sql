-- 20260501130000_payment_method_terms_restructure.sql
-- Phase 2: split payment_type into payment_method + payment_terms, add USHIP code.
-- Additive. Legacy payment_type retained ~90 days for audit (drop in 2026-08 cleanup migration).
-- Idempotent: safe to re-run.

BEGIN;

-- 1. Add payment_method column
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_method TEXT;

-- 2. Add USHIP confirmation code columns (Phase 4 reads/writes these)
ALTER TABLE vehicle_inspections ADD COLUMN IF NOT EXISTS uship_confirmation_code TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS uship_delivery_confirmation_code TEXT;

-- 3. Audit-flag column for orders that need manual payment-method review
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_review_required BOOLEAN DEFAULT FALSE;

-- The block_orders_field_escalation trigger (RLS migration 20260429200000) refuses
-- writes to orders columns outside its allow-list when auth.uid() is not staff.
-- Migrations run as a Supabase migration role, which is_tms_staff() returns false for.
-- Disable it for the duration of the data backfill, re-enable before COMMIT.
ALTER TABLE orders DISABLE TRIGGER block_orders_field_escalation;

-- 4. Normalize existing payment_terms in orders/brokers/dealers (idempotent).
-- Lossy: NET21/45/60 (and underscored NET_21/_45/_60) all collapse to NET_30
-- because the new schema has no NET_21/45/60 buckets. Documented in rollback.
UPDATE orders SET payment_terms = CASE UPPER(TRIM(COALESCE(payment_terms, '')))
    WHEN 'NET21' THEN 'NET_30' WHEN 'NET45' THEN 'NET_30' WHEN 'NET60' THEN 'NET_30'
    WHEN 'NET_21' THEN 'NET_30' WHEN 'NET_45' THEN 'NET_30' WHEN 'NET_60' THEN 'NET_30'
    WHEN 'NET5'  THEN 'NET_5'  WHEN 'NET7'  THEN 'NET_7'
    WHEN 'NET10' THEN 'NET_10' WHEN 'NET15' THEN 'NET_15' WHEN 'NET30' THEN 'NET_30'
    WHEN 'QUICK_PAY' THEN 'QUICKPAY'
    WHEN 'COLLECT_AT_PICKUP' THEN 'COP' WHEN 'COLLECT_AT_DELIVERY' THEN 'COD'
    ELSE payment_terms
END WHERE payment_terms IS NOT NULL
  AND UPPER(TRIM(payment_terms)) IN
    ('NET21','NET45','NET60','NET_21','NET_45','NET_60',
     'NET5','NET7','NET10','NET15','NET30',
     'QUICK_PAY','COLLECT_AT_PICKUP','COLLECT_AT_DELIVERY');

UPDATE brokers SET payment_terms = CASE UPPER(TRIM(COALESCE(payment_terms, '')))
    WHEN 'NET21' THEN 'NET_30' WHEN 'NET45' THEN 'NET_30' WHEN 'NET60' THEN 'NET_30'
    WHEN 'NET_21' THEN 'NET_30' WHEN 'NET_45' THEN 'NET_30' WHEN 'NET_60' THEN 'NET_30'
    WHEN 'NET5' THEN 'NET_5' WHEN 'NET7' THEN 'NET_7' WHEN 'NET10' THEN 'NET_10'
    WHEN 'NET15' THEN 'NET_15' WHEN 'NET30' THEN 'NET_30'
    WHEN 'QUICK_PAY' THEN 'QUICKPAY'
    WHEN 'COLLECT_AT_PICKUP' THEN 'COP' WHEN 'COLLECT_AT_DELIVERY' THEN 'COD'
    ELSE payment_terms
END WHERE payment_terms IS NOT NULL;

UPDATE dealers SET payment_terms = CASE UPPER(TRIM(COALESCE(payment_terms, '')))
    WHEN 'NET21' THEN 'NET_30' WHEN 'NET45' THEN 'NET_30' WHEN 'NET60' THEN 'NET_30'
    WHEN 'NET_21' THEN 'NET_30' WHEN 'NET_45' THEN 'NET_30' WHEN 'NET_60' THEN 'NET_30'
    WHEN 'NET5' THEN 'NET_5' WHEN 'NET7' THEN 'NET_7' WHEN 'NET10' THEN 'NET_10'
    WHEN 'NET15' THEN 'NET_15' WHEN 'NET30' THEN 'NET_30'
    WHEN 'QUICK_PAY' THEN 'QUICKPAY'
    ELSE payment_terms
END WHERE payment_terms IS NOT NULL;

-- 5. Backfill payment_method from legacy payment_type (only NULL rows)
UPDATE orders SET payment_method = CASE UPPER(TRIM(COALESCE(payment_type, '')))
    WHEN 'BILL' THEN 'ACH'  WHEN 'BILLING' THEN 'ACH'
    WHEN 'COD' THEN 'CASH'  WHEN 'COP' THEN 'CASH'
    WHEN 'LOCAL_COD' THEN 'CASH'
    WHEN 'CHECK' THEN 'CHECK'
    WHEN 'SPLIT' THEN 'CASH'
    ELSE NULL
END WHERE payment_method IS NULL;

-- 6. Backfill payment_terms when missing
UPDATE orders SET payment_terms = CASE UPPER(TRIM(COALESCE(payment_type, '')))
    WHEN 'BILL' THEN COALESCE(NULLIF(payment_terms,''), 'NET_30')
    WHEN 'BILLING' THEN COALESCE(NULLIF(payment_terms,''), 'NET_30')
    WHEN 'COD' THEN 'COD' WHEN 'COP' THEN 'COP'
    WHEN 'LOCAL_COD' THEN 'COD'
    WHEN 'CHECK' THEN 'COD' WHEN 'SPLIT' THEN 'COD'
    ELSE COALESCE(NULLIF(payment_terms,''), 'NET_30')
END WHERE payment_terms IS NULL OR payment_terms = '';

-- 7. Flag legacy CHECK orders for manual review (default term may be wrong)
UPDATE orders SET payment_review_required = TRUE
  WHERE UPPER(TRIM(COALESCE(payment_type, ''))) = 'CHECK'
    AND payment_review_required IS DISTINCT FROM TRUE;

-- Re-enable the field-escalation trigger now that data backfill is done.
-- Subsequent DDL (constraints, trigger, indexes, comments) doesn't trigger UPDATE.
ALTER TABLE orders ENABLE TRIGGER block_orders_field_escalation;

-- 8. CHECK constraints (NOT VALID — don't fail on legacy outliers, validate later)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'orders_payment_method_check' AND conrelid = 'orders'::regclass) THEN
    ALTER TABLE orders ADD CONSTRAINT orders_payment_method_check CHECK (
      payment_method IS NULL OR payment_method IN (
        'CASH','CHECK','ZELLE','CASHIERS_CHECK','MONEY_ORDER','COMCHEK',
        'ACH','CREDIT_CARD','VENMO','CASHAPP','USHIP','FACTORING'
      )
    ) NOT VALID;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'orders_payment_terms_check' AND conrelid = 'orders'::regclass) THEN
    ALTER TABLE orders ADD CONSTRAINT orders_payment_terms_check CHECK (
      payment_terms IS NULL OR payment_terms IN (
        'QUICKPAY','COMCHEK','COP','COD',
        'NET_5','NET_7','NET_10','NET_15','NET_20','NET_30'
      )
    ) NOT VALID;
  END IF;
END $$;

-- 9. Mirror trigger — old iOS builds writing only payment_type get auto-filled
CREATE OR REPLACE FUNCTION mirror_payment_type_to_method() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.payment_method IS NULL AND NEW.payment_type IS NOT NULL THEN
    NEW.payment_method := CASE UPPER(NEW.payment_type)
      WHEN 'BILL' THEN 'ACH' WHEN 'BILLING' THEN 'ACH'
      WHEN 'COD' THEN 'CASH' WHEN 'COP' THEN 'CASH'
      WHEN 'LOCAL_COD' THEN 'CASH'
      WHEN 'CHECK' THEN 'CHECK' WHEN 'SPLIT' THEN 'CASH'
      ELSE NULL
    END;
    IF NEW.payment_terms IS NULL THEN
      NEW.payment_terms := CASE UPPER(NEW.payment_type)
        WHEN 'BILL' THEN 'NET_30' WHEN 'BILLING' THEN 'NET_30'
        WHEN 'COP' THEN 'COP'
        WHEN 'COD' THEN 'COD' WHEN 'LOCAL_COD' THEN 'COD'
        WHEN 'CHECK' THEN 'COD' WHEN 'SPLIT' THEN 'COD'
        ELSE NULL
      END;
    END IF;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS orders_mirror_payment_type ON orders;
CREATE TRIGGER orders_mirror_payment_type
  BEFORE INSERT OR UPDATE OF payment_type, payment_method, payment_terms ON orders
  FOR EACH ROW EXECUTE FUNCTION mirror_payment_type_to_method();

-- 10. Indexes
CREATE INDEX IF NOT EXISTS idx_orders_payment_method ON orders(payment_method);
CREATE INDEX IF NOT EXISTS idx_orders_payment_terms  ON orders(payment_terms);

-- 11. Column comments (documentation in DB itself)
COMMENT ON COLUMN orders.payment_method IS
  'New (2026-05). One of CASH/CHECK/ZELLE/CASHIERS_CHECK/MONEY_ORDER/COMCHEK/ACH/CREDIT_CARD/VENMO/CASHAPP/USHIP/FACTORING.';
COMMENT ON COLUMN orders.payment_terms IS
  'New (2026-05). One of QUICKPAY/COMCHEK/COP/COD/NET_5/NET_7/NET_10/NET_15/NET_20/NET_30.';
COMMENT ON COLUMN orders.payment_type IS
  'LEGACY (deprecated 2026-05-01). Retained ~90 days. Drop in cleanup migration after 2026-08-01.';
COMMENT ON COLUMN vehicle_inspections.uship_confirmation_code IS
  'uShip confirmation code captured at delivery for payment_method=USHIP orders.';

COMMIT;
