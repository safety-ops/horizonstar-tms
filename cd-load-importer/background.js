// CD Load Importer - Background Service Worker v7
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
    return true;
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

  if (request.action === 'getRecentImports') {
    chrome.storage.local.get(['recentImports'], (result) => {
      sendResponse({ success: true, imports: result.recentImports || [] });
    });
    return true;
  }

  if (request.action === 'getDispatchers') {
    handleGetDispatchers()
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

  // Exclude completed/cancelled — catches all active statuses (PLANNED, IN_PROGRESS, DISPATCHED, IN_TRANSIT, AT_TERMINAL, etc.)
  const statusFilter = 'status=not.in.(COMPLETED,CANCELLED)';
  const headers = {
    'apikey': config.key,
    'Authorization': `Bearer ${config.key}`
  };

  // Fetch trips (simple query, no joins — most reliable)
  const response = await fetch(
    `${config.url}/rest/v1/trips?${statusFilter}&select=id,trip_number,status,driver_id&order=trip_date.desc`,
    { headers }
  );

  if (!response.ok) {
    const errorText = await response.text();
    log('Trips fetch error:', response.status, errorText);
    throw new Error(`Failed to fetch trips: ${response.status} - ${errorText}`);
  }

  const trips = await response.json();
  log('Fetched trips:', trips.length);

  // Fetch drivers separately to resolve names (first_name + last_name)
  let driverLookup = {};
  try {
    const driversResp = await fetch(
      `${config.url}/rest/v1/drivers?select=id,first_name,last_name`,
      { headers }
    );
    if (driversResp.ok) {
      const drivers = await driversResp.json();
      driverLookup = Object.fromEntries(
        drivers.map(d => [d.id, ((d.first_name || '') + ' ' + (d.last_name || '')).trim()])
      );
    }
  } catch (e) {
    log('Driver lookup failed (non-critical):', e.message);
  }

  // Format trips for dropdown
  const formattedTrips = trips.map(t => ({
    id: t.id,
    trip_number: t.trip_number,
    status: t.status,
    driver_name: driverLookup[t.driver_id] || null
  }));

  return {
    success: true,
    trips: formattedTrips
  };
}

// Get dispatchers from Supabase
async function handleGetDispatchers() {
  const config = await getSupabaseConfig();
  if (!config.key) throw new Error('API key not configured');

  const response = await fetch(
    `${config.url}/rest/v1/dispatchers?select=id,name,code,email,user_id&order=name.asc`,
    { headers: { 'apikey': config.key, 'Authorization': `Bearer ${config.key}` } }
  );

  if (!response.ok) {
    const errorText = await response.text();
    log('Dispatchers fetch error:', response.status, errorText);
    throw new Error(`Failed to fetch dispatchers: ${response.status}`);
  }

  const dispatchers = await response.json();
  log('Fetched dispatchers:', dispatchers.length);
  return { success: true, dispatchers };
}

// Resolve broker name to broker_id, creating if needed
async function resolveOrCreateBroker(brokerName, brokerDetails, config) {
  if (!brokerName) return { brokerId: null, brokerName: null };

  const headers = { 'apikey': config.key, 'Authorization': `Bearer ${config.key}` };
  const trimmedName = brokerName.trim();

  // Helper: enrich existing broker with missing fields
  async function enrichBroker(existing) {
    const patchData = {};
    if (!existing.contact_name && brokerDetails.contact_name) patchData.contact_name = brokerDetails.contact_name;
    if (!existing.phone && brokerDetails.phone) patchData.phone = brokerDetails.phone;
    if (!existing.email && brokerDetails.email) patchData.email = brokerDetails.email;
    if (Object.keys(patchData).length > 0) {
      log('Enriching broker with missing fields:', patchData);
      await fetch(`${config.url}/rest/v1/brokers?id=eq.${existing.id}`, {
        method: 'PATCH',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify(patchData)
      });
    }
    return { brokerId: existing.id, brokerName: existing.name };
  }

  try {
    // 1. Exact name match (case-insensitive)
    const exactUrl = `${config.url}/rest/v1/brokers?name=ilike.${encodeURIComponent(trimmedName)}&select=id,name,contact_name,phone,email&limit=1`;
    const exactResp = await fetch(exactUrl, { headers });
    if (exactResp.ok) {
      const brokers = await exactResp.json();
      if (brokers.length > 0) {
        log('Found existing broker (exact match):', brokers[0].id, brokers[0].name);
        return await enrichBroker(brokers[0]);
      }
    }

    // 2. Match by email (more reliable than name)
    if (brokerDetails.email) {
      const emailUrl = `${config.url}/rest/v1/brokers?email=ilike.${encodeURIComponent(brokerDetails.email.trim())}&select=id,name,contact_name,phone,email&limit=1`;
      const emailResp = await fetch(emailUrl, { headers });
      if (emailResp.ok) {
        const brokers = await emailResp.json();
        if (brokers.length > 0) {
          log('Found existing broker (email match):', brokers[0].id, brokers[0].name);
          return await enrichBroker(brokers[0]);
        }
      }
    }

    // 3. Fuzzy name match (contains, case-insensitive) — catches "LLC" vs "L.L.C." etc
    const coreName = trimmedName.replace(/[.,\s]+(LLC|INC|CORP|LTD|CO)\.?$/i, '').trim();
    if (coreName.length >= 4) {
      const fuzzyUrl = `${config.url}/rest/v1/brokers?name=ilike.*${encodeURIComponent(coreName)}*&select=id,name,contact_name,phone,email&limit=1`;
      const fuzzyResp = await fetch(fuzzyUrl, { headers });
      if (fuzzyResp.ok) {
        const brokers = await fuzzyResp.json();
        if (brokers.length > 0) {
          log('Found existing broker (fuzzy match):', brokers[0].id, brokers[0].name);
          return await enrichBroker(brokers[0]);
        }
      }
    }

    // 4. No match found — create new broker
    const createBody = { name: trimmedName };
    if (brokerDetails.contact_name) createBody.contact_name = brokerDetails.contact_name;
    if (brokerDetails.phone) createBody.phone = brokerDetails.phone;
    if (brokerDetails.email) createBody.email = brokerDetails.email;

    const createResponse = await fetch(`${config.url}/rest/v1/brokers`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': config.key,
        'Authorization': `Bearer ${config.key}`,
        'Prefer': 'return=representation'
      },
      body: JSON.stringify(createBody)
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

  // Build broker details for enrichment
  const brokerDetails = {
    contact_name: loadData.broker_contact_name || null,
    phone: loadData.broker_phone || null,
    email: loadData.broker_email || null
  };

  // Resolve broker name to broker_id
  let brokerId = null;
  let resolvedBrokerName = loadData.broker_name || null;
  if (resolvedBrokerName) {
    const brokerResult = await resolveOrCreateBroker(resolvedBrokerName, brokerDetails, config);
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
    broker_fee: loadData.broker_fee || null,
    local_fee: loadData.local_fee || null,
    payment_type: loadData.payment_type || null,
    payment_terms: loadData.payment_terms || null,
    vehicle_year: loadData.vehicle_year || null,
    vehicle_make: loadData.vehicle_make || null,
    vehicle_model: loadData.vehicle_model || null,
    vehicle_vin: loadData.vehicle_vin || null,
    vehicle_color: loadData.vehicle_color || null,
    vehicle_body_type: loadData.vehicle_body_type || null,
    vehicle_lot_number: loadData.vehicle_lot_number || null,
    vehicle_buyer_number: loadData.vehicle_buyer_number || null,
    vehicles: loadData.vehicles && loadData.vehicles.length > 0 ? loadData.vehicles : [],
    origin: loadData.origin || null,
    pickup_full_address: loadData.pickup_full_address || null,
    pickup_address: loadData.pickup_address || null,
    pickup_city: loadData.pickup_city || null,
    pickup_state: loadData.pickup_state || null,
    pickup_zip: loadData.pickup_zip || null,
    pickup_phone: loadData.pickup_phone || null,
    pickup_contact_name: loadData.pickup_contact_name || null,
    pickup_contact_phone: loadData.pickup_contact_phone || loadData.pickup_phone || null,
    pickup_date: loadData.pickup_date || null,
    destination: loadData.destination || null,
    delivery_full_address: loadData.delivery_full_address || null,
    delivery_address: loadData.delivery_address || null,
    delivery_city: loadData.delivery_city || null,
    delivery_state: loadData.delivery_state || null,
    delivery_zip: loadData.delivery_zip || null,
    delivery_phone: loadData.delivery_phone || null,
    delivery_contact_name: loadData.delivery_contact_name || null,
    delivery_contact_phone: loadData.delivery_contact_phone || loadData.delivery_phone || null,
    dropoff_date: loadData.dropoff_date || null,
    notes: loadData.notes || null,
    dispatcher_notes: loadData.dispatcher_notes || 'Imported from Central Dispatch',
    dispatcher_id: config.dispatcherId || null,
    delivery_status: 'pending',
    // Fields for Future Cars / Trip assignment
    load_category: loadData.load_category || null,
    load_subcategory: loadData.load_subcategory || null,
    trip_id: loadData.trip_id || null,
    vehicle_direction: loadData.vehicle_direction || null,
    // SPLIT payment fields
    cod_amount: loadData.cod_amount || null,
    bill_amount: loadData.bill_amount || null
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

  // Save to recent imports history (keep last 20)
  try {
    const stored = await chrome.storage.local.get(['recentImports']);
    const history = stored.recentImports || [];
    history.unshift({
      order_number: orderData.order_number,
      broker_name: resolvedBrokerName || '',
      revenue: orderData.revenue || 0,
      origin: orderData.origin || '',
      destination: orderData.destination || '',
      timestamp: new Date().toISOString()
    });
    if (history.length > 20) history.length = 20;
    await chrome.storage.local.set({ recentImports: history });
  } catch (e) {
    log('Failed to save import history:', e.message);
  }

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

log('Background service worker v7 started');
