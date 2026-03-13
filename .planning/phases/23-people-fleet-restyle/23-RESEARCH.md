# Phase 23: People & Fleet Restyle - Research

**Researched:** 2026-03-13
**Domain:** CSS/JS visual restyling of 5 people/fleet management pages
**Confidence:** HIGH

## Summary

This phase restyles five pages -- Drivers (line 22715), Local Drivers (line 23686), Trucks (line 23435), Brokers (line 24399), and Dispatchers (line 24715) -- to the Stripe/Linear aesthetic established in Phases 19-22. All required CSS classes, tokens, and component patterns already exist in base.css and variables.css from prior phases.

The main work is replacing inline styles with CSS tokens, swapping hardcoded hex colors for CSS variables, capping font weights at 600, removing gradient summary cards, applying `.stat-flat` / `.data-table` / `.card-flush` / `.segmented-control` classes, and normalizing page headers to the 18px/600 pattern. No behavior changes, no layout restructuring.

**Primary recommendation:** Process each render function top-to-bottom, replacing inline styles with existing CSS component classes. The Brokers page has the most work (gradient summary cards, hardcoded colors throughout). Drivers and Local Drivers are moderate. Trucks and Dispatchers are the simplest -- Trucks already uses `.data-table` and `.card-flush`, and Dispatchers is a short function.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| CSS custom properties | N/A | Theming tokens | Established in variables.css (Phase 19) |
| base.css component library | v1.4 | Reusable UI classes | Established in Phase 19, extended in 20-22 |
| Inline JS template literals | N/A | DOM rendering | Existing pattern for all 5 render functions |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `getBadge()` | N/A | Status badge CSS class mapping | Driver/truck status badges (already used) |
| `renderEmptyState()` | N/A | Empty state rendering | Already used on all 5 pages |
| `renderOrderPreviewCard()` | N/A | Order card rendering | Already used in Local Drivers pending sections |
| `formatMoney()` | N/A | Currency formatting | All monetary values |

### Alternatives Considered
None -- this phase uses only existing tools and patterns from Phases 19-22.

## Architecture Patterns

### Pattern 1: Page Header (v1.4 Standard)
**What:** Consistent header with 18px/600 title, no emoji icons, btn-primary for main CTA only.
**Established in:** Phase 21 (Orders), Phase 22 (Trips)
**Template:**
```html
<div class="header responsive-page-header">
  <h2 style="font-size:18px;font-weight:600">Page Title</h2>
  <div class="responsive-page-actions">
    <!-- filters here -->
    <button class="btn btn-primary">+ New Thing</button>
  </div>
</div>
```
**Changes needed per page:**
- Drivers: Remove `[[icon:users]]` emoji, change header font to 18px/600, change Owner-OP button from `btn-primary style="background:#f59e0b"` to `btn-secondary`
- Local Drivers: Remove `[[icon:car]]` emoji, simplify year filter wrapper (remove `surface-elevated` bg), use `.select` class
- Trucks: Remove `[[icon:truck]]` emoji, change header font to 18px/600
- Brokers: Remove `[[icon:building]]` emoji, change header font to 18px/600, replace inline-styled selects with `.select` class, replace inline-styled period badges with neutral style
- Dispatchers: Remove "Dispatchers" emoji-less header is already okay but needs 18px/600 sizing

### Pattern 2: Stat Cards (v1.4 Flat)
**What:** Replace gradient/colored summary cards with `.stat-flat` class pattern.
**Established in:** Phase 20 (Dashboard), Phase 21 (Orders)
**Template:**
```html
<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:var(--space-3);margin-bottom:var(--space-5)">
  <div class="stat-flat">
    <div class="stat-flat-label">Label</div>
    <div class="stat-flat-value" style="font-family:var(--font-mono)">123</div>
  </div>
</div>
```
**Pages needing stat card restyle:**
- Brokers: 4 gradient cards (blue/green/amber/purple with white text) must become flat
- Local Drivers: 6 `.stat-card` with colored backgrounds must become `.stat-flat`
- Dispatchers: `.responsive-stat-strip` with colored backgrounds must become `.stat-flat`
- Dispatcher Ranking: Multiple colored stat cards + "TOP PERFORMER" / "NEEDS IMPROVEMENT" spotlight cards

### Pattern 3: Card Grid (Drivers/Brokers)
**What:** Keep existing `grid-template-columns:repeat(auto-fill,minmax(Xpx,1fr))` layout, restyle individual cards.
**Changes:**
- Driver cards: Already use `var(--bg-card)` and `var(--border)` -- mostly correct. Need to cap `font-weight:700` to 600, change trip count `font-weight:800` to 600, change earnings `font-weight:700` to 600. Owner-OP badge uses hardcoded `#f59e0b` -- change to `badge-amber`.
- Broker cards: Currently use correct `var(--bg-card)` bg. Need to remove hardcoded colors from activity status dots (`#16a34a`, `#2563eb`, `#f59e0b`, `#dc2626`), score colors, rank medals. Replace with CSS variable equivalents. Cap font weights at 600.

### Pattern 4: Table Pages (Trucks, Local Drivers, Dispatchers)
**What:** Use `.data-table` class with `.card-flush` wrapper for clean tables.
**Established in:** Phase 21 (Orders table view), Phase 22 (Trips table)
**Template:**
```html
<div class="card card-flush">
  <div class="table-wrapper">
    <table class="data-table">
      <thead><tr><th>...</th></tr></thead>
      <tbody>...</tbody>
    </table>
  </div>
</div>
```
**Changes needed:**
- Trucks: Already uses `.data-table` and `.card-flush` -- minimal changes needed (check for inline style overrides)
- Local Drivers: Table is inside `.card` but missing `.card-flush` and `.data-table` class
- Dispatchers: Table inside `.card` but missing `.data-table` class, uses bare `<table>`
- Dispatcher Ranking: Table inside `.card` but missing `.data-table` class, has hardcoded background colors on rows

### Pattern 5: Period/Year Filters (v1.4 Standard)
**What:** Use `.select` class for dropdowns, neutral pill for period label.
**Established in:** Phase 21 (Orders year filter)
**Template:**
```html
<div style="display:flex;align-items:center;gap:var(--space-2)">
  <label style="font-weight:500;color:var(--text-secondary);font-size:13px">Year:</label>
  <select class="select" onchange="...">...</select>
</div>
<span style="font-size:10px;background:var(--bg-tertiary);color:var(--text-secondary);padding:2px 6px;border-radius:4px">Year 2026</span>
```
**Pages needing filter restyle:**
- Local Drivers: Overly styled year filter (surface-elevated bg, fancy border-radius) -- simplify
- Brokers: Inline-styled selects -- add `.select` class, replace colored period badge
- Dispatchers: Inline-styled selects -- add `.select` class, replace colored period badge
- Dispatcher Ranking: Multiple inline-styled selects -- add `.select` class

### Pattern 6: Alerts/Banners (Drivers)
**What:** Document expiration alerts banner at top of Drivers page.
**Current:** Uses hardcoded `#fef2f2`, `#fecaca` background/border.
**Restyle:** Replace with CSS variable equivalents -- `background:var(--bg-card);border:1px solid var(--border)` with a subtle left border accent `border-left:3px solid var(--red)`.

### Anti-Patterns to Avoid
- **Gradient stat cards:** `background:linear-gradient(135deg,...)` with white text -- replace with `.stat-flat`
- **Hardcoded hex colors:** `#16a34a`, `#2563eb`, `#f59e0b`, `#dc2626`, `#7c3aed` etc in inline styles -- replace with `var(--green)`, `var(--blue)`, `var(--amber)`, `var(--red)`, `var(--purple)` or semantic tokens
- **Font-weight above 600:** `font-weight:700`, `font-weight:800` -- cap at 600
- **Colored stat card backgrounds:** `background:#dbeafe`, `background:#d1fae5` etc -- use `.stat-flat` (neutral bg)
- **Emoji icons in headers:** `[[icon:users]]`, `[[icon:car]]`, `[[icon:building]]`, `[[icon:truck]]`, `[[icon:trophy]]` -- remove from page headings
- **Full-width colored card-header bars:** `background:#3b82f6;color:white` on `.card-header` -- use neutral header or subtle left border accent
- **rgba() inline backgrounds on rows:** `background:rgba(34,197,94,0.1)` on table rows -- remove or use very subtle `var(--bg-secondary)` for top row only

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Status badges | Inline colored spans | `getBadge()` + `.badge-*` classes | Already handles all statuses consistently |
| Stat cards | Inline gradient divs | `.stat-flat` / `.stat-flat-label` / `.stat-flat-value` | Consistent flat appearance |
| Tables | Bare `<table>` with inline styles | `.data-table` + `.card-flush` | Headers, borders, row styling handled by CSS |
| Period filter pills | Inline colored spans | Neutral `var(--bg-tertiary)` pill | Consistent with Orders/Trips |
| Empty states | Custom "no data" divs | `renderEmptyState()` | Already used everywhere |
| Form selects | Inline-styled `<select>` | `.select` class | Consistent input styling |

## Common Pitfalls

### Pitfall 1: Missing the Dispatcher Ranking Page
**What goes wrong:** renderDispatcherRanking (line 24835) is a separate function from renderDispatchers and could be overlooked.
**Why it happens:** It renders a completely different page ("Dispatcher Performance Ranking") with its own header, stat cards, spotlight cards, and ranking table.
**How to avoid:** Explicitly plan for both renderDispatchers AND renderDispatcherRanking as separate tasks.
**Warning signs:** If only renderDispatchers is in the plan, the ranking page will look inconsistent.

### Pitfall 2: viewDriverProfile and viewBrokerDetails Detail Views
**What goes wrong:** Driver cards link to a detailed profile view (viewDriverProfile, line 22781) and brokers link to viewBrokerDetails (line 24618). These detail views also have inline styles and hardcoded colors.
**Why it happens:** These are "sub-pages" rendered in the same main-content area, easy to miss when focusing on list views.
**How to avoid:** Plan for both the list view AND detail views for Drivers and Brokers.
**Warning signs:** Clicking "View" on a driver/broker shows old-style detail page.

### Pitfall 3: viewLocalDriverDetails
**What goes wrong:** Local Drivers page has a detail view (viewLocalDriverDetails) that may have old-style inline styles.
**How to avoid:** Check for and include this detail view in the plan.

### Pitfall 4: Hardcoded Colors in Broker Score/Activity Functions
**What goes wrong:** `getScoreColor()`, `getScoreLabel()`, and `getActivityStatus()` helper functions (lines 24480-24500) return hardcoded hex colors used in inline styles.
**Why it happens:** These functions are defined inside renderBrokers and return color values directly.
**How to avoid:** Replace hardcoded hex returns with CSS variable references (`var(--green)`, `var(--blue)`, `var(--amber)`, `var(--red)`) and corresponding semantic background references.

### Pitfall 5: Colored Section Headers in Local Drivers
**What goes wrong:** The "Pending Local Pickup" and "Pending Local Delivery" sections use full-width colored `.card-header` backgrounds (`background:#3b82f6;color:white` and `background:#f59e0b;color:white`).
**Why it happens:** These were designed as high-visibility sections before the restyle.
**How to avoid:** Replace with neutral card headers + subtle left border accent or a small colored dot/icon. The content descriptions below also use colored backgrounds (`#dbeafe`, `#fffbeb`) that need replacing.

### Pitfall 6: Owner-OP Button Dual Primary Buttons
**What goes wrong:** Drivers page currently has TWO `btn-primary` buttons -- "New Driver" and "Add Owner-OP" (styled orange with inline background override).
**Why it happens:** Owner-OP add was added separately with a distinct color.
**How to avoid:** Change "Add Owner-OP" to `btn-secondary` per the one-primary-per-page rule.

## Code Examples

### Example 1: Driver Card (Before -> After)
**Before (current):**
```javascript
'<h4 style="margin:0;font-size:14px;font-weight:700;...">'
'<span style="font-size:18px;font-weight:800;color:var(--text-primary)">' + trips.length + '</span>'
'<div style="font-size:15px;font-weight:700;font-family:var(--font-mono);color:var(--success)">'
```
**After (v1.4):**
```javascript
'<h4 style="margin:0;font-size:14px;font-weight:600;...">'
'<span style="font-size:18px;font-weight:600;color:var(--text-primary)">' + trips.length + '</span>'
'<div style="font-size:15px;font-weight:600;font-family:var(--font-mono);color:var(--green)">'
```

### Example 2: Broker Stat Cards (Before -> After)
**Before (current):**
```javascript
'<div style="background:linear-gradient(135deg,#3b82f6,#1d4ed8);color:white;padding:14px 16px;border-radius:12px;text-align:center">' +
'<div style="font-size:12px;opacity:0.9">Total Brokers</div>' +
'<div style="font-size:24px;font-weight:800">' + count + '</div></div>'
```
**After (v1.4):**
```javascript
'<div class="stat-flat">' +
'<div class="stat-flat-label">Total Brokers</div>' +
'<div class="stat-flat-value">' + count + '</div></div>'
```

### Example 3: Period Filter Badge (Before -> After)
**Before (current):**
```javascript
'<span style="font-size:12px;background:var(--dim-blue);color:var(--info);padding:6px 10px;border-radius:999px;font-weight:600;border:1px solid var(--info-border)">' + label + '</span>'
```
**After (v1.4):**
```javascript
'<span style="font-size:10px;background:var(--bg-tertiary);color:var(--text-secondary);padding:2px 6px;border-radius:4px">' + label + '</span>'
```

### Example 4: Local Drivers Table (Before -> After)
**Before:**
```javascript
'<div class="card" style="margin-bottom:24px"><div class="card-header"><h3>...</h3></div>' +
'<div class="desktop-only"><div class="table-wrapper"><table><thead>...'
```
**After:**
```javascript
'<div class="card card-flush" style="margin-bottom:var(--space-5)"><div class="card-header" style="padding:var(--space-3) var(--space-4)"><h3 style="font-size:14px;font-weight:600;margin:0">...</h3></div>' +
'<div class="desktop-only"><div class="table-wrapper"><table class="data-table"><thead>...'
```

### Example 5: Colored Card Header (Before -> After)
**Before:**
```javascript
'<div class="card-header" style="background:#3b82f6;color:white;border-radius:8px 8px 0 0"><h3 style="margin:0">Pending Local Pickup</h3></div>'
```
**After:**
```javascript
'<div class="card-header" style="padding:var(--space-3) var(--space-4);border-left:3px solid var(--blue)"><h3 style="font-size:14px;font-weight:600;margin:0;color:var(--text-primary)">Pending Local Pickup</h3></div>'
```

## Inventory of Changes Per Page

### renderDrivers (line 22715-22779) -- ~65 lines
- [ ] Page header: Remove emoji, 18px/600, Owner-OP button to btn-secondary
- [ ] Alert banner: Replace hardcoded `#fef2f2`/`#fecaca` with CSS variables
- [ ] Driver cards: Cap font-weight at 600 (currently 700/800 in several places)
- [ ] Owner-OP badge: `background:#f59e0b` to `badge-amber` class
- [ ] File count badges: Already use `var(--dim-*)` -- OK as-is
- [ ] viewDriverProfile detail view (line 22781-23434): Stat cards with hardcoded backgrounds, colored values

### renderLocalDrivers (line 23686-23854) -- ~170 lines
- [ ] Page header: Remove emoji, 18px/600, simplify year filter
- [ ] Stat strip: `.stat-card` with colored backgrounds to `.stat-flat`
- [ ] Driver table: Add `.data-table` class, `.card-flush` on wrapper
- [ ] Pending Pickup section: Remove colored card-header, replace colored info bar
- [ ] Pending Delivery section: Same as above
- [ ] Action buttons in pending sections: Currently use hardcoded colors
- [ ] viewLocalDriverDetails: Check for inline style issues

### renderTrucks (line 23435-23498) -- ~65 lines
- [ ] Page header: Remove emoji, 18px/600
- [ ] Table: Already uses `.data-table` and `.card-flush` -- verify, minimal changes
- [ ] Mobile cards: Check for any hardcoded colors
- [ ] This is the simplest page to restyle

### renderBrokers (line 24399-24558) -- ~160 lines
- [ ] Page header: Remove emoji, 18px/600, restyle selects with `.select` class
- [ ] Summary cards: 4 gradient cards to `.stat-flat`
- [ ] Broker card grid: Replace hardcoded activity colors, score colors, medal icons
- [ ] Helper functions: `getScoreColor()`, `getActivityStatus()` return hardcoded hex
- [ ] Revenue/profit values: font-weight 700 to 600, hardcoded color refs
- [ ] Per-load metric pills: Already use `var(--dim-*)` -- mostly OK
- [ ] viewBrokerDetails (line 24618-24713): Stat cards, broker info card, colored pills

### renderDispatchers (line 24715-24766) -- ~50 lines
- [ ] Page header: 18px/600 sizing
- [ ] Period filter: Restyle selects with `.select` class, neutral period badge
- [ ] Table: Add `.data-table` class, already inside `.card`
- [ ] Simplest page after Trucks

### renderDispatcherRanking (line 24835-25012) -- ~180 lines
- [ ] Page header: Remove `[[icon:trophy]]` emoji, 18px/600
- [ ] Filter bar: Restyle selects, neutral period badge
- [ ] Stat strip: Colored stat cards to `.stat-flat`
- [ ] Spotlight cards: "TOP PERFORMER" / "NEEDS IMPROVEMENT" -- flatten (remove large emoji, tone down colors, use subtle accent)
- [ ] Ranking table: Add `.data-table` class, remove colored row backgrounds
- [ ] Progress bars: Currently use `rgba()` colors -- use CSS variables
- [ ] Leaderboard cards: Remove colored headers
- [ ] `getMedal()` / `getProgressBar()` helper functions: Review for hardcoded colors

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Gradient stat cards | `.stat-flat` class | Phase 19-20 | All summary metrics should be flat |
| Bare `<table>` | `.data-table` class | Phase 19 | Consistent table styling |
| Colored card headers | Neutral + left border accent | Phase 21-22 | Section differentiation without color blocks |
| `font-weight:700-800` | Capped at 600 | Phase 19 | Lighter, more refined typography |
| Hardcoded hex colors | CSS variables | Phase 19 | Themeable, consistent palette |
| Emoji icons in headers | Text-only headers | Phase 21-22 | Cleaner, more professional |
| Colored period badges | Neutral `var(--bg-tertiary)` pills | Phase 21 | Less visual noise |

## Open Questions

1. **viewLocalDriverDetails function location**
   - What we know: It exists and is called from the local driver table
   - What's unclear: Exact line number -- need to search for it during implementation
   - Recommendation: Locate it early and include in scope

2. **rankedByCards helper (line 25014)**
   - What we know: Used by Dispatcher Ranking for leaderboard cards
   - What's unclear: Whether it has hardcoded colors
   - Recommendation: Check during Dispatcher Ranking task

## Sources

### Primary (HIGH confidence)
- Direct code inspection of index.html render functions (lines 22715-25012)
- base.css component library inspection (1948 lines)
- variables.css token inspection (162 lines)
- Phase 22 RESEARCH.md patterns and conventions

### Secondary (MEDIUM confidence)
- Memory/MEMORY.md accumulated context on design system conventions

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools already exist from Phases 19-22
- Architecture: HIGH - Patterns are identical to already-completed pages
- Pitfalls: HIGH - Based on direct code inspection of all 5+ render functions

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (stable -- CSS restyle patterns are well-established)
