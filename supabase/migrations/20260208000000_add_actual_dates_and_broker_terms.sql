-- Add actual pickup/delivery timestamps to orders (set when driver completes inspection)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS actual_pickup_date TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS actual_delivery_date TIMESTAMPTZ;

-- Add default payment terms to brokers table
ALTER TABLE brokers ADD COLUMN IF NOT EXISTS payment_terms TEXT DEFAULT 'NET30';
