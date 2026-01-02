/* ============================================================
   HORIZON STAR TMS - Utility Functions
   Formatters, validators, helpers, and common utilities
   ============================================================ */

// ============ FORMATTING FUNCTIONS ============

/**
 * Format a number as US currency
 * @param {number} n - The number to format
 * @returns {string} Formatted currency string (negative in parentheses)
 */
function formatMoney(n) {
  const val = n || 0;
  const formatted = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD'
  }).format(Math.abs(val));
  return val < 0 ? '(' + formatted + ')' : formatted;
}

/**
 * Format a date for display
 * @param {string|Date} d - Date to format
 * @returns {string} Formatted date string
 */
function formatDate(d) {
  return d ? new Date(d).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric'
  }) : '-';
}

/**
 * Format a datetime for display
 * @param {string|Date} dateStr - Date/time to format
 * @returns {string} Formatted datetime string
 */
function formatDateTime(dateStr) {
  if (!dateStr) return '-';
  const date = new Date(dateStr);
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit'
  });
}

/**
 * Format a phone number
 * @param {string} phone - Phone number to format
 * @returns {string} Formatted phone number
 */
function formatPhone(phone) {
  if (!phone) return '-';
  const cleaned = phone.replace(/\D/g, '');
  if (cleaned.length === 10) {
    return '(' + cleaned.slice(0, 3) + ') ' + cleaned.slice(3, 6) + '-' + cleaned.slice(6);
  }
  if (cleaned.length === 11 && cleaned[0] === '1') {
    return '+1 (' + cleaned.slice(1, 4) + ') ' + cleaned.slice(4, 7) + '-' + cleaned.slice(7);
  }
  return phone;
}

// ============ HTML SANITIZATION (XSS Prevention) ============

/**
 * Escape HTML special characters to prevent XSS attacks
 * @param {string} text - Text to escape
 * @returns {string} Escaped text
 */
function escapeHtml(text) {
  if (text === null || text === undefined) return '';
  const str = String(text);
  const map = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;'
  };
  return str.replace(/[&<>"']/g, char => map[char]);
}

/**
 * Sanitize user input before displaying (alias for escapeHtml)
 * @param {string} text - Text to sanitize
 * @returns {string} Sanitized text
 */
function sanitize(text) {
  return escapeHtml(text);
}

// ============ DEBOUNCE UTILITY ============

/**
 * Create a debounced version of a function
 * @param {Function} func - Function to debounce
 * @param {number} wait - Delay in milliseconds
 * @returns {Function} Debounced function
 */
function debounce(func, wait = 300) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

// ============ ID GENERATION ============

/**
 * Generate a random hex string
 * @param {number} length - Length of the hex string
 * @returns {string} Random hex string
 */
function generateRandomHex(length) {
  const array = new Uint8Array(length / 2);
  crypto.getRandomValues(array);
  return Array.from(array, b => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Generate a unique ID
 * @returns {string} UUID-like unique ID
 */
function generateId() {
  return 'id_' + Date.now().toString(36) + '_' + generateRandomHex(8);
}

// ============ BADGE UTILITIES ============

/**
 * Get badge class for a status
 * @param {string} s - Status string
 * @returns {string} Badge class name
 */
function getBadge(s) {
  const m = {
    COMPLETED: 'badge-green',
    IN_PROGRESS: 'badge-amber',
    PLANNED: 'badge-blue',
    CANCELLED: 'badge-red',
    ACTIVE: 'badge-green',
    INACTIVE: 'badge-gray',
    MAINTENANCE: 'badge-amber',
    DELIVERED: 'badge-green',
    IN_TRANSIT: 'badge-amber',
    PENDING: 'badge-blue'
  };
  return m[s] || 'badge-gray';
}

// ============ FORM VALIDATION UTILITIES ============

const validators = {
  required: (value, fieldName) => {
    if (!value || (typeof value === 'string' && !value.trim())) {
      return fieldName + ' is required';
    }
    return null;
  },

  email: (value) => {
    if (!value) return null;
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  },

  phone: (value) => {
    if (!value) return null;
    const cleaned = value.replace(/\D/g, '');
    if (cleaned.length < 10 || cleaned.length > 11) {
      return 'Please enter a valid phone number';
    }
    return null;
  },

  number: (value, min, max) => {
    if (!value && value !== 0) return null;
    const num = parseFloat(value);
    if (isNaN(num)) return 'Please enter a valid number';
    if (min !== undefined && num < min) return 'Value must be at least ' + min;
    if (max !== undefined && num > max) return 'Value must not exceed ' + max;
    return null;
  },

  date: (value) => {
    if (!value) return null;
    const date = new Date(value);
    if (isNaN(date.getTime())) return 'Please enter a valid date';
    return null;
  },

  vin: (value) => {
    if (!value) return null;
    if (value.length !== 17) return 'VIN must be exactly 17 characters';
    if (!/^[A-HJ-NPR-Z0-9]{17}$/i.test(value)) return 'Invalid VIN format';
    return null;
  }
};

/**
 * Validate a form field and show inline error
 * @param {HTMLInputElement} input - Input element to validate
 * @param {Array} validations - Array of validation rules
 * @returns {boolean} True if valid
 */
function validateField(input, validations) {
  const value = input.value;
  const fieldName = input.getAttribute('data-field-name') || input.name || 'This field';

  for (const validation of validations) {
    let error;
    if (typeof validation === 'string') {
      error = validators[validation] ? validators[validation](value, fieldName) : null;
    } else if (typeof validation === 'object') {
      const { type, ...params } = validation;
      error = validators[type] ? validators[type](value, ...Object.values(params)) : null;
    }

    if (error) {
      showFieldError(input, error);
      return false;
    }
  }

  clearFieldError(input);
  return true;
}

/**
 * Show error message on a field
 * @param {HTMLInputElement} input - Input element
 * @param {string} message - Error message
 */
function showFieldError(input, message) {
  clearFieldError(input);
  input.classList.add('field-error');
  input.setAttribute('aria-invalid', 'true');

  const errorEl = document.createElement('div');
  errorEl.className = 'field-error-message';
  errorEl.textContent = message;
  errorEl.id = input.id + '-error';
  input.setAttribute('aria-describedby', errorEl.id);
  input.parentNode.appendChild(errorEl);
}

/**
 * Clear error message from a field
 * @param {HTMLInputElement} input - Input element
 */
function clearFieldError(input) {
  input.classList.remove('field-error');
  input.removeAttribute('aria-invalid');
  input.removeAttribute('aria-describedby');
  const existingError = input.parentNode.querySelector('.field-error-message');
  if (existingError) existingError.remove();
}

/**
 * Validate an entire form
 * @param {HTMLFormElement} form - Form element
 * @param {Object} rules - Validation rules per field
 * @returns {boolean} True if all fields valid
 */
function validateForm(form, rules) {
  let isValid = true;

  for (const [fieldName, validations] of Object.entries(rules)) {
    const input = form.querySelector('[name="' + fieldName + '"]');
    if (input && !validateField(input, validations)) {
      isValid = false;
    }
  }

  return isValid;
}

// ============ PAGINATION UTILITIES ============

/**
 * Get paginated data from an array
 * @param {Array} dataArray - Full data array
 * @param {string} pageKey - Key for pagination state
 * @returns {Object} Paginated result with data and meta
 */
function getPaginatedData(dataArray, pageKey) {
  const p = pagination[pageKey] || { page: 1, perPage: 50 };
  p.total = dataArray.length;
  const start = (p.page - 1) * p.perPage;
  const end = start + p.perPage;
  return {
    data: dataArray.slice(start, end),
    page: p.page,
    perPage: p.perPage,
    total: p.total,
    totalPages: Math.ceil(p.total / p.perPage)
  };
}

/**
 * Render pagination controls
 * @param {string} pageKey - Key for pagination state
 * @param {Function} onPageChange - Callback when page changes
 * @returns {string} HTML for pagination controls
 */
function renderPaginationControls(pageKey, onPageChange) {
  const p = pagination[pageKey];
  if (!p || p.total <= p.perPage) return '';

  const totalPages = Math.ceil(p.total / p.perPage);

  return `
    <div class="pagination-controls" style="display:flex;align-items:center;justify-content:center;gap:8px;margin-top:16px;padding:16px;">
      <button class="btn btn-sm" onclick="changePage('${pageKey}', 1)" ${p.page === 1 ? 'disabled' : ''}>First</button>
      <button class="btn btn-sm" onclick="changePage('${pageKey}', ${p.page - 1})" ${p.page === 1 ? 'disabled' : ''}>Prev</button>
      <span style="padding:0 12px;color:var(--text-secondary)">Page ${p.page} of ${totalPages}</span>
      <button class="btn btn-sm" onclick="changePage('${pageKey}', ${p.page + 1})" ${p.page >= totalPages ? 'disabled' : ''}>Next</button>
      <button class="btn btn-sm" onclick="changePage('${pageKey}', ${totalPages})" ${p.page >= totalPages ? 'disabled' : ''}>Last</button>
    </div>
  `;
}

/**
 * Change page for a pagination key
 * @param {string} pageKey - Key for pagination state
 * @param {number} newPage - New page number
 */
function changePage(pageKey, newPage) {
  if (!pagination[pageKey]) return;
  const totalPages = Math.ceil(pagination[pageKey].total / pagination[pageKey].perPage);
  pagination[pageKey].page = Math.max(1, Math.min(newPage, totalPages));

  // Re-render current page
  if (typeof navigate === 'function') {
    navigate(currentPage);
  }
}
