// CD Load Importer - Background Service Worker v6
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
  const result = await chrome.storage.sync.get(['supabaseUrl', 'supabaseKey', 'dispatcherId']);
  return {
    url: result.supabaseUrl || DEFAULT_SUPABASE_URL,
    key: result.supabaseKey || '',
    dispatcherId: result.dispatcherId ? parseInt(result.dispatcherId, 10) : null
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

// Resolve broker name to broker_id, creating if needed
async function resolveOrCreateBroker(brokerName, config) {
  if (!brokerName) return { brokerId: null, brokerName: null };

  try {
    // Look up existing broker by name (case-insensitive)
    const lookupUrl = `${config.url}/rest/v1/brokers?name=ilike.${encodeURIComponent(brokerName)}&select=id,name&limit=1`;
    const lookupResponse = await fetch(lookupUrl, {
      headers: {
        'apikey': config.key,
        'Authorization': `Bearer ${config.key}`
      }
    });

    if (lookupResponse.ok) {
      const brokers = await lookupResponse.json();
      if (brokers.length > 0) {
        log('Found existing broker:', brokers[0].id, brokers[0].name);
        return { brokerId: brokers[0].id, brokerName: brokers[0].name };
      }
    }

    // Create new broker
    const createResponse = await fetch(`${config.url}/rest/v1/brokers`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': config.key,
        'Authorization': `Bearer ${config.key}`,
        'Prefer': 'return=representation'
      },
      body: JSON.stringify({ name: brokerName })
    });

    if (createResponse.ok) {
      const created = await createResponse.json();
      const broker = created[0] || created;
      log('Created new broker:', broker.id, broker.name);
      return { brokerId: broker.id, brokerName: broker.name };
    }

    log('Broker create failed, continuing with name only');
  } catch (e) {
    log('Broker resolution error:', e.message);
  }

  return { brokerId: null, brokerName: brokerName };
}

// Import load to Supabase
async function handleImportLoad(loadData) {
  log('Importing load:', loadData);

  const config = await getSupabaseConfig();

  if (!config.key) {
    throw new Error('Supabase API key not configured. Please open extension settings.');
  }

  // Resolve broker name to broker_id
  let brokerId = null;
  let resolvedBrokerName = loadData.broker_name || null;
  if (resolvedBrokerName) {
    const brokerResult = await resolveOrCreateBroker(resolvedBrokerName, config);
    brokerId = brokerResult.brokerId;
    resolvedBrokerName = brokerResult.brokerName || resolvedBrokerName;
  }

  // Prepare order data for Supabase
  const orderData = {
    order_number: loadData.order_number || `CD-${Date.now()}`,
    status: 'PENDING',
    broker_id: brokerId,
    broker_name: resolvedBrokerName,
    revenue: loadData.revenue || null,
    payment_type: loadData.payment_type || null,
    payment_terms: loadData.payment_terms || null,
    vehicle_year: loadData.vehicle_year || null,
    vehicle_make: loadData.vehicle_make || null,
    vehicle_model: loadData.vehicle_model || null,
    vehicle_vin: loadData.vehicle_vin || null,
    vehicle_color: loadData.vehicle_color || null,
    origin: loadData.origin || null,
    pickup_full_address: loadData.pickup_full_address || null,
    pickup_city: loadData.pickup_city || null,
    pickup_state: loadData.pickup_state || null,
    pickup_zip: loadData.pickup_zip || null,
    pickup_phone: loadData.pickup_phone || null,
    pickup_contact_name: loadData.pickup_contact_name || null,
    pickup_contact_phone: loadData.pickup_phone || null,
    pickup_date: loadData.pickup_date || null,
    destination: loadData.destination || null,
    delivery_full_address: loadData.delivery_full_address || null,
    delivery_city: loadData.delivery_city || null,
    delivery_state: loadData.delivery_state || null,
    delivery_zip: loadData.delivery_zip || null,
    delivery_phone: loadData.delivery_phone || null,
    delivery_contact_name: loadData.delivery_contact_name || null,
    delivery_contact_phone: loadData.delivery_phone || null,
    dropoff_date: loadData.dropoff_date || null,
    dispatcher_notes: loadData.dispatcher_notes || 'Imported from Central Dispatch',
    dispatcher_id: config.dispatcherId || null,
    delivery_status: 'pending',
    // Fields for Future Cars / Trip assignment
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

  // Pre-check for duplicate order number
  if (orderData.order_number) {
    const checkUrl = `${config.url}/rest/v1/orders?order_number=eq.${encodeURIComponent(orderData.order_number)}&select=id&limit=1`;
    const checkResponse = await fetch(checkUrl, {
      headers: {
        'apikey': config.key,
        'Authorization': `Bearer ${config.key}`
      }
    });
    if (checkResponse.ok) {
      const existing = await checkResponse.json();
      if (existing.length > 0) {
        throw new Error('This load has already been imported to TMS (Order #' + orderData.order_number + ')');
      }
    }
  }

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
  }
});

log('Background service worker v6 started');
