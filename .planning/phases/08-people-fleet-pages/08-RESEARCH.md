# Phase 8: People & Fleet Pages - Research

**Researched:** 2026-02-09
**Domain:** Production UI structure mapping for UI-only mockup redesign
**Confidence:** HIGH

## Summary

This phase requires creating UI-only mockups for 5 people and fleet management pages by extracting the exact structure, sections, data fields, and relationships from the production code in `index.html`. All pages follow a consistent pattern of render functions that build HTML via template literals.

The production code uses:
- **Card-based layouts** for Drivers and Brokers with dense information display
- **Table-based layouts** for Trucks, Dispatchers, and Local Drivers
- **Detail views** accessed via "View" buttons that replace the entire page content
- **Document management systems** for both drivers and trucks with expiration tracking
- **Computed metrics and rankings** for Brokers with reliability scoring
- **Complex status systems** for Local Drivers with 5-state color coding

All pages must preserve exact data field placement, badge types, action buttons, and computational logic in the mockup design.

**Primary recommendation:** Map every production data field, badge, status indicator, and computed metric to Phase 6 design system components. Use realistic 2026 sample data showing all visual states.

## Standard Stack

### Production Code Patterns
| Pattern | Usage | Source Location |
|---------|-------|-----------------|
| Render functions | All pages | `renderDrivers()` (line 18149), `renderTrucks()` (18622), `renderLocalDrivers()` (18832), `renderBrokers()` (19306), `renderDispatchers()` (19535) |
| Detail view functions | Drivers, Trucks, Local Drivers | `viewDriverProfile()` (18190), `viewTruckCompliance()` (22537), `viewLocalDriverDetails()` (19141) |
| Template literals | HTML generation | All render functions use `c.innerHTML = '<div>...'` pattern |
| Inline badge logic | Status display | `getBadge()` helper function for status badges |
| Computed metrics | Brokers, Drivers | Inline reduce/filter calculations in render functions |

### Design System Components (Phase 6)
| Component | Purpose | CSS Classes |
|-----------|---------|-------------|
| Cards | Driver/Broker cards, section containers | `.card`, `.card-header`, `.card-title` |
| Tables | Trucks, Dispatchers, Local Drivers | `.table`, `.table-container`, `.table-wrapper` |
| Badges | Status indicators | `.badge`, `.badge-green`, `.badge-amber`, `.badge-red`, `.badge-blue`, `.badge-purple`, `.badge-gray` |
| Stat cards | Metrics display | `.stat-card`, `.stat-icon`, `.stat-value`, `.stat-label` |
| Hero cards | Summary sections | `.hero-card` with color variants |
| Buttons | Actions | `.btn`, `.btn-primary`, `.btn-secondary`, `.action-btn` |

## Architecture Patterns

### Page Structure Pattern

All 5 pages follow this consistent structure:

```javascript
function renderPageName(c) {
  // 1. Clear detail view flag (for pages with detail views)
  currentDetailView = null;

  // 2. Calculate aggregate data and stats
  const stats = /* compute from appData */;

  // 3. Build HTML with sections:
  c.innerHTML =
    '<div class="header">...</div>' +  // Page title + action buttons
    '<!-- Alert/Summary section (optional) -->' +
    '<!-- Stats cards (optional) -->' +
    '<!-- Main content (cards grid or table) -->' +
    '<!-- Additional sections (optional) -->';
}
```

### Detail View Pattern

Pages with detail views (Drivers, Trucks, Local Drivers):

```javascript
function viewEntityDetail(entityId) {
  // 1. Set detail view flag to prevent re-renders
  currentDetailView = { type: 'driver', id: entityId };

  // 2. Fetch entity data
  const entity = appData.entities.find(x => x.id === entityId);
  if (!entity) {
    // Entity deleted - return to list
    currentDetailView = null;
    renderPageList(document.getElementById('main-content'));
    return;
  }

  // 3. Build detail view with multiple sections
  c.innerHTML =
    '<div class="header">Back button + entity name + Edit</div>' +
    '<!-- Stats cards -->' +
    '<!-- Section 1: Primary data table -->' +
    '<!-- Section 2: Secondary data table -->' +
    '<!-- Section 3+: Additional sections -->';
}
```

### Data Field Organization

**Pattern for dense information cards (Drivers, Brokers):**
```
Card Header: Name/ID + Primary badge
Card Body:
  - Contact info (phone, email)
  - File/compliance badges
  - Computed metrics
  - Action buttons (View, Edit, Delete)
```

**Pattern for tables (Trucks, Dispatchers, Local Drivers):**
```
Table Header: Column names
Table Body:
  - Primary identifier (bold)
  - Status badges
  - Numeric data (formatted)
  - Actions column (sticky)
```

## Production Page Specifications

### PEOPLE-01: Drivers List

**File:** `index.html`, function `renderDrivers()` at line 18149

**Sections (in order):**
1. **Header**: Title "👥 Drivers" + 2 buttons (+ New Driver, + Add Owner-OP)
2. **Document Expiration Alerts Banner** (if any drivers have expiring/expired docs):
   - Red background with warning icon
   - Shows driver name, document type, days until expiry
   - Badge colors: red (expired), amber (expiring)
3. **Drivers Grid** (`.drivers-grid` - card layout)

**Driver Card Data Fields:**
- **Top Row**:
  - Avatar circle (initials)
  - Name (h4)
  - Driver type badge ("Owner-OP" if applicable - orange badge)
  - Percentage label (e.g., "32% cut" or "15% dispatch fee")
  - Status badge (right-aligned)
- **Contact Row**:
  - Phone (📞 icon)
  - Email (📧 icon, if present)
- **File/Compliance Badges Row**:
  - Qualification files count (blue background: "📁 X Qual")
  - Personal files count (purple background: "🔒 X Pers")
  - Expired files count (red background: "⚠️ X Exp", only if > 0)
  - Open tickets count (amber background: "🎫 X", only if > 0)
  - Open violations count (pink background: "⚠️ X", only if > 0)
  - Open claims count (orange background: "💥 X", only if > 0)
- **Bottom Stats Row** (border-top separator):
  - Trips count + label
  - Earnings (green, formatted money) + label
  - Action buttons: View | Edit | Del

**Computed Metrics:**
- Total trips: `appData.trips.filter(t => t.driver_id === d.id).length`
- Earnings: Sum of `getTripFin(t.id).driverCut` for all trips
- File counts: Filter `appData.driver_files` by category
- Open tickets/violations/claims: Filter by driver_id and status

### PEOPLE-02: Driver Detail View

**File:** `index.html`, function `viewDriverProfile()` at line 18190

**Sections (in order):**
1. **Header**:
   - Back button
   - Avatar (larger, 50px)
   - Name + contact info
   - Status badge
   - Edit Driver button (right)
2. **Stats Cards Row** (6 stat cards):
   - Driver Cut %
   - Total Trips
   - Total Earnings (green background)
   - Qualification Files (X/10)
   - Personal Files (X/3)
   - Custom Folders count (blue background)
3. **Driver Qualification Files Section** (blue header):
   - Table with columns: Document Type | Status | Expiration | Uploaded | Actions
   - 10 required file types:
     - CDL (has expiry)
     - MEDICAL_CARD (has expiry)
     - MEDICAL_EXAMINER_VERIFICATION
     - MVR (has expiry)
     - PSP_REPORT (has expiry)
     - EMPLOYMENT_VERIFICATION
     - APPLICATION_OF_EMPLOYMENT
     - CLEARING_HOUSE_QUERY
     - DRUG_TEST_RESULT
     - CHAIN_OF_CUSTODY
   - Status badges: green "✓ Uploaded" or gray "Missing"
   - Expiration badges: red (expired), amber (< 7d), green (valid)
   - Actions: View + Del (if uploaded), or Upload button (if missing)
4. **Driver Personal Files Section** (purple header):
   - Table with columns: Document Type | Status | Uploaded | Actions
   - 3 file types: SSN, BANKING_INFO, W9
   - Same status/action pattern as qualification files
5. **Custom Folders Section** (cyan header with + New Folder button):
   - Accordion-style expandable folders
   - Each folder shows:
     - Folder name + file count
     - + Add File button
     - Table: File Name | Type | Uploaded | Notes | Actions
6. **Compliance Record Section** (red header with + Ticket, + Violation, + Claim buttons):
   - Summary badges row showing open/closed counts
   - Driver fault paid amount (if any)
   - Three subsections:
     - **Tickets table**: Date | Description | Status | Court Date | Decision | Actions
     - **Violations table**: Date | Type | Description | Severity | Status | Actions
     - **Claims table**: Date | Type | Fault | Amount | Status | Actions

### PEOPLE-03: Local Drivers List

**File:** `index.html`, function `renderLocalDrivers()` at line 18832

**Sections (in order):**
1. **Header**:
   - Title "🚙 Local Drivers"
   - Year selector dropdown (default: current year, shows 4 years)
   - + Add Local Driver button
2. **Stats Cards Row** (5 stat cards):
   - Local Drivers count
   - Pending Pickup count (blue background)
   - Pending Delivery count (amber background)
   - Total Pending Fees (red money value)
   - Total Delivery Revenue (green background)
3. **Local Drivers List Card** (table):
   - Columns: Name | Phone | Area | Total Jobs | Pending | Total Earnings | Actions
   - Actions: View | Edit | Del
4. **Pending Local Pickup Section** (blue header):
   - Info bar: Description + status legend (🔵 Pending | 🟠 Scheduled | 🟡 Confirmed | 🟢 Ready | 🔴 Issue)
   - Table (14 columns): Status | Order | Broker | Vehicle | Origin | 📞P | Destination | Pick-Up | Delivery | Payment | Broker Fee | Local Fee | Revenue | Actions (sticky)
   - Row background colors based on confirmation status:
     - pending: #dbeafe (blue)
     - scheduled: #ffedd5 (orange)
     - confirmed: #fef9c3 (yellow)
     - ready: #dcfce7 (green)
     - issue: #fee2e2 (red)
   - Status icon clickable to cycle through states
   - Local notes shown in expandable row below if present
   - Actions: 📝 Note | Assign (green) | Not Local (gray)
5. **Pending Local Delivery Section** (amber header):
   - Same structure as Pickup section
   - Table has 15 columns (adds "Trip" column)
   - Same status color system

**Key Features:**
- Year filtering affects stats and local driver earnings calculations
- Status cycling: pending → scheduled → confirmed → ready → issue → pending
- Phone numbers are clickable `tel:` links
- Full-row background colors for status visualization
- Separate note rows in purple background when local_notes exist

### PEOPLE-04: Local Driver Detail View

**File:** `index.html`, function `viewLocalDriverDetails()` at line 19141

**Sections (in order):**
1. **Header**: Back button + driver name
2. **Stats Cards Row** (6 stat cards):
   - Total Deliveries
   - Completed (green)
   - Pending (amber)
   - 🟡 Pickups (amber background)
   - 🔘 Deliveries (gray background)
   - Total Earnings (green background)
3. **Driver Info Card**:
   - Phone, Service Area, Notes (if any)
4. **Assigned Orders Table**:
   - Columns: Order | Type | Vehicle | Origin | Destination | Pickup | Delivery | Local Fee | Status | Actions
   - Type badges: 🟡 Pickup or 🔘 Delivery
   - Status badges for delivery status
   - Actions: Mark Delivered | Edit

**Data Filtering:**
- All stats and orders filtered by `localDriversYear` (global variable)
- Date range: `YYYY-01-01` to `YYYY-12-31`

### PEOPLE-05: Trucks List

**File:** `index.html`, function `renderTrucks()` at line 18622

**Sections (in order):**
1. **Header**: Title "🚚 Fleet" + New Unit button
2. **Trucks Table**:
   - Columns: Unit # | Type | Year/Make/Model | VIN | Plate | Ownership | Compliance | Status | Actions (sticky)
   - **Unit # cell**:
     - Truck number (bold, with #)
     - TRAILER badge (gray) if vehicle_type is TRAILER
     - Assigned trailer badge (blue, clickable) if truck has trailer assigned
   - **Type cell**: Truck type + capacity (e.g., "8 cars")
   - **Year/Make/Model cell**: Combined string + color (muted text) if present
   - **VIN cell**: Last 6 characters only, monospace font
   - **Plate cell**: Plate number + state badge (blue)
   - **Ownership cell**: Badge (green=OWNED, amber=LEASED, blue=FINANCED)
   - **Compliance cell**: "✓ OK" (green) or "X Issues" (red) based on:
     - Cab card expiration
     - Annual inspection expiration
     - 2290 paid status
     - IFTA decal status
   - **Status cell**: Badge (ACTIVE, INACTIVE, MAINTENANCE, SOLD)
   - **Actions**: Files | Edit | Del

**Compliance Logic:**
```javascript
const complianceIssues =
  (cabCardExpired ? 1 : 0) +
  (annualExpired ? 1 : 0) +
  (!t.is_2290_paid ? 1 : 0) +
  (!t.has_ifta_decal ? 1 : 0);
```

### PEOPLE-06: Truck Detail View (Compliance Files)

**File:** `index.html`, function `viewTruckCompliance()` at line 22537

**Sections (in order):**
1. **Header**: Back to Compliance button + Truck # + status badge
2. **Stats Cards Row** (stats computed from files and maintenance):
   - Compliance files count
   - Custom folders count
   - Total maintenance cost (computed from maintenance_records)
3. **Truck Compliance Files Section** (amber header):
   - Table: Document Type | Status | Expiration | Uploaded | Actions
   - 8 required file types:
     - VEHICLE_REGISTRATION (has expiry)
     - ANNUAL_INSPECTION (has expiry)
     - PA_INSPECTION (has expiry)
     - INSURANCE_CARD (has expiry)
     - TITLE
     - LEASE_AGREEMENT (has expiry)
     - IRP_CAB_CARD (has expiry)
     - IFTA_PERMIT (has expiry)
   - Same expiration badge logic as Driver files
4. **Custom Folders Section** (cyan header with + New Folder button):
   - Same accordion pattern as Driver detail
   - Table: File Name | Type | Uploaded | Notes | Actions
5. **Maintenance Records Section** (green header with + Add Service Record button):
   - Table: Date | Service Type | Shop | Description | Odometer | Cost | Actions

**Key Features:**
- File expiration tracking with color-coded badges
- Custom folder system for additional documents
- Maintenance history tracking
- Back button returns to Compliance page (not Trucks page)

### PEOPLE-07: Brokers List

**File:** `index.html`, function `renderBrokers()` at line 19306

**Sections (in order):**
1. **Header**: Title "🏢 Brokers" + New Broker button
2. **Summary Cards Row** (4 gradient cards):
   - Total Brokers (blue gradient)
   - Total Revenue (green gradient)
   - Avg Fee % (amber gradient)
   - Est. Total Profit (purple gradient)
3. **Broker Cards Grid** (responsive grid: auto-fill, minmax(340px, 1fr))

**Each Broker Card Contains:**
- **Card Header** (dark gradient background):
  - Ranking medal (🥇 🥈 🥉 for top 3 by profit)
  - Broker name (18px bold)
  - Load/trip counts (12px)
  - Activity status badge (Active/Recent/Inactive/Dormant) - right aligned
- **Reliability Score Bar** (light background):
  - Score label + percentage (0-100)
  - Colored label: Excellent (≥80), Good (≥60), Fair (≥40), New (<40)
  - Progress bar with dynamic color (green, blue, amber, red)
- **Stats Grid** (4 boxes in 2x2 layout):
  - **Avg Rate/Load** (blue background)
  - **Avg Fee** (amber background) with fee percentage
  - **Est. Profit/Load** (green/red background based on value)
  - **Total Revenue** (gray background)
- **Additional Stats Row** (small text, border-top):
  - Loads/Month
  - Total Fees
- **Last Order Info** (small text, dashed border):
  - Last order date + days since
- **Actions Footer** (light background):
  - Edit | Delete buttons

**Computed Metrics (per broker):**
```javascript
// Basic stats
orderCount = brokerOrders.length
tripCount = unique trip_ids
totalRevenue = sum(order.revenue)
totalBrokerFee = sum(order.broker_fee)
avgRevenue = totalRevenue / orderCount
avgBrokerFee = totalBrokerFee / orderCount
feePercent = (totalBrokerFee / totalRevenue) * 100

// Profit estimation (assumes 32% driver cut)
cleanRevenue = totalRevenue - totalBrokerFee
estimatedDriverCut = cleanRevenue * 0.32
estimatedProfit = cleanRevenue - estimatedDriverCut
profitPerLoad = estimatedProfit / orderCount

// Activity tracking
lastOrderDate = most recent pickup_date
daysSinceLastOrder = days since lastOrderDate
ordersPerMonth = orderCount / monthsActive

// Reliability score (0-100 scale)
// Volume component (max 30):
//   ≥10 orders: +30, ≥5: +20, ≥1: +10
// Fee efficiency component (max 30):
//   ≤8%: +30, ≤12%: +20, ≤15%: +10
// Profitability component (max 40):
//   ≥$500/load: +40, ≥$300: +30, ≥$100: +20, >$0: +10
```

**Activity Status Logic:**
- **Active** (green): Last order ≤ 7 days ago
- **Recent** (blue): Last order ≤ 30 days ago
- **Inactive** (amber): Last order ≤ 90 days ago
- **Dormant** (red): Last order > 90 days ago
- **No orders** (gray): No orders yet

**Sorting:** Brokers sorted by estimatedProfit (descending)

### PEOPLE-08: Dispatchers List

**File:** `index.html`, function `renderDispatchers()` at line 19535

**Sections (in order):**
1. **Header**: Title "Dispatchers" + New Dispatcher button
2. **Dispatchers Table**:
   - Columns: Code | Name | Cars Booked | Revenue Generated | Actions
   - **Code cell**: Bold text (dispatcher code)
   - **Name cell**: Plain text
   - **Cars Booked cell**: Count of orders
   - **Revenue Generated cell**: Money format (green)
   - **Actions**: Edit | Del

**Computed Metrics (per dispatcher):**
```javascript
const dispOrders = appData.orders.filter(o => o.dispatcher_id === d.id);
const cars = dispOrders.length;
const revenue = dispOrders.reduce((s, o) => s + parseFloat(o.revenue || 0), 0);
```

**Key Features:**
- Simplest page design - just a table
- No rankings shown on main list (separate Dispatcher Ranking page exists)
- Revenue displayed with `.money.positive` class

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Expiration date calculations | Custom date math | Production logic: `Math.ceil((expDate - today) / (1000 * 60 * 60 * 24))` | Consistent with production, handles edge cases |
| Status badge colors | Hardcoded colors | Phase 6 design system badge classes | Maintains design consistency |
| Money formatting | Custom functions | `formatMoney()` from production utils.js | Standard formatting already defined |
| Date formatting | Custom functions | `formatDate()` from production utils.js | Consistent date display |
| Reliability score calculation | Simplified version | Full production algorithm (volume + fee + profit components) | Shows realistic data distribution |

## Common Pitfalls

### Pitfall 1: Incomplete Data Field Coverage
**What goes wrong:** Mockup omits minor fields like "color" in truck table or "service area" in local drivers, causing design review failures.
**Why it happens:** Designer focuses on major fields and misses supporting information fields.
**How to avoid:** Create a checklist for each table/card from production code. Check every field in the render function.
**Warning signs:** Production code shows more badges/fields than mockup design.

### Pitfall 2: Missing Visual States
**What goes wrong:** Mockup only shows "uploaded" files, never "missing" or "expired" states. Doesn't demonstrate full status badge range.
**Why it happens:** Sample data created with all-green happy-path scenario.
**How to avoid:** For every badge/status field, create sample data showing ALL possible states. Use mixed data (some expired, some current, some missing).
**Warning signs:** All badges are the same color in mockup.

### Pitfall 3: Incorrect Computed Metric Logic
**What goes wrong:** Broker reliability score shown as simple percentage instead of 0-100 composite score with volume/fee/profit components.
**Why it happens:** Misunderstanding complex calculation formulas in production code.
**How to avoid:** Copy exact calculation logic from production. Document formula in research notes. Test with realistic data.
**Warning signs:** Metrics don't match production value ranges.

### Pitfall 4: Detail View Organization Confusion
**What goes wrong:** Mixing Driver detail pattern (sections in single page) with separate detail file approach.
**Why it happens:** Phase context says "detail views within same HTML file" but doesn't clarify whether it's visible sections or JavaScript-swapped content.
**How to avoid:** Production uses `c.innerHTML = ...` replacement pattern - detail view replaces entire page content, not a separate section. Mockup should show both list and detail as separate visible sections.
**Warning signs:** Unclear how Back button would work in mockup.

### Pitfall 5: Local Drivers Status Color Rows
**What goes wrong:** Using status badges only instead of full-row background colors for pending pickup/delivery tables.
**Why it happens:** Standard table styling doesn't include row background tinting.
**How to avoid:** Production explicitly sets `style="background:` + rowColor on `<tr>` tags. Must preserve full-row tinting.
**Warning signs:** Mockup tables look like standard Trucks table instead of color-coded rows.

### Pitfall 6: Action Button Placement
**What goes wrong:** Moving action buttons to dropdown menu or modal to "simplify" dense cards.
**Why it happens:** Designer optimizes without realizing production UX requires instant access.
**How to avoid:** Phase decision: "Action buttons stay on cards — View, Edit, Del buttons visible on every driver/broker card."
**Warning signs:** Fewer than 3 action buttons visible on cards.

### Pitfall 7: Brokers Card vs. Table Layout
**What goes wrong:** Converting Brokers to table layout like Dispatchers for "consistency."
**Why it happens:** Designer assumes all list pages should use same layout pattern.
**How to avoid:** Production intentionally uses dense cards for Brokers to show computed metrics. Cards ≠ Tables - each serves different data density needs.
**Warning signs:** Brokers mockup lacks gradient header, score bar, or 4-stat grid.

## Code Examples

### Expiration Badge Logic (Drivers & Trucks)

Production pattern for file expiration status:

```javascript
const getExpiryBadge = (file) => {
  if (!file || !file.expiration_date) return '';
  const expDate = new Date(file.expiration_date);
  const daysUntil = Math.ceil((expDate - today) / (1000 * 60 * 60 * 24));
  if (daysUntil < 0) return '<span class="badge badge-red">EXPIRED</span>';
  if (daysUntil === 0) return '<span class="badge badge-red">EXPIRES TODAY</span>';
  if (daysUntil <= 3) return '<span class="badge badge-red">Expires in ' + daysUntil + 'd</span>';
  if (daysUntil <= 7) return '<span class="badge badge-amber">Expires in ' + daysUntil + 'd</span>';
  return '<span class="badge badge-green">Valid until ' + formatDate(file.expiration_date) + '</span>';
};
```

**Mockup application:** Show 5 different file rows with each expiration state (expired, today, 2d, 5d, valid).

### Broker Reliability Score Calculation

Production algorithm (0-100 scale):

```javascript
let reliabilityScore = 0;

// Volume component (max 30 points)
if (brokerOrders.length >= 10) reliabilityScore += 30;
else if (brokerOrders.length >= 5) reliabilityScore += 20;
else if (brokerOrders.length >= 1) reliabilityScore += 10;

// Fee efficiency component (max 30 points)
if (feePercent <= 8) reliabilityScore += 30;
else if (feePercent <= 12) reliabilityScore += 20;
else if (feePercent <= 15) reliabilityScore += 10;

// Profitability component (max 40 points)
if (profitPerLoad >= 500) reliabilityScore += 40;
else if (profitPerLoad >= 300) reliabilityScore += 30;
else if (profitPerLoad >= 100) reliabilityScore += 20;
else if (profitPerLoad > 0) reliabilityScore += 10;

// Score label
const scoreLabel =
  reliabilityScore >= 80 ? 'Excellent' :
  reliabilityScore >= 60 ? 'Good' :
  reliabilityScore >= 40 ? 'Fair' : 'New';

// Progress bar color
const scoreColor =
  reliabilityScore >= 80 ? '#16a34a' : // green
  reliabilityScore >= 60 ? '#2563eb' : // blue
  reliabilityScore >= 40 ? '#f59e0b' : // amber
  '#dc2626'; // red
```

**Mockup application:** Create 4 broker cards showing different score ranges (85/Excellent, 65/Good, 45/Fair, 25/New).

### Local Drivers Row Color Pattern

Production status-to-color mapping:

```javascript
const confirmStatus = o.local_confirmation_status || 'pending';
const rowColors = {
  pending: '#dbeafe',   // blue
  scheduled: '#ffedd5', // orange
  confirmed: '#fef9c3', // yellow
  ready: '#dcfce7',     // green
  issue: '#fee2e2'      // red
};
const statusIcons = {
  pending: '🔵',
  scheduled: '🟠',
  confirmed: '🟡',
  ready: '🟢',
  issue: '🔴'
};
const rowColor = rowColors[confirmStatus] || '#dbeafe';
const statusIcon = statusIcons[confirmStatus] || '🔵';

// Apply to row
'<tr style="background:' + rowColor + '">...</tr>'
```

**Mockup application:** Pending tables must show mix of all 5 status colors across rows.

## State of the Art

| Production Pattern | Current Implementation | Notes |
|-------------------|------------------------|-------|
| Document expiration tracking | 7-day, 3-day, 1-day, 0-day, expired alerts | Industry standard for compliance software |
| Broker ranking by profit | Computed metric sort with medals | Common in B2B management platforms |
| Local drivers status cycling | Click icon to cycle through 5 states | Mobile-inspired quick status change pattern |
| Custom folder system | User-defined categories per driver/truck | Flexible beyond rigid compliance categories |
| Reliability scoring | Multi-factor 0-100 composite score | More nuanced than simple star rating |
| Year-filtered earnings | Dropdown selector with recalculation | Standard accounting practice |
| Inline editing context | `currentDetailView` flag prevents re-render race | Prevents data loss during background updates |

**Deprecated/outdated:**
- Single compliance category per file (replaced with custom folders in v3)
- Manual expiration tracking (replaced with automated alert banners)

## Open Questions

1. **Document expiration alert banner prominence**
   - What we know: Production shows red banner at top of Drivers page if any docs expiring/expired
   - What's unclear: Optimal placement in redesigned layout (above or below stats cards)
   - Recommendation: Place above stats cards for immediate visibility (alerts take precedence over metrics)

2. **Driver detail tabbed vs. scrollable layout**
   - What we know: Production uses single scrollable page with 6 sequential sections
   - What's unclear: Whether tabbed interface would improve UX for multi-section detail
   - Recommendation: START with scrollable (matches production), document as "Claude's discretion" for planner to choose tab variant if desired

3. **Local Drivers column density handling**
   - What we know: Pending tables have 14-15 columns, production uses horizontal scroll
   - What's unclear: Whether to keep all columns visible with scroll or restructure
   - Recommendation: Keep horizontal scroll with sticky Actions column (production pattern works)

4. **Broker summary card gradient backgrounds**
   - What we know: Production uses CSS gradients for top summary cards
   - What's unclear: Whether to keep gradients or switch to Phase 6 flat stat-card pattern
   - Recommendation: Keep gradients for Broker summary cards (differentiates from other pages), use flat pattern for Broker detail cards

## Sources

### Primary (HIGH confidence)
- Production code: `/Users/reepsy/Desktop/OG TMS CLAUDE/index.html`
  - Lines 18149-18448: `renderDrivers()` and `viewDriverProfile()`
  - Lines 18622-18821: `renderTrucks()`
  - Lines 18832-19140: `renderLocalDrivers()`
  - Lines 19141-19240: `viewLocalDriverDetails()`
  - Lines 19306-19489: `renderBrokers()`
  - Lines 19535-19568: `renderDispatchers()`
  - Lines 22537-22618: `viewTruckCompliance()`
- Phase 6 design system: `/Users/reepsy/Desktop/OG TMS CLAUDE/mockups/web-tms-redesign/shared.css`
- Completed mockup reference: `/Users/reepsy/Desktop/OG TMS CLAUDE/mockups/web-tms-redesign/dashboard.html`
- Phase context: `.planning/phases/08-people-fleet-pages/08-CONTEXT.md`

### Secondary (MEDIUM confidence)
- Badge helper functions: `getBadge()`, `getTicketStatusBadge()`, `getViolationStatusBadge()`, `getClaimStatusBadge()` (referenced in render functions)
- Utility functions: `formatMoney()`, `formatDate()`, `escapeHtml()` (from `assets/js/utils.js`)

## Metadata

**Confidence breakdown:**
- Page structure mapping: HIGH - Direct extraction from production code
- Data field inventory: HIGH - Line-by-line code analysis
- Computed metrics formulas: HIGH - Exact algorithms documented
- Design system compatibility: HIGH - Phase 6 CSS provides all needed components
- Sample data scenarios: MEDIUM - Inferred from production logic, needs realistic 2026 dates

**Research date:** 2026-02-09
**Valid until:** 2026-03-09 (30 days - stable production code, no rapid changes expected)
