// CD Load Importer - Background Service Worker v5
// Handles Supabase API calls for load import and trip fetching

const DEBUG = true;
const log = (...args) => DEBUG && console.log('[CD Importer BG]', ...args);

// Default Supabase config (can be overridden in settings)
const DEFAULT_SUPABASE_URL = 'https://yrrczhlzulwvdqjwvhtu.supabase.co';

// Listen for messages from content script
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'importLoad') {
    handleImportLoad(request.data)
      .then(result => sendResponse(result))
      .catch(error => sendResponse({ success: false, error: error.message }));
    return true; // Keep channel open for async response
  }

  if (request.action === 'getTrips') {
    handleGetTrips()
      .then(result => sendResponse(result))
      .catch(error => sendResponse({ success: false, error: error.message }));
    return true;
  }

  if (request.action === 'testConnection') {
    testSupabaseConnection()
      .then(result => sendResponse(result))
      .catch(error => sendResponse({ success: false, error: error.message }));
    return true;
  }
});

// Get Supabase config from storage
async function getSupabaseConfig() {
  const result = await chrome.storage.sync.get(['supabaseUrl', 'supabaseKey']);
  return {
    url: result.supabaseUrl || DEFAULT_SUPABASE_URL,
    key: result.supabaseKey || ''
  };
}

// Get active trips from Supabase
async function handleGetTrips() {
  log('Fetching trips...');

  const config = await getSupabaseConfig();

  if (!config.key) {
    throw new Error('Supabase API key not configured. Please open extension settings.');
  }

  // Fetch trips with driver info - get PLANNED and IN_PROGRESS trips
  const response = await fetch(
    `${config.url}/rest/v1/trips?status=in.(PLANNED,IN_PROGRESS)&select=id,trip_number,status,driver_id,drivers(name)&order=trip_date.desc`,
    {
      headers: {
        'apikey': config.key,
        'Authorization': `Bearer ${config.key}`
      }
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    log('Trips fetch error:', response.status, errorText);
    throw new Error(`Failed to fetch trips: ${response.status}`);
  }

  const trips = await response.json();
  log('Fetched trips:', trips.length);

  // Format trips for dropdown
  const formattedTrips = trips.map(t => ({
    id: t.id,
    trip_number: t.trip_number,
    status: t.status,
    driver_name: t.drivers?.name || null
  }));

  return {
    success: true,
    trips: formattedTrips
  };
}

// Import load to Supabase
async function handleImportLoad(loadData) {
  log('Importing load:', loadData);

  const config = await getSupabaseConfig();

  if (!config.key) {
    throw new Error('Supabase API key not configured. Please open extension settings.');
  }

  // Prepare order data for Supabase
  const orderData = {
    order_number: loadData.order_number || `CD-${Date.now()}`,
    broker_name: loadData.broker_name || null,
    revenue: loadData.revenue || null,
    payment_type: loadData.payment_type || null,
    vehicle_year: loadData.vehicle_year || null,
    vehicle_make: loadData.vehicle_make || null,
    vehicle_model: loadData.vehicle_model || null,
    vehicle_vin: loadData.vehicle_vin || null,
    vehicle_color: loadData.vehicle_color || null,
    origin: loadData.origin || null,
    pickup_full_address: loadData.pickup_full_address || null,
    pickup_phone: loadData.pickup_phone || null,
    pickup_date: loadData.pickup_date || null,
    destination: loadData.destination || null,
    delivery_full_address: loadData.delivery_full_address || null,
    delivery_phone: loadData.delivery_phone || null,
    delivery_date: loadData.delivery_date || null,
    dispatcher_notes: loadData.dispatcher_notes || 'Imported from Central Dispatch',
    status: 'PENDING',
    // New fields for Future Cars / Trip assignment
    load_category: loadData.load_category || null,
    load_subcategory: loadData.load_subcategory || null,
    trip_id: loadData.trip_id || null,
    vehicle_direction: loadData.vehicle_direction || null
  };

  // Clean up null/empty values
  Object.keys(orderData).forEach(key => {
    if (orderData[key] === '' || orderData[key] === null) {
      delete orderData[key];
    }
  });

  // Keep required fields
  if (!orderData.order_number) {
    orderData.order_number = `CD-${Date.now()}`;
  }

  log('Order data to insert:', orderData);

  // Make Supabase API call
  const response = await fetch(`${config.url}/rest/v1/orders`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': config.key,
      'Authorization': `Bearer ${config.key}`,
      'Prefer': 'return=representation'
    },
    body: JSON.stringify(orderData)
  });

  if (!response.ok) {
    const errorText = await response.text();
    log('Supabase error:', response.status, errorText);
    throw new Error(`Failed to import: ${response.status} - ${errorText}`);
  }

  const result = await response.json();
  log('Import successful:', result);

  return {
    success: true,
    order: result[0] || result,
    message: 'Load imported successfully!'
  };
}

// Test Supabase connection
async function testSupabaseConnection() {
  const config = await getSupabaseConfig();

  if (!config.key) {
    throw new Error('API key not configured');
  }

  const response = await fetch(`${config.url}/rest/v1/orders?select=id&limit=1`, {
    headers: {
      'apikey': config.key,
      'Authorization': `Bearer ${config.key}`
    }
  });

  if (!response.ok) {
    throw new Error(`Connection failed: ${response.status}`);
  }

  return { success: true, message: 'Connected to TMS!' };
}

// On install, open options page
chrome.runtime.onInstalled.addListener((details) => {
  if (details.reason === 'install') {
    log('Extension installed');
    // Could open options page here
  }
});

log('Background service worker v5 started');
