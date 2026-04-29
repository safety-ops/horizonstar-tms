-- Billing workspace fields and activity timeline support

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS invoice_sent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_follow_up_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS next_follow_up_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS promise_to_pay_date DATE,
  ADD COLUMN IF NOT EXISTS promise_to_pay_amount NUMERIC(12,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS billing_hold_reason TEXT;

COMMENT ON COLUMN orders.invoice_sent_at IS 'Timestamp when the invoice email was sent to the customer';
COMMENT ON COLUMN orders.last_follow_up_at IS 'Timestamp of the latest collections follow-up';
COMMENT ON COLUMN orders.next_follow_up_at IS 'Next collections follow-up target date/time';
COMMENT ON COLUMN orders.promise_to_pay_date IS 'Customer promised payment date';
COMMENT ON COLUMN orders.promise_to_pay_amount IS 'Customer promised payment amount';
COMMENT ON COLUMN orders.billing_hold_reason IS 'Internal reason the order is on billing hold';

CREATE INDEX IF NOT EXISTS idx_orders_invoice_sent_at ON orders(invoice_sent_at);
CREATE INDEX IF NOT EXISTS idx_orders_last_follow_up_at ON orders(last_follow_up_at);
CREATE INDEX IF NOT EXISTS idx_orders_next_follow_up_at ON orders(next_follow_up_at);
CREATE INDEX IF NOT EXISTS idx_orders_promise_to_pay_date ON orders(promise_to_pay_date);

CREATE TABLE IF NOT EXISTS billing_events (
  id BIGSERIAL PRIMARY KEY,
  order_id INT REFERENCES orders(id) ON DELETE CASCADE,
  broker_id INT REFERENCES brokers(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL,
  event_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor_user_id INT REFERENCES users(id) ON DELETE SET NULL,
  channel TEXT,
  subject TEXT,
  body_preview TEXT,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE billing_events IS 'Normalized billing and collections activity timeline';
COMMENT ON COLUMN billing_events.event_type IS 'invoice_marked, invoice_sent, reminder_sent, note_added, promise_recorded, payment_marked, hold_updated';
COMMENT ON COLUMN billing_events.channel IS 'ui, email, phone, note, system';
COMMENT ON COLUMN billing_events.metadata IS 'Additional structured event context';

CREATE INDEX IF NOT EXISTS idx_billing_events_order_id ON billing_events(order_id);
CREATE INDEX IF NOT EXISTS idx_billing_events_broker_id ON billing_events(broker_id);
CREATE INDEX IF NOT EXISTS idx_billing_events_event_at ON billing_events(event_at DESC);
CREATE INDEX IF NOT EXISTS idx_billing_events_event_type ON billing_events(event_type);

ALTER TABLE billing_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "billing_events_all" ON billing_events;
CREATE POLICY "billing_events_all" ON billing_events
  FOR ALL
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);
