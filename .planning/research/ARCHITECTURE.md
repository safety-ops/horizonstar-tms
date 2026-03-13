# Architecture Patterns: Stripe/Linear Restyle Strategy

**Domain:** CSS restyle of a 38K-line single-file vanilla JS web application
**Researched:** 2026-03-12
**Confidence:** HIGH (based on direct codebase analysis, not external sources)

## Executive Summary

The restyle target is a single `index.html` containing ~122 render functions that build DOM via template literals with `innerHTML`. There are approximately **4,344 inline style attributes** across the file, with the heaviest categories being `font-size:` (979), `border-radius:` (809), `margin` (596), `padding:` (558), `display:flex` (504), `color:` (486), `display:grid` (153), and `linear-gradient` (62). The existing CSS layer (variables.css + base.css) already has a solid token system with spacing, typography, color, and shadow scales. The prior Phase 16 design token cleanup already flattened gradient variables to solid colors in variables.css.

The core architectural challenge: you cannot refactor 4,344 inline styles in one pass without catastrophic regression risk. The strategy must be **incremental, page-scoped, and CSS-class-first**.

## Recommended Architecture: Three-Layer Restyle

### Layer 1: Token Foundation (variables.css + base.css)

Update the design token layer to Stripe/Linear aesthetic values. This is a one-time change that immediately shifts the global feel.

**What changes:**
- Tighten shadow values (Stripe uses barely-visible 1px borders + micro-shadows)
- Adjust border-radius scale (Stripe: 6-8px cards, not 12-16px)
- Refine the color palette (cooler neutrals, less saturated status colors)
- Typography weight adjustments (Stripe: 500 medium as primary weight, not 600)
- Border color refinement (Stripe: solid light borders, not rgba transparency)

**What does NOT change:** Variable names. All existing `--bg-card`, `--shadow-sm`, `--radius` references continue to work but resolve to new values.

**Risk:** LOW. Changing token values is the safest operation because every consumer updates simultaneously. If a shadow goes from `0 1px 3px rgba(0,0,0,0.04)` to `0 1px 2px rgba(0,0,0,0.03)`, every card, modal, and dropdown gets the update.

### Layer 2: Component Class Library (new file: `restyle.css`)

Create a new CSS file loaded after base.css that defines Stripe/Linear-style component classes. These classes replace the most common inline style patterns.

**Why a new file instead of expanding base.css:**
- base.css is 1,534 lines and already has component styles from the prior UI overhaul
- A separate `restyle.css` keeps the new aesthetic isolated for easy rollback
- Can be loaded conditionally during development for A/B comparison
- Merges into base.css after restyle is complete

**Key classes to create (based on inline style frequency analysis):**

| Class | Replaces | Frequency |
|-------|----------|-----------|
| `.flex-row` / `.flex-col` | `display:flex;align-items:center;gap:Xpx` | ~504 |
| `.grid-2` / `.grid-3` / `.grid-4` | `display:grid;grid-template-columns:repeat(N,1fr);gap:Xpx` | ~153 |
| `.text-xs` through `.text-2xl` (already exist) | `font-size:11px` through `font-size:24px` | ~979 |
| `.p-2` through `.p-6` (partially exist) | `padding:8px` through `padding:24px` | ~558 |
| `.rounded-sm` / `.rounded` / `.rounded-lg` | `border-radius:6px/8px/12px` | ~809 |
| `.color-muted` / `.color-secondary` | `color:var(--text-muted)` / `color:#6b7280` | ~486 |
| `.bg-surface` / `.bg-elevated` | `background:var(--bg-card)` / `background:var(--bg-tertiary)` | inline bg refs |
| `.metric-value` | `font-size:24px;font-weight:800;font-family:monospace` | ~80 KPI displays |
| `.section-header` | `font-size:13px;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;color:var(--text-muted)` | ~60 section headers |
| `.action-row` | `display:flex;gap:8px;align-items:center` | ~100 button rows |
| `.stripe-card` | Flat card: 1px solid border, 8px radius, no shadow on rest, subtle shadow on hover | replaces current `.card` look |
| `.stripe-table` | Tighter rows, no alternating tint, hairline borders | replaces `.data-table` tweaks |
| `.pill-filter` / `.pill-filter.active` | Replaces the inline-styled period/status filter buttons | ~20 filter bars |

### Layer 3: Render Function Sweeps (index.html)

Page-by-page replacement of inline styles with class references. Each render function is a self-contained unit that can be restyled independently.

**Per-function process:**
1. Search for the render function boundaries (e.g., `function renderOrders(c) {` to the next `function render`)
2. Identify inline `style="..."` attributes in the template literal
3. Replace with appropriate classes from Layer 2
4. For truly one-off styles (dynamic conditional colors like profit green/red), keep inline but use CSS variable references
5. Test the page visually, then move to next function

## Component Boundaries

| Component | Responsibility | Files Touched |
|-----------|---------------|---------------|
| Token Layer | Global aesthetic values | `variables.css` |
| Component Classes | Reusable style patterns | `restyle.css` (new) |
| Render Functions | Page-specific HTML generation | `index.html` (per-function) |
| Dark Theme | Variable overrides for dark mode | `variables.css` (dark section, if exists) or `index.html` inline `<style>` |

**Current dark theme status:** The codebase references a `.dark-theme` class toggle pattern in CLAUDE.md, but there is NO dark theme override block in `variables.css` (only light theme `:root` values) and NO `.dark-theme` CSS rules found in `index.html`. Phase 16 research references a `body.dark-theme` block that may have been planned but not implemented, or was removed. The existing `variables.css` sets `--shadow-glow-green: none` and `--glass-blur: none`, suggesting glow/glass effects were already stripped.

**Implication:** Dark theme can be deferred entirely. The restyle should focus on light mode. If dark theme is later needed, add a `body.dark-theme { }` override block to `variables.css` that reassigns the semantic tokens.

## Strategy: Tokens First, Then Pages

**Order of operations:**

```
Phase 1: Token Foundation
  variables.css token values updated
  restyle.css created with core component classes
  Result: Global feel shifts, but inline styles still dominate individual pages

Phase 2+: Page-by-page sweeps
  Each phase targets specific render functions
  Replace inline styles with classes
  Remove dead inline style patterns
  Result: Each page reaches final aesthetic
```

**Why tokens first:**
- Tokens are the highest-leverage change (1 line change affects hundreds of elements)
- Gives immediate visual feedback on the target aesthetic
- Reduces the delta that per-page sweeps need to cover
- If `--radius` goes from `12px` to `8px`, every `.card`, `.stat-card`, `.filter-chip` etc. updates without touching index.html

**Why NOT page-by-page with tokens inline:**
- Creates inconsistency (restyled pages next to un-restyled pages look jarring)
- Token changes would need to be repeated per page
- Harder to maintain a consistent aesthetic language

## Suggested Build Order for Pages

Priority based on: user visibility, inline style density, dependency on other pages.

### Tier 1: Dispatch Core (highest traffic, most visible)

| Order | Function | Lines | Inline Styles (est.) | Rationale |
|-------|----------|-------|---------------------|-----------|
| 1 | `renderOrders(c)` | ~1,000 | ~250 | Most-used page, card + table dual view, heavy inline styles |
| 2 | `renderTrips(c)` | ~1,200 | ~280 | Second most-used, complex table with density toggle |
| 3 | `renderDashboard(c)` | ~500 | ~180 | Landing page, KPI cards, needs action strip, attention strip |
| 4 | `renderLoadBoard(c)` | ~550 | ~120 | Connected to orders workflow |

### Tier 2: People and Fleet

| Order | Function | Lines | Inline Styles (est.) | Rationale |
|-------|----------|-------|---------------------|-----------|
| 5 | `renderDrivers(c)` | ~160 | ~80 | Card grid layout |
| 6 | `renderTrucks(c)` | ~250 | ~70 | Table layout |
| 7 | `renderBrokers(c)` | ~320 | ~100 | Card grid with metrics |

### Tier 3: Finance

| Order | Function | Lines | Inline Styles (est.) | Rationale |
|-------|----------|-------|---------------------|-----------|
| 8 | `renderBillingPage(c)` | ~600 | ~200 | Complex tabs, aging bars, invoice tables |
| 9 | `renderPayroll(c)` | ~400 | ~150 | Driver cards, period summaries |
| 10 | `renderConsolidatedFinancials(c)` | ~400 | ~120 | Multi-tab financial views |

### Tier 4: Operations and Admin

| Order | Function | Lines | Inline Styles (est.) | Rationale |
|-------|----------|-------|---------------------|-----------|
| 11 | `renderTasks(c)` | ~180 | ~60 | Simpler layout |
| 12 | `renderCompliance(c)` + sub-functions | ~400 | ~120 | Multiple sub-tabs |
| 13 | `renderSettings(c)` | ~200 | ~80 | Admin-only, lower priority |
| 14 | `renderMaintenance(c)` | ~300 | ~80 | Operations page |

### Tier 5: Specialized (lowest priority)

| Order | Function | Rationale |
|-------|----------|-----------|
| 15 | `renderFuelTracking(c)` + analytics tabs | Domain-specific |
| 16 | `renderIFTA(c)` | Specialized compliance |
| 17 | `renderExecutiveDashboard(c)` | Heavy gradients (62 gradient refs live here), needs most cleanup |
| 18 | `renderReports(c)` + sub-reports | Lower traffic |
| 19 | `renderAIAdvisor(c)` + sub-tabs | Newer feature |
| 20 | Dealer portal render functions | Separate user flow |
| 21 | `renderLiveMap(c)`, `renderTeamChat(c)` | Mostly functional, less style-heavy |

### Shared/Utility Functions (address alongside Tier 1)

These helper functions generate HTML used across multiple pages:

| Function | Used By | Importance |
|----------|---------|------------|
| `renderOrderPreviewCard()` | Orders, Trips, Dashboard | HIGH - restyle once, propagates everywhere |
| `renderPaginationControls()` | All list pages | HIGH |
| `renderEmptyState()` | All pages | MEDIUM |
| `renderSuggestedActions()` | Dashboard | LOW |
| `renderSparkline()` / `renderHealthGauge()` | Dashboard, Reports | LOW |

## Inline Style Replacement Taxonomy

Not all 4,344 inline styles should be replaced with classes. Here is the decision framework:

### Replace with CSS class (target: ~70% of inline styles)

Repeated patterns that appear 10+ times across the codebase:

```
BEFORE: style="display:flex;align-items:center;gap:8px"
AFTER:  class="flex items-center gap-2"

BEFORE: style="font-size:11px;font-weight:600;color:var(--text-muted);text-transform:uppercase;letter-spacing:0.5px"
AFTER:  class="section-header"

BEFORE: style="padding:6px 12px;border-radius:6px;border:1px solid var(--border);background:var(--bg-secondary);..."
AFTER:  class="pill-filter"  (or class="pill-filter active")
```

### Keep as inline style (target: ~20% of inline styles)

Dynamic/conditional values that depend on runtime data:

```javascript
// Color based on profit/loss - KEEP INLINE
style="color:${profit >= 0 ? 'var(--green)' : 'var(--red)'}"

// Width based on percentage - KEEP INLINE
style="width:${percentage}%"

// Grid columns that vary per context - KEEP INLINE
style="grid-template-columns:${cols}"
```

### Replace with CSS variable reference (target: ~10% of inline styles)

Hardcoded hex colors that should reference tokens:

```
BEFORE: style="color:#3b82f6"
AFTER:  style="color:var(--blue)"  (or better: class="text-info")

BEFORE: style="background:#f59e0b20"
AFTER:  style="background:var(--amber-dim)"  (or class with bg-amber-dim)
```

## Risk Mitigation

### Risk 1: Breaking existing functionality during 38K-line file edits

**Mitigation:**
- Each render function is a self-contained scope. Restyling `renderOrders()` cannot break `renderTrips()`.
- Use function-boundary search (find `function renderOrders(c) {` and work within that scope).
- Test each page immediately after changes.
- Commit after each render function is complete (not in bulk).

### Risk 2: Class name conflicts with existing classes

**Mitigation:**
- Audit existing class names in base.css before creating new ones.
- The existing utility classes (`.flex`, `.gap-2`, `.p-4`, `.text-muted`) already follow Tailwind-like naming. Extend this convention rather than creating a parallel system.
- New restyle-specific classes use descriptive names: `.stripe-card`, `.metric-value`, `.section-header`.

### Risk 3: Inconsistency during multi-phase rollout

**Mitigation:**
- Token layer changes (Phase 1) provide baseline consistency across ALL pages immediately.
- Pages in Tier 1 (dispatch) are where users spend 80% of their time -- restyle these first.
- Lower-tier pages may look slightly different during transition but the token changes keep them in the same ballpark.

### Risk 4: Inline styles with `!important` or high specificity

**Finding:** No `!important` inline styles found in render functions. Inline `style=""` attributes naturally have high specificity, so replacing them with classes actually REDUCES specificity (good for maintainability). No conflicts expected.

### Risk 5: Executive Dashboard gradient density

**Finding:** `renderExecutiveDashboard()` (line 13258) contains the heaviest gradient usage -- colored card headers with `linear-gradient(135deg, ...)` in nearly every card. This function has 62+ gradient references.

**Mitigation:** Address this function last (Tier 5). Replace gradient card headers with flat colored headers using:
```css
.card-header-green { background: var(--green); color: white; }
.card-header-blue { background: var(--blue); color: white; }
/* etc. */
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Global find-and-replace of inline styles

**What:** Using regex to bulk-replace `style="padding:16px"` with `class="p-4"` across the entire file.
**Why bad:** Template literals contain JavaScript expressions. A regex cannot distinguish between `style="color:${dynamicVar}"` and `style="color:red"`. Will create broken template strings.
**Instead:** Manual per-function review. Each render function is ~200-1000 lines, manageable for focused review.

### Anti-Pattern 2: Creating too many utility classes

**What:** Creating a class for every unique inline style combination.
**Why bad:** Leads to class explosion (`.flex-center-gap8-p16-rounded12` etc.), making the CSS file larger than the inline styles it replaces.
**Instead:** Create classes for repeated PATTERNS (10+ occurrences). Leave one-off styles inline or use composition of existing utilities.

### Anti-Pattern 3: Changing render function logic during restyle

**What:** Refactoring JavaScript logic while replacing styles.
**Why bad:** Mixes visual changes with functional changes, making regressions impossible to attribute.
**Instead:** Style-only changes per function. Logic refactoring is a separate concern.

### Anti-Pattern 4: Restyling modals separately from their parent pages

**What:** Treating modal render code as separate from its host page.
**Why bad:** Many modals (openOrderModal, openTripModal) are defined near their parent render functions and share inline style patterns. Restyling the page without the modal creates inconsistency.
**Instead:** When restyling a page's render function, also restyle its associated modal functions in the same pass.

## Dark Theme Strategy

**Recommendation:** Defer dark theme entirely during restyle.

**Rationale:**
1. No dark theme CSS currently exists in production (verified by searching both files).
2. The Stripe/Linear aesthetic is primarily defined in light mode.
3. Adding dark theme multiplies every token decision by 2.
4. After the light-mode restyle is complete, adding dark theme is a single block in variables.css:

```css
body.dark-theme {
  --bg-primary: #0a0a0b;
  --bg-secondary: #18181b;
  --bg-card: #1c1c1f;
  --bg-tertiary: #27272a;
  --text-primary: #fafafa;
  --text-secondary: #a1a1aa;
  --text-muted: #71717a;
  --border: rgba(255,255,255,0.08);
  --shadow-sm: 0 1px 2px rgba(0,0,0,0.3);
  --shadow-md: 0 2px 8px rgba(0,0,0,0.4);
  --shadow-lg: 0 8px 24px rgba(0,0,0,0.5);
}
```

**Key point:** If inline styles use CSS variables (e.g., `color:var(--text-muted)` instead of `color:#9ca3af`), dark theme works automatically. This is an additional motivation for replacing hardcoded hex values with variable references during the page sweeps.

## Stripe/Linear Design Characteristics (Target Aesthetic)

Based on analysis of Stripe Dashboard and Linear App:

| Property | Current TMS | Stripe/Linear Target |
|----------|-------------|---------------------|
| Card radius | 12px | 8px |
| Card shadow | `0 1px 2px rgba(0,0,0,0.04)` | `0 0 0 1px rgba(0,0,0,0.04), 0 1px 2px rgba(0,0,0,0.02)` (border + micro-shadow) |
| Card border | `1px solid rgba(0,0,0,0.08)` | `1px solid #e4e4e7` (solid, not transparent) |
| Card padding | 16px | 16-20px |
| Table row height | ~40px | ~36px |
| Table borders | Alternating row tint | No tint, hairline bottom borders only |
| Heading weight | 700-800 | 500-600 |
| Body font size | 14px | 13-14px |
| Primary button | Solid green, rounded | Solid, 6px radius, subtle shadow |
| Status badges | Uppercase, 11px, pill shape | Sentence case or dot + text, less shouting |
| Page headers | 18px bold | 16px medium weight |
| Spacing rhythm | 4px base (irregular usage) | 4px base (consistent usage) |
| Color saturation | Full saturation (#22c55e) | Slightly muted, or same but used more sparingly |
| Gradients | 62 inline + variable remnants | Zero. Flat solid colors only |
| Hover effects | Background color change | Subtle lift (1px translate) or background tint |

## Summary for Roadmap

1. **Phase A: Token + Class Foundation** -- Update `variables.css` values, create `restyle.css` with ~25 component classes. Immediate global impact, zero risk to functionality.

2. **Phase B: Dispatch Pages** -- Sweep `renderOrders`, `renderTrips`, `renderDashboard`, `renderLoadBoard`, and their shared helpers (`renderOrderPreviewCard`, `renderPaginationControls`). This covers 80% of user-facing time.

3. **Phase C: People and Fleet Pages** -- Sweep `renderDrivers`, `renderTrucks`, `renderBrokers`, `renderDispatchers`. Card grid and table layouts.

4. **Phase D: Finance Pages** -- Sweep `renderBillingPage`, `renderPayroll`, `renderConsolidatedFinancials`. Complex multi-tab layouts.

5. **Phase E: Operations, Admin, and Long Tail** -- Everything else: compliance, settings, fuel, IFTA, reports, AI advisor, executive dashboard (gradient cleanup), dealer portal, live map, team chat.

6. **Phase F (optional): Dark Theme** -- Add `body.dark-theme` block to variables.css after all pages are restyled to use CSS variables consistently.

**Each phase is independently shippable.** After Phase A + B, the app looks dramatically different where users spend most of their time. Later phases clean up the long tail.
