/* ============================================================
   HORIZON STAR TMS - UI Components
   Toast notifications, modals, theme, sidebar, loading states
   ============================================================ */

// ============ THEME MANAGEMENT ============
let isDarkTheme = localStorage.getItem('horizonstar_dark') === 'true';

/**
 * Apply the current theme to the document
 */
function applyTheme() {
  if (isDarkTheme) {
    document.body.classList.add('dark-theme');
  } else {
    document.body.classList.remove('dark-theme');
  }
}

/**
 * Toggle between dark and light themes
 */
function toggleDarkTheme() {
  isDarkTheme = !isDarkTheme;
  localStorage.setItem('horizonstar_dark', isDarkTheme);
  applyTheme();
  if (currentUser && typeof renderApp === 'function') {
    renderApp();
  } else if (typeof renderLogin === 'function') {
    renderLogin();
  }
}

// ============ TOAST NOTIFICATIONS ============

/**
 * Show a toast notification
 * @param {string} msg - Message to display
 * @param {string} type - Type: 'success', 'error', 'warning', 'info'
 */
function showToast(msg, type = 'success') {
  // Remove existing toasts
  document.querySelectorAll('.toast').forEach(t => t.remove());

  const t = document.createElement('div');
  t.className = 'toast ' + type;
  t.textContent = msg;
  t.setAttribute('role', 'alert');
  t.setAttribute('aria-live', 'polite');
  document.body.appendChild(t);

  setTimeout(() => t.remove(), 3000);
}

// ============ SIDEBAR & NAVIGATION UI ============

/**
 * Toggle sidebar collapsed state
 */
function toggleSidebar() {
  const sidebar = document.getElementById('sidebar');
  const main = document.querySelector('.main');
  if (!sidebar || !main) return;

  sidebar.classList.toggle('collapsed');
  main.classList.toggle('sidebar-collapsed');
  localStorage.setItem('sidebarCollapsed', sidebar.classList.contains('collapsed'));
}

/**
 * Toggle mobile menu
 */
function toggleMobileMenu() {
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('mobileOverlay');

  if (sidebar.classList.contains('mobile-open')) {
    sidebar.classList.remove('mobile-open');
    overlay?.classList.remove('active');
    document.body.classList.remove('menu-open');
  } else {
    sidebar.classList.add('mobile-open');
    overlay?.classList.add('active');
    document.body.classList.add('menu-open');
  }
}

/**
 * Close mobile menu
 */
function closeMobileMenu() {
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('mobileOverlay');

  if (sidebar && sidebar.classList.contains('mobile-open')) {
    sidebar.classList.remove('mobile-open');
    overlay?.classList.remove('active');
    document.body.classList.remove('menu-open');
  }
}

/**
 * Toggle user dropdown in topbar
 */
function toggleUserDropdown() {
  const wrapper = document.querySelector('.topbar-user-wrapper');
  if (wrapper) {
    wrapper.classList.toggle('open');
  }
}

// Close user dropdown when clicking outside
document.addEventListener('click', function(e) {
  const wrapper = document.querySelector('.topbar-user-wrapper');
  if (wrapper && !wrapper.contains(e.target)) {
    wrapper.classList.remove('open');
  }
});

// ============ MODAL MANAGEMENT ============

/**
 * Close a modal by ID
 * @param {string} modalId - Modal element ID
 */
function closeModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.remove();
  }
}

/**
 * Close all open modals
 */
function closeAllModals() {
  document.querySelectorAll('.modal-overlay').forEach(m => m.remove());
}

// ============ KEYBOARD SHORTCUTS ============

// Keyboard shortcut handler
document.addEventListener('keydown', function(e) {
  // Skip if typing in input/textarea
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.isContentEditable) {
    // Only handle Escape in inputs
    if (e.key === 'Escape') {
      e.target.blur();
      closeAllModals();
    }
    return;
  }

  // Ctrl/Cmd + K - Quick Search
  if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
    e.preventDefault();
    openQuickSearch();
    return;
  }

  // Ctrl/Cmd + N - New Item (context-aware)
  if ((e.ctrlKey || e.metaKey) && e.key === 'n') {
    e.preventDefault();
    triggerNewItem();
    return;
  }

  // Ctrl/Cmd + Shift + D - Dashboard
  if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'D') {
    e.preventDefault();
    if (typeof navigate === 'function') navigate('dashboard');
    return;
  }

  // Ctrl/Cmd + Shift + T - Trips
  if ((e.ctrlKey || e.metaKey) && e.shiftKey && e.key === 'T') {
    e.preventDefault();
    if (typeof navigate === 'function') navigate('trips');
    return;
  }

  // ? or / - Show keyboard shortcuts help
  if (e.key === '?' || (e.key === '/' && !e.ctrlKey)) {
    e.preventDefault();
    showKeyboardShortcutsHelp();
    return;
  }

  // Escape - Close modals
  if (e.key === 'Escape') {
    closeAllModals();
    return;
  }

  // Number keys 1-9 for quick navigation
  if (/^[1-9]$/.test(e.key) && !e.ctrlKey && !e.metaKey && !e.altKey) {
    const navPages = ['dashboard', 'trips', 'orders', 'drivers', 'trucks', 'fuel', 'ifta', 'payroll', 'settings'];
    const pageIndex = parseInt(e.key) - 1;
    if (pageIndex < navPages.length && typeof navigate === 'function') {
      navigate(navPages[pageIndex]);
      showToast('Navigated to ' + navPages[pageIndex].charAt(0).toUpperCase() + navPages[pageIndex].slice(1));
    }
  }
});

// ============ QUICK SEARCH ============

/**
 * Open quick search modal
 */
function openQuickSearch() {
  const existing = document.querySelector('.quick-search-overlay');
  if (existing) {
    existing.remove();
    return;
  }

  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay quick-search-overlay';
  overlay.style.cssText = 'display:flex;align-items:flex-start;justify-content:center;padding-top:15vh';
  overlay.innerHTML = `
    <div class="modal" style="max-width:500px;width:100%;margin:0 16px">
      <div style="padding:20px">
        <input type="text" id="quickSearchInput" placeholder="Search pages, trips, drivers..."
               style="width:100%;padding:14px 18px;font-size:16px;border:2px solid var(--primary);border-radius:var(--radius);background:var(--bg-secondary);color:var(--text-primary)"
               autocomplete="off">
        <div id="quickSearchResults" style="margin-top:16px;max-height:300px;overflow-y:auto"></div>
        <div style="margin-top:12px;font-size:12px;color:var(--text-muted);display:flex;gap:16px">
          <span>↑↓ Navigate</span>
          <span>↵ Select</span>
          <span>Esc Close</span>
        </div>
      </div>
    </div>
  `;
  document.body.appendChild(overlay);

  const input = document.getElementById('quickSearchInput');
  input.focus();

  input.addEventListener('input', handleQuickSearch);
  input.addEventListener('keydown', handleQuickSearchNav);
  overlay.addEventListener('click', e => { if (e.target === overlay) overlay.remove(); });
}

function handleQuickSearch(e) {
  const query = e.target.value.toLowerCase();
  const results = document.getElementById('quickSearchResults');

  if (!query) {
    results.innerHTML = '<div style="color:var(--text-muted);text-align:center;padding:20px">Start typing to search...</div>';
    return;
  }

  // Search pages
  const pages = [
    { name: 'Dashboard', page: 'dashboard', icon: '📊' },
    { name: 'Trips', page: 'trips', icon: '🚛' },
    { name: 'Orders', page: 'orders', icon: '📦' },
    { name: 'Drivers', page: 'drivers', icon: '👥' },
    { name: 'Trucks', page: 'trucks', icon: '🚚' },
    { name: 'Fuel', page: 'fuel', icon: '⛽' },
    { name: 'IFTA', page: 'ifta', icon: '📋' },
    { name: 'Payroll', page: 'payroll', icon: '💰' },
    { name: 'Chat', page: 'team_chat', icon: '💬' },
    { name: 'Settings', page: 'settings', icon: '⚙️' }
  ];

  const matchedPages = pages.filter(p => p.name.toLowerCase().includes(query));

  if (matchedPages.length === 0) {
    results.innerHTML = '<div style="color:var(--text-muted);text-align:center;padding:20px">No results found</div>';
    return;
  }

  results.innerHTML = matchedPages.map((p, i) => `
    <div class="quick-search-item${i === 0 ? ' selected' : ''}" data-page="${p.page}"
         style="padding:12px 16px;cursor:pointer;border-radius:var(--radius);display:flex;align-items:center;gap:12px;${i === 0 ? 'background:var(--primary-light)' : ''}"
         onmouseover="this.style.background='var(--bg-hover)';selectQuickSearchItem(this)"
         onclick="navigateFromQuickSearch('${p.page}')">
      <span style="font-size:20px">${p.icon}</span>
      <span style="font-weight:500">${escapeHtml(p.name)}</span>
    </div>
  `).join('');
}

function handleQuickSearchNav(e) {
  const results = document.getElementById('quickSearchResults');
  const items = results.querySelectorAll('.quick-search-item');
  const selected = results.querySelector('.quick-search-item.selected');

  if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
    e.preventDefault();
    if (!items.length) return;

    let idx = Array.from(items).indexOf(selected);
    idx = e.key === 'ArrowDown' ? Math.min(idx + 1, items.length - 1) : Math.max(idx - 1, 0);

    items.forEach(i => { i.classList.remove('selected'); i.style.background = ''; });
    items[idx].classList.add('selected');
    items[idx].style.background = 'var(--primary-light)';
    items[idx].scrollIntoView({ block: 'nearest' });
  }

  if (e.key === 'Enter' && selected) {
    e.preventDefault();
    navigateFromQuickSearch(selected.dataset.page);
  }
}

function selectQuickSearchItem(item) {
  document.querySelectorAll('.quick-search-item').forEach(i => {
    i.classList.remove('selected');
    i.style.background = '';
  });
  item.classList.add('selected');
  item.style.background = 'var(--primary-light)';
}

function navigateFromQuickSearch(page) {
  document.querySelector('.quick-search-overlay')?.remove();
  if (typeof navigate === 'function') navigate(page);
}

/**
 * Trigger new item based on current page
 */
function triggerNewItem() {
  const newItemActions = {
    'trips': 'openTripModal',
    'orders': 'openOrderModal',
    'drivers': 'openDriverModal',
    'trucks': 'openTruckModal',
    'brokers': 'openBrokerModal',
    'tasks': 'openTaskModal',
    'fuel': 'openFuelModal',
    'future_cars': 'openLoadBoardOrder'
  };

  const action = newItemActions[typeof currentPage !== 'undefined' ? currentPage : ''];
  if (action && typeof window[action] === 'function') {
    window[action]();
  } else {
    showToast('Press + button to create new item on this page', 'info');
  }
}

/**
 * Show keyboard shortcuts help modal
 */
function showKeyboardShortcutsHelp() {
  const existing = document.querySelector('.shortcuts-help-overlay');
  if (existing) { existing.remove(); return; }

  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay shortcuts-help-overlay';
  overlay.innerHTML = `
    <div class="modal" style="max-width:450px">
      <div class="modal-header">
        <h3>⌨️ Keyboard Shortcuts</h3>
        <button class="modal-close" onclick="this.closest('.modal-overlay').remove()">×</button>
      </div>
      <div style="padding:20px">
        <div style="display:grid;gap:12px">
          <div style="display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--border)">
            <span>Quick Search</span><kbd style="background:var(--bg-tertiary);padding:4px 8px;border-radius:4px;font-family:monospace">Ctrl + K</kbd>
          </div>
          <div style="display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--border)">
            <span>New Item</span><kbd style="background:var(--bg-tertiary);padding:4px 8px;border-radius:4px;font-family:monospace">Ctrl + N</kbd>
          </div>
          <div style="display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--border)">
            <span>Go to Dashboard</span><kbd style="background:var(--bg-tertiary);padding:4px 8px;border-radius:4px;font-family:monospace">Ctrl + Shift + D</kbd>
          </div>
          <div style="display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--border)">
            <span>Go to Trips</span><kbd style="background:var(--bg-tertiary);padding:4px 8px;border-radius:4px;font-family:monospace">Ctrl + Shift + T</kbd>
          </div>
          <div style="display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--border)">
            <span>Quick Navigate</span><kbd style="background:var(--bg-tertiary);padding:4px 8px;border-radius:4px;font-family:monospace">1 - 9</kbd>
          </div>
          <div style="display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--border)">
            <span>Close Modal</span><kbd style="background:var(--bg-tertiary);padding:4px 8px;border-radius:4px;font-family:monospace">Esc</kbd>
          </div>
          <div style="display:flex;justify-content:space-between;padding:8px 0">
            <span>Show This Help</span><kbd style="background:var(--bg-tertiary);padding:4px 8px;border-radius:4px;font-family:monospace">?</kbd>
          </div>
        </div>
        <div style="margin-top:16px;font-size:12px;color:var(--text-muted);text-align:center">
          Use <strong>Cmd</strong> instead of Ctrl on Mac
        </div>
      </div>
    </div>
  `;
  document.body.appendChild(overlay);
  overlay.addEventListener('click', e => { if (e.target === overlay) overlay.remove(); });
}

// ============ GLOBAL ERROR HANDLERS ============

// Catch unhandled errors to prevent silent failures
window.onerror = function(message, source, lineno, colno, error) {
  console.error('Unhandled error:', message, 'at', source, lineno + ':' + colno);
  // Show user-friendly message
  if (typeof showToast === 'function') {
    showToast('Something went wrong. Please try again or refresh the page.', 'error');
  }
  return false; // Let error propagate for debugging
};

// Catch unhandled promise rejections
window.addEventListener('unhandledrejection', function(event) {
  console.error('Unhandled promise rejection:', event.reason);
  if (typeof showToast === 'function') {
    showToast('A network or data error occurred. Please try again.', 'error');
  }
});

// ============ TABLE SCROLL INDICATORS ============

/**
 * Initialize scroll indicators for responsive tables
 */
function initTableScrollIndicators() {
  document.querySelectorAll('.table-wrapper').forEach(wrapper => {
    const updateScrollIndicators = () => {
      const { scrollLeft, scrollWidth, clientWidth } = wrapper;
      wrapper.classList.toggle('scrolled-left', scrollLeft > 10);
      wrapper.classList.toggle('scrolled-right', scrollLeft < scrollWidth - clientWidth - 10);
    };

    wrapper.addEventListener('scroll', updateScrollIndicators);
    updateScrollIndicators();
  });
}

// ============ SVG ICONS ============
const icons = {
  dashboard: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>',
  loadboard: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>',
  trips: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="1" y="3" width="15" height="13" rx="2"/><polygon points="16 8 20 8 23 11 23 16 16 16 16 8"/><circle cx="5.5" cy="18.5" r="2.5"/><circle cx="18.5" cy="18.5" r="2.5"/></svg>',
  orders: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M7 17m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"/><path d="M17 17m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0"/><path d="M5 17h-2v-6l2-5h9l4 5h1a2 2 0 0 1 2 2v4h-2m-4 0h-6m-6 -6h15m-6 0v-5"/></svg>',
  drivers: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
  trucks: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="1" y="3" width="15" height="13" rx="2"/><polygon points="16 8 20 8 23 11 23 16 16 16 16 8"/><circle cx="5.5" cy="18.5" r="2.5"/><circle cx="18.5" cy="18.5" r="2.5"/></svg>',
  fuel: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 22V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v17"/><path d="M15 22H3"/><path d="M15 10h2a2 2 0 0 1 2 2v3a2 2 0 0 0 2 2v0a2 2 0 0 0 2-2V9.83a2 2 0 0 0-.59-1.42L18 4"/><path d="M7 10h4"/></svg>',
  ifta: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>',
  payroll: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="4" width="20" height="16" rx="2"/><line x1="6" y1="12" x2="18" y2="12"/><line x1="6" y1="8" x2="12" y2="8"/><line x1="6" y1="16" x2="10" y2="16"/></svg>',
  settings: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>',
  chat: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>',
  brokers: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 21h18"/><path d="M9 8h1"/><path d="M9 12h1"/><path d="M9 16h1"/><path d="M14 8h1"/><path d="M14 12h1"/><path d="M14 16h1"/><path d="M5 21V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16"/></svg>',
  dispatchers: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 22 16.92z"/></svg>',
  compliance: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>',
  tasks: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>',
  reports: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>',
  ai_advisor: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2a4 4 0 0 1 4 4v1a4 4 0 0 1-8 0V6a4 4 0 0 1 4-4z"/><path d="M12 11v3"/><circle cx="12" cy="18" r="4"/><path d="M9 18h6"/></svg>',
  profitability: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/></svg>',
  maintenance: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>',
  claims: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>',
  tickets: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5v2m0 4v2m0 4v2M5 5a2 2 0 00-2 2v3a2 2 0 002 2 2 2 0 010 4 2 2 0 00-2 2v3a2 2 0 002 2h14a2 2 0 002-2v-3a2 2 0 00-2-2 2 2 0 010-4 2 2 0 002-2V7a2 2 0 00-2-2H5z"/></svg>',
  live_map: '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="10" r="3"/><path d="M12 21.7C17.3 17 20 13 20 10a8 8 0 1 0-16 0c0 3 2.7 7 8 11.7z"/></svg>'
};

// Apply theme on load
applyTheme();
