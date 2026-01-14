-- Add payment terms and due date fields for AR tracking
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_terms TEXT DEFAULT 'NET30';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS due_date DATE;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS custom_terms_days INT;

-- Create index for faster AR queries
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON orders(payment_status);
CREATE INDEX IF NOT EXISTS idx_orders_payment_type ON orders(payment_type);
CREATE INDEX IF NOT EXISTS idx_orders_due_date ON orders(due_date);
