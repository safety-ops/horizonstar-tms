-- Fix RLS policies for driver_notifications to allow anon access (like other tables in the driver app)
-- The driver app uses the anon key, not Supabase Auth, so auth.uid() is always NULL
-- This is the same fix applied to vehicle_inspections in 20260103_2_fix_inspection_rls.sql

-- Ensure RLS is enabled (needed for policies to work)
ALTER TABLE driver_notifications ENABLE ROW LEVEL SECURITY;

-- Drop any existing restrictive policies
DROP POLICY IF EXISTS "Authenticated users can view notifications" ON driver_notifications;
DROP POLICY IF EXISTS "Authenticated users can insert notifications" ON driver_notifications;
DROP POLICY IF EXISTS "Authenticated users can update notifications" ON driver_notifications;
DROP POLICY IF EXISTS "Authenticated users can delete notifications" ON driver_notifications;

-- Add permissive policies (same pattern as all other tables the app uses)
CREATE POLICY "Enable read access for all users" ON driver_notifications
  FOR SELECT USING (true);

CREATE POLICY "Enable insert for all users" ON driver_notifications
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable update for all users" ON driver_notifications
  FOR UPDATE USING (true);

CREATE POLICY "Enable delete for all users" ON driver_notifications
  FOR DELETE USING (true);
