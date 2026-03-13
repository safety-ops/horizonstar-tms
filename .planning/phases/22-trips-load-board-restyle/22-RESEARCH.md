# Phase 22: Trips & Load Board Restyle - Research

**Researched:** 2026-03-13
**Domain:** CSS/JS visual restyling of trips page and load board page
**Confidence:** HIGH

## Summary

This phase restyles two pages — the Trips page (renderTrips, line 19167) and the Load Board / "Future Cars" page (renderLoadBoard, line 17650) — to match the Stripe/Linear aesthetic established in Phases 19-21. Both pages currently use hardcoded inline styles with the old blue `#1e40af` active states, colored borders, and gradient-style category buttons that conflict with the neutral/monochrome design system.

The work is purely visual — no behavior changes. All the CSS tokens, component classes, and patterns needed already exist from Phases 19-21: `.data-table`, `.badge-*`, `.btn-primary/.btn-secondary/.btn-ghost`, `.input/.select`, `.stat-flat`, `.card-flush`, `renderOrderPreviewCard()`, `renderEmptyState()`, and `renderPaginationControls()`.

**Primary recommendation:** Apply existing component classes and CSS tokens to replace all hardcoded inline styles. Build two new CSS classes (`.segmented-control` and `.trip-card`) in base.css. The Load Board already uses `renderOrderPreviewCard` which was restyled in Phase 21 — only the surrounding chrome (category tabs, stats, section headers) needs updating.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| CSS custom properties | N/A | Theming tokens | Already established in variables.css |
| Inline JS template literals | N/A | DOM rendering | Existing renderTrips/renderLoadBoard pattern |
| base.css component library | v1.4 | Reusable UI classes | Established in Phase 19 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `getBadge()` | N/A | Status badge classes | Trip status badges |
| `renderOrderPreviewCard()` | N/A | Order card rendering | Load Board cards (already used) |
| `renderEmptyState()` | N/A | Empty state rendering | Already used in trips table |

### Alternatives Considered
None — this phase uses only existing tools.

## Architecture Patterns

### Pattern 1: Segmented Control (New Component)
**What:** A contained control with multiple options in a shared background container, used for truck tabs and density toggle.
**When to use:** Any multi-option toggle where options are mutually exclusive.
**CSS class to add to base.css:**
```css
/* --- Segmented Control --- */
.segmented-control {
  display: inline-flex;
  align-items: center;
  gap: 0;
  padding: 2px;
  background: var(--bg-tertiary);
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
}
.segmented-control-btn {
  padding: 6px 14px;
  font-size: 13px;
  font-weight: 500;
  color: var(--text-secondary);
  background: transparent;
  border: none;
  border-radius: calc(var(--radius-sm) - 2px);
  cursor: pointer;
  transition: background 150ms ease, color 150ms ease, box-shadow 150ms ease;
  white-space: nowrap;
  font-family: inherit;
}
.segmented-control-btn.active {
  background: var(--bg-card);
  color: var(--text-primary);
  box-shadow: var(--shadow-xs);
  font-weight: 600;
}
.segmented-control-btn:hover:not(.active) {
  color: var(--text-primary);
}
```
**Rationale for "white card lift" style:** The active tab lifts out with a white card bg + subtle shadow against the gray container. This is the Stripe/Linear convention — neutral, clean, no bold color fills. Dark slate fill (the alternative) would draw too much visual weight to a navigation control.

### Pattern 2: Truck Tabs as Horizontal Scrolling Segmented Control
**What:** All truck tabs inside a single `.segmented-control` container, horizontal scroll on overflow.
**Current code (line 19201-19209):** Each truck tab is a standalone `<button>` with inline styles, blue `#1e40af` active state, badge count.
**New approach:** Wrap all tabs in `.segmented-control`, use `.segmented-control-btn` per tab. Show truck number only (per decision), no trip counts.
**Overflow:** Horizontal scroll with `overflow-x: auto; scrollbar-width: none; -webkit-overflow-scrolling: touch` on the container. This matches the current behavior (line 19324 already uses `overflow-x:auto`). Scroll is preferred over wrap because trucks can scale to 10+ and wrapping would push content down unpredictably.

### Pattern 3: Density Toggle as Segmented Control
**What:** Reuse the exact same `.segmented-control` pattern for the density toggle (Compact/Default/Comfy).
**Position:** Place in the same row as truck tabs, right-aligned. Year filter and density toggle on the left side of the header row, truck tabs below. This keeps filter controls grouped together and truck tabs in their own visual band.
**Label text:** Keep "Compact", "Default", "Comfy" — these are concise and established.

### Pattern 4: Trip Cards (New Structure)
**What:** Flat card for trip data in card view mode (currently only mobile has cards, desktop is table-only).
**Key data:** Trip number, truck number, driver name, order count, status, revenue, dates.
**Structure:**
```
.trip-card (border:1px solid var(--border), bg: var(--bg-card), radius: var(--radius), padding: var(--space-3))
  Row 1: [Trip # (link)] [status badge (top-right)]
  Row 2: [Truck #xxx] [Driver Name]
  Row 3: [4 orders badge] [Revenue amount]
  Row 4: [Date range] [Actions]
```
**CSS class to add:**
```css
.trip-card {
  border: 1px solid var(--border);
  background: var(--bg-card);
  border-radius: var(--radius);
  padding: var(--space-3) var(--space-4);
  cursor: pointer;
  transition: border-color 150ms ease, box-shadow 150ms ease;
}
.trip-card:hover {
  border-color: var(--border-strong);
  box-shadow: var(--shadow-sm);
}
```

### Pattern 5: Orders Table Restyling (Follow Phase 21)
**What:** The trips table should use `.data-table` class and `.card-flush` wrapper, exactly like the orders table in Phase 21.
**Current code (line 19326):** Uses inline `style` attributes with hardcoded `#f8fafc`, `#e2e8f0` colors.
**New approach:** Apply `.data-table` class to `<table id="trips-table">`, wrap in `.card.card-flush`, use density CSS classes to modify `.data-table td/th` padding.

### Pattern 6: Load Board Category Tabs
**What:** Category tabs currently use colored borders and fills matching each category's color (blue, purple, cyan, green, amber, red, pink).
**New approach:** Use the segmented control pattern for categories. Active = white card lift, inactive = transparent. Show count in parentheses. Remove per-category colors from tabs — the staging area should feel neutral.
**Subcategory tabs:** Same pattern, slightly smaller (use `padding: 4px 10px; font-size: 12px` variant).

### Pattern 7: Load Board Stats and Section Headers
**What:** Stats row uses old `.stat-card` class. Category section header uses colored background.
**New approach:** Stats use `.stat-flat` class. Section header drops the colored background — use a simple heading with count, bordered bottom.

### Anti-Patterns to Avoid
- **Hardcoded hex colors in inline styles:** Always use CSS variables (e.g., `var(--text-secondary)` not `#475569`).
- **Blue `#1e40af` active states:** Replace with white card lift (segmented control) or `var(--btn-primary-bg)` (#0f172a dark slate).
- **Category-colored tabs:** The new aesthetic is monochrome for navigation controls. Color should only appear in badges/status indicators.
- **Inline `style` for repeated patterns:** Use CSS classes from the component library.
- **Using `--border-primary` or `--radius-md`:** These are NOT defined in variables.css and resolve to nothing. Use `--border` and `--radius` respectively.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Status badges | Inline badge styles | `getBadge(trip.status)` + `.badge` class | Already maps all trip statuses correctly |
| Order cards on load board | Custom card HTML | `renderOrderPreviewCard()` | Already restyled in Phase 21, already used by load board |
| Empty states | Custom empty HTML | `renderEmptyState()` | Already used in trips table |
| Table styling | Inline table CSS | `.data-table` class in base.css | Handles headers, hover, borders, sticky columns |
| Button styling | Inline button styles | `.btn-primary`, `.btn-secondary`, `.btn-ghost` | Component library from Phase 19 |
| Input/Select styling | Inline form styles | `.input`, `.select` classes | Component library from Phase 19 |

**Key insight:** Nearly everything needed already exists. The main new CSS is the segmented control component (which will be reused across other pages later).

## Common Pitfalls

### Pitfall 1: Undefined CSS Variables
**What goes wrong:** Code uses `var(--border-primary)` and `var(--radius-md)` which are not defined in variables.css. They resolve to empty/initial values.
**Why it happens:** Phase 21 introduced these without adding them to variables.css, or they were used assuming they existed.
**How to avoid:** Only use variables defined in variables.css. Use `--border` (not `--border-primary`) and `--radius` (not `--radius-md`).
**Warning signs:** Elements with missing borders or incorrect border-radius.

### Pitfall 2: Density Toggle CSS Specificity
**What goes wrong:** Density classes `.density-compact`, `.density-default`, `.density-comfortable` modify `#trips-table td/th` padding. If the table uses `.data-table` class, the `.data-table td` padding (10px 14px) may override density settings.
**Why it happens:** Both selectors target `td` padding with equal or conflicting specificity.
**How to avoid:** Use `.density-compact .data-table td` selectors (compound class + descendant) to ensure density overrides data-table defaults. Or place density CSS after data-table CSS.
**Warning signs:** Density toggle appears to do nothing.

### Pitfall 3: Truck Tab Click Handlers
**What goes wrong:** Truck tab `onclick` handlers set `selectedTruckTab` and re-render. The inline styles are embedded in the onclick attribute string. Changing to CSS classes requires keeping the onclick logic unchanged.
**Why it happens:** renderTrips builds truck tabs as string concatenation with embedded onclick.
**How to avoid:** Only change the visual attributes (class names, remove inline styles). Don't touch the onclick logic at all.
**Warning signs:** Clicking truck tabs no longer works.

### Pitfall 4: Load Board Category Color References
**What goes wrong:** Each `loadBoardCategories` entry has a `.color` property (e.g., `#3b82f6` for NY to Home). The current code uses `cat.color` for tab borders, backgrounds, and section headers.
**Why it happens:** Category colors are deeply integrated into the rendering.
**How to avoid:** Keep the `loadBoardCategories` data structure unchanged. Simply stop using `cat.color` in tab buttons and section headers. The color data still exists for any future use.
**Warning signs:** JavaScript errors from trying to access removed properties.

### Pitfall 5: Mobile Card View Divergence
**What goes wrong:** Trips has both desktop (table) and mobile (cards) views, with separate HTML generation. Restyling only the desktop view leaves mobile looking inconsistent.
**Why it happens:** The mobile cards HTML is built in the same loop (line 19229-19250) but with different markup.
**How to avoid:** Restyle both desktop table AND mobile cards in the same pass. Mobile cards should use the same `.trip-card` class.
**Warning signs:** Mobile view still shows old styling while desktop looks new.

## Code Examples

### Segmented Control for Truck Tabs
```javascript
// Replace current truckTabs building code (line 19201-19209)
const truckTabs = trucksWithTrips.map(t => {
  const isActive = t.id === selectedTruckTab;
  return '<button class="segmented-control-btn' + (isActive ? ' active' : '') + '" ' +
    'onclick="selectedTruckTab=' + t.id + ';renderTrips(document.getElementById(\'main-content\'))">' +
    escapeHtml(String(t.truck_number)) + '</button>';
}).join('');
// Wrap in: '<div class="segmented-control" style="overflow-x:auto;max-width:100%;scrollbar-width:none">' + truckTabs + '</div>'
```

### Segmented Control for Density Toggle
```javascript
// Replace current density toggle (line 19312-19316)
const densityHtml = '<div class="segmented-control">' +
  '<button class="segmented-control-btn' + (tripsDensity==='compact' ? ' active' : '') + '" ' +
    'onclick="localStorage.setItem(\'tripsDensity\',\'compact\');renderTrips(document.getElementById(\'main-content\'))">Compact</button>' +
  '<button class="segmented-control-btn' + (tripsDensity==='default' ? ' active' : '') + '" ' +
    'onclick="localStorage.setItem(\'tripsDensity\',\'default\');renderTrips(document.getElementById(\'main-content\'))">Default</button>' +
  '<button class="segmented-control-btn' + (tripsDensity==='comfortable' ? ' active' : '') + '" ' +
    'onclick="localStorage.setItem(\'tripsDensity\',\'comfortable\');renderTrips(document.getElementById(\'main-content\'))">Comfy</button>' +
  '</div>';
```

### Status Filter Tabs as Segmented Control
```javascript
// Replace current statusTabs (line 19261-19265)
const statusTabs = '<div class="segmented-control" style="margin-bottom:var(--space-4)">' +
  '<button class="segmented-control-btn' + (tripStatusFilter==='active' ? ' active' : '') + '" ' +
    'onclick="tripStatusFilter=\'active\';renderTrips(document.getElementById(\'main-content\'))">Active (' + activeCount + ')</button>' +
  '<button class="segmented-control-btn' + (tripStatusFilter==='completed' ? ' active' : '') + '" ' +
    'onclick="tripStatusFilter=\'completed\';renderTrips(document.getElementById(\'main-content\'))">Completed (' + completedCount + ')</button>' +
  '<button class="segmented-control-btn' + (tripStatusFilter==='all' ? ' active' : '') + '" ' +
    'onclick="tripStatusFilter=\'all\';renderTrips(document.getElementById(\'main-content\'))">All (' + allCount + ')</button>' +
  '</div>';
```

### Trip Table with data-table Class
```javascript
// Replace current table markup (line 19326)
'<div class="card card-flush density-' + tripsDensity + '">' +
  '<div style="padding:var(--space-3) var(--space-4);border-bottom:1px solid var(--border)">' +
    '<strong style="font-size:var(--text-base);font-weight:600">Truck ' + (selectedTruck ? escapeHtml(String(selectedTruck.truck_number)) : '-') + '</strong>' +
    '<span style="color:var(--text-secondary);margin-left:var(--space-3);font-size:var(--text-sm)">' + truckTrips.length + ' trips</span>' +
  '</div>' +
  '<div class="table-wrapper"><table id="trips-table" class="data-table"><thead>...'
```

### Load Board Category Tabs (Monochrome Segmented)
```javascript
// Replace current category tabs (line 17686-17691)
'<div class="segmented-control" style="margin-bottom:var(--space-4)">' +
loadBoardCategories.map(cat => {
  const isActive = cat.id === selectedLoadCategory;
  return '<button class="segmented-control-btn' + (isActive ? ' active' : '') + '" ' +
    'onclick="selectedLoadCategory=\'' + cat.id + '\';selectedLoadSub=null;renderLoadBoard(document.getElementById(\'main-content\'))">' +
    escapeHtml(cat.name) + ' (' + categoryCounts[cat.id] + ')</button>';
}).join('') + '</div>'
```

### Load Board Stats with stat-flat
```javascript
// Replace current stat-card usage (line 17679-17683)
'<div style="display:flex;flex-wrap:wrap;gap:var(--space-3);margin-bottom:var(--space-5)">' +
  '<div class="stat-flat"><div class="stat-flat-label">Total Unassigned</div><div class="stat-flat-value">' + unassignedOrders.length + '</div></div>' +
  '<div class="stat-flat"><div class="stat-flat-label">In ' + escapeHtml(currentCat.name) + '</div><div class="stat-flat-value">' + categoryCounts[currentCat.id] + '</div></div>' +
  '<div class="stat-flat"><div class="stat-flat-label">Revenue (Displayed)</div><div class="stat-flat-value">' + formatMoney(totalRevenue) + '</div></div>' +
'</div>'
```

## Current Code Inventory

### renderTrips (line 19167-19333)
Key inline-style areas to replace:
1. **Truck tabs** (line 19201-19209): Blue `#1e40af` active, `#e2e8f0` border, badge counts
2. **Status filter tabs** (line 19260-19265): Blue `#1e40af` active, `#f1f5f9` inactive
3. **Density toggle** (line 19299, 19312-19316): Inline var(--primary) active, transparent inactive
4. **Column visibility dropdown** (line 19306-19319): Inline styles for dropdown menu
5. **Year selector** (line 19311): Inline styles for background/border
6. **Page header** (line 19310): Old `.header` class with h2 icon
7. **Desktop table** (line 19326): Hardcoded `#f8fafc`, `#e2e8f0` in truck header
8. **Desktop table rows** (line 19226): No `.data-table` class on `<table>`
9. **Mobile cards** (line 19232-19250): Inline var(--bg-card) etc. — mixed token usage

### renderLoadBoard (line 17650-17727)
Key inline-style areas to replace:
1. **Page header** (line 17676): Old `.header` class
2. **Stats row** (line 17679-17683): `.stat-card` class (not `.stat-flat`)
3. **Category tabs** (line 17686-17691): Per-category colors, 2px colored borders
4. **Subcategory tabs** (line 17695-17701): `#cbd5e1` border, `#1e40af` active
5. **Section header** (line 17704): `cat.color` background with white text
6. **Empty state** (line 17705): Inline gray text
7. **Order cards** (line 17707-17724): Already use `renderOrderPreviewCard` (good, already restyled)

## Open Questions

1. **Card view toggle on trips page?**
   - What we know: Orders page has a card/table toggle. Trips currently has table on desktop, cards only on mobile.
   - What's unclear: Should trips get a desktop card view toggle like orders? The CONTEXT.md says "card view" but the current code only has mobile cards.
   - Recommendation: Add a card/table view toggle to match orders page, using the same view toggle pattern. Desktop card view uses the new `.trip-card` class.

2. **Column visibility dropdown styling**
   - What we know: The trips page has a column visibility dropdown (line 19306-19319) not present on orders.
   - What's unclear: Should it keep its gear icon style or adopt a different pattern?
   - Recommendation: Keep the dropdown but restyle with `.btn-secondary` for the trigger button and clean dropdown styles using existing tokens.

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection: `index.html` lines 17627-17900 (load board), 19161-19333 (trips)
- Direct codebase inspection: `assets/css/variables.css` (all token definitions)
- Direct codebase inspection: `assets/css/base.css` lines 1037-1229 (component library)
- Phase 21 orders page patterns: `index.html` lines 21700-21850

### Secondary (MEDIUM confidence)
- MEMORY.md prior decisions documentation
- Phase context decisions document

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all tools exist in codebase already
- Architecture: HIGH - patterns directly observed from Phase 19-21 precedent
- Pitfalls: HIGH - identified from direct code inspection of current implementation

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (stable — no external dependencies)
