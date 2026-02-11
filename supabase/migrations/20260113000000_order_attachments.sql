-- Create order_attachments table for storing file attachments to orders
CREATE TABLE IF NOT EXISTS order_attachments (
  id SERIAL PRIMARY KEY,
  order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  file_type TEXT,
  file_size INTEGER,
  uploaded_by TEXT DEFAULT 'dispatcher',
  uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  notes TEXT
);

-- Enable RLS
ALTER TABLE order_attachments ENABLE ROW LEVEL SECURITY;

-- Policies (permissive for anon key like other tables)
CREATE POLICY "Enable read access for all users" ON order_attachments FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON order_attachments FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON order_attachments FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON order_attachments FOR DELETE USING (true);

-- Index for fast lookups by order_id
CREATE INDEX idx_order_attachments_order_id ON order_attachments(order_id);

-- Create storage bucket for order-attachments
INSERT INTO storage.buckets (id, name, public)
VALUES ('order-attachments', 'order-attachments', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for order-attachments bucket
CREATE POLICY "Anyone can upload order attachments"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'order-attachments');

CREATE POLICY "Anyone can view order attachments"
ON storage.objects FOR SELECT
USING (bucket_id = 'order-attachments');

CREATE POLICY "Anyone can delete order attachments"
ON storage.objects FOR DELETE
USING (bucket_id = 'order-attachments');
