// CD Load Importer - Popup Script

const DEFAULT_SUPABASE_URL = 'https://yrrczhlzulwvdqjwvhtu.supabase.co';

// DOM elements
const supabaseUrlInput = document.getElementById('supabaseUrl');
const supabaseKeyInput = document.getElementById('supabaseKey');
const dispatcherSelect = document.getElementById('dispatcherId');
const saveBtn = document.getElementById('saveBtn');
const testBtn = document.getElementById('testBtn');
const statusIcon = document.getElementById('statusIcon');
const statusTitle = document.getElementById('statusTitle');
const statusMessage = document.getElementById('statusMessage');
const toast = document.getElementById('toast');

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
  const result = await chrome.storage.sync.get(['supabaseUrl', 'supabaseKey', 'dispatcherId', 'connected']);

  supabaseUrlInput.value = result.supabaseUrl || DEFAULT_SUPABASE_URL;
  supabaseKeyInput.value = result.supabaseKey || '';

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

// Initialize
loadSettings();
loadRecentImports();
