-- Add delivery_status column to orders table
-- Values: 'pending' (default), 'picked_up', 'delivered'

ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_status TEXT DEFAULT 'pending';

-- Add check constraint for valid values
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'orders_delivery_status_check'
    ) THEN
        ALTER TABLE orders ADD CONSTRAINT orders_delivery_status_check
        CHECK (delivery_status IN ('pending', 'picked_up', 'delivered'));
    END IF;
END $$;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_orders_delivery_status ON orders(delivery_status);
