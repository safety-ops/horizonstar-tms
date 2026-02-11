-- Dealer Portal Migration
-- Creates dealers table and adds dealer_id to orders

-- Dealers profile table
CREATE TABLE IF NOT EXISTS dealers (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  company_name TEXT NOT NULL,
  dealer_code TEXT UNIQUE NOT NULL,
  contact_name TEXT,
  contact_phone TEXT,
  company_address TEXT,
  payment_terms TEXT DEFAULT 'NET30',
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Link orders to dealers
ALTER TABLE orders ADD COLUMN IF NOT EXISTS dealer_id INTEGER REFERENCES dealers(id);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_orders_dealer_id ON orders(dealer_id);
CREATE INDEX IF NOT EXISTS idx_dealers_user_id ON dealers(user_id);
CREATE INDEX IF NOT EXISTS idx_dealers_dealer_code ON dealers(dealer_code);

-- Enable RLS
ALTER TABLE dealers ENABLE ROW LEVEL SECURITY;

-- RLS Policies for dealers table
CREATE POLICY "Enable read for all authenticated" ON dealers FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON dealers FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON dealers FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON dealers FOR DELETE USING (true);
