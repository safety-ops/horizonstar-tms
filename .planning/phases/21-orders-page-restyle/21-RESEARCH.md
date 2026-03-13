# Phase 21: Orders Page Restyle - Research

**Researched:** 2026-03-13
**Domain:** Orders page visual restyle (card view, table view, filters, pagination, shared helpers)
**Confidence:** HIGH

## Summary

Phase 21 restyles the orders page and two shared helpers (`renderOrderPreviewCard` at line 10598, `renderPaginationControls` at line 10066) to match the Stripe/Linear aesthetic established in Phase 19 (tokens) and Phase 20 (dashboard). The orders page renders at line 21703 via `renderOrders(c)` -- approximately 170 lines of template literal HTML supporting two view modes (cards and table) with filtering, search, pagination, and bulk selection.

The shared helper `renderOrderPreviewCard` is used in 8 locations across the codebase: the orders page (line 21859), loadboard/future cars (line 17718), trip detail assigned/available orders (lines 19964, 20002), local drivers (lines 23816, 23852), broker detail (line 24302), and dealer portal (line 24716). Restyling this single function propagates automatically to all these pages.

The current order card (lines 10598-10712) has a 30px order number heading (line 10658), 10px border-radius, 4px accent border-left, and extensive inline styles throughout. The pagination control (lines 10066-10079) uses a 12px rounded card background with Previous/Next buttons and inline centered text. Both need flattening to match the Stripe/Linear aesthetic: tighter spacing, smaller typography, hairline borders, desaturated badges.

**Primary recommendation:** Split into 3 sub-plans: (1) restyle `renderOrderPreviewCard` shared helper + order card CSS, (2) restyle `renderOrders` page header/filters/table view + `renderPaginationControls`, (3) verify downstream pages inherit correctly.

## Standard Stack

No new libraries needed. This phase is purely CSS/HTML restyle within the existing codebase.

### Core (Already Present)
| Tool | Version | Purpose | Notes |
|------|---------|---------|-------|
| CSS Variables (variables.css) | v3 | Design tokens | Slate scale, flat shadows, capped weights at 600 |
| Component Classes (base.css) | current | Reusable classes | `.badge`, `.badge-xs`, `.card`, `.text-label`, `.text-value`, `.section-header`, `.responsive-filter-bar` |
| Inline style block (index.html) | current | Order card CSS | `.order-list-item`, `.order-card-*` classes at lines 8422-8515 |

### Existing CSS Classes to USE
| Class | Purpose | Location |
|-------|---------|----------|
| `.badge` | Status badge container | base.css:1168 -- 11px, 500 weight, 2px 8px padding, 4px radius |
| `.badge-xs` | Extra-small badge | base.css:502 -- 10px, 2px 6px padding |
| `.badge-success/warning/danger/info/neutral` | Status colors | base.css:1178-1182 -- dim backgrounds with semantic text colors |
| `.section-header` / `.section-title` | Card section headers | base.css:402-424 -- flex between, 14px title, 1px border-bottom |
| `.responsive-filter-bar` | Filter container | base.css:764 -- flex wrap, padding 16px, bg-secondary, border, radius-lg |
| `.responsive-filter-group` | Filter label+select pair | base.css:776 -- flex, gap 8px |
| `.card` / `.card-flush` | Card containers | base.css -- bg-card, border, 16px padding, radius 8px |
| `.text-label` | Small uppercase label | base.css:496 -- 11px, 600 weight, text-muted, uppercase |
| `.text-value` | Data value | base.css:497 -- 14px, 600 weight, text-primary |
| `.action-btn-sm` | Compact action button | base.css:506 -- 4px 8px padding, 11px font, radius 6px |
| `.data-table` | Table styling | base.css -- alternating row tint, th bg tertiary |

### CSS Classes to MODIFY/ADD
| Class | Purpose | What Changes |
|-------|---------|-------------|
| `.order-list-item` | Order card container (line 8422) | Reduce border-radius from 10px to `var(--radius)` (8px), tighten padding |
| `.order-card-link` | Order number link (line 8453) | Reduce from 14px/600 to 13px/600, remove underline, add subtle hover |
| `.order-card-amount` | Revenue amount (line 8496) | Keep 13px/600, add `font-family: var(--font-mono)` and `tabular-nums` |
| `.pagination-controls` (NEW) | Pagination container | Flat inline bar, no card background, hairline top border |

## Architecture Patterns

### Current renderOrderPreviewCard Structure (line 10598-10712)
```
renderOrderPreviewCard(order, options)
  |
  +-- Row 1: Header (order-card-top)
  |     order-card-main: checkbox + order# link + status badge + payment type + trip#
  |     order-card-amount: revenue (right-aligned)
  |
  +-- Row 2: Vehicle + Driver (order-card-row, margin-top:6px)
  |
  +-- Row 3: Route + Pickup date (order-card-row, margin-top:4px)
  |
  +-- Row 4: Broker + Delivery date (order-card-row, margin-top:4px)
  |
  +-- Actions row (conditional, order-card-actions)
  |
  +-- Note row (conditional, order-card-note)
```

### Target renderOrderPreviewCard Structure (AFTER restyle)
```
renderOrderPreviewCard(order, options)
  |
  +-- Row 1: Header (order-card-top)
  |     order-card-main: checkbox + order# (14-16px, no underline) + status badge (desaturated) + payment chip
  |     order-card-amount: revenue (right, mono, tabular-nums)
  |
  +-- Row 2: Vehicle + Driver (order-card-row, tighter 4px gap)
  |
  +-- Row 3: Route + Pickup date (order-card-row)
  |
  +-- Row 4: Broker + Delivery date (order-card-row)
  |
  +-- Actions row (colored dim-blue/dim-amber/red buttons -- KEEP per user decision)
  |
  +-- Note row (desaturated amber indicator)
```

### renderOrders Page Structure
```
renderOrders(c)
  |
  +-- Page Header (.header .responsive-page-header)
  |     h2 "Vehicles / Orders"
  |     Year selector + info chips + view toggle + Export + AI Import (btn-secondary) + New Order (btn-primary)
  |
  +-- Filter Bar (.responsive-filter-bar)
  |     Search input + Status select + Dispatcher select + Driver select + Broker select + Clear + count
  |
  +-- Content (card view OR table view)
  |     Card: .card wrapper > select-all label > order cards via renderOrderPreviewCard
  |     Table: .card wrapper > select-all label > table > thead + tbody rows
  |
  +-- Pagination (renderPaginationControls)
```

### Pattern 1: Order Card Restyle (Stripe Invoice Row)
**What:** Compact, data-dense card with flat surface, hairline border, no heavy shadow, desaturated status badge.
**When to use:** All order card instances across the app.

```javascript
// Target card wrapper style change (in renderOrderPreviewCard)
let cardStyle = 'border:1px solid var(--border);background:var(--bg-card);border-radius:var(--radius);padding:10px 14px;cursor:pointer;transition:border-color 150ms ease,box-shadow 150ms ease';

// Target order number (14px, not 30px, no underline decoration)
'<button type="button" class="order-card-link" onclick="event.stopPropagation();openOrderDetailPage(' + order.id + ')">' + escapeHtml(orderLabel) + '</button>'

// CSS for order-card-link (restyle from current)
.order-card-link {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-primary);
  text-decoration: none;           /* Remove underline */
  cursor: pointer;
  background: none;
  border: none;
  padding: 0;
}
.order-card-link:hover {
  color: var(--blue);              /* Subtle hover color change */
}
```

### Pattern 2: Desaturated Status Badges
**What:** Status badges using the existing `.badge` + `.badge-*` classes from base.css. These already use dim backgrounds (8% opacity) with semantic colors.
**When to use:** All status indicators in order cards and table rows.

```javascript
// Current getBadge returns: badge-green, badge-amber, badge-blue, badge-red, badge-gray
// These DON'T match base.css classes which are: badge-success, badge-warning, badge-info, badge-danger, badge-neutral

// Need to either:
// (a) Update getBadge() returns to match base.css, OR
// (b) Add CSS rules for badge-green, badge-amber, badge-blue, badge-red, badge-gray

// Option (b) is safer -- add rules that mirror the base.css semantic badges:
.badge-green { background: var(--green-dim); color: var(--green); }
.badge-amber { background: var(--amber-dim); color: var(--amber); }
.badge-blue { background: var(--blue-dim); color: var(--blue); }
.badge-red { background: var(--red-dim); color: var(--red); }
.badge-gray { background: var(--bg-tertiary); color: var(--text-secondary); }
```

### Pattern 3: Flat Pagination Controls
**What:** Simple inline pagination with no card background, just a hairline top border.
**When to use:** renderPaginationControls (used on orders page + activity log).

```javascript
// Current (line 10074):
'<div class="pagination-controls" style="display:flex;align-items:center;justify-content:center;gap:12px;margin-top:20px;padding:16px;background:var(--bg-card);border-radius:12px">'

// Target:
'<div class="pagination-controls" style="display:flex;align-items:center;justify-content:center;gap:12px;margin-top:var(--space-4);padding:var(--space-3) var(--space-4);border-top:1px solid var(--border)">'
```

### Pattern 4: Filter Bar Label Style
**What:** Labels above or inline with selects, using text-label class pattern.
**When to use:** All filter dropdowns on orders page.

```javascript
// Current (line 21799):
'<label style="font-weight:600;color:var(--text-secondary)">Status:</label>'

// Target -- use text-label class (11px uppercase, muted):
'<label class="text-label">Status</label>'
```

### Pattern 5: View Toggle Active State
**What:** Card/table view toggle with subtle active indicator.
**When to use:** Orders page view mode toggle.

```javascript
// Current: active state uses var(--primary) background with white text
// Target: active state uses dark slate fill (matching btn-primary pattern)
const viewBtnActive = 'background:var(--btn-primary-bg);color:var(--btn-primary-color)';
const viewBtnInactive = 'background:transparent;color:var(--text-secondary)';
```

### Anti-Patterns to Avoid

- **30px order number heading:** The current `renderOrderPreviewCard` has a 30px heading at line 10658 that must be reduced to 14-16px. The `orderHeadingHtml` variable creates an alternative heading that is NOT used in the 4-row card layout but remains in the function -- it can be left as-is since it is only used when `orderClickable === false`.
- **Hardcoded hex colors in action buttons:** The action buttons in renderOrders (lines 21821-21822, 21854-21858) use inline styles like `background:var(--dim-red);color:var(--danger)`. These are already token-based per CONTEXT.md decisions -- KEEP them.
- **Purple AI Import button:** Currently `style="background:#8b5cf6;color:white"` (line 21793). Per user decision, change to `btn-secondary`.
- **border-radius: 12px on pagination:** Current pagination uses 12px radius card. Replace with flat borderless or hairline-top treatment.
- **10px border-radius on cards:** Current `border-radius:10px` in renderOrderPreviewCard (line 10668). Use `var(--radius)` (8px) instead.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Status badges | Custom inline styled spans | `.badge` + `.badge-success/warning/info/danger/neutral` from base.css | Already desaturated and consistent |
| Filter bar layout | Inline flex styles on filter container | `.responsive-filter-bar` + `.responsive-filter-group` from base.css | Already responsive and token-based |
| Table styling | Custom inline styles on table elements | `.data-table` class pattern from base.css | Alternating row tint, th bg tertiary already defined |
| Small labels | `style="font-weight:600;color:var(--text-secondary);font-size:13px"` | `.text-label` class | 11px uppercase muted, consistent across pages |
| Card containers | Inline border/bg/radius/padding | `.card` / `.card-flush` classes | Already token-based |

## Common Pitfalls

### Pitfall 1: renderOrderPreviewCard Has Dead Code for 30px Heading
**What goes wrong:** The function builds `orderHeadingHtml` at line 10658 with `font-size:30px;font-weight:700`. This is NOT used in the current 4-row card layout (the card uses `order-card-link` class instead at line 10682), but it looks like it should be restyled.
**Why it happens:** The heading was part of an older card design. The 4-row layout replaced it but left the variable.
**How to avoid:** Do NOT spend time on the `orderHeadingHtml` variable at line 10658. Focus on the `.order-card-link` class at line 10682 which is what actually renders. Optionally update the heading variable to 14px for safety.
**Warning signs:** Confusion about why the order number still looks big after changing the class.

### Pitfall 2: getBadge() Returns Don't Match base.css Badge Classes
**What goes wrong:** `getBadge()` at line 10270 returns `badge-green`, `badge-amber`, `badge-blue`, `badge-red`, `badge-gray`. But base.css defines `badge-success`, `badge-warning`, `badge-info`, `badge-danger`, `badge-neutral`.
**Why it happens:** The badge system was defined independently of the base.css class names.
**How to avoid:** Add CSS rules for the `badge-green/amber/blue/red/gray` class names that mirror the semantic badge styles. Do NOT change `getBadge()` return values as that would break every page using it.
**Warning signs:** Status badges render without color after removing inline styles.

### Pitfall 3: Mobile CSS Overrides for Order Cards (lines 5737-5835)
**What goes wrong:** The inline `<style>` block at line 5737 inside the `@media (max-width: 768px)` block has extensive `.order-list-item` and `.order-card-*` overrides with `!important` flags. If the desktop card CSS changes class names or structure, the mobile overrides may stop matching.
**Why it happens:** Mobile-specific CSS references specific child selectors like `.order-list-item > div:first-child > span:nth-child(4)`.
**How to avoid:** Keep the same class names (`.order-list-item`, `.order-card-top`, `.order-card-row`, `.order-card-link`, etc.). Only change styling properties, not class structure. After restyling, verify mobile view at 375px.
**Warning signs:** Mobile order cards show all metadata without truncation, or action buttons overflow.

### Pitfall 4: Inline Styles Override CSS Classes
**What goes wrong:** The `renderOrderPreviewCard` function builds `cardStyle` as a full inline style string (line 10668): `border:1px solid var(--border);background:var(--bg-card);border-radius:10px;padding:12px 16px;...`. This overrides any CSS class properties for border, background, radius, padding.
**Why it happens:** The function was written before the CSS class system existed.
**How to avoid:** Remove the conflicting inline style properties from `cardStyle` and let the `.order-list-item` class in the inline style block (line 8422) handle base styling. Or better: update the inline style block's `.order-list-item` with the new properties and reduce `cardStyle` to only dynamic overrides (accent border).
**Warning signs:** CSS class changes have no visible effect.

### Pitfall 5: Table View Has No Data-Table Class
**What goes wrong:** The orders table view (line 21839) uses `<table>` without the `.data-table` class, so it won't get the alternating row tint or refined header styling.
**Why it happens:** The table was written before the `.data-table` class existed.
**How to avoid:** Add `class="data-table"` to the table element in the table view branch.
**Warning signs:** Table rows have no visual separation.

### Pitfall 6: Year/Undated Info Chips Use Hardcoded 999px Radius
**What goes wrong:** The year badge and undated warning badge (line 21793) use `border-radius:999px` (pill shape) which contradicts the 6px/8px radius system.
**Why it happens:** Pre-Phase-19 design used pills.
**How to avoid:** Replace `border-radius:999px` with `border-radius:var(--radius-sm)` (6px). Use `.badge-xs` class pattern.
**Warning signs:** Info chips look visually inconsistent with other badges.

## Code Examples

### Current Order Card Container (line 10668) -- BEFORE
```javascript
let cardStyle = 'border:1px solid var(--border);background:var(--bg-card);border-radius:10px;padding:12px 16px;cursor:pointer;transition:background 0.15s ease';
if (options.accentColor) {
  cardStyle += ';border-left:4px solid ' + options.accentColor + ';padding-left:10px';
}
```

### Target Order Card Container -- AFTER
```javascript
let cardStyle = 'border:1px solid var(--border);background:var(--bg-card);border-radius:var(--radius);padding:var(--space-2-5) var(--space-3-5);cursor:pointer;transition:border-color 150ms ease,box-shadow 150ms ease';
if (options.accentColor) {
  cardStyle += ';border-left:3px solid ' + options.accentColor + ';padding-left:var(--space-2-5)';
}
```

### Current Order Number in Card (line 10682) -- BEFORE
```javascript
'<button type="button" class="order-card-link" onclick="event.stopPropagation();openOrderDetailPage(' + order.id + ')">' + escapeHtml(orderLabel) + '</button>'
// CSS: font-size: 14px; font-weight: 600; text-decoration: underline; text-underline-offset: 3px;
```

### Target Order Number in Card -- AFTER
```javascript
// Same HTML, update CSS class:
.order-card-link {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-primary);
  text-decoration: none;          /* Remove underline for cleaner look */
  cursor: pointer;
  background: none;
  border: none;
  padding: 0;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.order-card-link:hover {
  color: var(--blue);
}
```

### Current Pagination (line 10074) -- BEFORE
```javascript
return '<div class="pagination-controls" style="display:flex;align-items:center;justify-content:center;gap:12px;margin-top:20px;padding:16px;background:var(--bg-card);border-radius:12px">' +
  '<button class="btn btn-secondary" onclick="changePage(\'' + pageKey + '\', ' + (p.page - 1) + ')" ' + prevDisabled + ' style="padding:10px 16px">← Previous</button>' +
  '<span style="color:var(--text-muted)">Page <strong>' + p.page + '</strong> / ' + totalPages + ' (' + p.total + ' records)</span>' +
  '<button class="btn btn-secondary" onclick="changePage(\'' + pageKey + '\', ' + (p.page + 1) + ')" ' + nextDisabled + ' style="padding:10px 16px">Next →</button>' +
  '</div>';
```

### Target Pagination -- AFTER
```javascript
return '<div class="pagination-controls" style="display:flex;align-items:center;justify-content:center;gap:var(--space-3);padding:var(--space-3) var(--space-4);margin-top:var(--space-4);border-top:1px solid var(--border)">' +
  '<button class="btn btn-secondary" onclick="changePage(\'' + pageKey + '\', ' + (p.page - 1) + ')" ' + prevDisabled + ' style="padding:6px 12px;font-size:13px">← Previous</button>' +
  '<span style="color:var(--text-muted);font-size:13px">Page <strong>' + p.page + '</strong> / ' + totalPages + ' (' + p.total + ')</span>' +
  '<button class="btn btn-secondary" onclick="changePage(\'' + pageKey + '\', ' + (p.page + 1) + ')" ' + nextDisabled + ' style="padding:6px 12px;font-size:13px">Next →</button>' +
  '</div>';
```

### Current AI Import Button (line 21793) -- BEFORE
```javascript
'<button class="btn" style="background:#8b5cf6;color:white" onclick="openCreateNewLoad()">[[icon:file]] AI Import</button>'
```

### Target AI Import Button -- AFTER
```javascript
'<button class="btn btn-secondary" onclick="openCreateNewLoad()">[[icon:file]] AI Import</button>'
```

### Current Table Row Action Buttons (line 21821-21822) -- BEFORE
```javascript
const assignBtn = t
  ? '<button class="action-btn" style="padding:4px 8px;font-size:11px;background:var(--dim-red);color:var(--danger)" onclick="unassignOrderFromTrip(' + o.id + ')" title="Unassign">Unlink</button>'
  : '<button class="action-btn" style="padding:4px 8px;font-size:11px;background:var(--dim-blue);color:var(--info)" onclick="openAssignToTrip(' + o.id + ')" title="Assign to trip">Assign</button>';
```
Note: These STAY as-is per user decision (colored action buttons are functional).

### Current View Toggle (line 21788-21791) -- BEFORE
```javascript
const viewBtnBase = 'padding:6px 10px;border:none;cursor:pointer;transition:all 0.15s;display:flex;align-items:center;justify-content:center;';
// Active: background:var(--primary) + color:white
// Inactive: background:transparent + color:var(--text-secondary)
```

### Target View Toggle -- AFTER
```javascript
const viewBtnBase = 'padding:6px 10px;border:none;cursor:pointer;transition:background 150ms ease;display:flex;align-items:center;justify-content:center;';
// Active: dark slate fill matching btn-primary
const activeStyle = 'background:var(--btn-primary-bg);color:var(--btn-primary-color)';
// Inactive: transparent with muted icon
const inactiveStyle = 'background:transparent;color:var(--text-muted)';
```

### Table with data-table Class
```javascript
// Current table (line 21839):
'<div class="table-wrapper"><table><thead>...'
// Target:
'<div class="table-wrapper"><table class="data-table"><thead>...'
```

## Discretion Recommendations

Based on the Stripe/Linear aesthetic established in Phase 19-20:

### Card surface treatment: Hairline border, no left accent by default
Use `border: 1px solid var(--border)` with `background: var(--bg-card)` and `border-radius: var(--radius)`. Only add border-left accent when `options.accentColor` is passed (this already works via the existing conditional). No background tint.

### Table row separation: Alternating subtle tint via data-table
Use the `.data-table` class which already provides `nth-child(even)` background tinting via `var(--bg-tertiary)`. This is subtler than zebra stripes and matches Phase 20's table patterns.

### Table header styling: Standard flat headers
Use `.data-table th` which provides `background: var(--bg-tertiary)` and text-secondary color. Not uppercase -- keep standard capitalization for readability on dense data.

### Table card padding: Edge-to-edge (card-flush)
Use `padding:0` on the card wrapper with `overflow:hidden` so table extends to card edges. This is the Stripe pattern for tables-in-cards.

### Filter bar label style: text-label class (uppercase, muted)
Use the `.text-label` class pattern (11px, uppercase, muted, letter-spacing). This matches the stat-card-label pattern from Phase 20.

### View toggle active state: Dark slate fill
Use `var(--btn-primary-bg)` (#0f172a dark slate) for active state. This matches the primary button styling and is more professional than the green `var(--primary)`.

### Pagination container: Flat with hairline top border
No card background or radius. Just a `border-top: 1px solid var(--border)` with centered content. Compact padding (12px 16px).

### Status badge desaturation: Already handled
The existing `.badge-*` classes in base.css already use 8% opacity dim backgrounds. No additional desaturation needed -- just ensure badges use these classes consistently.

### Year/undated info chip styling: Use badge-xs pattern
Replace pill shapes (999px radius) with `badge-xs` class (4px radius, 10px font, 2px 6px padding). Use `badge-info` for year chip, `badge-warning` for undated exclusion chip.

### Dispatcher notes indicator: Keep current amber dim treatment
The note indicator button using `background:var(--dim-amber);color:var(--warning)` is already token-based and appropriately desaturated.

### Badge sizing: Use badge-xs (10px, 2px 6px padding)
Consistent with the Phase 20 attention pill sizing.

## State of the Art

| Old Approach (Current) | New Approach (Target) | Impact |
|------------------------|----------------------|--------|
| 30px order number heading | 14px compact link | Data-dense, scannable like Stripe invoice rows |
| `border-radius:10px` on cards | `var(--radius)` (8px) | System consistency |
| `border-radius:999px` on info chips | `badge-xs` class with 4px radius | System consistency |
| `border-radius:12px` on pagination | Flat with hairline border-top | Lighter visual weight |
| Purple AI Import button (`#8b5cf6`) | btn-secondary | Clear hierarchy: only New Order gets btn-primary |
| Underline text-decoration on order# | No underline, blue hover color | Cleaner look, still clickable |
| Table without `.data-table` class | Table with `.data-table` class | Alternating tint, refined headers |
| Inline style labels (`font-weight:600;color:var(--text-secondary)`) | `.text-label` CSS class | Consistent uppercase muted labels |
| View toggle active = green `var(--primary)` | Active = dark slate `var(--btn-primary-bg)` | Professional neutral active state |
| Pagination = card with background | Flat bar with hairline top border | Lighter, integrated feel |

## Open Questions

1. **Order detail modal restyle scope:**
   - What we know: The success criteria mentions "order detail modals all follow the Stripe/Linear aesthetic." But the order detail view (`openOrderDetailPage`) is a separate full-page render, not a modal.
   - What's unclear: Should the order detail page be restyled in this phase, or is it a separate phase?
   - Recommendation: Keep scope to the orders LIST page (card view + table view), the filter bar, pagination, and the shared helpers. The order detail page is a full-page view with its own render function and should be a separate phase if needed.

2. **getBadge color class CSS definitions:**
   - What we know: `getBadge()` returns `badge-green`, `badge-amber`, etc. These are used with inline styles on some pages. Base.css defines `badge-success`, `badge-warning`, etc.
   - What's unclear: Whether `badge-green` etc. are defined anywhere in the inline style block.
   - Recommendation: Add `.badge-green`, `.badge-amber`, `.badge-blue`, `.badge-red`, `.badge-gray` rules to the inline style block (or base.css) that mirror the semantic badge styling using dim backgrounds.

## Sources

### Primary (HIGH confidence)
- `index.html` lines 10066-10079 -- renderPaginationControls function fully read
- `index.html` lines 10598-10712 -- renderOrderPreviewCard function fully read
- `index.html` lines 21703-21870 -- renderOrders function fully read
- `index.html` lines 8422-8515 -- order card CSS classes in inline style block
- `index.html` lines 5737-5835 -- mobile order card CSS overrides
- `assets/css/base.css` lines 369-493 -- Phase 20 CSS additions (stat-card, section-header, attention-pill)
- `assets/css/base.css` lines 496-507 -- text utilities and compact badge/action classes
- `assets/css/base.css` lines 747-789 -- responsive filter/page header classes
- `assets/css/base.css` lines 1168-1182 -- badge variant definitions
- `assets/css/variables.css` -- Full token inventory (Design System v3)
- Phase 20 RESEARCH.md and VERIFICATION.md -- Established patterns and verified approach

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- No new dependencies, all existing code analyzed line-by-line
- Architecture: HIGH -- All three functions (renderOrders, renderOrderPreviewCard, renderPaginationControls) fully read, all CSS classes mapped, all inline styles catalogued
- Pitfalls: HIGH -- Cascade conflicts identified with exact line numbers, mobile overrides mapped, getBadge class mismatch identified, dead code heading identified

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (stable -- no external dependencies)
