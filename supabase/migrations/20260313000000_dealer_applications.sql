-- Dealer Self-Registration Applications
-- Allows dealers to submit registration requests for admin approval

CREATE TABLE IF NOT EXISTS dealer_applications (
  id SERIAL PRIMARY KEY,
  company_name TEXT NOT NULL,
  contact_name TEXT NOT NULL,
  contact_email TEXT NOT NULL,
  contact_phone TEXT,
  company_address TEXT,
  payment_terms TEXT DEFAULT 'NET30',
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'approved', 'rejected')),
  submitted_at TIMESTAMPTZ DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by INTEGER,
  rejection_reason TEXT
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_dealer_applications_status ON dealer_applications(status);
CREATE INDEX IF NOT EXISTS idx_dealer_applications_email ON dealer_applications(contact_email);

-- RLS
ALTER TABLE dealer_applications ENABLE ROW LEVEL SECURITY;

-- Anyone can submit a dealer application (no auth required)
CREATE POLICY "Anyone can submit dealer application" ON dealer_applications FOR INSERT WITH CHECK (true);

-- Only authenticated users (admins) can view applications
CREATE POLICY "Authenticated users can view dealer applications" ON dealer_applications FOR SELECT USING (auth.uid() IS NOT NULL);

-- Only authenticated users (admins) can update application status
CREATE POLICY "Authenticated users can update dealer applications" ON dealer_applications FOR UPDATE USING (auth.uid() IS NOT NULL);
