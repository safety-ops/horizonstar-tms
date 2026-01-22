-- Add invoice tracking columns to orders table
-- This enables tracking when orders are formally invoiced vs just delivered

ALTER TABLE orders ADD COLUMN IF NOT EXISTS invoiced_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS invoice_number TEXT;

-- Index for efficient queries on invoice date
CREATE INDEX IF NOT EXISTS idx_orders_invoiced_at ON orders(invoiced_at);

-- Comments for documentation
COMMENT ON COLUMN orders.invoiced_at IS 'Timestamp when order was formally invoiced to broker';
COMMENT ON COLUMN orders.invoice_number IS 'Optional invoice number/reference for the order';
