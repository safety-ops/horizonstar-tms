BEGIN;
DROP TRIGGER IF EXISTS orders_mirror_payment_type ON orders;
DROP FUNCTION IF EXISTS mirror_payment_type_to_method();
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_payment_method_check;
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_payment_terms_check;
DROP INDEX IF EXISTS idx_orders_payment_method;
DROP INDEX IF EXISTS idx_orders_payment_terms;
ALTER TABLE orders DROP COLUMN IF EXISTS payment_method;
ALTER TABLE orders DROP COLUMN IF EXISTS payment_review_required;
ALTER TABLE orders DROP COLUMN IF EXISTS uship_delivery_confirmation_code;
ALTER TABLE vehicle_inspections DROP COLUMN IF EXISTS uship_confirmation_code;
COMMIT;
-- Note: payment_terms normalization is one-way (NET21/45/60 → NET_30 loses precision).
-- True rollback requires a pre-migration pg_dump — take one before applying.
