-- Add payment tracking columns to orders table
-- This allows tracking invoice/payment status while QuickBooks remains the source of truth

-- Payment status: UNINVOICED (default) → INVOICED → PAID
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'UNINVOICED';

-- Invoice number from QuickBooks
ALTER TABLE orders ADD COLUMN IF NOT EXISTS invoice_number TEXT;

-- Date invoice was created
ALTER TABLE orders ADD COLUMN IF NOT EXISTS invoice_date DATE;

-- Date payment was received
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_received_date DATE;

-- Create index for filtering by payment status
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON orders(payment_status);

-- Add comment for documentation
COMMENT ON COLUMN orders.payment_status IS 'Payment status: UNINVOICED, INVOICED, PAID';
COMMENT ON COLUMN orders.invoice_number IS 'Invoice number from QuickBooks';
COMMENT ON COLUMN orders.invoice_date IS 'Date invoice was created in QuickBooks';
COMMENT ON COLUMN orders.payment_received_date IS 'Date payment was received';
