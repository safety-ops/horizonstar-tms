/* ============================================================
   HORIZON STAR TMS - API / Database Functions
   Supabase CRUD operations, real-time sync, and data loading
   ============================================================ */

// ============ CORE DATABASE FUNCTIONS ============

/**
 * Fetch data from a Supabase table with optional filters
 * @param {string} table - Table name
 * @param {Object} options - Query options (select, filter, order)
 * @returns {Promise<Array>} Data array
 */
async function dbFetch(table, options = {}) {
  let query = sb.from(table).select(options.select || '*');

  if (options.filter) {
    Object.entries(options.filter).forEach(([key, value]) => {
      // Parse filter like "email=eq.test@example.com"
      if (value.startsWith('eq.')) {
        query = query.eq(key, value.substring(3));
      } else if (value.startsWith('neq.')) {
        query = query.neq(key, value.substring(4));
      } else if (value.startsWith('gt.')) {
        query = query.gt(key, value.substring(3));
      } else if (value.startsWith('gte.')) {
        query = query.gte(key, value.substring(4));
      } else if (value.startsWith('lt.')) {
        query = query.lt(key, value.substring(3));
      } else if (value.startsWith('lte.')) {
        query = query.lte(key, value.substring(4));
      } else if (value.startsWith('like.')) {
        query = query.like(key, value.substring(5));
      } else if (value.startsWith('ilike.')) {
        query = query.ilike(key, value.substring(6));
      } else if (value.startsWith('in.(')) {
        // Parse in.(val1,val2,val3) format
        const values = value.substring(4, value.length - 1).split(',').map(v => v.trim());
        query = query.in(key, values);
      } else {
        query = query.eq(key, value);
      }
    });
  }

  if (options.order) {
    const [column, direction] = options.order.split('.');
    query = query.order(column, { ascending: direction !== 'desc' });
  }

  const { data, error } = await query;
  if (error) throw error;
  return data || [];
}

/**
 * Insert data into a Supabase table
 * @param {string} table - Table name
 * @param {Object} data - Data to insert
 * @returns {Promise<Object>} Inserted record
 */
async function dbInsert(table, data) {
  const { data: result, error } = await sb
    .from(table)
    .insert(data)
    .select()
    .single();

  if (error) throw new Error(error.message || 'Insert failed');

  // Track that we just made a change (for realtime sync)
  window.lastSaveTimestamp = Date.now();

  // Invalidate cache so next load gets fresh data
  dataCache.invalidate('appData');

  return result;
}

// Store original updated_at when opening edit modals (for conflict detection)
let editingRecords = {};

function startEditing(table, id, updatedAt) {
  editingRecords[table + '_' + id] = updatedAt || new Date().toISOString();
}

function getEditingTimestamp(table, id) {
  return editingRecords[table + '_' + id];
}

function clearEditing(table, id) {
  delete editingRecords[table + '_' + id];
}

/**
 * Update data in a Supabase table
 * @param {string} table - Table name
 * @param {string|number} id - Record ID
 * @param {Object} data - Data to update
 * @param {boolean} skipConflictCheck - Skip conflict detection
 * @returns {Promise<Object|null>} Updated record or null if cancelled
 */
async function dbUpdate(table, id, data, skipConflictCheck = false) {
  // Check for conflicts on important tables
  if (!skipConflictCheck && ['trips', 'orders', 'drivers', 'trucks', 'expenses', 'brokers', 'maintenance_records', 'fuel_transactions'].includes(table)) {
    const originalTimestamp = getEditingTimestamp(table, id);
    if (originalTimestamp) {
      // Fetch current record to check if it was modified
      try {
        const { data: current, error } = await sb.from(table).select('updated_at').eq('id', id).single();
        // Only check conflict if we successfully got data with updated_at column
        if (!error && current && current.updated_at && current.updated_at !== originalTimestamp) {
          const confirmOverwrite = confirm(
            '⚠️ This record was modified by another user while you were editing.\n\n' +
            'Click OK to save your changes anyway (will overwrite their changes)\n' +
            'Click Cancel to refresh and see the latest version'
          );
          if (!confirmOverwrite) {
            await loadAllData(true); // Force refresh
            showToast('Data refreshed - please review and try again', 'info');
            return null; // Signal that save was cancelled
          }
        }
      } catch (e) {
        // If conflict check fails (e.g., updated_at column doesn't exist), skip it
        console.warn('Conflict check skipped:', e.message);
      }
    }
  }

  const { data: result, error } = await sb
    .from(table)
    .update(data)
    .eq('id', id)
    .select()
    .single();

  if (error) throw new Error(error.message || 'Update failed');

  // Track that we just made a change (for realtime sync)
  window.lastSaveTimestamp = Date.now();

  // Clear editing tracker
  clearEditing(table, id);

  // Invalidate cache so next load gets fresh data
  dataCache.invalidate('appData');

  return result;
}

/**
 * Delete data from a Supabase table
 * @param {string} table - Table name
 * @param {string|number} id - Record ID
 */
async function dbDelete(table, id) {
  const { error } = await sb
    .from(table)
    .delete()
    .eq('id', id);

  if (error) throw new Error(error.message || 'Delete failed');

  // Track that we just made a change (for realtime sync)
  window.lastSaveTimestamp = Date.now();

  // Invalidate cache so next load gets fresh data
  dataCache.invalidate('appData');
}

// ============ REAL-TIME COLLABORATION ============
let realtimeChannel = null;

function startRealtimeSync() {
  if (!sb || realtimeChannel) return;

  // Subscribe to changes on key tables
  realtimeChannel = sb
    .channel('tms-realtime')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'trips' }, handleRealtimeChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, handleRealtimeChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'drivers' }, handleRealtimeChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'trucks' }, handleRealtimeChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'expenses' }, handleRealtimeChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'tasks' }, handleRealtimeChange)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'chat_messages' }, handleChatRealtimeChange)
    .subscribe((status) => {
      if (status === 'SUBSCRIBED') {
        console.log('✅ Real-time sync active');
      }
    });
}

// Debounce realtime updates to avoid too many refreshes
let realtimeDebounceTimer = null;
let pendingRealtimeUpdate = false;

function handleRealtimeChange(payload) {
  // Don't refresh if we just made the change ourselves (within last 2 seconds)
  const timeSinceLastSave = Date.now() - (window.lastSaveTimestamp || 0);
  if (timeSinceLastSave < 2000) {
    return; // Skip - this is likely our own change
  }

  // Debounce multiple rapid changes
  pendingRealtimeUpdate = true;
  if (realtimeDebounceTimer) clearTimeout(realtimeDebounceTimer);

  realtimeDebounceTimer = setTimeout(async () => {
    if (!pendingRealtimeUpdate) return;
    pendingRealtimeUpdate = false;

    // Show notification
    const table = payload.table;
    const action = payload.eventType;
    const tableNames = { trips: 'Trip', orders: 'Vehicle', drivers: 'Driver', trucks: 'Truck', expenses: 'Expense' };
    const actionNames = { INSERT: 'added', UPDATE: 'updated', DELETE: 'deleted' };

    showToast('🔄 ' + (tableNames[table] || table) + ' ' + (actionNames[action] || 'changed') + ' by another user', 'info');

    // Refresh data
    await loadAllData(true);
    if (typeof renderPage === 'function') renderPage();
  }, 1000); // Wait 1 second for any additional changes
}

function handleChatRealtimeChange(payload) {
  // For chat, just trigger a re-render of chat if we're on that page
  if (['INSERT', 'UPDATE', 'DELETE'].includes(payload.eventType) && currentPage === 'team_chat') {
    const timeSinceLastSave = Date.now() - (window.lastSaveTimestamp || 0);
    if (timeSinceLastSave < 2000) return;

    // Reload chat messages
    loadAllData(true).then(() => {
      const main = document.getElementById('main-content');
      if (main && currentPage === 'team_chat' && typeof renderTeamChat === 'function') {
        renderTeamChat(main);
      }
    });
  }
}

function stopRealtimeSync() {
  if (realtimeChannel) {
    sb.removeChannel(realtimeChannel);
    realtimeChannel = null;
    console.log('Real-time sync stopped');
  }
}

// ============ ACTIVITY LOGGING ============

/**
 * Log an activity to the activity_log table
 * @param {string} action - Action name
 * @param {Object} details - Additional details
 */
async function logActivity(action, details = {}) {
  try {
    // Get user's full name for display in activity log
    const userName = currentUser ? (currentUser.first_name + ' ' + currentUser.last_name).trim() : null;

    await dbInsert('activity_log', {
      user_id: currentUser?.id || null,
      user_email: currentUser?.email || details.email || 'unknown',
      user_name: userName || details.user_name || 'System',
      action: action,
      details: JSON.stringify(details),
      ip_address: 'client', // Can't get real IP from client
      created_at: new Date().toISOString()
    });
  } catch (e) {
    // Activity log table may not exist, fail silently
    console.log('Activity log:', action, details);
  }
}

// ============ DATA LOADING ============

// Track if we're viewing a detail (trip, driver, truck, etc.)
let currentDetailView = null; // { type: 'trip', id: 123 } or null

/**
 * Load all data from the database
 * @param {boolean} forceReload - Force refresh even if cached
 */
async function loadAllData(forceReload = false) {
  try {
    // Check cache first (unless forced reload)
    if (!forceReload && dataCache.get('appData')) {
      appData = dataCache.get('appData');
      return;
    }

    // Load essential data first (what dashboard needs - including tasks)
    const [users, trucks, drivers, dispatchers, trips, orders, brokers, tasks] = await Promise.all([
      dbFetch('users'),
      dbFetch('trucks', { order: 'truck_number' }),
      dbFetch('drivers'),
      dbFetch('dispatchers'),
      dbFetch('trips', { order: 'trip_date.desc' }),
      dbFetch('orders', { order: 'id.desc' }),
      dbFetch('brokers', { order: 'name' }),
      dbFetch('tasks', { order: 'due_date.asc' })
    ]);

    // Set initial data
    appData = {
      users, trucks, drivers, dispatchers, trips, orders, brokers: brokers || [],
      tasks: tasks || [],
      local_drivers: [], expenses: [], fixed_costs: [], variable_costs: [],
      driver_files: [], truck_files: [], fuel_transactions: [],
      maintenance_records: [], claims: [], tickets: [], violations: [],
      ticket_files: [], violation_files: [], claim_files: [], compliance_tasks: [], accidents: [],
      company_files: []
    };

    // Load secondary data in background (non-blocking)
    loadSecondaryData();

    // Cache the data
    dataCache.set('appData', appData);
  } catch (e) {
    console.error('Failed to load data:', e);
    showToast('Failed to load data', 'error');
  }
}

/**
 * Load secondary/less critical data in the background
 */
async function loadSecondaryData() {
  try {
    const [local_drivers, expenses, fixed_costs, variable_costs, driver_files, truck_files, fuel_transactions, maintenance_records] = await Promise.all([
      dbFetch('local_drivers', { order: 'name' }),
      dbFetch('expenses'),
      dbFetch('fixed_costs', { order: 'name' }),
      dbFetch('variable_costs', { order: 'date.desc' }),
      dbFetch('driver_files', { order: 'id.desc' }),
      dbFetch('truck_files', { order: 'id.desc' }),
      dbFetch('fuel_transactions', { order: 'transaction_date.desc' }),
      dbFetch('maintenance_records', { order: 'service_date.desc' })
    ]);

    // Try to load claims separately (table may not exist yet)
    let claims = [];
    try { claims = await dbFetch('claims', { order: 'incident_date.desc' }) || []; } catch(e) { claims = []; }

    // Try to load tickets separately (table may not exist yet)
    let tickets = [];
    try { tickets = await dbFetch('tickets', { order: 'ticket_date.desc' }) || []; } catch(e) { tickets = []; }

    // Try to load violations separately (table may not exist yet)
    let violations = [];
    try { violations = await dbFetch('violations', { order: 'violation_date.desc' }) || []; } catch(e) { violations = []; }

    // Try to load ticket/violation/claim files
    let ticket_files = [];
    try { ticket_files = await dbFetch('ticket_files') || []; } catch(e) { ticket_files = []; }
    let violation_files = [];
    try { violation_files = await dbFetch('violation_files') || []; } catch(e) { violation_files = []; }
    let claim_files = [];
    try { claim_files = await dbFetch('claim_files') || []; } catch(e) { claim_files = []; }

    // Try to load compliance tasks
    let compliance_tasks = [];
    try { compliance_tasks = await dbFetch('compliance_tasks', { order: 'next_due_date.asc' }) || []; } catch(e) { compliance_tasks = []; }

    // Try to load accidents
    let accidents = [];
    try { accidents = await dbFetch('accidents', { order: 'accident_date.desc' }) || []; } catch(e) { accidents = []; }

    // Try to load company files
    let company_files = [];
    try { company_files = await dbFetch('company_files', { order: 'id.desc' }) || []; } catch(e) { console.error('Failed to load company_files:', e); company_files = []; }

    // Update appData with secondary data
    Object.assign(appData, {
      local_drivers: local_drivers || [],
      expenses: expenses || [],
      fixed_costs: fixed_costs || [],
      variable_costs: variable_costs || [],
      driver_files: driver_files || [],
      truck_files: truck_files || [],
      fuel_transactions: fuel_transactions || [],
      maintenance_records: maintenance_records || [],
      claims: claims,
      tickets: tickets,
      violations: violations,
      ticket_files: ticket_files,
      violation_files: violation_files,
      claim_files: claim_files,
      compliance_tasks: compliance_tasks,
      accidents: accidents,
      company_files: company_files
    });

    // Update cache
    dataCache.set('appData', appData);

    // Load Samsara settings from database (shared across all users)
    if (typeof loadSamsaraSettings === 'function') {
      await loadSamsaraSettings();
    }

    // Try to load dealers
    let dealers = [];
    try { dealers = await dbFetch('dealers', { order: 'company_name' }) || []; } catch(e) { dealers = []; }

    // Update appData with dealers
    appData.dealers = dealers;

    // Update cache
    dataCache.set('appData', appData);

    // Only re-render if we're NOT viewing a detail page (trip/driver/truck detail)
    // This prevents getting kicked out of detail views when secondary data loads
    if (!currentDetailView && typeof renderPage === 'function') {
      renderPage();
    }
  } catch (e) {
    console.error('Failed to load secondary data:', e);
  }
}

// ============ DEALER PORTAL FUNCTIONS ============

/**
 * Load dealer profile for current user
 * @returns {Promise<Object|null>} Dealer profile or null
 */
async function loadDealerProfile() {
  if (!currentUser || currentUser.role !== 'DEALER') return null;

  try {
    const dealers = await dbFetch('dealers', {
      filter: { user_id: 'eq.' + currentUser.id }
    });
    currentDealerProfile = dealers[0] || null;
    return currentDealerProfile;
  } catch (e) {
    console.error('Failed to load dealer profile:', e);
    return null;
  }
}

/**
 * Load orders for a specific dealer
 * @param {number} dealerId - Dealer ID
 * @param {Object} filters - Optional filters (status, dateRange)
 * @returns {Promise<Array>} Dealer's orders
 */
async function loadDealerOrders(dealerId, filters = {}) {
  try {
    let filterObj = { dealer_id: 'eq.' + dealerId };

    if (filters.status && filters.status !== 'all') {
      filterObj.delivery_status = 'eq.' + filters.status;
    }

    const orders = await dbFetch('orders', {
      filter: filterObj,
      order: 'created_at.desc'
    });

    return orders || [];
  } catch (e) {
    console.error('Failed to load dealer orders:', e);
    return [];
  }
}

/**
 * Calculate dealer spending/financial summary
 * @param {number} dealerId - Dealer ID
 * @param {Object} dateRange - Optional date range { start, end }
 * @returns {Promise<Object>} Spending summary
 */
async function getDealerSpending(dealerId, dateRange = {}) {
  try {
    const orders = await loadDealerOrders(dealerId);

    // Filter by date range if provided
    let filteredOrders = orders;
    if (dateRange.start) {
      filteredOrders = filteredOrders.filter(o =>
        new Date(o.created_at) >= new Date(dateRange.start)
      );
    }
    if (dateRange.end) {
      filteredOrders = filteredOrders.filter(o =>
        new Date(o.created_at) <= new Date(dateRange.end)
      );
    }

    // Calculate totals
    const totalSpent = filteredOrders.reduce((sum, o) => sum + (parseFloat(o.revenue) || 0), 0);
    const totalVehicles = filteredOrders.length;
    const avgCostPerVehicle = totalVehicles > 0 ? totalSpent / totalVehicles : 0;

    // Count by status
    const pending = filteredOrders.filter(o => o.delivery_status === 'pending').length;
    const pickedUp = filteredOrders.filter(o => o.delivery_status === 'picked_up').length;
    const inTransit = filteredOrders.filter(o => o.delivery_status === 'in_transit').length;
    const delivered = filteredOrders.filter(o => o.delivery_status === 'delivered').length;

    return {
      totalSpent,
      totalVehicles,
      avgCostPerVehicle,
      pending,
      pickedUp,
      inTransit,
      delivered,
      orders: filteredOrders
    };
  } catch (e) {
    console.error('Failed to get dealer spending:', e);
    return {
      totalSpent: 0,
      totalVehicles: 0,
      avgCostPerVehicle: 0,
      pending: 0,
      pickedUp: 0,
      inTransit: 0,
      delivered: 0,
      orders: []
    };
  }
}

/**
 * Submit a vehicle order from dealer portal
 * @param {Object} orderData - Vehicle/order data
 * @returns {Promise<Object>} Created order
 */
async function submitDealerOrder(orderData) {
  if (!currentDealerProfile) {
    await loadDealerProfile();
  }

  if (!currentDealerProfile) {
    throw new Error('Dealer profile not found. Please contact support.');
  }

  // Generate order number with dealer prefix
  const orderNumber = 'DLR-' + currentDealerProfile.dealer_code + '-' + Date.now().toString().slice(-6);

  const order = await dbInsert('orders', {
    order_number: orderNumber,
    dealer_id: currentDealerProfile.id,
    vehicle_year: orderData.vehicle_year,
    vehicle_make: orderData.vehicle_make,
    vehicle_model: orderData.vehicle_model,
    vehicle_vin: orderData.vehicle_vin,
    vehicle_color: orderData.vehicle_color,
    origin: orderData.pickup_location,
    destination: orderData.delivery_location,
    pickup_date: orderData.pickup_date,
    dropoff_date: orderData.delivery_date,
    delivery_status: 'pending',
    status: 'PENDING',
    dispatcher_notes: orderData.notes || ''
  });

  // Log activity
  await logActivity('DEALER_ORDER_SUBMITTED', {
    dealer_id: currentDealerProfile.id,
    dealer_name: currentDealerProfile.company_name,
    order_id: order.id,
    order_number: orderNumber
  });

  return order;
}

/**
 * Generate a unique dealer code
 * @param {string} companyName - Company name to base code on
 * @returns {string} Unique dealer code
 */
function generateDealerCode(companyName) {
  // Take first 3 letters of company name + random 3 digits
  const prefix = (companyName || 'DLR').substring(0, 3).toUpperCase().replace(/[^A-Z]/g, 'X');
  const suffix = Math.floor(100 + Math.random() * 900);
  return prefix + suffix;
}
