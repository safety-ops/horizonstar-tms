const { test, expect } = require('@playwright/test');
const fs = require('fs');
const path = require('path');

const SCREENSHOT_DIR = path.join(__dirname, '..', 'output', 'mobile-screenshots');

const PAGES = [
  'dashboard',
  'orders',
  'trips',
  'drivers',
  'brokers',
  'trucks',
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
        await page.screenshot({
          path: path.join(viewportDir, filename),
          fullPage: true,
        });

        const hasIssues =
          audit.documentOverflow.hasDocumentOverflow ||
          audit.interactiveProblems.length > 0 ||
          audit.layoutProblems.length > 0;
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

        const result = {
          viewport: viewport.name,
          page: pageId,
          status,
          screenshot: filename,
          documentOverflow: audit.documentOverflow,
          interactiveProblems: audit.interactiveProblems,
          layoutProblems: audit.layoutProblems,
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
