-- Add payment_date column to orders table for tracking when payments are received
-- This enables accurate "Avg Days to Pay" calculation

ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_date TIMESTAMPTZ;

-- Index for efficient queries on payment date
CREATE INDEX IF NOT EXISTS idx_orders_payment_date ON orders(payment_date);

-- Comment for documentation
COMMENT ON COLUMN orders.payment_date IS 'Timestamp when payment was received/marked as paid';
