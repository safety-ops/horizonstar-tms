/* ============================================================
   HORIZON STAR TMS - Configuration
   Supabase setup, API keys, and global constants
   ============================================================ */

// Supabase Configuration
const SUPABASE_URL = 'https://yrrczhlzulwvdqjwvhtu.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlycmN6aGx6dWx3dmRxand2aHR1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU1NDYyOTQsImV4cCI6MjA4MTEyMjI5NH0.qVVxDH36OkLXnUe3Sfng1CJY7_Qt_IOGC-1QaDw6WlE';

// Initialize Supabase client (sb is global)
let sb;
function initSupabase() {
  if (!sb && window.supabase) {
    sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
  }
  return sb;
}

// Current auth session
let authSession = null;

// Get current access token for API calls
function getAccessToken() {
  return authSession?.access_token || SUPABASE_KEY;
}

// ============ GLOBAL STATE ============
// Current logged-in user
let currentUser = JSON.parse(localStorage.getItem('horizonstar_user') || 'null');

// Current page/route
let currentPage = 'dashboard';

// Current language
let currentLang = 'en';

// Central data store
let appData = {
  users: [],
  trucks: [],
  drivers: [],
  local_drivers: [],
  dispatchers: [],
  trips: [],
  orders: [],
  expenses: [],
  fixed_costs: [],
  variable_costs: [],
  driver_files: [],
  truck_files: [],
  brokers: [],
  fuel_transactions: [],
  maintenance_records: [],
  claims: [],
  tickets: [],
  violations: [],
  ticket_files: [],
  violation_files: [],
  claim_files: [],
  compliance_tasks: [],
  accidents: [],
  company_files: [],
  tasks: [],
  dealers: []
};

// Current dealer profile (for dealer portal)
let currentDealerProfile = null;

// ============ SESSION CONFIGURATION ============
const LOGIN_ATTEMPT_LIMIT = 5;
const LOGIN_LOCKOUT_MINUTES = 15;
const SESSION_TIMEOUT_MINUTES = 60; // 1 hour

// ============ PAGINATION DEFAULT STATE ============
const pagination = {
  trips: { page: 1, perPage: 50, total: 0 },
  orders: { page: 1, perPage: 50, total: 0 },
  maintenance: { page: 1, perPage: 50, total: 0 },
  expenses: { page: 1, perPage: 50, total: 0 },
  activity_log: { page: 1, perPage: 100, total: 0 }
};

// ============ DATA CACHE ============
const dataCache = {
  data: {},
  timestamps: {},
  maxAge: 5 * 60 * 1000, // 5 minutes cache

  set(key, value) {
    this.data[key] = value;
    this.timestamps[key] = Date.now();
  },

  get(key) {
    if (!this.data[key]) return null;
    if (Date.now() - this.timestamps[key] > this.maxAge) {
      delete this.data[key];
      delete this.timestamps[key];
      return null;
    }
    return this.data[key];
  },

  invalidate(key) {
    if (key) {
      delete this.data[key];
      delete this.timestamps[key];
    } else {
      this.data = {};
      this.timestamps = {};
    }
  }
};

// ============ KEYBOARD SHORTCUTS CONFIG ============
const keyboardShortcuts = {
  enabled: true,
  shortcuts: {
    'k': { ctrl: true, action: 'search', description: 'Quick Search' },
    'n': { ctrl: true, action: 'new', description: 'New Item' },
    'd': { ctrl: true, shift: true, action: 'dashboard', description: 'Go to Dashboard' },
    't': { ctrl: true, shift: true, action: 'trips', description: 'Go to Trips' },
    '/': { action: 'help', description: 'Show Shortcuts' },
    'Escape': { action: 'close', description: 'Close Modal' }
  }
};
