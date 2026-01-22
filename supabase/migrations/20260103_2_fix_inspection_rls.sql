-- Fix RLS policies for vehicle_inspections to allow anon access (like other tables in the driver app)
-- The driver app uses the anon key, not Supabase Auth

-- Drop existing policies
DROP POLICY IF EXISTS "Authenticated users can view inspections" ON vehicle_inspections;
DROP POLICY IF EXISTS "Authenticated users can insert inspections" ON vehicle_inspections;
DROP POLICY IF EXISTS "Authenticated users can update inspections" ON vehicle_inspections;

DROP POLICY IF EXISTS "Authenticated users can view inspection photos" ON inspection_photos;
DROP POLICY IF EXISTS "Authenticated users can insert inspection photos" ON inspection_photos;
DROP POLICY IF EXISTS "Authenticated users can delete inspection photos" ON inspection_photos;

DROP POLICY IF EXISTS "Authenticated users can view inspection videos" ON inspection_videos;
DROP POLICY IF EXISTS "Authenticated users can insert inspection videos" ON inspection_videos;
DROP POLICY IF EXISTS "Authenticated users can delete inspection videos" ON inspection_videos;

DROP POLICY IF EXISTS "Authenticated users can view inspection damages" ON inspection_damages;
DROP POLICY IF EXISTS "Authenticated users can insert inspection damages" ON inspection_damages;
DROP POLICY IF EXISTS "Authenticated users can update inspection damages" ON inspection_damages;
DROP POLICY IF EXISTS "Authenticated users can delete inspection damages" ON inspection_damages;

-- Create new permissive policies (same pattern as other tables in the app)
-- vehicle_inspections
CREATE POLICY "Enable read access for all users" ON vehicle_inspections
  FOR SELECT USING (true);

CREATE POLICY "Enable insert for all users" ON vehicle_inspections
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable update for all users" ON vehicle_inspections
  FOR UPDATE USING (true);

CREATE POLICY "Enable delete for all users" ON vehicle_inspections
  FOR DELETE USING (true);

-- inspection_photos
CREATE POLICY "Enable read access for all users" ON inspection_photos
  FOR SELECT USING (true);

CREATE POLICY "Enable insert for all users" ON inspection_photos
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable delete for all users" ON inspection_photos
  FOR DELETE USING (true);

-- inspection_videos
CREATE POLICY "Enable read access for all users" ON inspection_videos
  FOR SELECT USING (true);

CREATE POLICY "Enable insert for all users" ON inspection_videos
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable delete for all users" ON inspection_videos
  FOR DELETE USING (true);

-- inspection_damages
CREATE POLICY "Enable read access for all users" ON inspection_damages
  FOR SELECT USING (true);

CREATE POLICY "Enable insert for all users" ON inspection_damages
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable update for all users" ON inspection_damages
  FOR UPDATE USING (true);

CREATE POLICY "Enable delete for all users" ON inspection_damages
  FOR DELETE USING (true);
