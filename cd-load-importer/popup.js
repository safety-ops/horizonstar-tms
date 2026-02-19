// CD Load Importer - Popup Script

const DEFAULT_SUPABASE_URL = 'https://yrrczhlzulwvdqjwvhtu.supabase.co';

// DOM elements
const supabaseUrlInput = document.getElementById('supabaseUrl');
const supabaseKeyInput = document.getElementById('supabaseKey');
const dispatcherIdInput = document.getElementById('dispatcherId');
const saveBtn = document.getElementById('saveBtn');
const testBtn = document.getElementById('testBtn');
const statusIcon = document.getElementById('statusIcon');
const statusTitle = document.getElementById('statusTitle');
const statusMessage = document.getElementById('statusMessage');
const toast = document.getElementById('toast');

// Load saved settings
async function loadSettings() {
  const result = await chrome.storage.sync.get(['supabaseUrl', 'supabaseKey', 'dispatcherId', 'connected']);

  supabaseUrlInput.value = result.supabaseUrl || DEFAULT_SUPABASE_URL;
  supabaseKeyInput.value = result.supabaseKey || '';
  dispatcherIdInput.value = result.dispatcherId || '';

  if (result.connected) {
    updateStatus('connected');
  } else if (result.supabaseKey) {
    updateStatus('configured');
  } else {
    updateStatus('disconnected');
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
      dispatcherId: dispatcherIdInput.value.trim() || null
    });

    showToast('Settings saved!', 'success');
    updateStatus('configured');
  } catch (error) {
    showToast('Failed to save: ' + error.message, 'error');
  } finally {
    saveBtn.disabled = false;
    saveBtn.innerHTML = '💾 Save Settings';
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

// Event listeners
saveBtn.addEventListener('click', saveSettings);
testBtn.addEventListener('click', testConnection);

// Initialize
loadSettings();
