# Phase 24: Finance Pages Restyle - Research

**Researched:** 2026-03-13
**Domain:** CSS/HTML restyle of finance pages in single-file TMS web app
**Confidence:** HIGH

## Summary

This phase restyles six finance pages (Billing, Payroll, Financials, Trip Profitability, Fuel, IFTA) to match the Stripe/Linear flat aesthetic established in Phases 19-23. The codebase is a single `index.html` with inline render functions, CSS in `base.css` and `variables.css`, and no build step.

Research focused on: (1) cataloguing every finance render function and its current styling patterns, (2) identifying established CSS classes and patterns from prior restyled pages, (3) documenting specific anti-patterns (hardcoded hex colors, old stat-card patterns, gradient backgrounds) that need replacement, and (4) understanding print style requirements.

**Primary recommendation:** Systematically replace inline styles with established CSS classes (`stat-flat`, `data-table`, `segmented-control`, `stat-card-label`/`stat-card-value`) and swap hardcoded hex colors for CSS variables across all six finance render functions.

## Standard Stack

No new libraries needed. This is a pure CSS/HTML restyle within the existing codebase.

### Core CSS Classes (established in Phases 19-23)

| Class | Purpose | Where Defined |
|-------|---------|---------------|
| `.stat-flat` | Flat stat card (16px padding, bg-card, border, radius) | `base.css:1204` |
| `.stat-flat-label` | Stat label (13px, 500 weight, text-secondary) | `base.css:1210` |
| `.stat-flat-value` | Stat value (24px, 600 weight, tabular-nums) | `base.css:1216` |
| `.stat-card-label` | Dashboard label (11px, uppercase, letter-spacing) | `base.css:369` |
| `.stat-card-value` | Dashboard value (20px, 600 weight, font-mono) | `base.css:377` |
| `.stat-card-sub` | Sub-label text (11px, text-secondary) | `base.css:387` |
| `.stat-card--green/red/blue/purple/amber/slate` | Left-border accent variants | `base.css:394-399` |
| `.data-table` | Clean table (13px, sticky thead, alternating hover) | `base.css:566` |
| `.segmented-control` | Tab container (inline-flex, bg-tertiary, 2px padding) | `base.css:1231` |
| `.segmented-control-btn` | Tab button (6px 14px, 13px, transitions) | `base.css:1240` |
| `.segmented-control-btn.active` | Active tab (bg-card, shadow-xs, 600 weight) | `base.css:1254` |
| `.card-flush` | Card with no padding | `base.css:323` |
| `.stat-flat-delta.positive/.negative` | Delta indicators (green/red) | `base.css:1227-1228` |

### CSS Variables (from `variables.css`)

| Variable | Value | Use |
|----------|-------|-----|
| `--green` / `--success` | `#16a34a` | Profit, positive values |
| `--red` / `--danger` | `#dc2626` | Loss, negative values, overdue |
| `--amber` / `--warning` | `#d97706` | Caution, pending |
| `--blue` / `--info` | `#2563eb` | Informational, links |
| `--purple` | `#a855f7` | Accent |
| `--green-dim` etc. | `rgba(...)` 8% opacity | Dim background tints |
| `--bg-tertiary` | `#f1f5f9` | Summary row backgrounds, segmented controls |
| `--text-muted` | `#94a3b8` | Labels, secondary text |
| `--font-mono` | Defined in variables | Monetary values |

## Architecture Patterns

### Pattern 1: stat-flat Card (Established — Drivers, Brokers, Local Drivers)
**What:** Label-above-number flat card for stats, no icon, tight spacing.
**When to use:** All summary stat displays across finance pages.
**Example (from renderBrokers, line ~24506):**
```html
<div class="stat-flat">
  <div class="stat-flat-label">Total Brokers</div>
  <div class="stat-flat-value" style="font-family:var(--font-mono)">12</div>
</div>
```

### Pattern 2: segmented-control Tabs (Established — base.css)
**What:** Pill-style tab switcher with bg-tertiary container and active state.
**When to use:** Tab switching on billing (overview/brokers/invoices/collections), payroll (current/history), fuel (overview/analytics/efficiency/prices), financials (8 tabs).
**Example:**
```html
<div class="segmented-control">
  <button class="segmented-control-btn active" onclick="...">Overview</button>
  <button class="segmented-control-btn" onclick="...">Brokers</button>
</div>
```
For many tabs, use `segmented-control-scroll` variant (scrollable, no wrap).

### Pattern 3: data-table with Totals Row (Established — Trucks, Drivers)
**What:** Table using `.data-table` class with alternating hover, uppercase 11px headers, and totals row with `background:var(--bg-tertiary)` + top border separator.
**When to use:** All finance data tables (invoices, IFTA calculations, fuel transactions, trip profitability, payroll history).
**Example:**
```html
<table class="data-table">
  <thead><tr><th>Column</th></tr></thead>
  <tbody>
    <tr><td>Data</td></tr>
    <tr style="background:var(--bg-tertiary);border-top:2px solid var(--border)">
      <td><strong>TOTAL</strong></td>
    </tr>
  </tbody>
</table>
```

### Pattern 4: Page Header (14px/600 or 18px/700)
**What:** Compact page header matching established sizing.
**Current pages use `font-size:18px;font-weight:700;font-family:var(--font-display)` for main headers (billing) and `font-size:18px;font-weight:600` for drivers.
**Recommendation:** Use 18px/600 for primary page titles, 14px/600 for card section headers — consistent with Phase 23.

### Pattern 5: Filter Bar (Orders Pattern)
**What:** Horizontal layout with `.input`/`.select` component classes, consistent gap spacing.
**When to use:** Trip profitability filters, fuel tracking filters, IFTA quarter/year selector.

### Anti-Patterns to Avoid
- **Hardcoded hex in inline styles:** Replace `#22c55e` → `var(--green)`, `#ef4444` → `var(--red)`, `#64748b` → `var(--text-secondary)`, `#dc2626` → `var(--danger)`, `#3b82f6` → `var(--blue)`, `#1e40af`/`#1d4ed8` → `var(--blue)`, `#e2e8f0` → `var(--border)`, `#f8fafc` → `var(--bg-primary)`, `#059669` → `var(--green)`, `#d97706` → `var(--amber)`, `#f59e0b` → `var(--amber)`, `#f97316` → `var(--amber)` (or keep for orange accent)
- **Gradient backgrounds:** `linear-gradient(135deg,...)` on fuel Samsara card → replace with flat `var(--dim-blue)` or `var(--blue-dim)`
- **Old `.stat-card` with icon pattern:** The old stat-card had `.stat-icon` divs (44px colored squares) — payroll still uses this. Replace with stat-flat label-above-number.
- **Hardcoded light-mode-only backgrounds:** `#f0fdf4`, `#fee2e2`, `#d1fae5`, `#fef3c7` → use `var(--green-dim)`, `var(--red-dim)`, etc. for dark-mode compatibility
- **Inline `border-left: 4px solid` on stat cards** → use `.stat-card--green` etc. accent classes

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tab switching UI | Custom inline button styles | `.segmented-control` + `.segmented-control-btn` classes | Already defined, consistent with other pages |
| Stat card styling | Inline padding/border/font styles | `.stat-flat` + `.stat-flat-label`/`.stat-flat-value` | Eliminates 100+ lines of inline CSS per page |
| Table styling | Inline `<table>` with custom th/td styles | `.data-table` class | Gets sticky headers, hover states, alternating rows for free |
| Alternating row tint | Manual nth-child in JS | `.data-table` already has hover; add `tbody tr:nth-child(even)` rule if not present | One CSS rule vs repeating in each function |

## Common Pitfalls

### Pitfall 1: Breaking Dark Mode with Hardcoded Colors
**What goes wrong:** Hardcoded hex like `#f8fafc` (light background) or `color:#64748b` stays light-colored in dark theme.
**Why it happens:** Finance pages were built before the design system with CSS variables.
**How to avoid:** Replace EVERY hardcoded hex with the corresponding CSS variable. The aging bar in billing uses `#22c55e`, `#eab308`, `#f97316`, `#ef4444`, `#991b1b` — these are intentional brand colors for aging buckets and can remain hardcoded OR be mapped to new CSS custom properties.
**Warning signs:** Any `style="..."` containing `#` followed by 3 or 6 hex chars.

### Pitfall 2: Breaking Print Styles
**What goes wrong:** Print preview for billing/payroll stops rendering correctly after restyle.
**Why it happens:** Current print styles (lines 5863-5875 of index.html) are minimal — they just hide sidebar/mobile header. The paystub print page (lines ~34415-34454) has its own embedded styles.
**How to avoid:** After restyle, verify that (1) billing page prints cleanly with the new flat styling, (2) paystub/settlement print page is untouched or updated to match, (3) color-coded elements print in color (decision: no grayscale conversion).
**Warning signs:** Color elements that relied on hardcoded backgrounds may lose their meaning if changed to CSS variables that get overridden by print media queries.

### Pitfall 3: stat-card vs stat-flat Confusion
**What goes wrong:** Mixing old `.stat-card` (with `.stat-icon`, `.label`, `.value` children) and new `.stat-flat` (with `.stat-flat-label`, `.stat-flat-value` children).
**Why it happens:** The codebase has BOTH patterns. Payroll uses old `.stat-card`, billing overview uses custom inline card divs, brokers/drivers use `.stat-flat`.
**How to avoid:** Standardize ALL finance pages on `.stat-flat` with `.stat-flat-label`/`.stat-flat-value` children. The accent colors use `.stat-card--green` etc. for left-border accent.
**Warning signs:** Any render function using `<div class="stat-card">` with `<div class="label">` and `<div class="value">` children.

### Pitfall 4: Fuel Samsara Card Has Gradient
**What goes wrong:** The Samsara fleet mileage status card (fuel page, line ~25302) uses `linear-gradient(135deg,#dbeafe 0%,#e0f2fe 100%)` — this is an anti-pattern for the flat aesthetic.
**How to avoid:** Replace with flat `var(--blue-dim)` or `background:var(--dim-blue)` with solid border.

### Pitfall 5: Inconsistent Tab Patterns Across Finance Pages
**What goes wrong:** Each page uses a different tab mechanism:
- Billing: Custom inline `tabBtnStyle()` function generating segmented-control-like styles
- Payroll: `btn btn-primary`/`btn-secondary` toggle buttons
- Fuel: `btn btn-primary`/`btn-secondary` buttons
- Financials: `btn btn-primary`/`btn-secondary` buttons in `approved-scroll-x`
- IFTA: No tabs (single view)
- Trip Profitability: No tabs (single view with filter bar)

**How to avoid:** Standardize all tab UIs on `.segmented-control` (for <=5 tabs) or `.segmented-control-scroll` (for >5 tabs like Financials with 8 tabs).

## Code Examples

### Converting Payroll Stat Cards (Old → New)

**Before (current, line ~32204):**
```html
<div class="stat-card" style="border-left:4px solid var(--success)">
  <div class="stat-icon green">[[icon:money]]</div>
  <div class="stat-content">
    <div class="label">Total Net Payroll</div>
    <div class="value green">$12,500</div>
  </div>
</div>
```

**After (stat-flat pattern):**
```html
<div class="stat-flat stat-card--green">
  <div class="stat-flat-label">Total Net Payroll</div>
  <div class="stat-flat-value" style="font-family:var(--font-mono);color:var(--green)">$12,500</div>
</div>
```

### Converting Billing Tabs (Old → New)

**Before (custom inline, line ~29992):**
```javascript
const tabBtnStyle = (key) => {
  const isActive = billingTab === key;
  return 'padding:8px 16px;font-size:13px;...' +
    (isActive ? 'background:var(--bg-secondary)...' : '...');
};
html += '<div style="display:inline-flex;min-width:max-content;background:var(--bg-tertiary);...">';
html += '<button style="' + tabBtnStyle('overview') + '" onclick="...">Overview</button>';
```

**After (segmented-control class):**
```javascript
html += '<div class="segmented-control">';
html += '<button class="segmented-control-btn' + (billingTab === 'overview' ? ' active' : '') + '" onclick="...">Overview</button>';
html += '<button class="segmented-control-btn' + (billingTab === 'brokers' ? ' active' : '') + '" onclick="...">Brokers</button>';
html += '</div>';
```

### Converting IFTA Stat Cards (Old → New)

**Before (line ~26443):**
```html
<div class="stat-card" style="flex:0 0 auto;min-width:100px;padding:12px 16px">
  <div class="label">Total Miles</div>
  <div class="value">12,345</div>
</div>
```

**After:**
```html
<div class="stat-flat" style="flex:0 0 auto;min-width:100px">
  <div class="stat-flat-label">Total Miles</div>
  <div class="stat-flat-value" style="font-family:var(--font-mono)">12,345</div>
</div>
```

### Converting Totals Rows (Old → New)

**Before (IFTA, line ~26463):**
```html
<tr style="background:var(--surface-elevated);font-weight:700">
  <td>TOTAL</td><td>12,345.00</td>
</tr>
```

**After:**
```html
<tr style="background:var(--bg-tertiary);border-top:2px solid var(--border);font-weight:600">
  <td>TOTAL</td><td>12,345.00</td>
</tr>
```

### Aging Bar Decision (Claude's Discretion)

**Recommendation: Keep as visual element.** The stacked aging bar in billing overview (line ~30107) is a strong data visualization that gives immediate visual weight to the AR distribution. Converting to stat cards would lose this spatial encoding. The aging bar already uses clean flat segments with gap spacing — just needs hardcoded colors replaced with CSS variables or kept as intentional brand aging colors. The legend cards below the bar can stay as-is since they provide the numeric detail.

### Invoice Table Actions (Claude's Discretion)

**Recommendation: Inline buttons.** The invoice table rows already have inline action buttons (line ~30358+) and the billing page is action-heavy (mark invoiced, record payment, view details). Hover-reveal would hide important CTAs. Keep inline but use `.action-btn` classes for consistent sizing.

### Period Tabs (Claude's Discretion)

**Recommendation: segmented-control for billing/payroll.** Billing has 4 tabs (Overview, Brokers, Invoices, Collections) — fits perfectly in segmented-control. Payroll has 2 tabs (Run Payroll, Paystub History) — also fits. Financials has 8 tabs — use segmented-control-scroll.

### Finance Section Headers (Claude's Discretion)

**Recommendation: 14px/600 for card section headers, 18px/600 for page titles.** This matches the pattern established in Phase 23 (drivers page uses 18px/600 for page title, 14px/600 for card section headers like "Driver Qualification Files").

## Inventory of Finance Render Functions

### Functions to Restyle

| Function | Line | Page | Key Issues |
|----------|------|------|------------|
| `renderBillingPage()` | 29947 | Billing | Custom tab styles, inline stat cards with dot indicators |
| `renderBillingOverviewTab()` | 30038 | Billing | 8 custom inline stat cards, aging bar with hardcoded colors, broker table not using data-table |
| `renderBillingBrokersTab()` | 30195 | Billing | 4 inline stat cards, search bar with inline styles, table not using data-table |
| `renderBillingInvoicesTab()` | 30289 | Billing | Custom segmented filter (inline), invoice table with inline styles |
| `renderBillingCollectionsTab()` | 30705 | Billing | Collections cards/table |
| `renderPayroll()` | 32102 | Payroll | Old stat-card with icons, btn toggle tabs, driver cards with inline stat boxes |
| `renderConsolidatedFinancials()` | 36985 | Financials | btn toggle tabs (8 tabs), year selector |
| `renderFinOverview()` | 37111 | Financials | Old stat-card with hardcoded hex, financials-list rows with hardcoded borders |
| `renderFinCosts()` | ~37190+ | Financials | Cost tables |
| `renderFinByTrip()` | ~37200+ | Financials | Trip table |
| `renderFinByDriver()` | ~37300+ | Financials | Driver breakdown |
| `renderFinByBroker()` | ~37400+ | Financials | Broker breakdown |
| `renderFinByLane()` | ~37450+ | Financials | Lane breakdown |
| `renderTripProfitability()` | 37538 | Trip Profitability | Old stat-card, filter bar with inline styles, table with hardcoded hex, top/bottom performer cards |
| `renderFuelTracking()` | 25073 | Fuel | Old stat-card with hardcoded hex, gradient Samsara card, btn tabs, 4 sub-tab render functions |
| `renderFuelAnalyticsTab()` | 25408 | Fuel | Analytics sub-tab |
| `renderFuelEfficiencyTab()` | 25503 | Fuel | Efficiency sub-tab |
| `renderFuelPricesTab()` | 25584 | Fuel | Prices sub-tab |
| `renderIFTA()` | 26333 | IFTA | Old stat-card with hardcoded backgrounds (#fee2e2, #d1fae5), tables not using data-table |

### Functions NOT to Restyle (Print/Paystub)
- Paystub print page (lines ~34300-34500) — has its own embedded `<style>` block, separate document
- But per decision: "Print output matches the flat Stripe/Linear restyle" — so the in-page print `@media print` rules need auditing

## IFTA Collapsible Sections

Per decision: "IFTA state-by-state breakdown uses collapsible sections — collapsed by default, expand on click."

**Implementation approach:** Wrap each table section (Fuel by State, IFTA Calculation) in a collapsible container using a simple `onclick` toggle pattern already used elsewhere in the codebase. No library needed — just a click handler toggling `display:none` on the content div.

```html
<div class="card card-flush" style="margin-bottom:16px">
  <div onclick="this.nextElementSibling.style.display=this.nextElementSibling.style.display==='none'?'block':'none';this.querySelector('.collapse-icon').textContent=this.nextElementSibling.style.display==='none'?'▸':'▾'"
       style="padding:12px 16px;cursor:pointer;display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid var(--border)">
    <h3 style="margin:0;font-size:14px;font-weight:600">Fuel Purchased by State</h3>
    <span class="collapse-icon" style="color:var(--text-muted)">▸</span>
  </div>
  <div style="display:none">
    <!-- table content -->
  </div>
</div>
```

## Print Styles Audit

Current print styles are minimal:
1. **Global print** (index.html line 5863): Hides sidebar, mobile header, modals. Sets main margin/padding to 20px.
2. **Paystub print** (index.html line 34445): Sets body white, hides print button, removes page constraints.

**What needs updating:**
- The global `@media print` rule already works for the flat aesthetic (no gradients to hide)
- Color-coded elements (aging bar segments, profitability cells, status badges) will print in color — per decision
- Stat-flat cards will print fine since they use borders/backgrounds from CSS variables
- The paystub print page has its own styles and should NOT be modified (it's a separate document template)
- Add `@media print` rules to hide interactive elements (filter dropdowns, action buttons) that don't make sense on paper

## Open Questions

1. **Payroll driver cards layout — grid vs list?**
   - Current: Stacked card list (each card ~14px 16px padding, full width)
   - Options: Keep as list (fits payroll workflow of reviewing one driver at a time) or convert to grid like drivers page
   - Recommendation: Keep as list — payroll cards contain action buttons and detailed breakdown, better at full width

2. **Alternating row tint in CSS**
   - The `.data-table` class does NOT currently have `tbody tr:nth-child(even)` styling
   - Decision says "alternating row tint (nth-child(even) pattern)"
   - Need to add `data-table tbody tr:nth-child(even) { background: var(--bg-tertiary); }` to base.css OR use a modifier class like `.data-table-striped`
   - Recommendation: Add as `.data-table tbody tr:nth-child(even)` directly since the decision says all data-table pages use it

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection of `index.html` (all render functions read)
- `assets/css/base.css` — stat-flat, data-table, segmented-control classes verified
- `assets/css/variables.css` — all CSS custom properties verified

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no external libraries, all CSS classes verified in codebase
- Architecture: HIGH — patterns directly observed from Phase 23 restyled pages
- Pitfalls: HIGH — identified from direct code inspection of current finance pages

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (stable — internal codebase patterns, no external dependencies)
