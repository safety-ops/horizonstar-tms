/* ============================================================
   HORIZON STAR TMS - Authentication
   Login, logout, session management, password reset
   ============================================================ */

// ============ SESSION MANAGEMENT ============
let sessionTimeoutId = null;
let lastActivityTime = Date.now();

/**
 * Update last activity timestamp
 */
function updateLastActivity() {
  lastActivityTime = Date.now();
  localStorage.setItem('last_activity', lastActivityTime.toString());
}

/**
 * Check if session has timed out
 * @returns {boolean} True if session expired
 */
function checkSessionTimeout() {
  const storedLastActivity = parseInt(localStorage.getItem('last_activity') || '0');
  const timeout = SESSION_TIMEOUT_MINUTES * 60 * 1000;

  // If no last_activity set, this is likely a fresh login - set it now
  if (storedLastActivity === 0) {
    localStorage.setItem('last_activity', Date.now().toString());
    return false; // Don't expire, treat as fresh session
  }

  if (currentUser && (Date.now() - storedLastActivity) > timeout) {
    sessionExpired();
    return true;
  }
  return false;
}

/**
 * Handle session expiration
 */
function sessionExpired() {
  currentUser = null;
  localStorage.removeItem('horizonstar_user');
  localStorage.removeItem('last_activity');
  showToast('Session expired. Please log in again.', 'warning');
  renderLogin();
}

/**
 * Start monitoring user session for timeout
 */
function startSessionMonitor() {
  // Update activity on user interactions
  ['click', 'keypress', 'mousemove', 'scroll'].forEach(event => {
    document.addEventListener(event, updateLastActivity, { passive: true });
  });

  // Check session every minute
  if (sessionTimeoutId) clearInterval(sessionTimeoutId);
  sessionTimeoutId = setInterval(() => {
    if (currentUser) checkSessionTimeout();
  }, 60000);

  updateLastActivity();
}

// ============ LOGIN ATTEMPT TRACKING ============

/**
 * Get login attempts for an email
 * @param {string} email - User email
 * @returns {Object} Login attempts data
 */
function getLoginAttempts(email) {
  const attempts = JSON.parse(localStorage.getItem('login_attempts') || '{}');
  return attempts[email] || { count: 0, lastAttempt: 0, lockedUntil: 0 };
}

/**
 * Record a login attempt
 * @param {string} email - User email
 * @param {boolean} success - Whether login was successful
 * @returns {Object} Updated attempts data
 */
function recordLoginAttempt(email, success) {
  const attempts = JSON.parse(localStorage.getItem('login_attempts') || '{}');
  const now = Date.now();

  if (success) {
    // Clear attempts on successful login
    delete attempts[email];
  } else {
    // Increment failed attempts
    if (!attempts[email]) {
      attempts[email] = { count: 0, lastAttempt: 0, lockedUntil: 0 };
    }
    attempts[email].count++;
    attempts[email].lastAttempt = now;

    // Lock account after too many attempts
    if (attempts[email].count >= LOGIN_ATTEMPT_LIMIT) {
      attempts[email].lockedUntil = now + (LOGIN_LOCKOUT_MINUTES * 60 * 1000);
    }
  }

  localStorage.setItem('login_attempts', JSON.stringify(attempts));
  return attempts[email];
}

/**
 * Check if an account is locked
 * @param {string} email - User email
 * @returns {Object} Lock status
 */
function isAccountLocked(email) {
  const attempts = getLoginAttempts(email);
  if (attempts.lockedUntil && Date.now() < attempts.lockedUntil) {
    const remainingMinutes = Math.ceil((attempts.lockedUntil - Date.now()) / 60000);
    return { locked: true, remainingMinutes };
  }
  // Reset if lockout expired
  if (attempts.lockedUntil && Date.now() >= attempts.lockedUntil) {
    const allAttempts = JSON.parse(localStorage.getItem('login_attempts') || '{}');
    delete allAttempts[email];
    localStorage.setItem('login_attempts', JSON.stringify(allAttempts));
  }
  return { locked: false };
}

// ============ PASSWORD HASHING ============

/**
 * Hash a password using SHA-256
 * @param {string} password - Password to hash
 * @returns {Promise<string>} Hashed password
 */
async function hashPassword(password) {
  const encoder = new TextEncoder();
  const data = encoder.encode(password + 'horizonstar_salt_2024');
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Generate a password reset token
 * @returns {string} Random token
 */
function generateResetToken() {
  const array = new Uint8Array(32);
  crypto.getRandomValues(array);
  return Array.from(array, b => b.toString(16).padStart(2, '0')).join('');
}

// ============ LOGIN/LOGOUT ============

let isSignUpMode = false;
let protectedAccessGranted = false;

/**
 * Render the login page
 */
function renderLogin() {
  applyTheme();

  // Generate 30 particles for animated background
  let particlesHtml = '<div class="login-particles">';
  for (let i = 1; i <= 30; i++) {
    particlesHtml += '<div class="login-particle"></div>';
  }
  particlesHtml += '</div>';

  // Navigation bar
  const navBar = `
    <nav class="login-nav">
      <div class="login-nav-logo">
        <div class="login-nav-logo-icon">🚛</div>
        <span>Horizon<span style="color:#22c55e">Star</span></span>
      </div>
      <div class="login-nav-links"></div>
      <div class="login-nav-buttons">
        <button class="login-nav-btn login" onclick="renderLogin()">LOGIN</button>
      </div>
    </nav>
  `;

  // Hero content (left side) with 5 features
  const heroContent = `
    <div class="login-hero-content">
      <h1>HORIZON STAR LLC<br><span>Transportation Management System</span></h1>
      <p class="login-hero-subtitle">Complete fleet operations platform — track, plan, optimize, and grow your transportation business</p>

      <div class="login-features">
        <div class="login-feature">
          <div class="login-feature-icon">🚛</div>
          <div class="login-feature-title">FLEET</div>
          <div class="login-feature-subtitle">MANAGEMENT</div>
        </div>
        <div class="login-feature">
          <div class="login-feature-icon">📍</div>
          <div class="login-feature-title">TRIP</div>
          <div class="login-feature-subtitle">PLANNING</div>
        </div>
        <div class="login-feature">
          <div class="login-feature-icon">🗺️</div>
          <div class="login-feature-title">REAL-TIME</div>
          <div class="login-feature-subtitle">TRACKING</div>
        </div>
        <div class="login-feature">
          <div class="login-feature-icon">💰</div>
          <div class="login-feature-title">FINANCIAL</div>
          <div class="login-feature-subtitle">DASHBOARD</div>
        </div>
        <div class="login-feature">
          <div class="login-feature-icon">📋</div>
          <div class="login-feature-title">DRIVER</div>
          <div class="login-feature-subtitle">PAYROLL</div>
        </div>
      </div>
    </div>
  `;

  // Login Form
  const loginForm = `
    <div class="login-form-card">
      <h2>Welcome back</h2>
      <p class="subtitle">Enter your credentials to continue</p>
      <div class="login-error" id="login-error"></div>
      <form onsubmit="handleLogin(event)">
        <div class="form-group">
          <label>${typeof t === 'function' ? t('email') : 'Email'}</label>
          <input type="email" id="login-email" required placeholder="you@company.com">
        </div>
        <div class="form-group">
          <label>${typeof t === 'function' ? t('password') : 'Password'}</label>
          <input type="password" id="login-password" required placeholder="Your password">
          <a href="#" onclick="showForgotPassword();return false;" style="font-size:12px;color:#22c55e;text-decoration:none;display:block;text-align:right;margin-top:6px">Forgot password?</a>
        </div>
        <button type="submit" class="btn-submit" id="login-btn">${typeof t === 'function' ? t('sign_in') : 'Sign In'}</button>
      </form>
      <div style="text-align:center;margin-top:20px;padding-top:20px;border-top:1px solid var(--border)">
        <p style="color:var(--text-secondary);font-size:13px;margin:0">
          🚗 Are you a dealer? <a href="#" onclick="showDealerLoginInfo();return false;" style="color:#22c55e;text-decoration:none;font-weight:500">Dealer Portal</a>
        </p>
      </div>
    </div>
  `;

  // Footer bar
  const footerBar = `
    <div class="login-footer-bar">
      <span>Powered by <strong>Horizon Star LLC</strong></span>
      <span>•</span>
      <span>Built by <a href="#">Levani Grigolia</a></span>
    </div>
  `;

  document.getElementById('app').innerHTML = `
    <div class="login-container">
      ${particlesHtml}
      ${navBar}
      <div class="login-hero">
        ${heroContent}
        ${loginForm}
      </div>
      ${footerBar}
    </div>
  `;
}

/**
 * Handle login form submission
 * @param {Event} e - Form submit event
 */
async function handleLogin(e) {
  e.preventDefault();
  const email = document.getElementById('login-email').value.trim().toLowerCase();
  const password = document.getElementById('login-password').value;
  const errorEl = document.getElementById('login-error');
  const btnEl = document.getElementById('login-btn');

  // Check if account is locked
  const lockStatus = isAccountLocked(email);
  if (lockStatus.locked) {
    errorEl.textContent = `Account locked. Try again in ${lockStatus.remainingMinutes} minutes.`;
    errorEl.style.display = 'block';
    return;
  }

  btnEl.textContent = 'Signing in...';
  btnEl.disabled = true;

  try {
    // Try Supabase Auth first
    const { data: authData, error: authError } = await sb.auth.signInWithPassword({
      email: email,
      password: password
    });

    if (!authError && authData.session) {
      // Supabase Auth success - store session
      authSession = authData.session;
      recordLoginAttempt(email, true);

      // Get user from our users table
      let users = await dbFetch('users', { filter: { email: 'eq.' + email } });

      if (users.length === 0) {
        // Create user record if doesn't exist (new Supabase Auth user)
        const newUser = await dbInsert('users', {
          auth_id: authData.user.id,
          email: email,
          first_name: authData.user.user_metadata?.first_name || email.split('@')[0],
          last_name: authData.user.user_metadata?.last_name || '',
          role: 'DISPATCHER',
          is_active: true
        });
        users = [newUser];
      } else if (!users[0].auth_id) {
        // Link existing user to Supabase Auth
        await dbUpdate('users', users[0].id, { auth_id: authData.user.id });
        users[0].auth_id = authData.user.id;
      }

      currentUser = users[0];
      localStorage.setItem('horizonstar_user', JSON.stringify(currentUser));
      startSessionMonitor();
      await logActivity('LOGIN_SUCCESS', { email, method: 'supabase_auth' });

      // Redirect dealers to dealer dashboard
      if (currentUser.role === 'DEALER') {
        currentPage = 'dealer_dashboard';
      }

      renderApp();
      return;
    }

    // Supabase Auth failed - try legacy login for migration
    const users = await dbFetch('users', { filter: { email: 'eq.' + email } });

    if (users.length === 0) {
      recordLoginAttempt(email, false);
      const attempts = getLoginAttempts(email);
      const remaining = LOGIN_ATTEMPT_LIMIT - attempts.count;
      errorEl.textContent = `Invalid credentials. ${remaining} attempts remaining.`;
      errorEl.style.display = 'block';
      btnEl.textContent = 'Sign In';
      btnEl.disabled = false;
      return;
    }

    const user = users[0];

    // Check if user is active
    if (user.is_active === false) {
      errorEl.textContent = 'Account deactivated.';
      errorEl.style.display = 'block';
      btnEl.textContent = 'Sign In';
      btnEl.disabled = false;
      return;
    }

    // Check legacy password (for users not yet migrated to Supabase Auth)
    const hashedPassword = await hashPassword(password);
    const passwordMatch = user.password === hashedPassword || user.password === password;

    if (!passwordMatch) {
      recordLoginAttempt(email, false);
      const attempts = getLoginAttempts(email);

      if (attempts.count >= LOGIN_ATTEMPT_LIMIT) {
        errorEl.textContent = `Too many attempts. Account locked for ${LOGIN_LOCKOUT_MINUTES} minutes.`;
      } else {
        const remaining = LOGIN_ATTEMPT_LIMIT - attempts.count;
        errorEl.textContent = `Invalid password. ${remaining} attempts remaining.`;
      }
      errorEl.style.display = 'block';
      btnEl.textContent = 'Sign In';
      btnEl.disabled = false;
      return;
    }

    // Legacy password matched - migrate to Supabase Auth
    recordLoginAttempt(email, true);

    // Try to sign in with Supabase Auth first (user might already exist there)
    let { data: signInData, error: signInError } = await sb.auth.signInWithPassword({
      email: email,
      password: password
    });

    if (signInError) {
      // User doesn't exist in Supabase Auth - create account
      const { data: signUpData, error: signUpError } = await sb.auth.signUp({
        email: email,
        password: password,
        options: {
          data: {
            first_name: user.first_name,
            last_name: user.last_name
          }
        }
      });

      if (!signUpError && signUpData.user) {
        // Update user with auth_id
        try {
          await dbUpdate('users', user.id, { auth_id: signUpData.user.id });
          user.auth_id = signUpData.user.id;
        } catch (e) { console.error('Update auth_id error:', e); }

        // Sign in immediately after signup
        const { data: newSignIn } = await sb.auth.signInWithPassword({
          email: email,
          password: password
        });
        if (newSignIn?.session) {
          authSession = newSignIn.session;
        }
      }
    } else if (signInData?.session) {
      // Successfully signed in to existing Supabase Auth account
      authSession = signInData.session;

      // Link auth_id if not linked yet
      if (!user.auth_id && signInData.user) {
        try {
          await dbUpdate('users', user.id, { auth_id: signInData.user.id });
          user.auth_id = signInData.user.id;
        } catch (e) { console.error('Update auth_id error:', e); }
      }
    }

    currentUser = user;
    localStorage.setItem('horizonstar_user', JSON.stringify(currentUser));
    startSessionMonitor();
    await logActivity('LOGIN_SUCCESS', { email, method: 'legacy_migrated' });

    // Redirect dealers to dealer dashboard
    if (currentUser.role === 'DEALER') {
      currentPage = 'dealer_dashboard';
    }

    renderApp();

  } catch (err) {
    console.error('Login error:', err);
    errorEl.textContent = 'Connection error';
    errorEl.style.display = 'block';
    btnEl.textContent = 'Sign In';
    btnEl.disabled = false;
  }
}

/**
 * Log out the current user
 */
async function logout() {
  // Log activity before clearing user
  if (currentUser) {
    await logActivity('LOGOUT', { email: currentUser.email });
  }

  // Update loading message
  const loadingMsg = document.getElementById('loading-message');
  if (loadingMsg) loadingMsg.textContent = 'Logging out';

  // Show loading animation
  const loadingOverlay = document.getElementById('loading-overlay');
  if (loadingOverlay) loadingOverlay.classList.add('show');

  // Sign out from Supabase Auth
  try {
    await sb.auth.signOut();
  } catch (e) { /* Ignore signout errors */ }

  // Clear session monitor
  if (sessionTimeoutId) {
    clearInterval(sessionTimeoutId);
    sessionTimeoutId = null;
  }

  // Clear user data and session
  currentUser = null;
  authSession = null;
  localStorage.removeItem('horizonstar_user');
  localStorage.removeItem('last_activity');
  protectedAccessGranted = false;

  // Redirect after 2.5 seconds
  setTimeout(() => {
    window.location.href = 'index.html';
  }, 2500);
}

// ============ FORGOT PASSWORD ============

/**
 * Show forgot password modal
 */
function showForgotPassword() {
  const m = document.createElement('div');
  m.className = 'modal-overlay';
  m.onclick = e => { if (e.target === m) m.remove(); };
  m.innerHTML = `
    <div class="modal" style="max-width:420px">
      <div class="modal-header">
        <h3>🔐 Reset Password</h3>
        <button class="modal-close" onclick="this.closest('.modal-overlay').remove()">×</button>
      </div>
      <div class="modal-body">
        <div id="forgot-step-1">
          <p style="color:var(--text-secondary);margin-bottom:20px;font-size:14px">
            Enter your email and we'll help you reset your password.
          </p>
          <div class="form-group">
            <label>Email</label>
            <input type="email" id="forgot-email" placeholder="your@email.com">
          </div>
          <div id="forgot-error" style="color:#ef4444;font-size:13px;margin-bottom:12px;display:none"></div>
        </div>
        <div id="forgot-step-2" style="display:none">
          <p style="color:var(--text-secondary);margin-bottom:20px;font-size:14px">
            Enter your new password.
          </p>
          <div class="form-group">
            <label>New Password</label>
            <input type="password" id="forgot-new-password" placeholder="Min 6 characters">
          </div>
          <div class="form-group">
            <label>Confirm Password</label>
            <input type="password" id="forgot-confirm-password" placeholder="Confirm">
          </div>
          <div id="forgot-error-2" style="color:#ef4444;font-size:13px;margin-bottom:12px;display:none"></div>
        </div>
        <div id="forgot-success" style="display:none;text-align:center;padding:20px">
          <div style="font-size:48px;margin-bottom:16px">✅</div>
          <p style="color:var(--accent-primary);font-weight:600">Password reset successful!</p>
        </div>
      </div>
      <div class="modal-footer" id="forgot-footer">
        <button class="btn btn-secondary" onclick="this.closest('.modal-overlay').remove()">Cancel</button>
        <button class="btn btn-primary" id="forgot-btn" onclick="handleForgotStep1()">Continue</button>
      </div>
    </div>
  `;
  document.body.appendChild(m);
}

/**
 * Handle forgot password step 1 - verify email
 */
async function handleForgotStep1() {
  const email = document.getElementById('forgot-email').value.trim().toLowerCase();
  const errorEl = document.getElementById('forgot-error');
  const btn = document.getElementById('forgot-btn');

  if (!email) {
    errorEl.textContent = 'Please enter your email';
    errorEl.style.display = 'block';
    return;
  }

  btn.disabled = true;
  btn.textContent = 'Verifying...';

  try {
    const users = await dbFetch('users', { filter: { email: 'eq.' + email } });

    if (users.length === 0) {
      errorEl.textContent = 'Email not found';
      errorEl.style.display = 'block';
      btn.disabled = false;
      btn.textContent = 'Continue';
      return;
    }

    // Store user for step 2
    window.forgotPasswordUser = users[0];

    // Log activity
    await logActivity('PASSWORD_RESET_REQUEST', { email });

    // Move to step 2
    document.getElementById('forgot-step-1').style.display = 'none';
    document.getElementById('forgot-step-2').style.display = 'block';
    btn.textContent = 'Reset Password';
    btn.disabled = false;
    btn.onclick = handleForgotStep2;

  } catch (e) {
    errorEl.textContent = 'Error: ' + e.message;
    errorEl.style.display = 'block';
    btn.disabled = false;
    btn.textContent = 'Continue';
  }
}

/**
 * Handle forgot password step 2 - set new password
 */
async function handleForgotStep2() {
  const newPassword = document.getElementById('forgot-new-password').value;
  const confirmPassword = document.getElementById('forgot-confirm-password').value;
  const errorEl = document.getElementById('forgot-error-2');
  const btn = document.getElementById('forgot-btn');

  if (newPassword.length < 6) {
    errorEl.textContent = 'Password must be at least 6 characters';
    errorEl.style.display = 'block';
    return;
  }

  if (newPassword !== confirmPassword) {
    errorEl.textContent = 'Passwords do not match';
    errorEl.style.display = 'block';
    return;
  }

  btn.disabled = true;
  btn.textContent = 'Resetting...';

  try {
    const hashedPassword = await hashPassword(newPassword);
    await dbUpdate('users', window.forgotPasswordUser.id, { password: hashedPassword });

    // Log activity
    await logActivity('PASSWORD_RESET_SUCCESS', { email: window.forgotPasswordUser.email });

    // Clear login attempts for this user
    const attempts = JSON.parse(localStorage.getItem('login_attempts') || '{}');
    delete attempts[window.forgotPasswordUser.email];
    localStorage.setItem('login_attempts', JSON.stringify(attempts));

    // Show success
    document.getElementById('forgot-step-2').style.display = 'none';
    document.getElementById('forgot-success').style.display = 'block';
    document.getElementById('forgot-footer').innerHTML = `
      <button class="btn btn-primary" onclick="this.closest('.modal-overlay').remove()">Close</button>
    `;

    delete window.forgotPasswordUser;

  } catch (e) {
    errorEl.textContent = 'Error: ' + e.message;
    errorEl.style.display = 'block';
    btn.disabled = false;
    btn.textContent = 'Reset Password';
  }
}

// ============ DEALER PORTAL INFO ============

/**
 * Show dealer portal information modal
 */
function showDealerLoginInfo() {
  const m = document.createElement('div');
  m.className = 'modal-overlay';
  m.onclick = e => { if (e.target === m) m.remove(); };
  m.innerHTML = `
    <div class="modal" style="max-width:500px">
      <div class="modal-header">
        <h3>🚗 Dealer Portal</h3>
        <button class="modal-close" onclick="this.closest('.modal-overlay').remove()">×</button>
      </div>
      <div class="modal-body" style="text-align:center;padding:30px">
        <div style="font-size:64px;margin-bottom:20px">🏪</div>
        <h3 style="margin-bottom:12px;color:var(--text-primary)">Welcome, Dealers!</h3>
        <p style="color:var(--text-secondary);margin-bottom:24px;line-height:1.6">
          The Dealer Portal allows you to submit vehicles for transport, track shipments, and view your spending history.
        </p>
        <div style="background:var(--bg-darker);border-radius:12px;padding:20px;text-align:left;margin-bottom:24px">
          <p style="font-weight:600;margin-bottom:12px;color:var(--text-primary)">✨ Portal Features:</p>
          <ul style="color:var(--text-secondary);margin:0;padding-left:20px;line-height:1.8">
            <li>Submit vehicles for transport</li>
            <li>Track order status in real-time</li>
            <li>View spending and financial history</li>
            <li>Manage your vehicle shipments</li>
          </ul>
        </div>
        <p style="color:var(--text-muted);font-size:13px">
          If you have dealer credentials, use them to log in above.<br>
          Need an account? Contact us at <strong style="color:#22c55e">info@horizonstarllc.com</strong>
        </p>
      </div>
      <div class="modal-footer">
        <button class="btn btn-primary" onclick="this.closest('.modal-overlay').remove()">Got it</button>
      </div>
    </div>
  `;
  document.body.appendChild(m);
}
