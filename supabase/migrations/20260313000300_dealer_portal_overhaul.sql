-- Dealer Portal Overhaul — Phase 3 & 4 tables

-- Order status history for timeline tracking
CREATE TABLE IF NOT EXISTS order_status_history (
  id BIGSERIAL PRIMARY KEY,
  order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  status TEXT NOT NULL,
  changed_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  changed_by_name TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_osh_order_id ON order_status_history(order_id);
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "osh_select" ON order_status_history FOR SELECT USING (true);
CREATE POLICY "osh_insert" ON order_status_history FOR INSERT WITH CHECK (true);

-- Dealer-dispatcher per-order messaging
CREATE TABLE IF NOT EXISTS dealer_order_messages (
  id BIGSERIAL PRIMARY KEY,
  order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  dealer_id INTEGER NOT NULL REFERENCES dealers(id) ON DELETE CASCADE,
  sender_type TEXT NOT NULL CHECK (sender_type IN ('dealer', 'dispatcher')),
  sender_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  sender_name TEXT NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_dom_order_id ON dealer_order_messages(order_id);
CREATE INDEX IF NOT EXISTS idx_dom_dealer_id ON dealer_order_messages(dealer_id);
ALTER TABLE dealer_order_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "dom_select" ON dealer_order_messages FOR SELECT USING (true);
CREATE POLICY "dom_insert" ON dealer_order_messages FOR INSERT WITH CHECK (true);
CREATE POLICY "dom_update" ON dealer_order_messages FOR UPDATE USING (true);

-- Order change requests (post-pickup modifications)
CREATE TABLE IF NOT EXISTS order_change_requests (
  id BIGSERIAL PRIMARY KEY,
  order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  dealer_id INTEGER NOT NULL REFERENCES dealers(id) ON DELETE CASCADE,
  requested_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  request_type TEXT NOT NULL CHECK (request_type IN ('edit', 'cancel')),
  changes JSONB NOT NULL DEFAULT '{}'::jsonb,
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  review_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_ocr_order_id ON order_change_requests(order_id);
CREATE INDEX IF NOT EXISTS idx_ocr_dealer_id ON order_change_requests(dealer_id);
CREATE INDEX IF NOT EXISTS idx_ocr_status ON order_change_requests(status);
ALTER TABLE order_change_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ocr_select" ON order_change_requests FOR SELECT USING (true);
CREATE POLICY "ocr_insert" ON order_change_requests FOR INSERT WITH CHECK (true);
CREATE POLICY "ocr_update" ON order_change_requests FOR UPDATE USING (true);
