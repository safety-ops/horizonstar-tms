/* ============================================================
   HORIZON STAR TMS - UI Components
   Toast notifications, modals, theme, sidebar, loading states
   ============================================================ */

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
  // Also close command palette
  document.querySelector('.command-palette-overlay')?.remove();
}

// ============ KEYBOARD SHORTCUTS ============

// Two-key sequence state
let pendingShortcutKey = null;
let pendingShortcutTimer = null;

document.addEventListener('keydown', function(e) {
  // Skip if typing in input/textarea
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.isContentEditable) {
    if (e.key === 'Escape') {
      e.target.blur();
      closeAllModals();
    }
    return;
  }

  // Cmd/Ctrl + K - Command Palette
  if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
    e.preventDefault();
    openCommandPalette();
    return;
  }

  // Cmd/Ctrl + N - New Item (context-aware)
  if ((e.ctrlKey || e.metaKey) && e.key === 'n') {
    e.preventDefault();
    triggerNewItem();
    return;
  }

  // Escape - Close modals
  if (e.key === 'Escape') {
    closeAllModals();
    return;
  }

  // ? - Show keyboard shortcuts help
  if (e.key === '?') {
    e.preventDefault();
    showKeyboardShortcutsHelp();
    return;
  }

  // / - Focus search (open command palette)
  if (e.key === '/' && !e.ctrlKey && !e.metaKey) {
    e.preventDefault();
    openCommandPalette();
    return;
  }

  // Two-key sequences: G→D (Dashboard), G→T (Trips), G→O (Orders), N→O (New Order), N→T (New Trip)
  if (pendingShortcutKey) {
    e.preventDefault();
    const combo = pendingShortcutKey + e.key.toLowerCase();
    clearTimeout(pendingShortcutTimer);
    pendingShortcutKey = null;

    const twoKeyActions = {
      'gd': () => { if (typeof navigate === 'function') navigate('dashboard'); },
      'gt': () => { if (typeof navigate === 'function') navigate('trips'); },
      'go': () => { if (typeof navigate === 'function') navigate('orders'); },
      'gf': () => { if (typeof navigate === 'function') navigate('drivers'); },
      'gb': () => { if (typeof navigate === 'function') navigate('billing'); },
      'no': () => { if (typeof openOrderModal === 'function') openOrderModal(); },
      'nt': () => { if (typeof openTripModal === 'function') openTripModal(); },
    };

    if (twoKeyActions[combo]) {
      twoKeyActions[combo]();
    }
    return;
  }

  // Start two-key sequence
  if (e.key === 'g' || e.key === 'n') {
    pendingShortcutKey = e.key;
    pendingShortcutTimer = setTimeout(() => { pendingShortcutKey = null; }, 1000);
    return;
  }
});

// ============ COMMAND PALETTE (Cmd+K) ============

// Recent navigation history
let recentNavHistory = JSON.parse(localStorage.getItem('tms_recent_nav') || '[]');

function addToRecentNav(pageId) {
  recentNavHistory = recentNavHistory.filter(p => p !== pageId);
  recentNavHistory.unshift(pageId);
  if (recentNavHistory.length > 5) recentNavHistory = recentNavHistory.slice(0, 5);
  localStorage.setItem('tms_recent_nav', JSON.stringify(recentNavHistory));
}

/**
 * Open command palette (replaces old quick search)
 */
function openCommandPalette() {
  const existing = document.querySelector('.command-palette-overlay');
  if (existing) {
    existing.remove();
    return;
  }

  const overlay = document.createElement('div');
  overlay.className = 'command-palette-overlay';
  overlay.innerHTML = `
    <div class="command-palette">
      <input type="text" class="command-palette-input" id="cmdPaletteInput"
             placeholder="Search pages, orders, trips, drivers..."
             autocomplete="off" spellcheck="false">
      <div class="command-palette-results" id="cmdPaletteResults"></div>
      <div class="command-palette-footer">
        <span><kbd>↑↓</kbd> Navigate</span>
        <span><kbd>↵</kbd> Select</span>
        <span><kbd>Esc</kbd> Close</span>
      </div>
    </div>
  `;
  document.body.appendChild(overlay);

  const input = document.getElementById('cmdPaletteInput');
  input.focus();

  // Show recent items on empty state
  renderCommandPaletteResults('');

  input.addEventListener('input', (e) => renderCommandPaletteResults(e.target.value));
  input.addEventListener('keydown', handleCommandPaletteNav);
  overlay.addEventListener('click', e => { if (e.target === overlay) overlay.remove(); });
}

// Backward compat
function openQuickSearch() { openCommandPalette(); }

function renderCommandPaletteResults(query) {
  const results = document.getElementById('cmdPaletteResults');
  const q = query.toLowerCase().trim();

  // All searchable pages
  const allPages = [
    { name: 'Dashboard', page: 'dashboard', group: 'Pages', icon: icons.dashboard },
    { name: 'Trips', page: 'trips', group: 'Dispatch', icon: icons.trips },
    { name: 'Orders', page: 'orders', group: 'Dispatch', icon: icons.orders },
    { name: 'Load Board', page: 'loadboard', group: 'Dispatch', icon: icons.loadboard },
    { name: 'Tasks', page: 'tasks', group: 'Dispatch', icon: icons.tasks },
    { name: 'Drivers', page: 'drivers', group: 'Fleet', icon: icons.drivers },
    { name: 'Trucks', page: 'trucks', group: 'Fleet', icon: icons.trucks },
    { name: 'Local Drivers', page: 'local_drivers', group: 'Fleet', icon: icons.drivers },
    { name: 'Brokers', page: 'brokers', group: 'Partners', icon: icons.brokers },
    { name: 'Dealers', page: 'dealers', group: 'Partners', icon: icons.brokers },
    { name: 'Dispatchers', page: 'dispatchers', group: 'Partners', icon: icons.dispatchers },
    { name: 'Dispatcher Ranking', page: 'dispatcher_ranking', group: 'Partners', icon: icons.dispatchers },
    { name: 'Billing', page: 'billing', group: 'Finance', icon: icons.payroll },
    { name: 'Payroll', page: 'payroll', group: 'Finance', icon: icons.payroll },
    { name: 'Financials', page: 'financials', group: 'Finance', icon: icons.payroll },
    { name: 'Trip Profitability', page: 'trip_profitability', group: 'Finance', icon: icons.profitability },
    { name: 'Fuel', page: 'fuel', group: 'Finance', icon: icons.fuel },
    { name: 'IFTA', page: 'ifta', group: 'Finance', icon: icons.ifta },
    { name: 'Reports', page: 'reports', group: 'Finance', icon: icons.reports },
    { name: 'AI Advisor', page: 'ai_advisor', group: 'Finance', icon: icons.ai_advisor },
    { name: 'Compliance', page: 'compliance', group: 'Operations', icon: icons.compliance },
    { name: 'Maintenance', page: 'maintenance', group: 'Operations', icon: icons.maintenance },
    { name: 'Applications', page: 'applications', group: 'Operations', icon: icons.compliance },
    { name: 'Settings', page: 'settings', group: 'Settings', icon: icons.settings },
    { name: 'Users', page: 'users', group: 'Settings', icon: icons.drivers },
    { name: 'Activity Log', page: 'activity_log', group: 'Settings', icon: icons.reports },
    { name: 'Live Map', page: 'live_map', group: 'Pages', icon: icons.live_map },
    { name: 'Team Chat', page: 'team_chat', group: 'Pages', icon: icons.chat },
  ];

  if (!q) {
    // Show recent items
    if (recentNavHistory.length > 0) {
      const recentItems = recentNavHistory.map(pageId => allPages.find(p => p.page === pageId)).filter(Boolean);
      if (recentItems.length > 0) {
        let html = '<div class="command-palette-group">Recent</div>';
        html += recentItems.map((p, i) =>
          `<div class="command-palette-item${i === 0 ? ' selected' : ''}" data-page="${p.page}">
            <span class="item-icon">${p.icon || ''}</span>
            <span>${escapeHtml(p.name)}</span>
          </div>`
        ).join('');
        results.innerHTML = html;
        attachCommandPaletteItemHandlers();
        return;
      }
    }
    results.innerHTML = '<div style="padding:20px;text-align:center;color:var(--text-muted)">Type to search pages, orders, trips...</div>';
    return;
  }

  let html = '';
  let totalItems = 0;

  // Search pages
  const matchedPages = allPages.filter(p => p.name.toLowerCase().includes(q));
  if (matchedPages.length > 0) {
    html += '<div class="command-palette-group">Pages</div>';
    matchedPages.forEach(p => {
      html += `<div class="command-palette-item${totalItems === 0 ? ' selected' : ''}" data-page="${p.page}">
        <span class="item-icon">${p.icon || ''}</span>
        <span>${escapeHtml(p.name)}</span>
        <span class="item-hint">${p.group}</span>
      </div>`;
      totalItems++;
    });
  }

  // Search entities (orders by VIN/number, trips by number, drivers by name)
  if (typeof appData !== 'undefined' && q.length >= 2) {
    // Search orders
    const matchedOrders = (appData.orders || []).filter(o => {
      const searchStr = [o.order_number, o.vin, o.year, o.make, o.model].filter(Boolean).join(' ').toLowerCase();
      return searchStr.includes(q);
    }).slice(0, 5);

    if (matchedOrders.length > 0) {
      html += '<div class="command-palette-group">Orders</div>';
      matchedOrders.forEach(o => {
        const label = [o.order_number, o.year, o.make, o.model].filter(Boolean).join(' ');
        html += `<div class="command-palette-item${totalItems === 0 ? ' selected' : ''}" data-page="orders" data-entity-type="order" data-entity-id="${o.id}">
          <span class="item-icon">${icons.orders || ''}</span>
          <span>${escapeHtml(label)}</span>
        </div>`;
        totalItems++;
      });
    }

    // Search trips
    const matchedTrips = (appData.trips || []).filter(t => {
      const searchStr = [t.trip_number, t.status].filter(Boolean).join(' ').toLowerCase();
      return searchStr.includes(q);
    }).slice(0, 5);

    if (matchedTrips.length > 0) {
      html += '<div class="command-palette-group">Trips</div>';
      matchedTrips.forEach(t => {
        html += `<div class="command-palette-item${totalItems === 0 ? ' selected' : ''}" data-page="trips" data-entity-type="trip" data-entity-id="${t.id}">
          <span class="item-icon">${icons.trips || ''}</span>
          <span>Trip ${escapeHtml(t.trip_number || '')}</span>
          <span class="item-hint">${escapeHtml(t.status || '')}</span>
        </div>`;
        totalItems++;
      });
    }

    // Search drivers
    const matchedDrivers = (appData.drivers || []).filter(d => {
      const name = ((d.first_name || '') + ' ' + (d.last_name || '')).toLowerCase();
      return name.includes(q);
    }).slice(0, 5);

    if (matchedDrivers.length > 0) {
      html += '<div class="command-palette-group">Drivers</div>';
      matchedDrivers.forEach(d => {
        html += `<div class="command-palette-item${totalItems === 0 ? ' selected' : ''}" data-page="drivers" data-entity-type="driver" data-entity-id="${d.id}">
          <span class="item-icon">${icons.drivers || ''}</span>
          <span>${escapeHtml((d.first_name || '') + ' ' + (d.last_name || ''))}</span>
        </div>`;
        totalItems++;
      });
    }

    // Search brokers
    const matchedBrokers = (appData.brokers || []).filter(b => {
      const name = (b.name || '').toLowerCase();
      return name.includes(q);
    }).slice(0, 5);

    if (matchedBrokers.length > 0) {
      html += '<div class="command-palette-group">Brokers</div>';
      matchedBrokers.forEach(b => {
        html += `<div class="command-palette-item${totalItems === 0 ? ' selected' : ''}" data-page="brokers" data-entity-type="broker" data-entity-id="${b.id}">
          <span class="item-icon">${icons.brokers || ''}</span>
          <span>${escapeHtml(b.name || '')}</span>
        </div>`;
        totalItems++;
      });
    }
  }

  if (totalItems === 0) {
    html = '<div style="padding:20px;text-align:center;color:var(--text-muted)">No results found</div>';
  }

  results.innerHTML = html;
  attachCommandPaletteItemHandlers();
}

function attachCommandPaletteItemHandlers() {
  document.querySelectorAll('.command-palette-item').forEach(item => {
    item.addEventListener('click', () => executeCommandPaletteItem(item));
    item.addEventListener('mouseenter', () => {
      document.querySelectorAll('.command-palette-item').forEach(i => i.classList.remove('selected'));
      item.classList.add('selected');
    });
  });
}

function handleCommandPaletteNav(e) {
  const results = document.getElementById('cmdPaletteResults');
  const items = results.querySelectorAll('.command-palette-item');
  const selected = results.querySelector('.command-palette-item.selected');

  if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
    e.preventDefault();
    if (!items.length) return;

    let idx = Array.from(items).indexOf(selected);
    idx = e.key === 'ArrowDown' ? Math.min(idx + 1, items.length - 1) : Math.max(idx - 1, 0);

    items.forEach(i => i.classList.remove('selected'));
    items[idx].classList.add('selected');
    items[idx].scrollIntoView({ block: 'nearest' });
  }

  if (e.key === 'Enter' && selected) {
    e.preventDefault();
    executeCommandPaletteItem(selected);
  }

  if (e.key === 'Escape') {
    e.preventDefault();
    document.querySelector('.command-palette-overlay')?.remove();
  }
}

function executeCommandPaletteItem(item) {
  const page = item.dataset.page;
  document.querySelector('.command-palette-overlay')?.remove();

  if (page && typeof navigate === 'function') {
    addToRecentNav(page);
    navigate(page);
  }
}

// Keep backward compat for old quick search functions
function handleQuickSearch(e) { renderCommandPaletteResults(e.target.value); }
function handleQuickSearchNav(e) { handleCommandPaletteNav(e); }
function selectQuickSearchItem(item) {}
function navigateFromQuickSearch(page) {
  document.querySelector('.command-palette-overlay')?.remove();
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

  const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
  const mod = isMac ? 'Cmd' : 'Ctrl';

  const shortcuts = [
    ['Command Palette', mod + ' + K  or  /'],
    ['New Item', mod + ' + N'],
    ['Go to Dashboard', 'G then D'],
    ['Go to Trips', 'G then T'],
    ['Go to Orders', 'G then O'],
    ['Go to Fleet', 'G then F'],
    ['Go to Billing', 'G then B'],
    ['New Order', 'N then O'],
    ['New Trip', 'N then T'],
    ['Close Modal', 'Esc'],
    ['Show This Help', '?'],
  ];

  const overlay = document.createElement('div');
  overlay.className = 'modal-overlay shortcuts-help-overlay';
  overlay.innerHTML = `
    <div class="modal" style="max-width:450px">
      <div class="modal-header">
        <h3>Keyboard Shortcuts</h3>
        <button class="modal-close" onclick="this.closest('.modal-overlay').remove()">&times;</button>
      </div>
      <div style="padding:20px">
        <div style="display:grid;gap:8px">
          ${shortcuts.map(([label, keys]) => `
            <div style="display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--border)">
              <span>${label}</span>
              <kbd style="background:var(--bg-tertiary);padding:4px 8px;border-radius:4px;font-family:monospace;font-size:12px">${keys}</kbd>
            </div>
          `).join('')}
        </div>
      </div>
    </div>
  `;
  document.body.appendChild(overlay);
  overlay.addEventListener('click', e => { if (e.target === overlay) overlay.remove(); });
}

// ============ GLOBAL ERROR HANDLERS ============

window.onerror = function(message, source, lineno, colno, error) {
  console.error('Unhandled error:', message, 'at', source, lineno + ':' + colno);
  if (typeof showToast === 'function') {
    showToast('Something went wrong. Please try again or refresh the page.', 'error');
  }
  return false;
};

window.addEventListener('unhandledrejection', function(event) {
  console.error('Unhandled promise rejection:', event.reason);
  if (typeof showToast === 'function') {
    showToast('A network or data error occurred. Please try again.', 'error');
  }
});

// ============ TABLE SCROLL INDICATORS ============

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

// ============ SYNC HEARTBEAT ============

function pulseSyncDot() {
  const dot = document.getElementById('syncDot');
  if (dot) {
    dot.classList.remove('pulse');
    void dot.offsetWidth; // trigger reflow
    dot.classList.add('pulse');
  }
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

