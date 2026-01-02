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
  if (!skipConflictCheck && ['trips', 'orders', 'drivers', 'trucks'].includes(table)) {
    const originalTimestamp = getEditingTimestamp(table, id);
    if (originalTimestamp) {
      // Fetch current record to check if it was modified
      const { data: current } = await sb.from(table).select('updated_at').eq('id', id).single();
      if (current && current.updated_at && current.updated_at !== originalTimestamp) {
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
    }
  }

  const { data: result, error } = await sb
    .from(table)
    .update(data)
    .eq('id', id)
    .select();

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
  if (payload.eventType === 'INSERT' && currentPage === 'team_chat') {
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
    await dbInsert('activity_log', {
      user_id: currentUser?.id || null,
      user_email: currentUser?.email || details.email || 'unknown',
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
      ticket_files: [], violation_files: [], claim_files: [], compliance_tasks: [], accidents: []
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
      accidents: accidents
    });

    // Update cache
    dataCache.set('appData', appData);

    // Load Samsara settings from database (shared across all users)
    if (typeof loadSamsaraSettings === 'function') {
      await loadSamsaraSettings();
    }

    // Only re-render if we're NOT viewing a detail page (trip/driver/truck detail)
    // This prevents getting kicked out of detail views when secondary data loads
    if (!currentDetailView && typeof renderPage === 'function') {
      renderPage();
    }
  } catch (e) {
    console.error('Failed to load secondary data:', e);
  }
}
