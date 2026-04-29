// CD Load Importer - Popup Script

const DEFAULT_SUPABASE_URL = 'https://yrrczhlzulwvdqjwvhtu.supabase.co';

// DOM elements
const supabaseUrlInput = document.getElementById('supabaseUrl');
const supabaseKeyInput = document.getElementById('supabaseKey');
const userEmailInput = document.getElementById('userEmail');
const userPasswordInput = document.getElementById('userPassword');
const loginBtn = document.getElementById('loginBtn');
const sessionStatusEl = document.getElementById('sessionStatus');
const dispatcherSelect = document.getElementById('dispatcherId');
const autoDispatcherRow = document.getElementById('autoDispatcherRow');
const autoDispatcherLabel = document.getElementById('autoDispatcherLabel');
const manualDispatcherRow = document.getElementById('manualDispatcherRow');
const signOutBtn = document.getElementById('signOutBtn');
const adminConfigSection = document.getElementById('adminConfigSection');

// Show/hide the Supabase URL + anon-key inputs. Admin-only when signed in.
// Always shown when not signed in so the first-install / re-config path
// works without any account.
function applyAdminConfigVisibility(role, isSignedIn) {
  if (!adminConfigSection) return;
  if (!isSignedIn || role === 'ADMIN') {
    adminConfigSection.style.display = '';
  } else {
    adminConfigSection.style.display = 'none';
  }
}
const saveBtn = document.getElementById('saveBtn');
const testBtn = document.getElementById('testBtn');
const statusIcon = document.getElementById('statusIcon');
const statusTitle = document.getElementById('statusTitle');
const statusMessage = document.getElementById('statusMessage');
const toast = document.getElementById('toast');

// Toggle which dispatcher UI row is visible based on whether the user is
// signed in AND we have an auto-resolved dispatcher.
function applyDispatcherUiMode(autoDispatcherName, autoDispatcherCode) {
  if (autoDispatcherName) {
    autoDispatcherLabel.textContent = autoDispatcherName + (autoDispatcherCode ? ' (' + autoDispatcherCode + ')' : '');
    autoDispatcherRow.style.display = '';
    manualDispatcherRow.style.display = 'none';
  } else {
    autoDispatcherRow.style.display = 'none';
    manualDispatcherRow.style.display = '';
  }
}

// Resolve the signed-in user's dispatcher row + role via the SECURITY
// DEFINER RPC. Persists dispatcher info AND role to chrome.storage.sync
// so the popup can apply admin-only UI gating without re-querying on
// every open. Returns {id, name, code, role, user_id} or null.
//   - If the user has no dispatchers row, id/name/code are null but role
//     is still populated (used to decide admin UI visibility).
//   - If no public.users row matches auth.uid() at all, the RPC returns
//     null; this function returns null too.
async function resolveCurrentUserDispatcher(url, key, accessToken) {
  if (!accessToken) return null;
  try {
    const resp = await fetch(url + '/rest/v1/rpc/current_user_dispatcher', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': key,
        'Authorization': 'Bearer ' + accessToken
      },
      body: '{}'
    });
    if (!resp.ok) return null;
    const data = await resp.json();
    if (!data || typeof data !== 'object') return null;
    await chrome.storage.sync.set({
      dispatcherId: data.id || null,
      dispatcherName: data.name || '',
      dispatcherCode: data.code || '',
      userRole: data.role || ''
    });
    return data;
  } catch (e) {
    return null;
  }
}

async function signOut() {
  await chrome.storage.sync.remove([
    'userAccessToken', 'userRefreshToken', 'userTokenExpiresAt',
    'dispatcherId', 'dispatcherName', 'dispatcherCode', 'userRole'
  ]);
  applyDispatcherUiMode(null);
  applyAdminConfigVisibility(null, false);
  renderSessionStatus({});
  showToast('Signed out', 'success');
  // Reload the manual dispatcher dropdown so it's usable as a fallback.
  await loadDispatchers('');
}

// Load dispatchers into dropdown
async function loadDispatchers(savedId) {
  try {
    const response = await chrome.runtime.sendMessage({ action: 'getDispatchers' });
    if (response.success && response.dispatchers && response.dispatchers.length > 0) {
      dispatcherSelect.innerHTML = '<option value="">Select Dispatcher</option>' +
        response.dispatchers.map(d => {
          const label = d.name + (d.code ? ' (' + d.code + ')' : '');
          const selected = savedId && String(d.id) === String(savedId) ? ' selected' : '';
          return '<option value="' + d.id + '"' + selected + '>' + label + '</option>';
        }).join('');
    } else {
      dispatcherSelect.innerHTML = '<option value="">No dispatchers found</option>';
    }
  } catch (e) {
    dispatcherSelect.innerHTML = '<option value="">Could not load dispatchers</option>';
  }
}

// Load saved settings
async function loadSettings() {
  const result = await chrome.storage.sync.get([
    'supabaseUrl', 'supabaseKey', 'dispatcherId', 'connected',
    'userEmail', 'userAccessToken', 'userRefreshToken', 'userTokenExpiresAt',
    'dispatcherName', 'dispatcherCode', 'userRole'
  ]);

  supabaseUrlInput.value = result.supabaseUrl || DEFAULT_SUPABASE_URL;
  supabaseKeyInput.value = result.supabaseKey || '';
  userEmailInput.value = result.userEmail || '';
  renderSessionStatus(result);

  // If signed in AND we have a stored auto-dispatcher + role, render
  // the auto-row immediately (no network). If signed in but missing
  // either the dispatcher info or the role, re-resolve via RPC (handles
  // upgrades from earlier versions).
  let role = result.userRole || null;
  if (result.userAccessToken) {
    const haveCachedDispatcher = result.dispatcherId && result.dispatcherName;
    if (haveCachedDispatcher && role) {
      applyDispatcherUiMode(result.dispatcherName, result.dispatcherCode);
    } else {
      const resolved = await resolveCurrentUserDispatcher(
        supabaseUrlInput.value.trim(),
        supabaseKeyInput.value.trim(),
        result.userAccessToken
      );
      if (resolved && resolved.id) {
        applyDispatcherUiMode(resolved.name, resolved.code);
      } else {
        applyDispatcherUiMode(null);
      }
      if (resolved) role = resolved.role || null;
    }
  } else {
    applyDispatcherUiMode(null);
  }
  applyAdminConfigVisibility(role, !!result.userAccessToken);

  if (result.connected) {
    updateStatus('connected');
  } else if (result.supabaseKey) {
    updateStatus('configured');
  } else {
    updateStatus('disconnected');
  }

  // Load dispatchers if we have an API key
  if (result.supabaseKey) {
    await loadDispatchers(result.dispatcherId || '');
  } else {
    dispatcherSelect.innerHTML = '<option value="">Configure API key first</option>';
  }
}

// Save settings
async function saveSettings() {
  const url = supabaseUrlInput.value.trim();
  const key = supabaseKeyInput.value.trim();

  if (!url) {
    showToast('Please enter Supabase URL', 'error');
    return;
  }

  if (!key) {
    showToast('Please enter API key', 'error');
    return;
  }

  saveBtn.disabled = true;
  saveBtn.textContent = 'Saving...';

  try {
    await chrome.storage.sync.set({
      supabaseUrl: url,
      supabaseKey: key,
      dispatcherId: dispatcherSelect.value || null
    });

    showToast('Settings saved!', 'success');
    updateStatus('configured');

    // Refresh dispatcher dropdown now that API key is saved
    await loadDispatchers(dispatcherSelect.value || '');
  } catch (error) {
    showToast('Failed to save: ' + error.message, 'error');
  } finally {
    saveBtn.disabled = false;
    saveBtn.innerHTML = '\u{1F4BE} Save';
  }
}

// Test connection
async function testConnection() {
  testBtn.disabled = true;
  testBtn.textContent = 'Testing...';

  try {
    const response = await chrome.runtime.sendMessage({ action: 'testConnection' });

    if (response.success) {
      showToast('Connected to TMS!', 'success');
      updateStatus('connected');
      await chrome.storage.sync.set({ connected: true });
    } else {
      throw new Error(response.error || 'Connection failed');
    }
  } catch (error) {
    showToast('Connection failed: ' + error.message, 'error');
    updateStatus('error');
    await chrome.storage.sync.set({ connected: false });
  } finally {
    testBtn.disabled = false;
    testBtn.innerHTML = '🔗 Test Connection';
  }
}

// Update status display
function updateStatus(status) {
  statusIcon.className = 'status-icon';

  switch (status) {
    case 'connected':
      statusIcon.classList.add('connected');
      statusIcon.textContent = '✓';
      statusTitle.textContent = 'Connected';
      statusMessage.textContent = 'Ready to import loads';
      break;

    case 'configured':
      statusIcon.textContent = '⚙️';
      statusTitle.textContent = 'Configured';
      statusMessage.textContent = 'Click "Test Connection" to verify';
      break;

    case 'error':
      statusIcon.classList.add('disconnected');
      statusIcon.textContent = '✕';
      statusTitle.textContent = 'Connection Error';
      statusMessage.textContent = 'Check your credentials';
      break;

    default:
      statusIcon.classList.add('disconnected');
      statusIcon.textContent = '❓';
      statusTitle.textContent = 'Not Connected';
      statusMessage.textContent = 'Configure API key below';
  }
}

function renderSessionStatus(result) {
  if (result.userAccessToken && result.userTokenExpiresAt) {
    const remaining = (result.userTokenExpiresAt * 1000) - Date.now();
    if (remaining > 0) {
      const mins = Math.floor(remaining / 60000);
      sessionStatusEl.textContent = 'Signed in as ' + (result.userEmail || 'unknown') +
        ' — expires in ' + mins + ' min (auto-refresh on use)';
      sessionStatusEl.style.color = '#10b981';
    } else {
      sessionStatusEl.textContent = 'Signed in as ' + (result.userEmail || 'unknown') +
        ' — token expired, will refresh on next request';
      sessionStatusEl.style.color = '#f59e0b';
    }
  } else {
    sessionStatusEl.textContent = 'Not signed in. RLS now blocks anon writes — sign in to use the importer.';
    sessionStatusEl.style.color = '#ef4444';
  }
}

// Sign in to TMS via Supabase Auth REST endpoint. Stores access_token and
// refresh_token in chrome.storage.sync; background.js refreshes on 401.
async function signIn() {
  const url = supabaseUrlInput.value.trim();
  const key = supabaseKeyInput.value.trim();
  const email = userEmailInput.value.trim();
  const password = userPasswordInput.value;

  if (!url || !key) { showToast('Enter Supabase URL and API key first', 'error'); return; }
  if (!email || !password) { showToast('Enter your TMS email and password', 'error'); return; }

  loginBtn.disabled = true;
  loginBtn.textContent = 'Signing in…';

  try {
    const response = await fetch(url + '/auth/v1/token?grant_type=password', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'apikey': key },
      body: JSON.stringify({ email: email, password: password })
    });

    if (!response.ok) {
      const errorText = await response.text();
      let msg = 'Sign-in failed';
      try { msg = JSON.parse(errorText).error_description || msg; } catch (_) {}
      throw new Error(msg);
    }

    const data = await response.json();
    if (!data.access_token || !data.refresh_token) {
      throw new Error('Auth response missing tokens');
    }

    const expiresAt = Math.floor(Date.now() / 1000) + (data.expires_in || 3600);

    await chrome.storage.sync.set({
      userEmail: email,
      userAccessToken: data.access_token,
      userRefreshToken: data.refresh_token,
      userTokenExpiresAt: expiresAt,
      supabaseUrl: url,
      supabaseKey: key
    });

    userPasswordInput.value = '';
    showToast('Signed in successfully', 'success');
    renderSessionStatus({
      userEmail: email,
      userAccessToken: data.access_token,
      userTokenExpiresAt: expiresAt
    });

    // Auto-resolve the signed-in user's dispatcher record so imports
    // are attributed to them automatically — no manual dropdown. Also
    // fetches the user's role to drive admin-only UI gating.
    const resolved = await resolveCurrentUserDispatcher(url, key, data.access_token);
    if (resolved && resolved.id) {
      applyDispatcherUiMode(resolved.name, resolved.code);
    } else {
      // Signed-in user without a dispatcher record (e.g. dealer or admin
      // with no dispatcher row). Fall back to the manual dropdown.
      applyDispatcherUiMode(null);
      await loadDispatchers(dispatcherSelect.value || '');
    }
    applyAdminConfigVisibility(resolved ? resolved.role : null, true);
    updateStatus('configured');
  } catch (error) {
    showToast('Sign-in failed: ' + error.message, 'error');
  } finally {
    loginBtn.disabled = false;
    loginBtn.textContent = '\u{1F511} Sign in to TMS';
  }
}

// Show toast notification
function showToast(message, type = 'success') {
  toast.textContent = message;
  toast.className = 'toast ' + type;
  toast.classList.add('show');

  setTimeout(() => {
    toast.classList.remove('show');
  }, 3000);
}

// Load recent imports
async function loadRecentImports() {
  try {
    const response = await chrome.runtime.sendMessage({ action: 'getRecentImports' });
    if (response.success && response.imports && response.imports.length > 0) {
      const section = document.getElementById('recentImportsSection');
      const list = document.getElementById('recentImportsList');
      section.style.display = 'block';

      const imports = response.imports.slice(0, 5);
      const countEl = document.getElementById('recentCount');
      if (countEl) countEl.textContent = imports.length;
      list.innerHTML = imports.map(imp => {
        const date = new Date(imp.timestamp);
        const timeStr = date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        const route = [imp.origin, imp.destination].filter(Boolean).join(' \u2192 ') || 'Unknown route';
        const revenue = imp.revenue ? '$' + Number(imp.revenue).toLocaleString() : '';
        return `
          <div class="recent-item">
            <div class="row">
              <span class="order-num">${imp.order_number || '\u2014'}</span>
              <span class="revenue">${revenue}</span>
            </div>
            <div class="route">${route}</div>
            <div class="meta">${timeStr}${imp.broker_name ? ' \u00b7 ' + imp.broker_name : ''}</div>
          </div>
        `;
      }).join('');
    }
  } catch (e) {
    // Silently fail
  }
}

// Event listeners
saveBtn.addEventListener('click', saveSettings);
testBtn.addEventListener('click', testConnection);
loginBtn.addEventListener('click', signIn);
if (signOutBtn) signOutBtn.addEventListener('click', signOut);

// Initialize
loadSettings();
loadRecentImports();
