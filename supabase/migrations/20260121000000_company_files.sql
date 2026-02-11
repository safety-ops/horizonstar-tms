-- Company Files table for storing company-level compliance documents
-- Follows same pattern as driver_files and truck_files

CREATE TABLE IF NOT EXISTS company_files (
  id SERIAL PRIMARY KEY,
  file_type TEXT NOT NULL,
  category TEXT DEFAULT 'QUALIFICATION',
  file_name TEXT NOT NULL,
  file_data TEXT NOT NULL,
  notes TEXT,
  expiration_date DATE,
  folder_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE company_files ENABLE ROW LEVEL SECURITY;

-- Allow all operations for authenticated users
CREATE POLICY "Enable read access for all users" ON company_files FOR SELECT USING (true);
CREATE POLICY "Enable insert for all users" ON company_files FOR INSERT WITH CHECK (true);
CREATE POLICY "Enable update for all users" ON company_files FOR UPDATE USING (true);
CREATE POLICY "Enable delete for all users" ON company_files FOR DELETE USING (true);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_company_files_file_type ON company_files(file_type);
CREATE INDEX IF NOT EXISTS idx_company_files_category ON company_files(category);
CREATE INDEX IF NOT EXISTS idx_company_files_expiration ON company_files(expiration_date);
