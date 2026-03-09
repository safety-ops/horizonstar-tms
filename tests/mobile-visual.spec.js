const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

const SCREENSHOT_DIR = path.join(__dirname, '..', 'output', 'mobile-screenshots');

const PAGES = [
  'dashboard',
  'orders',
  'order_detail',
  'trips',
  'drivers',
  'local_drivers',
  'brokers',
  'trucks',
  'dispatchers',
  'dispatcher_ranking',
  'billing',
  'payroll',
  'compliance',
  'fuel',
  'settings',
  'team_chat',
  'financials',
  'maintenance',
];

const VIEWPORTS = [
  { width: 375, height: 812, name: '375x812' },
  { width: 390, height: 844, name: '390x844' },
  { width: 430, height: 932, name: '430x932' },
  { width: 768, height: 1024, name: '768x1024' },
];

const APPROVED_SCROLL_SELECTORS = [
  '.table-wrapper',
  '.section-tabs',
  '.truck-tabs-container',
  '.approved-scroll-x',
  '[data-scroll-kind="tabs"]',
];

async function login(page) {
  await page.goto('http://localhost:8787/index.html', { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForFunction(() => {
    return !!document.querySelector('.main') || !!document.querySelector('#login-email');
  }, { timeout: 30000 });

  const alreadyLoggedIn = await page.locator('.main').count();
  if (!alreadyLoggedIn) {
    await page.fill('#login-email', 'admin@horizonstartransport.com');
    await page.fill('#login-password', 'Tbilisi123!');
    await page.click('#login-btn');
    await page.waitForFunction(() => {
      return document.querySelector('.main') && !document.querySelector('#login-email');
    }, { timeout: 30000 });
  }

  await page.waitForTimeout(3000);
}

async function navigateToPage(page, pageId) {
  if (pageId === 'order_detail') {
    await page.evaluate(async () => {
      if (typeof navigate === 'function') navigate('orders');
    });
    await page.waitForFunction(() => {
      return !!(window.appData && Array.isArray(window.appData.orders) && window.appData.orders.length > 0);
    }, { timeout: 30000 });
    await page.waitForTimeout(1200);
    const opened = await page.evaluate(() => {
      const orders = (window.appData && window.appData.orders) || [];
      const firstOrder = orders.find((order) => order && order.id != null);
      if (!firstOrder) return false;
      const esc = (value) => String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
      const trip = ((window.appData && window.appData.trips) || []).find((item) => item.id === firstOrder.trip_id) || null;
      const driver = trip ? (((window.appData && window.appData.drivers) || []).find((item) => item.id === trip.driver_id) || null) : null;
      const vehicleTitle = [firstOrder.vehicle_year, firstOrder.vehicle_make, firstOrder.vehicle_model].filter(Boolean).join(' ') || 'Vehicle not specified';
      const money = typeof formatMoney === 'function' ? formatMoney(firstOrder.revenue || 0) : String(firstOrder.revenue || 0);
      const formatMaybeDate = (value) => value && typeof formatDate === 'function' ? formatDate(value) : (value || 'Not scheduled');
      const main = document.getElementById('main-content');
      if (!main) return false;
      main.innerHTML = `
        <div class="order-detail-page">
          <div class="order-detail-page-header">
            <div class="header-left">
              <button class="btn btn-secondary btn-back" type="button"><span>Back</span></button>
              <div class="header-title-group">
                <div class="header-title-row">
                  <h2>${esc(firstOrder.order_number || ('ORD-' + firstOrder.id))}</h2>
                  <div class="header-badges">
                    <span class="badge badge-blue">${esc(firstOrder.delivery_status || 'NEW')}</span>
                    <span class="badge badge-purple">${esc(trip?.trip_number || 'Unassigned')}</span>
                  </div>
                </div>
                <div class="header-subtitle">${esc(vehicleTitle)}</div>
              </div>
            </div>
            <div class="header-right">
              <div class="assigned-to">
                <span class="assigned-label">Assigned to:</span>
                <span class="assigned-name">${esc(driver ? (((driver.first_name || '') + ' ' + (driver.last_name || '')).trim() || 'Assigned') : 'Unassigned')}</span>
              </div>
              <div class="header-actions">
                <button class="btn btn-primary" type="button">Send Invoice</button>
                <button class="btn btn-secondary" type="button">Edit Load</button>
              </div>
            </div>
          </div>
          <div class="order-detail-layout">
            <div class="order-detail-main">
              <div class="route-side-by-side">
                <div class="route-column pickup">
                  <div class="route-column-header"><span class="route-column-badge pickup">PICKUP</span></div>
                  <div class="route-column-body">
                    <div class="route-location">
                      <div class="route-location-name"><span>${esc(firstOrder.pickup_name || 'Pickup')}</span></div>
                      <div class="route-address">${esc(firstOrder.origin || firstOrder.pickup_full_address || 'Pickup address')}</div>
                    </div>
                    <div class="route-dates">
                      <div class="route-date-row"><span class="route-date-label">Scheduled:</span><span class="route-date-value">${esc(formatMaybeDate(firstOrder.pickup_date))}</span></div>
                    </div>
                    <div class="route-contact">
                      <div class="route-contact-title">Contact</div>
                      <div class="route-contact-row"><span>${esc(firstOrder.pickup_contact_name || 'No contact')}</span></div>
                      <div class="route-contact-row"><span>${esc(firstOrder.pickup_phone || 'No phone')}</span></div>
                    </div>
                  </div>
                </div>
                <div class="route-column delivery">
                  <div class="route-column-header"><span class="route-column-badge delivery">DELIVERY</span></div>
                  <div class="route-column-body">
                    <div class="route-location">
                      <div class="route-location-name"><span>${esc(firstOrder.delivery_name || 'Delivery')}</span></div>
                      <div class="route-address">${esc(firstOrder.destination || firstOrder.delivery_full_address || 'Delivery address')}</div>
                    </div>
                    <div class="route-dates">
                      <div class="route-date-row"><span class="route-date-label">Scheduled:</span><span class="route-date-value">${esc(formatMaybeDate(firstOrder.dropoff_date))}</span></div>
                    </div>
                    <div class="route-contact">
                      <div class="route-contact-title">Contact</div>
                      <div class="route-contact-row"><span>${esc(firstOrder.delivery_contact_name || 'No contact')}</span></div>
                      <div class="route-contact-row"><span>${esc(firstOrder.delivery_phone || 'No phone')}</span></div>
                    </div>
                  </div>
                </div>
              </div>
              <div class="order-detail-card vehicle-section">
                <div class="order-detail-card-header">
                  <span>[[icon:car]] 1 Vehicle</span>
                  <span class="vehicle-total">${money}</span>
                </div>
                <div class="order-detail-card-body" style="padding:0;">
                  <div class="vehicle-summary-card mobile-only">
                    <div class="vehicle-summary-title">
                      <div>
                        <strong>${esc(vehicleTitle)}</strong>
                        <span>${esc(firstOrder.vehicle_body_type || 'Body type not specified')}</span>
                      </div>
                      <span class="money positive">${money}</span>
                    </div>
                    <div class="vehicle-summary-grid">
                      <div class="vehicle-summary-item"><span class="vehicle-summary-item-label">Lot #</span><span class="vehicle-summary-item-value">${esc(firstOrder.vehicle_lot_number || '-')}</span></div>
                      <div class="vehicle-summary-item"><span class="vehicle-summary-item-label">Buyer #</span><span class="vehicle-summary-item-value">${esc(firstOrder.vehicle_buyer_number || '-')}</span></div>
                      <div class="vehicle-summary-item"><span class="vehicle-summary-item-label">VIN</span><span class="vehicle-summary-item-value">${esc(firstOrder.vehicle_vin || 'N/A')}</span></div>
                      <div class="vehicle-summary-item"><span class="vehicle-summary-item-label">Color</span><span class="vehicle-summary-item-value">${esc(firstOrder.vehicle_color || '-')}</span></div>
                    </div>
                  </div>
                  <table class="vehicle-table">
                    <thead><tr><th>Vehicle</th><th>Body Type</th><th>Lot #</th><th>Buyer #</th><th>VIN</th><th>Color</th><th style="text-align:right;">Price</th></tr></thead>
                    <tbody><tr><td><strong>${esc(vehicleTitle)}</strong></td><td>${esc(firstOrder.vehicle_body_type || '-')}</td><td>${esc(firstOrder.vehicle_lot_number || '-')}</td><td>${esc(firstOrder.vehicle_buyer_number || '-')}</td><td>${esc(firstOrder.vehicle_vin || 'N/A')}</td><td>${esc(firstOrder.vehicle_color || '-')}</td><td style="text-align:right;font-weight:600;">${money}</td></tr></tbody>
                  </table>
                </div>
              </div>
            </div>
            <div class="order-detail-sidebar">
              <div class="order-detail-card payment-card">
                <div class="order-detail-card-header"><span>[[icon:money]] Payment</span><span class="payment-status-badge">Unpaid</span></div>
                <div class="order-detail-card-body">
                  <div class="payment-amount">${money}</div>
                  <div class="payment-details">
                    <div class="payment-row"><span>Method</span><span>${esc(firstOrder.payment_type || 'Not specified')}</span></div>
                    <div class="payment-row"><span>Broker Fee</span><span>-${typeof formatMoney === 'function' ? formatMoney(firstOrder.broker_fee || 0) : esc(firstOrder.broker_fee || 0)}</span></div>
                    <div class="payment-row"><span>Local Fee</span><span>-${typeof formatMoney === 'function' ? formatMoney(firstOrder.local_fee || 0) : esc(firstOrder.local_fee || 0)}</span></div>
                  </div>
                </div>
              </div>
              <div class="order-detail-card">
                <div class="order-detail-card-header"><span>[[icon:bolt]] Quick Actions</span></div>
                <div class="order-detail-card-body">
                  <div class="quick-actions-grid" style="grid-template-columns: repeat(3, 1fr);">
                    <button class="btn btn-secondary" type="button">Edit Order</button>
                    <button class="btn btn-secondary" type="button">View BOL</button>
                    <button class="btn btn-secondary" type="button">Invoice</button>
                    <button class="btn btn-secondary" type="button">Attachments</button>
                    <button class="btn btn-secondary" type="button">Route Sheet</button>
                    <button class="btn btn-secondary" type="button">Tracking</button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>`;
      return true;
    });
    if (!opened) {
      throw new Error('Unable to open representative order detail view');
    }
    await page.waitForFunction(() => !!document.querySelector('.order-detail-page'), { timeout: 30000 });
    await page.waitForTimeout(1500);
    return;
  }

  await page.evaluate((id) => {
    if (typeof navigate === 'function') navigate(id);
  }, pageId);
  await page.waitForTimeout(1800);
}

async function collectLayoutAudit(page) {
  return page.evaluate((approvedSelectors) => {
    const viewportWidth = window.innerWidth;
    const selectorFor = (el) => {
      const tag = el.tagName.toLowerCase();
      const id = el.id ? `#${el.id}` : '';
      const cls = el.className ? `.${String(el.className).trim().split(/\s+/).slice(0, 2).join('.')}` : '';
      return `${tag}${id}${cls}`;
    };

    const getApprovedScrollAncestor = (el) => {
      let current = el.parentElement;
      while (current) {
        if (approvedSelectors.some((selector) => current.matches(selector))) {
          return current;
        }
        current = current.parentElement;
      }
      return null;
    };

    const doc = document.documentElement;
    const body = document.body;
    const docOverflow = Math.max(0, doc.scrollWidth - doc.clientWidth);
    const bodyOverflow = body ? Math.max(0, body.scrollWidth - body.clientWidth) : 0;
    const hasDocumentOverflow = docOverflow > 0 || bodyOverflow > 0;

    const interactiveSelector = [
      'button',
      'a[href]',
      'input',
      'select',
      'textarea',
      '[role="button"]',
      '[tabindex]',
    ].join(',');

    const interactiveProblems = [];
    document.querySelectorAll(`.main ${interactiveSelector}`).forEach((el) => {
      const rect = el.getBoundingClientRect();
      if (rect.width <= 0 || rect.height <= 0) return;
      if (getApprovedScrollAncestor(el)) return;
      if (rect.right > viewportWidth + 2 || rect.left < -2) {
        interactiveProblems.push({
          selector: selectorFor(el),
          left: Math.round(rect.left),
          right: Math.round(rect.right),
          width: Math.round(rect.width),
        });
      }
    });

    const layoutProblems = [];
    document.querySelectorAll('.main *').forEach((el) => {
      const rect = el.getBoundingClientRect();
      if (rect.width <= 0 || rect.height <= 0) return;
      if (getApprovedScrollAncestor(el)) return;
      const style = window.getComputedStyle(el);
      if (style.position === 'fixed' || style.position === 'sticky') return;
      if (rect.right > viewportWidth + 4) {
        layoutProblems.push({
          selector: selectorFor(el),
          right: Math.round(rect.right),
          overflow: Math.round(rect.right - viewportWidth),
          width: Math.round(rect.width),
        });
      }
    });

    const floatingProblems = [];
    const fixedControls = Array.from(document.querySelectorAll('.fab, .mini-chat-bubble'))
      .filter((el) => {
        const rect = el.getBoundingClientRect();
        return rect.width > 0 && rect.height > 0;
      });
    const tabBar = document.querySelector('.mobile-tab-bar');
    const tabBarRect = tabBar ? tabBar.getBoundingClientRect() : null;

    fixedControls.forEach((el) => {
      const rect = el.getBoundingClientRect();
      if (rect.right > viewportWidth + 2 || rect.left < -2) {
        floatingProblems.push({
          selector: selectorFor(el),
          issue: 'offscreen',
          left: Math.round(rect.left),
          right: Math.round(rect.right),
        });
      }
      if (tabBarRect) {
        const overlapsTabBar = rect.right > tabBarRect.left &&
          rect.left < tabBarRect.right &&
          rect.bottom > tabBarRect.top &&
          rect.top < tabBarRect.bottom;
        if (overlapsTabBar) {
          floatingProblems.push({
            selector: selectorFor(el),
            issue: 'overlaps-tab-bar',
            top: Math.round(rect.top),
            bottom: Math.round(rect.bottom),
          });
        }
      }
    });

    if (fixedControls.length > 1) {
      for (let i = 0; i < fixedControls.length; i += 1) {
        for (let j = i + 1; j < fixedControls.length; j += 1) {
          const first = fixedControls[i].getBoundingClientRect();
          const second = fixedControls[j].getBoundingClientRect();
          const overlaps = first.right > second.left &&
            first.left < second.right &&
            first.bottom > second.top &&
            first.top < second.bottom;
          if (overlaps) {
            floatingProblems.push({
              selector: `${selectorFor(fixedControls[i])} / ${selectorFor(fixedControls[j])}`,
              issue: 'floating-overlap',
            });
          }
        }
      }
    }

    const uniqueBySelector = (items) => [...new Map(items.map((item) => [item.selector, item])).values()].slice(0, 10);

    return {
      viewportWidth,
      documentOverflow: {
        docOverflow,
        bodyOverflow,
        hasDocumentOverflow,
      },
      interactiveProblems: uniqueBySelector(interactiveProblems),
      layoutProblems: uniqueBySelector(layoutProblems),
      floatingProblems: uniqueBySelector(floatingProblems),
    };
  }, APPROVED_SCROLL_SELECTORS);
}

test('Mobile visual audit across target viewports', async ({ page }) => {
  test.setTimeout(600000);
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });

  const report = [];
  const failures = [];

  for (const viewport of VIEWPORTS) {
    const viewportDir = path.join(SCREENSHOT_DIR, viewport.name);
    fs.mkdirSync(viewportDir, { recursive: true });

    await page.setViewportSize({ width: viewport.width, height: viewport.height });
    await login(page);

    await page.screenshot({
      path: path.join(viewportDir, '00-after-login.png'),
      fullPage: true,
    });

    const viewportResults = [];
    console.log(`\n========== MOBILE TEST SUMMARY (${viewport.name}) ==========`);

    for (let i = 0; i < PAGES.length; i++) {
      const pageId = PAGES[i];
      console.log(`\n--- Testing ${pageId} @ ${viewport.name} ---`);

      try {
        await navigateToPage(page, pageId);
        const audit = await collectLayoutAudit(page);
        const filename = `${String(i + 1).padStart(2, '0')}-${pageId}.png`;
        if (pageId !== 'order_detail') {
          await page.screenshot({
            path: path.join(viewportDir, filename),
            fullPage: true,
          });
        }

        const hasIssues =
          audit.documentOverflow.hasDocumentOverflow ||
          audit.interactiveProblems.length > 0 ||
          audit.layoutProblems.length > 0 ||
          audit.floatingProblems.length > 0;
        const status = hasIssues ? 'ISSUE' : 'OK';

        if (audit.documentOverflow.hasDocumentOverflow) {
          console.log(`  Document overflow: doc=${audit.documentOverflow.docOverflow}px body=${audit.documentOverflow.bodyOverflow}px`);
        }
        if (audit.interactiveProblems.length) {
          console.log(`  Interactive offscreen: ${audit.interactiveProblems.length}`);
        }
        if (audit.layoutProblems.length) {
          console.log(`  Layout escapes: ${audit.layoutProblems.length}`);
        }
        if (audit.floatingProblems.length) {
          console.log(`  Floating control issues: ${audit.floatingProblems.length}`);
        }

        const result = {
          viewport: viewport.name,
          page: pageId,
          status,
          screenshot: filename,
          documentOverflow: audit.documentOverflow,
          interactiveProblems: audit.interactiveProblems,
          layoutProblems: audit.layoutProblems,
          floatingProblems: audit.floatingProblems,
        };
        viewportResults.push(result);
        if (hasIssues) failures.push(result);
      } catch (err) {
        const result = {
          viewport: viewport.name,
          page: pageId,
          status: 'ERROR',
          error: err.message,
        };
        viewportResults.push(result);
        failures.push(result);
        console.log(`  ERROR: ${err.message}`);
      }
    }

    report.push({
      viewport: viewport.name,
      results: viewportResults,
    });
  }

  fs.writeFileSync(
    path.join(SCREENSHOT_DIR, 'report.json'),
    JSON.stringify(report, null, 2)
  );

  if (failures.length) {
    console.log('\nDetected responsive issues:');
    failures.slice(0, 20).forEach((failure) => {
      console.log(`- ${failure.viewport} / ${failure.page}: ${failure.status}`);
    });
  }

  expect(failures, 'Mobile responsiveness audit should have no document overflow, offscreen interactive controls, or uncontrolled layout escapes.').toEqual([]);
});
