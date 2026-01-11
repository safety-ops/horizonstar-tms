-- PrePass API Integration for Toll Transactions
-- Uses PrePass Toll Transaction API v1 and Token API v1

-- Store PrePass API configuration
CREATE TABLE IF NOT EXISTS prepass_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id TEXT NOT NULL,
    api_key TEXT NOT NULL,
    client_id TEXT,
    client_secret TEXT,
    environment TEXT DEFAULT 'production', -- 'sandbox' or 'production'
    last_sync_date TIMESTAMP WITH TIME ZONE,
    sync_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Store toll transactions from PrePass
CREATE TABLE IF NOT EXISTS toll_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    truck_id UUID REFERENCES trucks(id),
    transaction_date TIMESTAMP WITH TIME ZONE NOT NULL,
    posted_date TIMESTAMP WITH TIME ZONE,
    plaza_name TEXT,
    plaza_id TEXT,
    state TEXT,
    amount DECIMAL(10, 2) NOT NULL,
    transponder_id TEXT,
    prepass_reference TEXT UNIQUE, -- For deduplication
    lane_type TEXT, -- 'TOLL', 'WEIGH_STATION', etc.
    trip_id UUID REFERENCES trips(id), -- Optional link to trip
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Map transponders to trucks
CREATE TABLE IF NOT EXISTS transponder_mappings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transponder_id TEXT NOT NULL UNIQUE,
    truck_id UUID REFERENCES trucks(id) NOT NULL,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_toll_transactions_truck_id ON toll_transactions(truck_id);
CREATE INDEX IF NOT EXISTS idx_toll_transactions_date ON toll_transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_toll_transactions_state ON toll_transactions(state);
CREATE INDEX IF NOT EXISTS idx_toll_transactions_trip_id ON toll_transactions(trip_id);
CREATE INDEX IF NOT EXISTS idx_transponder_mappings_transponder ON transponder_mappings(transponder_id);

-- Comments for documentation
COMMENT ON TABLE prepass_config IS 'PrePass API configuration for toll transaction sync';
COMMENT ON TABLE toll_transactions IS 'Toll transactions imported from PrePass';
COMMENT ON TABLE transponder_mappings IS 'Maps PrePass transponder IDs to trucks';
COMMENT ON COLUMN toll_transactions.prepass_reference IS 'Unique reference from PrePass for deduplication';
COMMENT ON COLUMN toll_transactions.lane_type IS 'Type of transaction: TOLL, WEIGH_STATION, etc.';
