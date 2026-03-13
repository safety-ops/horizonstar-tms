# Phase 20: Dashboard Restyle - Research

**Researched:** 2026-03-12
**Domain:** Dashboard visual restyle to Stripe/Linear aesthetic
**Confidence:** HIGH

## Summary

Phase 20 is a purely visual restyle of the existing `renderDashboard()` function (index.html lines 17188-17703) and its supporting functions (`renderSuggestedActions`, `renderTasksWidget`, `renderSparkline`). The function currently outputs ~515 lines of template literal HTML with extensive inline styles. The token foundation from Phase 19 is already in place (variables.css uses Slate scale, flat shadows, 6px/8px radii, capped weights at 600). The work is replacing inline styles with token-based values and restructuring markup to match the Stripe/Linear aesthetic: label-above-number stat cards, flat neutral surfaces, whitespace-organized sections, no gradients or heavy shadows.

The current dashboard has three key visual problems: (1) the Company Profitability section uses a dark gradient background (`linear-gradient(135deg,#1e293b,#334155)`) which contradicts flat surfaces, (2) the attention strip pills use hardcoded colors and rounded-pill shapes (20px radius) that don't match the tighter 6px/8px radius system, and (3) the KPI grid is only 3 cards wide when 5-6 are needed.

**Primary recommendation:** Work in 3 sub-tasks: (1) KPI stat strip + attention strip restyle, (2) main content area + sidebar restyle, (3) analytics section restyle. Each sub-task rewrites the corresponding portion of the `renderDashboard` template literal using CSS variables from variables.css and component classes from base.css.

## Standard Stack

No new libraries needed. This phase is purely CSS/HTML restyle within the existing codebase.

### Core (Already Present)
| Tool | Version | Purpose | Notes |
|------|---------|---------|-------|
| CSS Variables (variables.css) | v3 | Design tokens | Slate scale, flat shadows already set by Phase 19 |
| Component Classes (base.css) | current | Reusable classes | `.stat-card`, `.card`, `.card-flush`, `.text-label`, `.text-value`, `.text-mono` |
| Inline SVG sparklines | N/A | Chart rendering | `renderSparkline()` at line 10676, inline SVG generation |

### Existing CSS Classes to USE (from base.css)
| Class | Purpose | Current Definition |
|-------|---------|-------------------|
| `.stat-card` | KPI card container | bg-card, border, 14px 16px padding, flex column, gap 8px |
| `.stat-card .stat-label` | Uppercase label | 11px, text-muted, uppercase, 0.5px letter-spacing |
| `.stat-card .stat-value` | Large number | text-2xl (24px), weight 600, font-mono |
| `.card` | Section container | bg-card, border, 16px padding, radius 8px, shadow-xs |
| `.card-flush` | Card with no padding | padding: 0 |
| `.text-label` | Small uppercase label | 11px, weight 600, text-muted, uppercase |
| `.text-value` | Data value | 14px, weight 600, text-primary |
| `.text-mono` | Monospace numbers | font-mono, tabular-nums |

### Existing CSS Classes CONFLICTING (in inline style block)
| Class | Location | Issue |
|-------|----------|-------|
| `.stat-card` | index.html line 1191 | Overrides base.css with `align-items: flex-start` (horizontal layout with icon), `border-radius: var(--radius-lg)` |
| `.dashboard-stat-card` | index.html line 1267 | "Premium" card with `::before` pseudo-element, `translateY(-3px)` hover, `border-radius: 16px` |
| `.stat-card:hover` | index.html line 1203 | Changes border to primary color + shadow-md -- too aggressive |

## Architecture Patterns

### Recommended Dashboard Structure

```
renderDashboard(c)
  |
  +-- Page Header (greeting + period selectors)
  |
  +-- KPI Stat Strip (5-6 cards in horizontal row)
  |     - Label above number pattern
  |     - Sub-label below number
  |     - Optional left border accent (2px, not 3px)
  |
  +-- Main Grid (2fr + 1fr)
  |   |
  |   +-- Left Column (2/3)
  |   |     +-- Section Header ("Recent Trips" + "View all -->")
  |   |     +-- Recent Trips table/cards
  |   |     +-- Section Header ("Company Profitability" + "View all -->")
  |   |     +-- Profitability metrics (FLAT background, no gradient)
  |   |
  |   +-- Right Column (1/3)
  |         +-- Needs Action card
  |         +-- Quick Actions card
  |         +-- Suggested Actions (or merged into Needs Action)
  |         +-- Payment Collection card
  |
  +-- Collapsible Analytics Section
        +-- Other Metrics + Expense Breakdown
        +-- Fuel Tracking
        +-- KPIs + Top Performers
        +-- Cost Trend Sparklines
```

### Pattern 1: Label-Above-Number Stat Card (REQUIRED by success criteria)

**What:** Stripe-style KPI card with small uppercase label on top, large monospace number below, optional sub-label at bottom.
**When to use:** All 5-6 KPI cards on the dashboard.

```html
<!-- Target markup pattern -->
<div class="stat-card">
  <div class="stat-card-label">Revenue</div>
  <div class="stat-card-value">$142,800</div>
  <div class="stat-card-sub">24 trips / 187 cars</div>
</div>
```

```css
/* Stat card restyle -- override inline block and base.css */
.stat-card {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius);        /* 8px */
  padding: var(--space-4) var(--space-5); /* 16px 20px */
  display: flex;
  flex-direction: column;
  gap: var(--space-1);                 /* 4px */
  box-shadow: var(--shadow-xs);
}

.stat-card-label {
  font-size: var(--text-xs);           /* 11px */
  font-weight: var(--weight-medium);   /* 500 */
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: var(--tracking-wide); /* 0.05em */
}

.stat-card-value {
  font-size: var(--text-xl);           /* 20px */
  font-weight: var(--weight-semibold); /* 600 */
  font-family: var(--font-mono);
  color: var(--text-primary);
  letter-spacing: -0.02em;
  font-variant-numeric: tabular-nums;
}

.stat-card-sub {
  font-size: var(--text-xs);           /* 11px */
  color: var(--text-secondary);
}
```

### Pattern 2: Section Header with Action Link

**What:** Section title on left, "View all -->" link on right.
**When to use:** Every content section (Recent Trips, Profitability, Needs Action, etc.).

```html
<div class="section-header">
  <h3 class="section-title">Recent Trips</h3>
  <a class="section-link" onclick="navigate('trips')">View all &rarr;</a>
</div>
```

```css
.section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space-3-5) var(--space-4); /* 14px 16px */
  border-bottom: 1px solid var(--border);
}

.section-title {
  font-size: var(--text-base);         /* 14px */
  font-weight: var(--weight-semibold); /* 600 */
  color: var(--text-primary);
  margin: 0;
}

.section-link {
  font-size: var(--text-sm);           /* 13px */
  font-weight: var(--weight-medium);   /* 500 */
  color: var(--text-secondary);
  cursor: pointer;
  text-decoration: none;
}
.section-link:hover {
  color: var(--text-primary);
}
```

### Pattern 3: Flat Profitability Section (replacing gradient card)

**What:** The Company Profitability section currently uses `background: linear-gradient(135deg, #1e293b, #334155)` with white text. Replace with a flat card using standard surface colors.
**Why:** Gradient backgrounds contradict the "flat surfaces, no gradients" success criteria.

```html
<!-- Replace dark gradient card with flat card -->
<div class="card card-flush">
  <div class="section-header">
    <h3 class="section-title">Company Profitability</h3>
    <span class="badge-xs" style="...">10,240 mi / 187 cars</span>
  </div>
  <div class="dashboard-profitability-grid">
    <!-- Each metric cell uses standard flat background -->
    <div class="profitability-cell">
      <div class="stat-card-label">Cost Per Mile</div>
      <div class="stat-card-value" style="color: var(--red)">$1.42</div>
      <div class="stat-card-sub">Operating CPM</div>
    </div>
    ...
  </div>
</div>
```

### Anti-Patterns to Avoid

- **Dark gradient backgrounds:** The current profitability section (`linear-gradient(135deg,#1e293b,#334155)`) must be replaced with flat `var(--bg-card)`.
- **Hardcoded colors in inline styles:** Current template has 50+ hardcoded hex values (e.g., `#10b981`, `#ef4444`, `#f59e0b`). Replace with CSS variable references.
- **Rounded pill shapes (20px+ radius):** Attention strip pills use `border-radius: 20px`. The design system uses 6px/8px. Use `var(--radius-sm)` or `var(--radius)`.
- **Icon boxes in stat cards:** Success criteria explicitly says "no icon boxes" -- don't add `.stat-icon` divs.
- **translateY hover effects:** The `.dashboard-stat-card:hover` uses `transform: translateY(-3px)`. Stripe/Linear does not lift cards on hover.
- **Colored border-bottom on section headers:** Current analytics headers use `border-bottom: 2px solid #color`. Use `1px solid var(--border)` instead.
- **Font weight 700:** Phase 19 capped at 600. Several inline styles use `font-weight: 700`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Stat card component | Custom div structures with inline styles | `.stat-card` class with `.stat-card-label`, `.stat-card-value`, `.stat-card-sub` | Consistency, maintainability |
| Section headers | Inline `<div style="display:flex;justify-content:space-between...">` | `.section-header` / `.section-title` / `.section-link` pattern | Reusable across all pages |
| Sparkline charts | New charting library | Existing `renderSparkline()` function | Already built, just needs color updates |
| Loading skeletons | Complex animation system | Simple CSS `@keyframes shimmer` with `.skeleton` class | 5 lines of CSS |
| Color accents on cards | Inline `style="border-left:3px solid #10b981"` | CSS class like `.stat-card--green` with `border-left: 2px solid var(--green)` | Token-consistent |

## Common Pitfalls

### Pitfall 1: Inline Style Block Override Cascade
**What goes wrong:** Changes to base.css `.stat-card` get overridden by the inline `<style>` block at line 1191 in index.html.
**Why it happens:** The inline style block declares `.stat-card` with different layout (horizontal with icon, `align-items: flex-start`) and also `.dashboard-stat-card` which won't be used.
**How to avoid:** Either (a) update the inline style block's `.stat-card` rules to match the new pattern, or (b) add dashboard-specific overrides at higher specificity. Option (a) is cleaner.
**Warning signs:** Stat cards render horizontally instead of vertically after changes.

### Pitfall 2: Hardcoded Colors Surviving the Restyle
**What goes wrong:** After restyle, some elements still use pre-Phase-19 colors (e.g., `#10b981` instead of `var(--green)`; `#ef4444` instead of `var(--red)`).
**Why it happens:** The renderDashboard template has ~50 hardcoded hex color references in inline styles.
**How to avoid:** Search-and-replace all hex values in the dashboard template with corresponding CSS variable references. Key mappings:
- `#10b981` / `#047857` -> `var(--green)` / green dark variant
- `#ef4444` / `#dc2626` -> `var(--red)` / `var(--danger)`
- `#f59e0b` / `#92400e` -> `var(--amber)` / amber dark variant
- `#3b82f6` / `#1d4ed8` -> `var(--blue)` / blue dark variant
- `#8b5cf6` / `#7c3aed` -> `var(--purple)` / purple dark variant
- `#64748b` -> `var(--text-secondary)`
- `#94a3b8` -> `var(--text-muted)`
- `#334155` / `#1e293b` -> slate values (for profitability section -- REMOVE gradient)
**Warning signs:** Colors look wrong in dark theme toggle.

### Pitfall 3: Breaking Mobile Layout
**What goes wrong:** KPI grid changes from 3 columns to 5-6 columns but doesn't have mobile breakpoints.
**Why it happens:** The `.dashboard-kpi-grid` currently does `grid-template-columns: repeat(3, minmax(0, 1fr))` with a mobile override at 768px to `1fr`.
**How to avoid:** Use `repeat(auto-fit, minmax(160px, 1fr))` for the 5-6 card KPI grid. This naturally collapses on narrow screens.
**Warning signs:** Cards are too narrow or overflow on tablet.

### Pitfall 4: Profitability Grid Collapse
**What goes wrong:** The 6-column profitability grid (`repeat(6, minmax(0, 1fr))`) breaks on medium screens.
**Why it happens:** 6 equal columns at 280px min width need 1680px+ to render properly.
**How to avoid:** Already has responsive breakpoints at lines 1125 and 1145 of base.css. Verify they still work after restyle.

### Pitfall 5: Attention Strip Identity Crisis
**What goes wrong:** The attention strip pills become visually identical to stat cards after restyle.
**Why it happens:** If both use the same card treatment, the distinction between "actionable alerts" and "metrics" is lost.
**How to avoid:** Make attention strip items more compact than stat cards. Use inline-flex with gap, no card background. Alternatively, merge them into a single horizontal row of subtle count badges at the page header level.

## Code Examples

### Current KPI Card (line 17444) -- BEFORE
```javascript
'<div class="stat-card" style="border-left:3px solid #10b981">' +
  '<div style="font-size:11px;color:var(--text-muted);text-transform:uppercase;letter-spacing:0.5px">Revenue</div>' +
  '<div style="font-size:20px;font-weight:700;font-family:var(--font-mono);margin-top:4px">' + formatMoney(totalRev) + '</div>' +
  '<div style="font-size:11px;color:var(--text-muted);margin-top:2px">' + yearTrips.length + ' trips &middot; ' + totalCars + ' cars</div>' +
'</div>'
```

### Target KPI Card -- AFTER
```javascript
'<div class="stat-card">' +
  '<div class="stat-card-label">Revenue</div>' +
  '<div class="stat-card-value">' + formatMoney(totalRev) + '</div>' +
  '<div class="stat-card-sub">' + yearTrips.length + ' trips &middot; ' + totalCars + ' cars</div>' +
'</div>'
```

### Current Attention Strip Pill (line 17405) -- BEFORE
```javascript
'<div onclick="navigate(\'orders\')" style="display:inline-flex;align-items:center;gap:8px;padding:8px 16px;border-radius:20px;background:var(--dim-amber,#fef3c7);cursor:pointer;border:1px solid rgba(245,158,11,0.2);transition:all 0.15s" onmouseover="this.style.transform=\'translateY(-1px)\'" onmouseout="this.style.transform=\'translateY(0)\'">' +
  '<span style="font-size:14px;color:#f59e0b">[[icon:order]]</span>' +
  '<span style="font-size:13px;font-weight:700;color:#f59e0b">' + count + '</span>' +
  '<span style="font-size:12px;color:#92400e;font-weight:500">Unassigned</span>' +
'</div>'
```

### Target Attention Strip Pill -- AFTER
```javascript
'<div class="attention-pill attention-pill--amber" onclick="navigate(\'orders\')">' +
  '<span class="attention-pill-count">' + count + '</span>' +
  '<span class="attention-pill-label">Unassigned Orders</span>' +
'</div>'
```

### Current Section Header -- BEFORE
```javascript
'<div style="padding:14px 16px;border-bottom:1px solid var(--border)">' +
  '<h3 style="margin:0;font-size:14px;font-weight:700">[[icon:truck]] Recent Trips (' + label + ')</h3>' +
'</div>'
```

### Target Section Header -- AFTER
```javascript
'<div class="section-header">' +
  '<h3 class="section-title">Recent Trips (' + label + ')</h3>' +
  '<a class="section-link" onclick="navigate(\'trips\')">View all &rarr;</a>' +
'</div>'
```

### Recommended 5-6 KPI Card Set
Based on the existing metrics calculated in renderDashboard:

| # | Label | Value Source | Sub-label | Accent |
|---|-------|-------------|-----------|--------|
| 1 | Revenue | `totalRev` | `X trips / Y cars` | green |
| 2 | Profit | `totalProfit` | `X% margin` | green/red (conditional) |
| 3 | Expenses | `totalExpenses + fees + driverCut` | `$X driver cuts` | red |
| 4 | Clean Gross | `cleanGross` | `Rev - broker - local` | blue |
| 5 | Miles | `totalMiles` | `source: samsara/trips` | slate |
| 6 | Avg/Car | `avgPricePerCar` | `X cars hauled` | purple |

All values already computed in lines 17194-17308. No new data fetching needed.

### Skeleton Loading State (recommended for Claude's discretion)
```css
.skeleton {
  background: var(--bg-tertiary);
  border-radius: var(--radius-sm);
  animation: shimmer 1.5s infinite;
}

@keyframes shimmer {
  0% { opacity: 0.6; }
  50% { opacity: 1; }
  100% { opacity: 0.6; }
}
```

```javascript
// Use in stat cards while loading
'<div class="stat-card"><div class="skeleton" style="width:60px;height:11px"></div><div class="skeleton" style="width:100px;height:20px;margin-top:4px"></div></div>'
```

## State of the Art

| Old Approach (Current) | New Approach (Target) | Impact |
|------------------------|----------------------|--------|
| 3 KPI cards with icon boxes | 5-6 flat label-above-number cards | More metrics at a glance |
| Dark gradient profitability card | Flat card with neutral surfaces | Consistency with design system |
| Attention pills with 20px radius | Compact badges with system radius | Visual coherence |
| Hardcoded hex colors in inline styles | CSS variable references | Dark theme support, maintainability |
| `font-weight: 700` in stat values | `var(--weight-semibold)` (600) | Phase 19 compliance |
| `translateY(-1px/-3px)` hover effects | No transform hovers (or very subtle border color change) | Stripe/Linear aesthetic |
| Section headers with colored borders | Uniform 1px var(--border) bottom | Flat, clean look |
| Inline `<style>` for grid layout | CSS classes in base.css | Already mostly done |

## Discretion Recommendations

Based on analysis of the Stripe/Linear aesthetic and the existing codebase:

### KPI Card Layout: Horizontal strip
Use `repeat(auto-fit, minmax(150px, 1fr))` for 5-6 cards in one row. This naturally wraps on smaller screens.

### Visual Accents: Subtle 2px left border
Use a 2px left border in the card's semantic color. It's the Stripe pattern -- minimal but scannable. No backgrounds, no icon boxes.

### Overall Layout: Keep 2fr + 1fr grid
The existing `dash-main-grid` with `grid-template-columns: 2fr 1fr` is the correct Stripe pattern. Keep it.

### Section Separators: Whitespace primary, 1px hairlines for card internals
Use 20px (`var(--space-5)`) margin-bottom between sections. Use `1px solid var(--border)` only inside cards to separate headers from content.

### Attention Strip: Merge into page header or make ultra-compact
Rather than large colored pills, make them small inline badges in the page header area. Count + label, no icon, minimal visual weight.

### Chart Color Palette: Use design system semantic colors
- Revenue/profit: `var(--green)` (#16a34a)
- Expenses/losses: `var(--red)` (#dc2626)
- Neutral metrics: `var(--blue)` (#2563eb)
- Warnings: `var(--amber)` (#d97706)
- Secondary: `var(--purple)` (#a855f7)
- Background fills: Use `*-dim` variants at 8% opacity

### Sparklines: Keep in analytics section
Inline sparklines on stat cards add clutter. Keep them in the collapsible analytics section where there's room.

### Suggested Actions: Keep as separate card in sidebar
It provides actionable value and is already well-structured. Just restyle to flat treatment.

### Loading State: Skeleton shimmer
Use CSS-only pulse animation on placeholder divs. Simpler than spinners, more modern, matches Stripe's approach.

## Open Questions

1. **Inline style block cleanup scope:**
   - What we know: Lines 1191-1360 in index.html contain `.stat-card` and `.dashboard-stat-card` CSS that will conflict with restyled cards.
   - What's unclear: Should we delete the `.dashboard-stat-card` class entirely (it's not used in current dashboard template) or keep it for potential other pages?
   - Recommendation: Delete `.dashboard-stat-card` and its variants -- grep shows it's not referenced in any render function. Clean up `.stat-card` in inline block to match the new vertical layout.

2. **Greeting header position:**
   - What we know: Currently the page header shows "Dashboard" with period selectors. The greeting ("Good morning, John") is required per CONTEXT.md.
   - What's unclear: Where exactly the greeting lives -- it's not visible in the current template. It may have been removed or is generated elsewhere.
   - Recommendation: Add greeting as first element: `"Good morning, " + currentUser.name` with date below it, before the KPI strip.

## Sources

### Primary (HIGH confidence)
- `index.html` lines 17188-17703 -- Full renderDashboard function analyzed
- `assets/css/variables.css` -- Complete token inventory (Phase 19 tokens confirmed in place)
- `assets/css/base.css` lines 327-367 -- `.stat-card` component class
- `assets/css/base.css` lines 671-707 -- Dashboard grid classes
- `index.html` lines 1191-1360 -- Inline style block stat card overrides
- Phase 19 RESEARCH.md -- Token values and design decisions

### Secondary (MEDIUM confidence)
- [Linear design: The SaaS design trend - LogRocket](https://blog.logrocket.com/ux-design/linear-design/) -- Design principles
- [Stripe Dashboard patterns](https://docs.stripe.com/stripe-apps/patterns) -- Stripe component patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- No new dependencies, all existing code analyzed line-by-line
- Architecture: HIGH -- Dashboard template fully read, all grid classes mapped, all inline styles catalogued
- Pitfalls: HIGH -- Cascade conflicts identified with exact line numbers, mobile breakpoints verified

**Research date:** 2026-03-12
**Valid until:** 2026-04-12 (stable -- no external dependencies)
