/* ============================================================
   HORIZON STAR TMS - Main Application Entry Point
   Initialization and bootstrap
   ============================================================ */

// ============ APPLICATION INITIALIZATION ============

/**
 * Initialize the application
 * Called when DOM is ready
 */
async function initApp() {
  console.log('🚛 HORIZON STAR TMS - Initializing...');

  // Initialize Supabase client
  initSupabase();

  // Apply saved theme
  applyTheme();

  // Check for existing session
  if (currentUser) {
    console.log('✅ User session found:', currentUser.email);

    // Check session timeout
    if (checkSessionTimeout()) {
      console.log('⚠️ Session expired');
      return; // renderLogin() already called by checkSessionTimeout
    }

    // Start session monitoring
    startSessionMonitor();

    // Start realtime sync
    startRealtimeSync();

    // Render the main application
    if (typeof renderApp === 'function') {
      renderApp();
    }
  } else {
    console.log('ℹ️ No user session, showing login');
    renderLogin();
  }

  // Initialize table scroll indicators
  initTableScrollIndicators();

  console.log('✅ HORIZON STAR TMS - Ready!');
}

// ============ DOM READY ============

// Initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initApp);
} else {
  // DOM already loaded
  initApp();
}

// ============ TRANSLATIONS (Stub) ============

// Simple translation function (can be expanded for i18n)
const translations = {
  en: {
    email: 'Email',
    password: 'Password',
    sign_in: 'Sign In',
    dashboard: 'Dashboard',
    trips: 'Trips',
    orders: 'Orders',
    drivers: 'Drivers',
    trucks: 'Trucks',
    fuel: 'Fuel',
    ifta: 'IFTA',
    payroll: 'Payroll',
    settings: 'Settings'
  }
};

/**
 * Get translated string
 * @param {string} key - Translation key
 * @returns {string} Translated string
 */
function t(key) {
  return translations[currentLang]?.[key] || translations.en[key] || key;
}
