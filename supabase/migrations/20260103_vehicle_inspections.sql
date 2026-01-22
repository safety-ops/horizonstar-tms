-- Create vehicle_inspections table for BOL/DVIR vehicle inspections
CREATE TABLE IF NOT EXISTS vehicle_inspections (
  id SERIAL PRIMARY KEY,
  order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
  trip_id INTEGER REFERENCES trips(id) ON DELETE SET NULL,
  driver_id INTEGER REFERENCES drivers(id) ON DELETE SET NULL,
  inspection_type TEXT NOT NULL CHECK (inspection_type IN ('pickup', 'delivery')),

  -- Vehicle Info
  vehicle_year TEXT,
  vehicle_make TEXT,
  vehicle_model TEXT,
  vehicle_vin TEXT,
  vehicle_color TEXT,
  odometer INTEGER,

  -- Timestamps
  started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,

  -- Signatures (base64)
  customer_signature TEXT,
  customer_signed_at TIMESTAMP WITH TIME ZONE,
  customer_name TEXT,
  driver_signature TEXT,
  driver_signed_at TIMESTAMP WITH TIME ZONE,

  -- Notes
  notes TEXT,

  -- Status
  status TEXT DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed')),

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create inspection_photos table for captured photos
CREATE TABLE IF NOT EXISTS inspection_photos (
  id SERIAL PRIMARY KEY,
  inspection_id INTEGER NOT NULL REFERENCES vehicle_inspections(id) ON DELETE CASCADE,
  photo_type TEXT NOT NULL, -- front, rear, left, right, roof, interior, vin, extra
  photo_url TEXT NOT NULL,
  captured_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create inspection_videos table for walkthrough videos
CREATE TABLE IF NOT EXISTS inspection_videos (
  id SERIAL PRIMARY KEY,
  inspection_id INTEGER NOT NULL REFERENCES vehicle_inspections(id) ON DELETE CASCADE,
  video_url TEXT NOT NULL,
  duration_seconds INTEGER,
  captured_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create inspection_damages table for damage markers
CREATE TABLE IF NOT EXISTS inspection_damages (
  id SERIAL PRIMARY KEY,
  inspection_id INTEGER NOT NULL REFERENCES vehicle_inspections(id) ON DELETE CASCADE,
  damage_type TEXT NOT NULL CHECK (damage_type IN ('scratch', 'dent', 'chip', 'broken', 'missing')),
  view TEXT NOT NULL, -- side_left, side_right, front, rear, top
  x_position DECIMAL NOT NULL, -- 0-100 percentage
  y_position DECIMAL NOT NULL, -- 0-100 percentage
  description TEXT,
  photo_url TEXT, -- optional close-up photo
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS on all tables
ALTER TABLE vehicle_inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspection_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspection_videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE inspection_damages ENABLE ROW LEVEL SECURITY;

-- Policies for vehicle_inspections
CREATE POLICY "Authenticated users can view inspections" ON vehicle_inspections
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can insert inspections" ON vehicle_inspections
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update inspections" ON vehicle_inspections
  FOR UPDATE USING (auth.uid() IS NOT NULL);

-- Policies for inspection_photos
CREATE POLICY "Authenticated users can view inspection photos" ON inspection_photos
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can insert inspection photos" ON inspection_photos
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can delete inspection photos" ON inspection_photos
  FOR DELETE USING (auth.uid() IS NOT NULL);

-- Policies for inspection_videos
CREATE POLICY "Authenticated users can view inspection videos" ON inspection_videos
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can insert inspection videos" ON inspection_videos
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can delete inspection videos" ON inspection_videos
  FOR DELETE USING (auth.uid() IS NOT NULL);

-- Policies for inspection_damages
CREATE POLICY "Authenticated users can view inspection damages" ON inspection_damages
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can insert inspection damages" ON inspection_damages
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can update inspection damages" ON inspection_damages
  FOR UPDATE USING (auth.uid() IS NOT NULL);

CREATE POLICY "Authenticated users can delete inspection damages" ON inspection_damages
  FOR DELETE USING (auth.uid() IS NOT NULL);

-- Create indexes for faster lookups
CREATE INDEX idx_vehicle_inspections_order_id ON vehicle_inspections(order_id);
CREATE INDEX idx_vehicle_inspections_trip_id ON vehicle_inspections(trip_id);
CREATE INDEX idx_vehicle_inspections_driver_id ON vehicle_inspections(driver_id);
CREATE INDEX idx_vehicle_inspections_type ON vehicle_inspections(inspection_type);
CREATE INDEX idx_vehicle_inspections_status ON vehicle_inspections(status);
CREATE INDEX idx_inspection_photos_inspection_id ON inspection_photos(inspection_id);
CREATE INDEX idx_inspection_videos_inspection_id ON inspection_videos(inspection_id);
CREATE INDEX idx_inspection_damages_inspection_id ON inspection_damages(inspection_id);

-- Create storage bucket for inspection media (photos and videos)
INSERT INTO storage.buckets (id, name, public)
VALUES ('inspection-media', 'inspection-media', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for inspection-media bucket
CREATE POLICY "Authenticated users can upload inspection media" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'inspection-media' AND
    auth.uid() IS NOT NULL
  );

CREATE POLICY "Authenticated users can view inspection media" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'inspection-media' AND
    auth.uid() IS NOT NULL
  );

CREATE POLICY "Authenticated users can delete inspection media" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'inspection-media' AND
    auth.uid() IS NOT NULL
  );

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_vehicle_inspection_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
CREATE TRIGGER vehicle_inspections_updated_at
  BEFORE UPDATE ON vehicle_inspections
  FOR EACH ROW
  EXECUTE FUNCTION update_vehicle_inspection_updated_at();
