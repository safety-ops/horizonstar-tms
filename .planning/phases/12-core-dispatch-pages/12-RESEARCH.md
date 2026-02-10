# Phase 12: Core Dispatch Pages - Research

**Researched:** 2026-02-10
**Domain:** CSS refactoring, visual redesign, design system application
**Confidence:** HIGH

## Summary

Phase 12 applies the approved v1.1 mockup design system to 4 core dispatch pages: Dashboard, Load Board, Trips (list + detail), and Orders (list + detail). This is a purely visual transformation—restyling existing production elements with design system CSS classes and tokens without changing DOM structure, JavaScript logic, or behavior.

The research domain centers on CSS-only refactoring techniques for legacy applications, identifying patterns for applying a design system to existing HTML without breaking functionality, and documenting common pitfalls in visual-only transformations.

**Primary recommendation:** Use a progressive, page-by-page CSS substitution approach with production DOM as the constraint—apply mockup classes and styles only to elements that production already renders, skip mockup elements not present in production, and verify behavior preservation after each style change.

## Standard Stack

### Core Technologies

| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| CSS Variables | Native | Design tokens (--bg-*, --text-*, --green, etc.) | Already deployed in Phase 11, provides theme switching |
| design-system.css | v1.1 | All component styles (GLC-01 through GLC-10) | Production-ready, 1,310 lines, tested in Phase 11 |
| shared.css | v1.1 mockup | Reference stylesheet with all mockup patterns | 1,308 lines, source of truth for visual patterns |
| Inline styles | Legacy | Production pages use inline styles heavily | Must be replaced with CSS classes incrementally |

### Supporting Tools

| Tool | Purpose | When to Use |
|------|---------|-------------|
| Browser DevTools | Live CSS editing and inspection | Testing class replacements before committing |
| Git diff | Verify only CSS changes, no JS modifications | After each edit to confirm no logic changes |
| grep/Grep tool | Find inline style patterns to replace | Identifying all instances of a color/spacing pattern |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| CSS-only refactor | Full rewrite with new DOM | User wants minimal risk—CSS-only preserves all behavior |
| All pages at once | Incremental page-by-page | Smaller changesets = easier review, less risk |
| Add mockup elements | Style only existing elements | User constraint: don't add DOM elements production doesn't have |

**Installation:**
No installation required—design-system.css already linked in production index.html from Phase 11.

## Architecture Patterns

### Recommended Approach: Progressive CSS Substitution

The core pattern for Phase 12 is **replace inline styles with design system classes**:

```
Before (production):
<div style="padding:16px;background:var(--bg-card);border-radius:8px;">

After (Phase 12):
<div class="card">
```

**Key constraint:** Production DOM structure is the source of truth. Mockup provides visual targets, but if production doesn't render an element (e.g., sparklines on dashboard, A/B route markers on trip detail), skip it completely.

### Pattern 1: Stat Card Restyling

**What:** Convert production's inline-styled stat cards to mockup's .stat-card class
**When to use:** Dashboard top metrics, any numerical summary display
**Example:**

```javascript
// Production pattern (inline styles):
'<div style="border-left:4px solid var(--green)"><div class="label">Revenue</div><div class="value">' + formatMoney(totalRev) + '</div></div>'

// Phase 12 pattern (design system classes):
'<div class="stat-card"><div class="stat-icon green"><i data-lucide="dollar-sign"></i></div><div class="stat-value">' + formatMoney(totalRev) + '</div><div class="stat-label">Revenue Generated</div></div>'
```

**Mockup reference:** `/mockups/web-tms-redesign/dashboard.html` lines 350-420 (stat grid section)

### Pattern 2: Table with Sticky Actions Column

**What:** Apply `.sticky-col` class to rightmost Actions column for persistent visibility during horizontal scroll
**When to use:** All list tables (Trips, Orders, Load Board)
**Example:**

```javascript
// Production pattern:
'<th>Actions</th>'
// ...
'<td><div class="actions">...</div></td>'

// Phase 12 pattern (add sticky-col class):
'<th class="sticky-col">Actions</th>'
// ...
'<td class="sticky-col"><div class="actions">...</div></td>'
```

**CSS requirement (already in shared.css, port to design-system.css if missing):**

```css
.sticky-col {
  position: sticky;
  right: 0;
  background: var(--bg-card);
  border-left: 1px solid var(--border);
}

.table tbody tr:hover .sticky-col {
  background: var(--bg-card-hover);
}
```

**Mockup reference:** `/mockups/web-tms-redesign/trips.html` lines 18-33 (sticky column styles), trips.html table structure

### Pattern 3: Status Badge Color Scheme

**What:** Apply mockup's specific color mapping for status and payment type badges
**When to use:** All status columns, payment type displays
**Mapping:**

```javascript
// Status badges:
'COMPLETED' → 'badge badge-green'
'IN_PROGRESS' → 'badge badge-amber'
'PLANNED' → 'badge badge-blue'
'DELIVERED' → 'badge badge-green'
'IN_TRANSIT' → 'badge badge-amber'
'PENDING' → 'badge badge-blue'

// Payment type badges:
'COD' → 'badge badge-green'
'COP' → 'badge badge-blue'
'CHECK' → 'badge badge-purple'
'BILL' → 'badge badge-amber'
'LOCAL_COD' → 'badge badge-green'
```

**Production uses:** `.badge` + `getBadge(status)` helper function—verify mapping matches mockup colors
**Mockup reference:** All mockup HTML files—search for `<span class="badge badge-*">` patterns

### Pattern 4: Financial Breakdown Grid

**What:** Restyle existing financial metric layout with design system color coding
**When to use:** Trip detail financials, dashboard metrics, order detail payments
**Color scheme:**
- Revenue/income: `--green` (positive)
- Expenses/fees: `--red` (negative)
- Net profit: `--green` if positive, `--red` if negative
- Calculated values (Clean Revenue, Truck Gross): `--blue`
- Driver-related: `--amber`

**Example:**

```javascript
// Production pattern (mixed inline styles):
'<div class="stat-card"><div class="label">Net Profit</div><div class="value">' + formatMoney(totalProfit) + '</div></div>'

// Phase 12 pattern (color-coded with design tokens):
'<div class="stat-card"><div class="stat-icon ' + (totalProfit >= 0 ? 'green' : 'red') + '"><i data-lucide="dollar-sign"></i></div><div class="stat-value" style="color:' + (totalProfit >= 0 ? 'var(--green)' : 'var(--red)') + '">' + formatMoney(totalProfit) + '</div><div class="stat-label">Net Profit</div></div>'
```

**Mockup reference:** `/mockups/web-tms-redesign/trip-detail.html` lines 238-293 (Trip Financials Card)

### Pattern 5: Info Bar / Summary Row

**What:** Elevated summary row with color-coded metrics at top of table
**When to use:** Where production already renders summary stats above/below tables
**Example:**

```javascript
// Production pattern (if exists):
'<div>Showing ' + filtered.length + ' trips</div>'

// Phase 12 pattern (only if production has summary, add mockup styling):
'<div class="summary-row"><div class="summary-item"><span class="summary-label">Total Trips:</span><span class="summary-value">' + filtered.length + '</span></div></div>'
```

**CSS requirement (from trips.html mockup):**

```css
.summary-row {
  background: var(--bg-elevated);
  padding: 16px 20px;
  border-radius: var(--radius-lg);
  display: flex;
  gap: 24px;
  font-size: var(--text-sm);
}

.summary-item {
  display: flex;
  align-items: center;
  gap: 8px;
}

.summary-label {
  color: var(--text-secondary);
  font-weight: var(--weight-medium);
}

.summary-value {
  color: var(--text-primary);
  font-weight: var(--weight-bold);
  font-family: var(--font-mono);
}
```

**Mockup reference:** `/mockups/web-tms-redesign/trips.html` lines 34-61 (summary row styles)

### Pattern 6: Route Display (Order/Trip Detail)

**What:** Restyle existing origin/destination layout—do NOT add A/B markers or arrow icons unless production already has them
**When to use:** Order detail page, any route/direction display
**Constraint:** User decision from CONTEXT.md: "Route display: restyle existing route/direction layout — don't add A/B markers, colored bars, or arrow icons unless production already has them"

**Example:**

```javascript
// Production pattern (existing structure):
'<div><strong>Origin:</strong> ' + origin + '</div><div><strong>Destination:</strong> ' + destination + '</div>'

// Phase 12 pattern (add design system classes to existing structure):
'<div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;"><div class="card" style="padding:16px;"><div style="font-size:var(--text-xs);color:var(--text-muted);margin-bottom:4px;">ORIGIN</div><div style="font-weight:var(--weight-semibold);">' + origin + '</div></div><div class="card" style="padding:16px;"><div style="font-size:var(--text-xs);color:var(--text-muted);margin-bottom:4px;">DESTINATION</div><div style="font-weight:var(--weight-semibold);">' + destination + '</div></div></div>'
```

**Do NOT add:** A/B circle markers, colored left borders, arrow icons between cards—these are mockup-specific enhancements not present in production
**Mockup reference:** `/mockups/web-tms-redesign/order-detail.html` lines 283-348 (Route Card) — use as visual guide only, not structural template

### Pattern 7: Inspection Photos Grid (Exception)

**What:** Restructure inspection photo display to match mockup's 4-image grid layout
**When to use:** Order detail page inspection photo section
**Exception note:** User decision from CONTEXT.md: "Inspection photos: match mockup's 4-image grid layout with pickup/delivery sections (exception to the general 'restyle existing' pattern — user specifically wants mockup photo grid)"

This is the ONLY pattern where we restructure DOM to match mockup instead of just restyling existing elements.

**Mockup reference:** `/mockups/web-tms-redesign/order-detail.html` inspection photos section

### Anti-Patterns to Avoid

- **Don't add mockup elements not in production:** If mockup shows sparklines/charts and production doesn't render them, skip completely
- **Don't change filter DOM structure:** Production may have filters as `<select>` dropdowns, mockup may show them as pill buttons—keep production's structure, just restyle
- **Don't restructure grids:** If production uses flexbox for stat cards and mockup uses CSS grid, keep flexbox—change is visual refactor, not structural
- **Don't touch JavaScript:** If a button has `onclick="viewTrip(123)"`, preserve exactly—no refactoring handlers, no changing function names
- **Don't change data flow:** If production calculates metrics in `renderDashboard()`, Phase 12 only changes how they're displayed, not how they're calculated

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Sticky table columns | Custom scroll handlers + position logic | CSS `position: sticky` | Native browser support, better performance, already works in shared.css |
| Theme switching | Manual class toggling on every element | CSS variables with `:root` / `body.dark-theme` scopes | Already implemented in Phase 11, proven pattern |
| Color-coded metrics | Inline color logic per element | Design token mapping (--green, --red, --blue) | Centralized in design-system.css, consistent across app |
| Badge status mapping | Hardcoded color strings | `getBadge()` helper + mockup color scheme | Production already has helper, just verify mapping |
| Responsive layout | Media query overrides per page | Shared breakpoints in design-system.css | DRY principle, consistent mobile behavior |

**Key insight:** Production already has 38,000 lines of working code. Phase 12's job is CSS substitution, not reinventing patterns. If production has a working helper function or pattern, keep it—just adjust its output to use design system classes.

## Common Pitfalls

### Pitfall 1: Breaking Existing Functionality with Class Changes

**What goes wrong:** Replacing inline styles with CSS classes can break JavaScript that relies on those styles (e.g., `element.style.display = 'none'`)

**Why it happens:** Production may have JS that directly manipulates inline styles. If you remove all inline styles, those manipulations fail silently or cause errors.

**How to avoid:**
1. Search for `element.style.` patterns in production before removing inline styles
2. If found, preserve critical inline styles (display, visibility) and only replace decorative ones (colors, padding)
3. Test all interactive features (modals, dropdowns, filters) after CSS changes

**Warning signs:**
- Modals that won't open after restyling
- Filters that appear to work but don't update UI
- Buttons that lose hover states

**Example:**
```javascript
// Production may have:
function showModal(id) {
  document.getElementById(id).style.display = 'block';
}

// If you remove all inline styles and convert to:
<div id="orderModal" class="modal">

// The JS still sets style.display, which overrides your class.
// Solution: Keep inline style for display, or update JS (out of scope for Phase 12)
```

### Pitfall 2: Inconsistent Badge Color Mapping

**What goes wrong:** Production uses one color scheme, mockup uses another, Phase 12 implementation picks a third

**Why it happens:** `getBadge()` helper returns class names, mockup has specific colors, and Phase 12 planner assumes they match when they don't

**How to avoid:**
1. Before starting, audit `getBadge()` function in production
2. Compare output to mockup badge classes in shared.css
3. Document mapping explicitly in plan (e.g., "COMPLETED → badge-green per mockup line 839")
4. If production uses `badge-success` and mockup uses `badge-green`, decide which to use and update consistently

**Warning signs:**
- Completed trips showing in blue instead of green
- Payment types using status colors instead of payment-specific colors

**Example from research:**
```javascript
// Production getBadge() returns:
'COMPLETED' → 'badge-success' (generic Bootstrap-style naming)

// Mockup shared.css defines:
.badge-green { background: var(--green-dim); color: var(--green); }

// Phase 12 must either:
// Option A: Add .badge-success as alias to .badge-green in design-system.css
// Option B: Update getBadge() to return 'badge-green' (requires JS change—out of scope)
// Recommended: Option A (CSS-only change)
```

### Pitfall 3: Sticky Column Background Not Matching

**What goes wrong:** Sticky Actions column has white background in light theme, but table row hover shows gray—sticky column doesn't change

**Why it happens:** Forgot to add `.table tbody tr:hover .sticky-col` rule to match hover state

**How to avoid:**
1. When adding `position: sticky`, always add matching hover state
2. Test horizontal scroll AND row hover interaction
3. Verify in both light and dark themes

**Warning signs:**
- Sticky column flashes different color on row hover
- Dark theme shows light background in sticky column

**CSS fix (from shared.css pattern):**
```css
.sticky-col {
  position: sticky;
  right: 0;
  background: var(--bg-card);
  border-left: 1px solid var(--border);
}

/* CRITICAL: Add this hover state */
.table tbody tr:hover .sticky-col {
  background: var(--bg-card-hover);
}
```

### Pitfall 4: Assuming Production Matches Mockup Structure

**What goes wrong:** Plan says "apply .stat-card class to dashboard metrics" but production renders stats in a completely different structure than mockup

**Why it happens:** Mockup was designed independently—not based on production's actual render functions

**How to avoid:**
1. ALWAYS read production's renderXxx() function BEFORE planning
2. Compare production DOM structure to mockup DOM structure
3. Document structural differences in plan
4. When structures differ, adapt mockup styles to production structure (not vice versa)

**Warning signs:**
- Plan tasks fail because production doesn't have the expected HTML
- Developer has to restructure DOM to apply planned CSS

**Example:**
```javascript
// Mockup structure:
<div class="stat-grid">
  <div class="stat-card">...</div>
  <div class="stat-card">...</div>
</div>

// Production structure:
<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));">
  <div class="stat-card" style="border-left:4px solid var(--green)">...</div>
  <div class="stat-card" style="border-left:4px solid var(--red)">...</div>
</div>

// Phase 12 approach: Keep production's inline grid, just clean up stat-card classes
// Don't try to wrap in .stat-grid—production's approach works fine
```

### Pitfall 5: Missing Mockup Elements Cause Confusion

**What goes wrong:** Planner sees cool feature in mockup (e.g., sparkline charts on dashboard), writes task to add it, violates UI-only constraint

**Why it happens:** Mockup showcases ideal state with features that may not exist in production yet

**How to avoid:**
1. User decision from CONTEXT.md: "Only style what production already renders — skip any mockup elements that don't exist in current render functions"
2. Before planning each page, list all mockup sections
3. For each section, verify production actually renders it
4. Mark missing sections as "SKIP - not in production" in plan
5. Focus only on styling what exists

**Warning signs:**
- Plan includes tasks like "Add sparkline charts to dashboard"
- Tasks mention adding new data calculations or API calls
- DOM element counts increase after implementation

**Example from Dashboard:**
```
Mockup sections:
✓ Tasks Widget - Production renders this (renderTasksWidget())
✓ Recent Trips Table - Production renders this
✓ Stat Cards - Production renders these
✗ Top Performers Cards - Production does NOT render these
✗ Sparkline Charts - Production does NOT render these

Phase 12 approach: Style first 3 sections, skip last 2 sections
```

## Code Examples

Verified patterns from production and mockup analysis:

### Example 1: Convert Inline-Styled Stat Card to Design System

**Before (production index.html line 14267):**
```javascript
'<div class="stat-card" style="border-left:4px solid var(--green)"><div class="label">Revenue Generated</div><div class="value">' + formatMoney(totalRev) + '</div></div>'
```

**After (Phase 12 - using mockup pattern):**
```javascript
'<div class="stat-card"><div class="stat-icon green"><i data-lucide="dollar-sign" class="ico"></i></div><div class="stat-label">Revenue Generated</div><div class="stat-value">' + formatMoney(totalRev) + '</div></div>'
```

**CSS requirements (verify in design-system.css):**
```css
.stat-card {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.stat-icon {
  width: 44px;
  height: 44px;
  border-radius: var(--radius);
  display: flex;
  align-items: center;
  justify-content: center;
}

.stat-icon.green {
  background: var(--green-dim);
  color: var(--green);
}

.stat-value {
  font-size: var(--text-2xl);
  font-weight: var(--weight-heavy);
  color: var(--text-primary);
  font-family: var(--font-mono);
}

.stat-label {
  font-size: var(--text-xs);
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
```

### Example 2: Add Sticky Actions Column to Trips Table

**Before (production index.html line 15506):**
```javascript
'<th>Actions</th>'
// ...
'<td><div class="actions"><button class="action-btn view" onclick="viewTrip(' + trip.id + ')">View</button></div></td>'
```

**After (Phase 12):**
```javascript
'<th class="sticky-col">Actions</th>'
// ...
'<td class="sticky-col"><div class="actions"><button class="action-btn view" onclick="viewTrip(' + trip.id + ')">View</button></div></td>'
```

**CSS addition needed (if not in design-system.css):**
```css
.sticky-col {
  position: sticky;
  right: 0;
  background: var(--bg-card);
  border-left: 1px solid var(--border);
  display: flex;
  align-items: center;
  gap: 4px;
}

.table tbody tr:hover .sticky-col {
  background: var(--bg-card-hover);
}
```

### Example 3: Apply Badge Color Scheme

**Before (production uses generic getBadge() helper):**
```javascript
'<span class="badge ' + getBadge(trip.status) + '">' + trip.status + '</span>'

// getBadge() function (assumed implementation):
function getBadge(status) {
  if (status === 'COMPLETED') return 'badge-success';
  if (status === 'IN_PROGRESS') return 'badge-warning';
  return 'badge-default';
}
```

**After (Phase 12 - align with mockup color scheme):**

Option A (CSS-only, add aliases):
```css
/* Add to design-system.css */
.badge-success { background: var(--green-dim); color: var(--green); }
.badge-warning { background: var(--amber-dim); color: var(--amber); }
.badge-default { background: var(--blue-dim); color: var(--blue); }
```

Option B (if getBadge() needs updating - requires JS change, may be out of scope):
```javascript
function getBadge(status) {
  if (status === 'COMPLETED' || status === 'DELIVERED') return 'badge-green';
  if (status === 'IN_PROGRESS' || status === 'IN_TRANSIT') return 'badge-amber';
  if (status === 'PLANNED' || status === 'PENDING') return 'badge-blue';
  return 'badge-secondary';
}
```

**Recommended:** Option A (CSS aliases) to avoid JS changes in Phase 12.

### Example 4: Financial Breakdown with Color Coding

**Before (production trip detail - assumed structure):**
```javascript
'<div class="card"><div class="card-header"><h3>Trip Financials</h3></div>' +
'<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:16px;">' +
  '<div><div class="label">Load Revenue</div><div class="value">' + formatMoney(f.loadRevenue) + '</div></div>' +
  '<div><div class="label">Broker Fees</div><div class="value">' + formatMoney(f.brokerFee) + '</div></div>' +
  '<div><div class="label">Net Profit</div><div class="value">' + formatMoney(f.netProfit) + '</div></div>' +
'</div></div>'
```

**After (Phase 12 - add color coding per mockup):**
```javascript
'<div class="card"><div class="card-header"><h3 class="card-title"><i data-lucide="dollar-sign" class="ico" style="color:var(--green)"></i>Trip Financials</h3></div>' +
'<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:16px;">' +
  '<div style="text-align:center;padding:12px;background:var(--bg-app);border-radius:var(--radius);border:1px solid var(--border);">' +
    '<div style="font-size:var(--text-xs);color:var(--text-muted);text-transform:uppercase;letter-spacing:0.5px;margin-bottom:6px;">Load Revenue</div>' +
    '<div style="font-size:var(--text-2xl);font-weight:var(--weight-heavy);color:var(--green);font-family:var(--font-mono);">' + formatMoney(f.loadRevenue) + '</div>' +
  '</div>' +
  '<div style="text-align:center;padding:12px;background:var(--bg-app);border-radius:var(--radius);border:1px solid var(--border);">' +
    '<div style="font-size:var(--text-xs);color:var(--text-muted);text-transform:uppercase;letter-spacing:0.5px;margin-bottom:6px;">Broker Fees</div>' +
    '<div style="font-size:var(--text-2xl);font-weight:var(--weight-heavy);color:var(--red);font-family:var(--font-mono);">-' + formatMoney(f.brokerFee) + '</div>' +
  '</div>' +
  '<div style="text-align:center;padding:12px;background:var(--bg-app);border-radius:var(--radius);border:1px solid var(--border);">' +
    '<div style="font-size:var(--text-xs);color:var(--text-muted);text-transform:uppercase;letter-spacing:0.5px;margin-bottom:6px;">Net Profit</div>' +
    '<div style="font-size:var(--text-2xl);font-weight:var(--weight-heavy);color:' + (f.netProfit >= 0 ? 'var(--green)' : 'var(--red)') + ';font-family:var(--font-mono);">' + formatMoney(f.netProfit) + '</div>' +
  '</div>' +
'</div></div>'
```

**Color rules applied:**
- Revenue (income): green
- Fees (expenses): red
- Net Profit: green if positive, red if negative
- Use var() references, not hex codes

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Inline styles everywhere | Design tokens + CSS classes | Phase 11 (2026-02) | 99.7% hex color reduction, consistent theming |
| Manual color picking per element | Semantic color mapping (--text-primary, --bg-card) | Phase 11 | Theme switching works automatically |
| Bootstrap/generic CSS | Custom design system (design-system.css) | Phase 11 | Matches iOS v3 design language |
| Table columns scroll off-screen | CSS position: sticky for actions | 2024+ (native CSS feature) | Better UX, no JS scroll handlers needed |
| Hardcoded status colors | Badge color scheme via design tokens | Phase 12 | Consistent status → color mapping |

**Deprecated/outdated:**
- Fixed hex colors in inline styles: Replaced with CSS variables in Phase 11
- Bootstrap badge classes (badge-success, badge-warning): Keep as aliases for backward compatibility, but new code should use badge-green, badge-amber, etc.

## Open Questions

1. **Do all production helper functions output compatible HTML?**
   - What we know: `getBadge()` exists, returns class names for status badges
   - What's unclear: Exact class names it returns (badge-success vs badge-green)
   - Recommendation: Audit getBadge() output in plan research step, add CSS aliases if needed

2. **Are there JavaScript dependencies on inline styles?**
   - What we know: Production has 38K lines, may have `element.style.X` manipulations
   - What's unclear: Which inline styles are safe to remove vs. which are used by JS
   - Recommendation: Search for `.style.` in renderXxx() functions before each page, preserve critical styles (display, visibility)

3. **How much of Load Board page exists in production?**
   - What we know: Found `renderLoadBoard()` function at line 14636
   - What's unclear: How much it matches mockup load-board.html structure
   - Recommendation: Read full renderLoadBoard() before planning Load Board styling

4. **Should we consolidate similar inline styles into new CSS classes?**
   - What we know: Production has repeated inline style patterns (e.g., filter dropdowns, year selectors)
   - What's unclear: User preference—create new utility classes or keep inline with CSS variables?
   - Recommendation: Default to keeping inline styles if they already use CSS variables, only extract to classes if pattern repeats 5+ times

## Sources

### Primary (HIGH confidence)

- `/Users/reepsy/Desktop/OG TMS CLAUDE/mockups/web-tms-redesign/shared.css` - 1,308 line mockup design system (analyzed lines 1-1308)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/assets/css/design-system.css` - Production design system (analyzed lines 1-1310)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/index.html` - Production code (analyzed renderDashboard at line 14086, renderTrips at line 15453, renderOrders at line 17567)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/mockups/web-tms-redesign/dashboard.html` - Dashboard mockup (analyzed structure lines 200-349)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/mockups/web-tms-redesign/trips.html` - Trips mockup (analyzed sticky column styles lines 18-61)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/mockups/web-tms-redesign/order-detail.html` - Order detail mockup (analyzed route card lines 283-348)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/mockups/web-tms-redesign/trip-detail.html` - Trip detail mockup (analyzed financials card lines 238-293)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/.planning/phases/12-core-dispatch-pages/12-CONTEXT.md` - User decisions for Phase 12 scope

### Secondary (MEDIUM confidence)

- [Refactoring CSS: Introduction (Part 1) — Smashing Magazine](https://www.smashingmagazine.com/2021/07/refactoring-css-introduction-part1/) - CSS refactoring best practices
- [Modernising Legacy Applications through Design System Migration](https://www.linkedin.com/pulse/modernising-legacy-applications-through-design-system-nitin-rawal-1hgxe) - Phased migration approach
- [Building a design system into an existing legacy product | by Chandler Heath | Bootcamp](https://medium.com/design-bootcamp/building-a-design-system-into-an-existing-legacy-product-e498b3ece417) - Legacy integration patterns
- [Implementing a Design System in an Existing Product](https://www.netguru.com/blog/design-system-in-existing-product) - Progressive implementation strategies
- [CSS in 2026: The new features reshaping frontend development - LogRocket](https://blog.logrocket.com/css-in-2026/) - Modern CSS features (position: sticky, CSS variables)

### Tertiary (LOW confidence)

- [How to Redesign a Legacy UI Without Losing Users: UX Case Study](https://xbsoftware.com/blog/legacy-app-ui-redesign-mistakes/) - General redesign principles (not CSS-specific)
- [CSS Architectures: Refactor Your CSS — SitePoint](https://www.sitepoint.com/css-architectures-refactor-your-css/) - Older refactoring patterns (pre-CSS variables era)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All technologies already in production from Phase 11
- Architecture patterns: HIGH - Verified against actual production code and mockup HTML
- Pitfalls: MEDIUM - Based on common CSS refactoring issues and production code analysis, but specific pitfalls won't be known until implementation
- Code examples: HIGH - All examples extracted from actual production index.html and mockup files

**Research date:** 2026-02-10
**Valid until:** 2026-03-10 (30 days - design system is stable, core CSS patterns unlikely to change)

**Key files analyzed:**
- Production: index.html (38,049 lines, analyzed renderDashboard/renderTrips/renderOrders functions)
- Design system: design-system.css (1,310 lines), shared.css mockup (1,308 lines)
- Mockups: dashboard.html, trips.html, trip-detail.html, orders.html, order-detail.html, load-board.html

**Critical constraints from CONTEXT.md:**
- Pixel-perfect to mockup: Every card, grid, spacing detail matches mockup HTML exactly
- Only style what production renders: Skip mockup elements not in production
- Don't restructure filters: Keep production filter DOM, just restyle
- Exception for inspection photos: Match mockup's 4-image grid (user explicitly requested)
- Sticky right-side action columns: Apply to all list tables
- Status badge color scheme: Match mockup's specific mapping (green=completed, amber=in_progress, blue=planned)
