-- Create driver_applications table for FMCSA-compliant CDL driver employment applications
CREATE TABLE IF NOT EXISTS driver_applications (
  id SERIAL PRIMARY KEY,

  -- Page 1: Applicant Information
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  date_of_birth DATE,
  ssn TEXT, -- encrypted in production
  phone TEXT,
  email TEXT,
  address TEXT,
  city TEXT,
  state TEXT,
  zip TEXT,
  lived_3_years BOOLEAN DEFAULT false,
  previous_addresses JSONB, -- array of previous addresses if lived < 3 years

  -- Driver's License Information
  license_number TEXT,
  license_state TEXT,
  license_class TEXT,
  license_expires DATE,
  license_front_url TEXT,
  license_back_url TEXT,
  endorsements TEXT[], -- H, N, P, T, S, X
  other_licenses_3_years BOOLEAN DEFAULT false,
  other_licenses_details JSONB, -- details of other licenses

  -- Medical Card
  medical_card_url TEXT,
  medical_expires DATE,

  -- Accidents/Crashes Previous 3 Years
  accidents_3_years BOOLEAN DEFAULT false,
  accidents_details JSONB, -- array of accident records

  -- Moving Traffic Violations Previous 3 Years
  violations_3_years BOOLEAN DEFAULT false,
  violations_details JSONB, -- array of violation records

  -- Forfeitures Previous 3 Years
  denied_license BOOLEAN DEFAULT false,
  denied_license_details TEXT,
  license_revoked BOOLEAN DEFAULT false,
  license_revoked_details TEXT,

  -- Employment Record Previous 10 Years
  employment_history JSONB, -- array of employer objects
  employment_gaps TEXT,

  -- Page 1 Signature
  page1_signature TEXT, -- base64 signature image
  page1_date DATE,

  -- Page 2: Fair Credit Reporting Act Disclosure
  page2_signature TEXT,
  page2_date DATE,

  -- Page 3: Driver License Requirements Compliance
  page3_signature TEXT,
  page3_date DATE,

  -- Page 4: Pre-Employment Alcohol & Drug Test
  tested_positive BOOLEAN DEFAULT false,
  alcohol_concentration BOOLEAN DEFAULT false,
  refused_test BOOLEAN DEFAULT false,
  return_to_duty_docs BOOLEAN DEFAULT false,
  page4_signature TEXT,
  page4_date DATE,

  -- Page 5: Safety Performance History Investigation
  page5_signature TEXT,
  page5_date DATE,

  -- Page 6: PSP Driver Disclosure & Authorization
  page6_full_name TEXT,
  page6_signature TEXT,
  page6_date DATE,

  -- Page 7: FMCSA Drug and Alcohol Clearinghouse Consent
  clearinghouse_registered BOOLEAN DEFAULT false,
  page7_signature TEXT,
  page7_date DATE,

  -- Page 8: MVR Release Consent
  page8_signature TEXT,
  page8_date DATE,

  -- Application Status
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'approved', 'rejected')),
  rejection_reason TEXT,

  -- Metadata
  submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  reviewed_at TIMESTAMP WITH TIME ZONE,
  reviewed_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE driver_applications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Anyone can submit application" ON driver_applications;
DROP POLICY IF EXISTS "Authenticated users can view applications" ON driver_applications;
DROP POLICY IF EXISTS "Authenticated users can update applications" ON driver_applications;

-- Policy: Anyone can insert (apply)
CREATE POLICY "Anyone can submit application" ON driver_applications
  FOR INSERT WITH CHECK (true);

-- Policy: Authenticated users can view all applications
-- (Role-based access is enforced at the application level since auth.users is not directly queryable)
CREATE POLICY "Authenticated users can view applications" ON driver_applications
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- Policy: Authenticated users can update applications
CREATE POLICY "Authenticated users can update applications" ON driver_applications
  FOR UPDATE USING (auth.uid() IS NOT NULL);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_driver_applications_status ON driver_applications(status);
CREATE INDEX IF NOT EXISTS idx_driver_applications_email ON driver_applications(email);
CREATE INDEX IF NOT EXISTS idx_driver_applications_submitted_at ON driver_applications(submitted_at DESC);

-- Create storage bucket for application files (license, medical card)
INSERT INTO storage.buckets (id, name, public)
VALUES ('driver-applications', 'driver-applications', false)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies if they exist
DROP POLICY IF EXISTS "Anyone can upload application files" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated can view application files" ON storage.objects;

-- Storage policy: Anyone can upload to driver-applications bucket
CREATE POLICY "Anyone can upload application files" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'driver-applications');

-- Storage policy: Authenticated users can view application files
CREATE POLICY "Authenticated can view application files" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'driver-applications' AND
    auth.uid() IS NOT NULL
  );
