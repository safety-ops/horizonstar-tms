# Phase 7: Core Dispatch Pages - Research

**Researched:** 2026-02-09
**Domain:** HTML/CSS mockup development for production TMS pages
**Confidence:** HIGH

## Summary

Phase 7 requires creating 6 HTML mockup files that mirror the current production TMS pages (Dashboard, Load Board, Trips, Orders) plus 2 detail views (Trip Detail, Order Detail). The research confirms:

- **Production structure is well-defined**: Each page has a clear `renderXxx()` function with distinct sections, data patterns, and UI conventions that must be preserved in mockups
- **Design system is complete**: Phase 6 delivered `shared.css` (1,308 lines) with all necessary components (cards, tables, badges, buttons, forms) ready for use
- **Data patterns are realistic**: Production code reveals actual data structures, enums, and business logic (payment types, route categories, trip financials) that mockups must reflect
- **UI conventions are consistent**: Inline action buttons (View/Edit/Del), horizontal filters, colored category tabs, and sticky right columns are standard patterns across all pages

**Primary recommendation:** Build mockups section-by-section matching production page order exactly, using realistic sample data extracted from production patterns. Do NOT reorganize, omit, or add sections beyond what exists in current TMS.

## Standard Stack

### Core (from Phase 6)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| shared.css | 1.0 | Design system foundation | Phase 6 deliverable, 1,308 lines of production-ready CSS |
| base-template.html | 1.0 | App shell (sidebar + header) | Phase 6 deliverable, working layout with theme toggle |
| Lucide Icons | 0.344.0 | Icon system | Already in Phase 6, CDN-hosted, no build step |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Inter font | Google Fonts | Typography | All pages (already in base-template) |
| None required | - | No JS frameworks | Static HTML mockups only |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Static HTML | Vue/React | Mockups are static, no need for JS frameworks |
| Realistic data | Lorem ipsum | Per CONTEXT.md Decision 3, realistic transport data required |

**Installation:**
```bash
# No installation required - all assets are CDN or local files
```

## Architecture Patterns

### Recommended Project Structure
```
mockups/web-tms-redesign/
├── shared.css                  # Design system (Phase 6)
├── base-template.html          # App shell (Phase 6)
├── component-showcase.html     # Component reference (Phase 6)
├── dashboard.html              # CORE-01 (Phase 7)
├── load-board.html             # CORE-02 (Phase 7)
├── trips.html                  # CORE-03 (Phase 7)
├── trip-detail.html            # CORE-04 (Phase 7)
├── orders.html                 # CORE-05 (Phase 7)
└── order-detail.html           # CORE-06 (Phase 7)
```

### Pattern 1: Dashboard Layout (9 sections, top-to-bottom)
**What:** Single scrollable page with multiple card sections containing stats, charts, and tables
**When to use:** CORE-01 (dashboard.html)
**Production order (DO NOT CHANGE):**
1. Tasks Widget (actionable items)
2. Recent Trips table (last 5 trips)
3. Revenue / Expenses / Profit stat cards (3-card row)
4. Quick View profitability hero (dark gradient, 6 metrics: CPM, RPM, Margin/Mile, Avg Vehicle Price, Break-Even Price, Profit/Vehicle)
5. Other Metrics + Direct Trip Expenses Breakdown (2-column grid)
6. Fuel Tracking comparison card (trip-level vs fleet fuel)
7. KPIs + Top Performers (2-column grid)
8. Payment Collection cards (COD, COP, Local COD, Check, Bill)
9. Cost Trend Sparklines (12-week charts for Fuel, Tolls, Maintenance, Permits, Parking)

**Example (stat cards row):**
```html
<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 24px;">
  <div class="stat-card">
    <div class="stat-icon green">
      <i data-lucide="dollar-sign" class="ico-lg"></i>
    </div>
    <div class="stat-value">$47,230</div>
    <div class="stat-label">Total Revenue</div>
  </div>
  <div class="stat-card">
    <div class="stat-icon red">
      <i data-lucide="trending-down" class="ico-lg"></i>
    </div>
    <div class="stat-value">$12,450</div>
    <div class="stat-label">Total Expenses</div>
  </div>
  <div class="stat-card">
    <div class="stat-icon blue">
      <i data-lucide="trending-up" class="ico-lg"></i>
    </div>
    <div class="stat-value">$34,780</div>
    <div class="stat-label">Net Profit</div>
  </div>
</div>
```

### Pattern 2: Load Board Category Tabs
**What:** 7 colored tabs (one per route category) with vehicle counts, subcategory pills, and vehicle table
**When to use:** CORE-02 (load-board.html)
**Production categories (exact names and colors from `loadBoardCategories`):**
- NY to Home: #3b82f6 (blue) — 6 subcategories
- Home to NY: #8b5cf6 (purple) — no subs
- Home to CA: #06b6d4 (cyan) — 2 subs (SF, LA)
- CA to Home: #10b981 (green) — no subs
- FL to CA: #f59e0b (amber) — no subs
- FL to Home: #ef4444 (red) — no subs
- NY to FL: #ec4899 (pink) — no subs

**Example (category tabs):**
```html
<div style="display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 16px;">
  <button class="btn" style="background: #3b82f6; color: white; border: 2px solid #3b82f6;">
    NY to Home <span class="badge badge-gray" style="background: rgba(255,255,255,0.2); margin-left: 8px;">12</span>
  </button>
  <button class="btn btn-secondary" style="border: 2px solid #8b5cf6; color: #8b5cf6;">
    Home to NY <span class="badge badge-gray" style="background: rgba(139,92,246,0.1); margin-left: 8px;">8</span>
  </button>
  <!-- Repeat for all 7 categories -->
</div>
```

### Pattern 3: Trips Page Truck Tabs
**What:** Status filter tabs (Active/Completed/All) + truck tabs showing trip count per truck
**When to use:** CORE-03 (trips.html)
**Production structure:**
- Status tabs: Active (count), Completed (count), All (count)
- Truck tabs: One per active truck, sorted by truck number (e.g., "77", "88", "55")
- Trip table: Shows trips for selected truck, sorted by date descending

**Example (status + truck tabs):**
```html
<!-- Status Filter -->
<div style="display: flex; gap: 8px; margin-bottom: 16px;">
  <button class="btn btn-primary">
    Active <span class="badge badge-gray" style="background: rgba(255,255,255,0.2); margin-left: 4px;">23</span>
  </button>
  <button class="btn btn-secondary">
    Completed <span class="badge badge-gray" style="background: rgba(0,0,0,0.05); margin-left: 4px;">47</span>
  </button>
  <button class="btn btn-secondary">
    All <span class="badge badge-gray" style="background: rgba(0,0,0,0.05); margin-left: 4px;">70</span>
  </button>
</div>

<!-- Truck Tabs -->
<div style="display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 16px;">
  <button class="btn btn-primary">
    Truck 77 <span class="badge badge-gray" style="background: rgba(255,255,255,0.2); margin-left: 4px;">12</span>
  </button>
  <button class="btn btn-secondary">
    Truck 88 <span class="badge badge-gray" style="background: rgba(0,0,0,0.05); margin-left: 4px;">9</span>
  </button>
  <button class="btn btn-secondary">
    Truck 55 <span class="badge badge-gray" style="background: rgba(0,0,0,0.05); margin-left: 4px;">8</span>
  </button>
</div>
```

### Pattern 4: Orders Filter Row
**What:** Horizontal filter bar with search input + 4 dropdowns (Status, Dispatcher, Driver, Broker)
**When to use:** CORE-05 (orders.html)
**Production filters:**
- Search: Text input (placeholder: "🔍 Search by Order ID, Broker, or Vehicle...")
- Status dropdown: All, Unassigned, Assigned, PENDING, IN_TRANSIT, DELIVERED
- Dispatcher dropdown: All + individual dispatchers
- Driver dropdown: All + drivers with orders
- Broker dropdown: All Brokers + unique broker names

**Example:**
```html
<div style="display: flex; gap: 16px; margin-bottom: 20px; flex-wrap: wrap; align-items: center; background: var(--bg-card); padding: 16px; border-radius: 12px;">
  <div style="flex: 1; min-width: 200px;">
    <input type="text" class="form-input" placeholder="🔍 Search by Order ID, Broker, or Vehicle..." style="width: 100%;">
  </div>
  <div style="display: flex; align-items: center; gap: 8px;">
    <label style="font-weight: 600; color: var(--text-secondary); font-size: var(--text-xs); text-transform: uppercase;">Status:</label>
    <select class="form-input" style="width: auto;">
      <option>All</option>
      <option>Unassigned</option>
      <option>Assigned</option>
      <option>PENDING</option>
      <option>IN_TRANSIT</option>
      <option>DELIVERED</option>
    </select>
  </div>
  <!-- Repeat for Dispatcher, Driver, Broker -->
  <button class="btn btn-secondary">Clear</button>
  <span style="color: var(--text-muted); font-size: var(--text-xs);">Showing 47 of 150</span>
</div>
```

### Pattern 5: Trip Detail Layout
**What:** 3 sections: Trip financials card, Vehicle list by direction (colored sections), Expense list
**When to use:** CORE-04 (trip-detail.html)
**Production structure (from `viewTrip()`):**
1. Back button + trip title (e.g., "TRIP 3 - 77 - 2025")
2. Financials card (Load Revenue, Broker Fees, Local Fees, Driver Cut, Net Profit, CPM, RPM)
3. Vehicles by Direction (6 colored sections: HOME_TO_CA, CA_TO_HOME, HOME_TO_FL, FL_TO_HOME, FL_TO_CA, CA_TO_FL)
4. Expenses table (category-grouped)

**Example (financials card):**
```html
<div class="card" style="margin-bottom: 24px;">
  <div class="card-header">
    <h3 class="card-title">💰 Trip Financials</h3>
  </div>
  <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 12px;">
    <div style="text-align: center; padding: 12px;">
      <div class="stat-label">Load Revenue</div>
      <div class="stat-value" style="color: var(--green);">$8,450</div>
    </div>
    <div style="text-align: center; padding: 12px;">
      <div class="stat-label">Broker Fees</div>
      <div class="stat-value" style="color: var(--red);">-$350</div>
    </div>
    <div style="text-align: center; padding: 12px;">
      <div class="stat-label">Driver Cut (32%)</div>
      <div class="stat-value" style="color: var(--amber);">-$2,704</div>
    </div>
    <div style="text-align: center; padding: 12px;">
      <div class="stat-label">Net Profit</div>
      <div class="stat-value" style="color: var(--blue);">$3,250</div>
    </div>
  </div>
</div>
```

### Pattern 6: Order Detail Layout
**What:** Full-page detail view with vehicle info, payment details, inspection photos, timeline
**When to use:** CORE-06 (order-detail.html)
**Production structure (from `openOrderDetailPage()`):**
1. Back button + vehicle title (e.g., "2024 Toyota Camry")
2. Order Info card (Order #, VIN, Color, Broker, Payment Type, Payment Status)
3. Route card (Origin, Destination with map link, Pickup/Delivery dates)
4. Payment Details card (Revenue, Broker Fee, Local Fee, Payment Type explanation)
5. Inspection Photos (Pickup + Delivery, if available)
6. Timeline (order created, assigned, picked up, delivered)

### Anti-Patterns to Avoid
- **Reordering sections:** Dashboard sections must stay in production order (Decision 1)
- **Unifying tables/cards:** Keep mixed data presentation (Decision 2)
- **Removing inline actions:** Keep View/Edit/Del buttons in sticky right column, no kebab menus
- **Generic sample data:** Use realistic transport data (e.g., "TRIP 3 - 77 - 2025", not "Trip 1") per Decision 3
- **Adding new sections:** UI-only reskin, no new features or sections

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Color system | Custom hex codes | `shared.css` CSS variables (`--green`, `--blue-dim`, etc.) | Consistent with Phase 6, theme-aware |
| Icon system | SVG files | Lucide icons via data attributes (`<i data-lucide="truck"></i>`) | Already loaded in base-template |
| Card styles | Inline CSS | `.card`, `.stat-card`, `.hero-card` classes | Consistent spacing, shadows, borders |
| Badge styles | Custom spans | `.badge-green`, `.badge-amber`, etc. | Consistent sizing, colors, uppercase |
| Table styles | Raw `<table>` | `.table-container` + `.table` | Responsive, hover states, sticky columns |
| Form inputs | Basic HTML | `.form-input`, `.form-group`, `.form-row` | Consistent styling, focus states |
| Buttons | Inline styles | `.btn-primary`, `.btn-secondary`, `.btn-icon` | Hover effects, sizing variants |

**Key insight:** Phase 6 delivered a complete design system. All UI components exist and are documented in `component-showcase.html`. Do NOT create custom CSS — use DS classes exclusively.

## Common Pitfalls

### Pitfall 1: Section Creep (Adding/Removing Sections)
**What goes wrong:** Planner adds "nice to have" sections or combines similar sections for "cleaner" layout
**Why it happens:** Designer instinct to improve UX, but mockups must match production exactly
**How to avoid:** Cross-reference every section with production `renderXxx()` function. Count sections. If Dashboard has 9 sections in production, mockup must have exactly 9.
**Warning signs:** Mockup has different number of sections than production, or sections are in different order

### Pitfall 2: Generic Sample Data
**What goes wrong:** Using "Order 1", "Trip 1", "John Doe" instead of realistic transport data
**Why it happens:** Faster to type generic data than research realistic patterns
**How to avoid:** Extract data patterns from production code (see Data Conventions below). Use specific values like "TRIP 3 - 77 - 2025", "ORD-2024-001", "2024 Toyota Camry".
**Warning signs:** Mockup data feels like a demo app, not a real TMS; round numbers ($1,000 instead of $1,247.50)

### Pitfall 3: Inconsistent Component Usage
**What goes wrong:** Mixing custom styles with DS components (e.g., custom badge next to `.badge-green`)
**Why it happens:** Forgetting what components exist in Phase 6, or tweaking DS styles per-page
**How to avoid:** Reference `component-showcase.html` before building each page. Use DS classes exactly as documented.
**Warning signs:** Page-specific `<style>` blocks, inline styles for common UI patterns, custom color values

### Pitfall 4: Light Theme Neglect
**What goes wrong:** Mockups look good in dark theme but broken in light theme (wrong contrast, invisible borders)
**Why it happens:** Dark theme is default (Decision from Phase 6), so light theme not tested
**How to avoid:** Toggle theme for every page during development. Use CSS variables exclusively (they swap automatically).
**Warning signs:** Light theme has low contrast text, invisible borders, or wrong backgrounds

### Pitfall 5: Unrealistic Density
**What goes wrong:** Too much whitespace (5-8 rows per table) or too little (20+ rows)
**Why it happens:** Misjudging "realistic" row count from Decision 3
**How to avoid:** Production tables show 5-8 rows typically. Use this as guide. Enough to show variety, not overwhelming.
**Warning signs:** Empty-looking pages, or pages that scroll excessively

## Code Examples

Verified patterns from production code:

### Recent Trips Table (Dashboard Section 2)
```html
<!-- Production shows last 5 trips -->
<div class="card" style="margin-bottom: 24px;">
  <div class="card-header">
    <h3 class="card-title">🚛 Recent Trips</h3>
    <button class="btn btn-ghost">View All →</button>
  </div>
  <div class="table-container">
    <table class="table">
      <thead>
        <tr>
          <th>Trip #</th>
          <th>Truck</th>
          <th>Driver</th>
          <th>Date</th>
          <th>Status</th>
          <th class="text-right">Revenue</th>
          <th class="text-right">Profit</th>
          <th class="sticky-col">Actions</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td class="font-mono">TRIP 3 - 77 - 2025</td>
          <td>77</td>
          <td>John Smith</td>
          <td>2025-01-15</td>
          <td><span class="badge badge-green">COMPLETED</span></td>
          <td class="mono text-right">$8,450.00</td>
          <td class="mono text-right">$3,250.00</td>
          <td class="sticky-col">
            <button class="btn-icon"><i data-lucide="eye" class="ico-sm"></i></button>
          </td>
        </tr>
        <!-- 4 more rows -->
      </tbody>
    </table>
  </div>
</div>
```

### Load Board Vehicle Row (with inline action buttons)
```html
<!-- Production shows inline View/Edit/Del buttons in sticky right column -->
<tr>
  <td class="font-mono">ORD-2024-001</td>
  <td>Central Dispatch</td>
  <td>2024 Toyota Camry</td>
  <td>Miami, FL</td>
  <td><a href="tel:+1234567890" style="color: var(--blue);">📞</a></td>
  <td>Atlanta, GA</td>
  <td><a href="tel:+1987654321" style="color: var(--green);">📞</a></td>
  <td>2025-01-20</td>
  <td>2025-01-22</td>
  <td><span class="badge badge-blue">COD</span></td>
  <td class="mono text-right">$50.00</td>
  <td class="mono text-right">$25.00</td>
  <td class="mono text-right">$1,250.00</td>
  <td class="sticky-col">
    <button class="btn-icon"><i data-lucide="eye" class="ico-sm"></i></button>
    <button class="btn-icon"><i data-lucide="edit" class="ico-sm"></i></button>
    <button class="btn-icon"><i data-lucide="trash" class="ico-sm"></i></button>
  </td>
</tr>
```

### Trip Detail Vehicle Section (colored by direction)
```html
<!-- Production groups vehicles by direction with colored headers -->
<div style="background: #22c55e; color: white; padding: 12px 16px; font-weight: 700; margin-top: 16px; border-radius: 8px 8px 0 0; display: flex; justify-content: space-between; align-items: center;">
  <span>HOME TO CA (5 cars)</span>
  <span>Revenue: $6,250 | Clean Revenue: $5,875</span>
</div>
<div class="table-container" style="border: 2px solid #22c55e; border-top: none; border-radius: 0 0 8px 8px;">
  <table class="table">
    <!-- Vehicle rows for this direction -->
  </table>
</div>

<!-- Repeat for CA_TO_HOME, HOME_TO_FL, FL_TO_HOME, FL_TO_CA, CA_TO_FL -->
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Separate CSS per page | Single `shared.css` design system | Phase 6 | All mockups use same CSS, consistent styling |
| Lorem ipsum data | Realistic transport data | Decision 3 (Phase 7 planning) | Mockups feel production-ready |
| Light theme default | Dark theme default | Phase 6 | Matches iOS v3, reduces eye strain |
| Reorganized layouts | Exact production structure | UI-only constraint | Zero production code changes needed |

**Deprecated/outdated:**
- Custom CSS per mockup: Phase 6 design system eliminates need for per-page styles
- Generic placeholders: Decision 3 requires realistic transport industry data

## Open Questions

Things that couldn't be fully resolved:

1. **Sparkline Chart Implementation**
   - What we know: Dashboard section 9 shows "Cost Trend Sparklines" (12-week charts)
   - What's unclear: Static mockup can't render real charts; use placeholder SVG or styled divs?
   - Recommendation: Use CSS-based mini bar charts (divs with heights) or inline SVG. No JS required for static mockup.

2. **Modal vs Separate Page for Detail Views**
   - What we know: Production uses `openOrderDetailPage()` (full-page replace), `viewTrip()` (full-page replace)
   - What's unclear: None — confirmed detail views are separate pages, not modals
   - Recommendation: Trip Detail and Order Detail are separate HTML files

3. **Pricing Guidance Widget Complexity**
   - What we know: Trip Detail includes large "Dispatcher Pricing Guidance" widget (lines 16514-16573 in production)
   - What's unclear: Should mockup show full widget or simplified version?
   - Recommendation: Show full widget with realistic calculated values (e.g., Minimum PPC: $850, Target PPC: $1,050)

## Data Conventions

Extracted from production code for realistic sample data:

### Trip Numbers
- Format: `TRIP {sequence} - {truck_number} - {year}`
- Examples: "TRIP 3 - 77 - 2025", "TRIP 5 - 88 - 2025", "TRIP 2 - 55 - 2025"

### Order Numbers
- Format: `ORD-{year}-{sequence}`
- Examples: "ORD-2024-001", "ORD-2024-027", "ORD-2025-003"

### Truck Numbers
- Format: 2-digit numbers
- Examples: "77", "88", "55", "42", "63"

### Routes
- Real corridors: "Miami, FL → Atlanta, GA", "Dallas, TX → Phoenix, AZ", "New York, NY → Boston, MA"
- States: Use full state names + 2-letter codes (e.g., "Miami, FL" not "Miami")

### Vehicle Data
- Format: `{year} {make} {model}`
- Examples: "2024 Toyota Camry", "2023 Honda Civic", "2025 Ford Mustang", "2022 Tesla Model 3"
- Colors: Realistic (Black, White, Silver, Blue, Red, Gray)

### Dollar Amounts
- Revenue: $750 - $1,200 per car (typical range)
- Broker fees: $50 - $150
- Local fees: $25 - $75
- Driver cut: 32% of clean revenue (after fees)
- Use specific cents: $1,247.50 not $1,250

### Payment Types (from production code)
- **COD**: Cash on Delivery
- **COP**: Check on Pickup
- **LOCAL_COD**: Local cash collection
- **CHECK**: Check payment
- **BILL**: Invoiced (pay later)
- **SPLIT**: Split between COD and Bill

### Status Values
**Trips:**
- PLANNED (blue)
- IN_PROGRESS (amber)
- COMPLETED (green)

**Orders:**
- PENDING (amber)
- IN_TRANSIT (blue)
- DELIVERED (green)

### Load Board Categories (exact from production)
1. NY to Home (#3b82f6 blue) — 6 subs: San Francisco, Los Angeles, Tennessee, Arkansas, Nevada, Oklahoma
2. Home to NY (#8b5cf6 purple) — no subs
3. Home to CA (#06b6d4 cyan) — 2 subs: San Francisco, Los Angeles
4. CA to Home (#10b981 green) — no subs
5. FL to CA (#f59e0b amber) — no subs
6. FL to Home (#ef4444 red) — no subs
7. NY to FL (#ec4899 pink) — no subs

### Vehicle Directions (from production `vehicleDirections`)
1. HOME_TO_CA (#22c55e green)
2. CA_TO_HOME (#22c55e green)
3. HOME_TO_FL (#3b82f6 blue)
4. FL_TO_HOME (#3b82f6 blue)
5. FL_TO_CA (#f59e0b amber)
6. CA_TO_FL (#f59e0b amber)

### Dispatcher/Driver Names
- Use realistic full names: "John Smith", "Maria Garcia", "David Chen", "Sarah Johnson", "Robert Williams"
- NOT generic: "User 1", "Driver A"

### Date Formats
- Tables: YYYY-MM-DD (e.g., "2025-01-15")
- Cards: MMM DD, YYYY (e.g., "Jan 15, 2025")

## Sources

### Primary (HIGH confidence)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/index.html` — Production TMS code (verified functions: `renderDashboard()` lines 14430-14580, `renderLoadBoard()` lines 14980-15045, `renderTrips()` lines 15798-15875, `renderOrders()` lines 17926-18026, `viewTrip()` lines 16435-16585, `openOrderDetailPage()` lines 13366-13466)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/mockups/web-tms-redesign/shared.css` — Phase 6 design system (1,308 lines)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/mockups/web-tms-redesign/base-template.html` — Phase 6 app shell (287 lines)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/mockups/web-tms-redesign/component-showcase.html` — Phase 6 component reference (865 lines)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/.planning/phases/07-core-dispatch-pages/07-CONTEXT.md` — User decisions (5 decisions locked)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/CLAUDE.md` — Project constraints (UI-only redesign, no changes to layouts/functions/logic)

### Secondary (MEDIUM confidence)
- None required (all information from primary sources)

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Phase 6 deliverables verified, no new dependencies
- Architecture: HIGH - Production code structure extracted directly from `renderXxx()` functions
- Pitfalls: HIGH - Based on common mockup mistakes and UI-only constraint violations
- Data conventions: HIGH - Extracted from production enums, calculations, and data structures

**Research date:** 2026-02-09
**Valid until:** 2026-03-09 (30 days - stable domain, no fast-moving dependencies)
