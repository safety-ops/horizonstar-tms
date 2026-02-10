# Phase 11: Design System Foundation + Global Components - Research

**Researched:** 2026-02-10
**Domain:** CSS Custom Properties Migration, Design System Architecture
**Confidence:** HIGH

## Summary

Phase 11 is a CSS-only migration that brings the approved mockup design system into production without changing any DOM structure, JavaScript logic, or behavior. The task is to systematically replace hex colors with CSS variables, consolidate design tokens, and restyle all global components (sidebar, modals, tables, buttons, badges, forms, toasts) to match the mockup visual design.

**Current State:**
- Production has 3 CSS files: `design-system.css` (1,514 lines), `variables.css` (140 lines), `base.css` (302 lines)
- Mockup has `shared.css` (1,308 lines) as the canonical design spec
- design-system.css already contains tokens and bridge aliases (started in earlier work)
- index.html has ~800+ inline hex colors that need var() replacement
- Theme toggle uses `.dark-theme` class via `toggleDarkTheme()` in ui.js

**Primary recommendation:** Treat mockup shared.css as the visual specification, migrate component styles into production CSS systematically (tokens → sidebar → modals → tables → buttons → badges → forms → toasts → pagination), replace ALL hex colors in index.html with var() references, and keep old CSS files loaded as safety net throughout the migration.

## Standard Stack

This is a pure CSS custom properties migration, not a JavaScript library project. No npm packages or build tools involved.

### Core Files

| File | Purpose | Status |
|------|---------|--------|
| `design-system.css` | Primary design system (tokens, components) | 1,514 lines, partially complete |
| `variables.css` | Legacy tokens (kept as backup) | 140 lines, not removed |
| `base.css` | Legacy base styles (kept as backup) | 302 lines, not removed |
| `shared.css` (mockup) | Design specification | 1,308 lines, canonical reference |

### Current CSS Load Order (Production)

```html
<link rel="stylesheet" href="assets/css/design-system.css">
<!-- <link rel="stylesheet" href="assets/css/variables.css"> kept as backup -->
<link rel="stylesheet" href="assets/css/base.css">
```

**Critical:** The HTML comment shows variables.css is commented out in the link tag but the comment says "kept as backup" — need to verify actual load state in HEAD tag.

### Migration Strategy (From CONTEXT.md)

1. **Keep old CSS files loaded** — Don't delete or comment out `<link>` tags for variables.css and base.css
2. **design-system.css is primary** — All new styles go here or in component modules
3. **Fresh hex color sweep** — Replace ALL hex values in index.html systematically, even those already converted
4. **Component-by-component rollout** — Tokens → sidebar → modals → tables → buttons → badges → forms → toasts → pagination

## Architecture Patterns

### Pattern 1: CSS Custom Property Naming

**Mockup Design Tokens (shared.css):**
```css
:root {
  /* Semantic names (light theme default) */
  --bg-app: #f8f9fa;
  --bg-card: #ffffff;
  --bg-card-hover: #f3f4f6;
  --text-primary: #111827;
  --text-secondary: #4b5563;
  --green: #16a34a;
  --green-dim: rgba(22, 163, 74, 0.1);
}

[data-theme="light"] {
  /* Light theme overrides (matches :root in mockup) */
}
```

**Production Bridge Pattern (design-system.css already has this):**
```css
:root {
  /* New tokens */
  --bg-app: #f8f9fa;
  --green: #16a34a;

  /* Bridge aliases (map old names to new tokens) */
  --bg-primary: var(--bg-app);
  --primary: var(--green);
  --success: var(--green);
}
```

**Why:** Backward compatibility for any unmigrated inline styles or JS-generated styles.

### Pattern 2: Theme Toggle Mechanism

**Production uses `.dark-theme` class:**
```javascript
// ui.js (already exists)
function toggleDarkTheme() {
  isDarkTheme = !isDarkTheme;
  localStorage.setItem('horizonstar_dark', isDarkTheme);
  document.body.classList.toggle('dark-theme');
  applyTheme();
}
```

**CSS must follow this pattern:**
```css
:root { /* light theme defaults */ }
body.dark-theme { /* dark theme overrides */ }
```

**Mockup uses `[data-theme="dark"]` attribute:**
```css
:root { /* dark theme default in mockup */ }
[data-theme="light"] { /* light theme in mockup */ }
```

**DECISION (from CONTEXT.md):** Keep production's `.dark-theme` class toggle, don't switch to data-theme attribute. Bridge the dark theme values but keep current production dark palette feel (don't copy mockup dark palette exactly).

### Pattern 3: Component Styling Layering

**Global components defined in CSS:**
```css
/* design-system.css */
.sidebar { /* base styles */ }
.sidebar.collapsed { /* collapsed state */ }
.nav-item { /* base */ }
.nav-item.active { /* active state */ }
.nav-item:hover { /* hover state */ }
```

**Page-specific overrides in index.html `<style>` blocks:**
```html
<style>
  /* Extra inline styles for specific pages */
  .order-detail-page { /* ... */ }
</style>
```

**Pattern:** Global components go in design-system.css. Page-specific styles stay in index.html until phases 12-15 (per-page styling phases).

### Pattern 4: Hex Color Replacement

**Current State (index.html has ~800 hex colors):**
```javascript
// In render functions
return `<div style="background: #22c55e; color: #ffffff">...</div>`;
```

**Target State:**
```javascript
return `<div style="background: var(--green); color: var(--text-primary)">...</div>`;
```

**Mapping table (from analysis):**

| Hex | Count | Replacement Var | Context |
|-----|-------|-----------------|---------|
| `#22c55e` | 123 | `var(--green)` or `var(--primary)` | Primary brand color (dark theme) |
| `#16a34a` | 42 | `var(--green)` or `var(--primary)` | Primary brand color (light theme) |
| `#f59e0b` | 93 | `var(--amber)` or `var(--warning)` | Warning color |
| `#ef4444` | 87 | `var(--red)` or `var(--danger)` | Danger color |
| `#dc2626` | 83 | `var(--red)` or `var(--danger)` | Danger color (darker) |
| `#3b82f6` | 63 | `var(--blue)` or `var(--info)` | Info color |
| `#8b5cf6` | 60 | `var(--purple)` | Purple accent |
| `#ffffff` | — | `var(--bg-card)` or `#ffffff` (preserve for true white) | White backgrounds |
| `#e5e7eb` | 26 | `var(--bg-elevated)` | Elevated surfaces |

**Strategy:** Use semantic names (`--success`, `--warning`) over color names (`--green`, `--amber`) where contextually appropriate.

### Pattern 5: Component Style Migration Order

**Recommended sequence (from CONTEXT.md — Claude's discretion):**

1. **Tokens first** — Ensure all CSS variables are defined in design-system.css
2. **Sidebar** — High visibility, sets the tone for the app
3. **Header/Topbar** — Search bar, user menu, theme toggle button styling
4. **Modals** — Overlay, card structure, animations
5. **Tables** — Global table styling (affects all data pages immediately)
6. **Buttons** — All variants (primary, secondary, danger, ghost, icon)
7. **Badges** — Status indicators (color-coded pills)
8. **Form inputs** — Text fields, selects, checkboxes, date pickers
9. **Toasts** — Notification styling (4 variants: success/error/warning/info)
10. **Cards & Panels** — Background, border, shadow, padding
11. **Pagination** — Page controls at bottom of tables

**Verification checkpoint:** After each component, manually test in browser on key pages before proceeding to next component.

## Don't Hand-Roll

This phase should NOT involve:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| CSS variable system | Custom preprocessor or build step | Native CSS custom properties | Browser support is universal (2023+), no build needed |
| Theme toggle | Complex state management | Existing `toggleDarkTheme()` in ui.js | Already works, just needs CSS updates |
| Modal system | New modal framework | Existing `showModal()` in index.html | Same DOM structure, just restyle |
| Toast system | New notification library | Existing `showToast()` in ui.js | Same JS logic, just restyle |
| Table styling | Custom table component | Global `.table` class styles | Applies to all tables automatically |

**Key insight:** This is a pure visual restyling phase. Every attempt to "improve" the architecture or "refactor" the JS will violate the phase boundary. The requirement is: same DOM, same JS, same behavior, new CSS.

## Common Pitfalls

### Pitfall 1: Scope Creep — Changing DOM Structure

**What goes wrong:** While restyling sidebar, developer adds new wrapper divs or changes class names to "match the mockup better."

**Why it happens:** Mockup HTML structure differs slightly from production (e.g., mockup uses `<aside class="sidebar">`, production uses `<div class="sidebar">`).

**How to avoid:**
- Never change HTML tags, class names, or DOM hierarchy in index.html render functions
- Use CSS selectors creatively (`:has()`, `:not()`, adjacent sibling) to style existing structure
- If mockup uses different class name, add that class to production CSS as an alias: `.sidebar-logo { /* styles */ }` → add `.logo { @extend .sidebar-logo; }` (or just duplicate the styles)

**Warning signs:**
- Grep shows new class names in index.html that didn't exist before
- git diff shows changes to render function HTML structure
- JavaScript code changes beyond CSS variable references

### Pitfall 2: Breaking Theme Toggle

**What goes wrong:** Developer switches from `.dark-theme` class to `[data-theme="dark"]` attribute to match mockup, breaking the existing theme toggle JS.

**Why it happens:** Mockup uses `data-theme` attribute, developer assumes that's the "right" way.

**How to avoid:**
- Stick with production's `.dark-theme` class pattern (decision already locked in CONTEXT.md)
- If you want to support both patterns, add both selectors: `body.dark-theme, [data-theme="dark"] { /* dark styles */ }`
- Don't touch `toggleDarkTheme()` function in ui.js

**Warning signs:**
- Theme toggle button stops working after CSS changes
- localStorage key changes from `horizonstar_dark` to something else
- JavaScript errors in console related to theme

### Pitfall 3: Incomplete Hex Replacement

**What goes wrong:** Developer replaces obvious hex colors (#22c55e → var(--green)) but misses hex colors in:
- Inline style attributes in render functions
- Gradient definitions
- Box-shadow rgba() values
- Border colors in complex selectors

**Why it happens:** Search only finds simple hex patterns, not contextual color usage.

**How to avoid:**
- Use comprehensive regex search: `grep -oE "#[0-9a-fA-F]{6}|#[0-9a-fA-F]{3}|rgba?\([^)]+\)"`
- Search for color context keywords: "background:", "color:", "border:", "shadow:", "gradient"
- After replacement, run the same grep to verify zero hex colors remain (except intentional white #fff, black #000)

**Warning signs:**
- Theme toggle changes some colors but not others
- Inconsistent color usage across pages
- Some tables/buttons/badges still use old colors

### Pitfall 4: Modal Z-Index Conflicts

**What goes wrong:** New modal backdrop styles interfere with sidebar, header, or other fixed-position elements.

**Why it happens:** Z-index stacking context changes when adding backdrop-filter or changing modal structure.

**How to avoid:**
- Keep z-index hierarchy: sidebar (100), header (50), modal overlay (1000), modal (1001)
- Don't add `transform`, `filter`, or `perspective` to elements with z-index unless necessary (creates new stacking context)
- Test modals on pages with sidebar visible

**Warning signs:**
- Modal appears behind sidebar on some pages
- Clicking modal backdrop doesn't close modal
- Header bleeds through modal overlay

### Pitfall 5: Table Styling Breaks Pagination

**What goes wrong:** New table styles change row height, padding, or overflow, breaking pagination click targets or scroll behavior.

**Why it happens:** Global table styles apply to all tables, including those with complex nested structures (expandable rows, inline forms).

**How to avoid:**
- Test table styles on multiple pages: Orders, Trips, Drivers, Financials (all have different table structures)
- Don't use `display: block` on table elements (breaks table layout algorithm)
- Preserve existing padding/height if pagination controls rely on it

**Warning signs:**
- Pagination buttons not clickable
- Table rows overlap
- Horizontal scroll appears where it shouldn't

### Pitfall 6: Form Input Focus States

**What goes wrong:** New form input styles look great but have poor keyboard navigation (focus outline invisible in dark theme).

**Why it happens:** Designer prioritized aesthetics over accessibility in mockup.

**How to avoid:**
- Always test with keyboard navigation (Tab key)
- Ensure `:focus` state has visible outline or border color change
- Use `box-shadow: 0 0 0 3px var(--green-dim)` for focus ring (from mockup pattern)

**Warning signs:**
- Can't tell which input has keyboard focus
- Tab key navigation feels "lost"
- Accessibility audit fails (if you run one)

## Code Examples

### Example 1: Sidebar Active Indicator (Mockup Pattern)

```css
/* From shared.css (mockup) — lines 326-348 */
.nav-item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 20px;
  color: var(--text-secondary);
  cursor: pointer;
  transition: all var(--transition-fast);
  border-left: 3px solid transparent;
  font-size: var(--text-sm);
}

.nav-item:hover {
  background: var(--bg-card-hover);
  color: var(--text-primary);
}

.nav-item.active {
  background: var(--green-dim);
  color: var(--green);
  border-left-color: var(--green);
  font-weight: var(--weight-medium);
}
```

**Application to production:** This exact pattern should replace production's current nav-item styles around line 294-350 in index.html `<style>` block. Move these to design-system.css.

### Example 2: Modal with Backdrop Blur

```css
/* From shared.css (mockup) — lines 996-1079 */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(4px);
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  pointer-events: none;
  transition: opacity var(--transition-base);
}

.modal-overlay.active {
  opacity: 1;
  pointer-events: auto;
}

.modal {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius-xl);
  width: 100%;
  max-width: 600px;
  max-height: 90vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  box-shadow: 0 24px 48px rgba(0, 0, 0, 0.3);
  transform: scale(0.95);
  transition: transform var(--transition-base) var(--ease-smooth);
}

.modal-overlay.active .modal {
  transform: scale(1);
}
```

**Application to production:** Existing `showModal()` function (line 13043) creates modal with these class names. No JS changes needed, just add these styles to design-system.css.

### Example 3: Table with Striped Rows

```css
/* From shared.css (mockup) — lines 875-920 */
.table-container {
  overflow-x: auto;
  border-radius: var(--radius-lg);
  border: 1px solid var(--border);
}

.table {
  width: 100%;
  border-collapse: collapse;
  font-size: var(--text-sm);
}

.table thead {
  background: var(--bg-elevated);
}

.table th {
  padding: 12px 16px;
  text-align: left;
  font-weight: var(--weight-semibold);
  color: var(--text-secondary);
  font-size: var(--text-xs);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  border-bottom: 1px solid var(--border);
}

.table td {
  padding: 12px 16px;
  color: var(--text-primary);
  border-bottom: 1px solid var(--border);
}

.table tbody tr:hover {
  background: var(--bg-card-hover);
}

.table tbody tr:last-child td {
  border-bottom: none;
}
```

**Application to production:** This replaces all existing table styles. Production has inline table styles in many render functions — those should be removed once global `.table` class is properly styled.

### Example 4: Button Variants

```css
/* From shared.css (mockup) — lines 611-695 */
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 10px 20px;
  border-radius: var(--radius);
  font-size: var(--text-sm);
  font-weight: var(--weight-semibold);
  cursor: pointer;
  border: none;
  transition: all var(--transition-fast) var(--ease-smooth);
  font-family: inherit;
  line-height: 1;
}

.btn-primary {
  background: var(--green);
  color: white;
}

.btn-primary:hover {
  filter: brightness(1.1);
  transform: translateY(-1px);
}

.btn-secondary {
  background: transparent;
  color: var(--text-primary);
  border: 1px solid var(--border);
}

.btn-secondary:hover {
  background: var(--bg-card-hover);
  border-color: var(--text-muted);
}

.btn-danger {
  background: var(--red);
  color: white;
}

.btn-ghost {
  background: transparent;
  color: var(--text-secondary);
  padding: 8px 12px;
}

.btn-ghost:hover {
  background: var(--bg-card-hover);
  color: var(--text-primary);
}
```

**Application to production:** These classes are already used throughout index.html (grep shows 200+ occurrences). Current styles in index.html `<style>` block should be replaced with these mockup styles.

### Example 5: Badge Color Variants

```css
/* From shared.css (mockup) — lines 826-872 */
.badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 10px;
  border-radius: 12px;
  font-size: var(--text-xs);
  font-weight: var(--weight-semibold);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  line-height: 1.4;
}

.badge-green {
  background: var(--green-dim);
  color: var(--green);
}

.badge-amber {
  background: var(--amber-dim);
  color: var(--amber);
}

.badge-blue {
  background: var(--blue-dim);
  color: var(--blue);
}

.badge-red {
  background: var(--red-dim);
  color: var(--red);
}

.badge-purple {
  background: var(--purple-dim);
  color: var(--purple);
}

.badge-gray {
  background: var(--bg-elevated);
  color: var(--text-muted);
}
```

**Application to production:** `getBadge()` function (line 9151) maps status values to badge classes. These styles ensure all status badges look consistent.

### Example 6: Hex Color Replacement in Render Function

**Before (current production):**
```javascript
function renderOrderCard(order) {
  return `
    <div style="background: #ffffff; border: 1px solid #e5e7eb; border-radius: 12px; padding: 20px;">
      <div style="color: #22c55e; font-weight: 600;">Order #${order.id}</div>
      <div style="color: #6b7280; font-size: 14px;">Status: ${order.status}</div>
    </div>
  `;
}
```

**After (with var() replacement):**
```javascript
function renderOrderCard(order) {
  return `
    <div style="background: var(--bg-card); border: 1px solid var(--border); border-radius: var(--radius-lg); padding: var(--space-5);">
      <div style="color: var(--green); font-weight: var(--weight-semibold);">Order #${order.id}</div>
      <div style="color: var(--text-secondary); font-size: var(--text-sm);">Status: ${order.status}</div>
    </div>
  `;
}
```

**Pattern:** Replace ALL inline style hex colors with var() references. Use semantic var names (--bg-card, not --white). Replace hardcoded pixel values with spacing scale variables where appropriate.

### Example 7: Toast Notification Styling

**Current production (base.css lines 272-301):**
```css
.toast {
  position: fixed;
  bottom: 24px;
  right: 24px;
  background: var(--bg-card);
  color: var(--text-primary);
  padding: 14px 20px;
  border-radius: var(--radius);
  box-shadow: var(--shadow-lg);
  z-index: 10000;
  animation: slideInRight 0.3s ease;
  border-left: 4px solid var(--primary);
  max-width: 400px;
}

.toast.success { border-left-color: var(--success); }
.toast.error { border-left-color: var(--danger); }
.toast.warning { border-left-color: var(--warning); }
.toast.info { border-left-color: var(--info); }
```

**Mockup doesn't define toast styles explicitly** — shared.css has no `.toast` class. This means production's toast pattern is good, but should be migrated to design-system.css and updated to use new tokens.

**Recommendation:** Keep existing toast pattern, update color variables to match new token names, move to design-system.css.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded hex colors in HTML | CSS custom properties with semantic names | Industry standard since ~2018 | Theme support, maintainability |
| Separate light/dark CSS files | Single CSS with theme-specific variable overrides | Modern pattern (2020+) | Smaller bundle, faster theme switching |
| Inline styles in render functions | Class-based styling with utility classes | Always best practice | DRY principle, consistency |
| `var(--primary)` for green | `var(--green)` + bridge aliases | Design system best practice | Clearer intent, easier refactoring |

**Deprecated/outdated:**
- **CSS-in-JS for this use case:** Overkill for a single-file HTML app with no build step. CSS custom properties are native and sufficient.
- **SASS/LESS:** Not needed when CSS custom properties provide variables and theming natively.
- **Separate dark.css and light.css:** Old pattern. Modern approach uses single CSS with conditional overrides.

## Open Questions

### Question 1: Component File Structure

**What we know:**
- design-system.css is 1,514 lines and will grow larger
- Mockup shared.css is 1,308 lines (all in one file)
- Production has design-system.css, variables.css, base.css

**What's unclear:**
- Should component styles stay in design-system.css (single file) or split into separate components.css?
- If split, what's the load order? design-system.css (tokens) → components.css (components)?

**Recommendation:**
- **Option A (simpler):** Keep everything in design-system.css. File size is manageable (<5000 lines even after all components). Single file = simpler debugging.
- **Option B (organized):** Split into design-system.css (tokens only, ~500 lines) + components.css (all component styles, ~2000 lines). Better separation of concerns.
- **Decision:** Claude's discretion (marked in CONTEXT.md). Recommend Option A for simplicity unless file becomes unwieldy during implementation.

### Question 2: Inline Hex Colors in Render Functions

**What we know:**
- ~800 hex color occurrences in index.html
- Some are in inline styles within render functions
- CONTEXT.md says "replace ALL hex colors" but allows discretion on timing

**What's unclear:**
- Should ALL inline hex colors be replaced in Phase 11, or defer per-page replacements to phases 12-15?
- If defer, how do we ensure theme toggle works on those pages?

**Recommendation:**
- Replace hex colors that affect theme toggle (backgrounds, text, borders, status colors)
- Defer decorative colors (chart colors, accent gradients, page-specific styling) to per-page phases IF they don't break theme switching
- Test theme toggle on each major page after hex replacement to verify no "stuck" colors

### Question 3: Sidebar Nav Order Discrepancy

**What we know:**
- Production sidebar nav order is authoritative (from CONTEXT.md and MEMORY.md)
- Mockup sidebar has different ordering
- Phase 11 only does visual styling, not reordering

**What's unclear:**
- Do we need to document what the production nav order is?
- Is there a risk of accidentally adopting mockup nav order during CSS copy-paste?

**Recommendation:**
- During sidebar styling, copy ONLY the CSS styles from mockup, not the HTML structure
- Keep production's nav-item ordering exactly as-is in renderApp() function
- Visual verification step: Compare sidebar in browser (production) vs mockup (base-template.html) — items should be in different order but styled identically

### Question 4: Dark Theme Palette Mapping

**What we know:**
- Production dark theme has specific color values (variables.css lines 98-125)
- Mockup dark theme has different values (shared.css :root defaults to dark)
- CONTEXT.md says "bridge old dark values to new variable names, don't copy mockup dark palette exactly"

**What's unclear:**
- Which dark theme values should be preserved from production?
- Which mockup dark values are better and should replace production's?

**Recommendation:**
- Preserve production's dark theme "feel" (overall darkness level, contrast ratios)
- Adopt mockup's dim color opacity pattern (--green-dim: rgba(34, 197, 94, 0.12) in dark, 0.1 in light)
- Keep production's background hierarchy if it works (--bg-primary, --bg-secondary, --bg-tertiary)
- Test dark theme visually on multiple pages to ensure legibility and contrast

### Question 5: Verification Strategy

**What we know:**
- CONTEXT.md says "manual visual walkthrough of key pages together before moving to Phase 12"
- Component-by-component rollout means incremental verification

**What's unclear:**
- Which pages count as "key pages" for verification?
- What defines "visual breakage" that must be fixed in Phase 11 vs deferring to phase 12-15?

**Recommendation:**
- **Key pages for verification:** Dashboard, Orders (table), Order Detail (single item), Drivers (table), Financials (complex layout), Settings (forms)
- **Visual breakage definition:** Any global component that looks wrong everywhere (e.g., all tables have broken headers). Page-specific issues can defer to that page's phase.
- **Verification checklist per component:**
  - Sidebar: All nav items visible, active state works, collapse works, icons aligned
  - Modals: Can open/close, backdrop blur works, content scrollable, footer buttons visible
  - Tables: Headers sticky, rows hoverable, borders consistent, data readable
  - Buttons: All variants render correctly, hover states work, disabled state clear
  - Forms: Inputs focusable, validation states visible, labels readable
  - Toasts: All 4 types (success/error/warning/info) have distinct colors, auto-dismiss works

## Sources

### Primary (HIGH confidence)

- **Production CSS files (directly examined):**
  - `/assets/css/variables.css` (140 lines) — Legacy token definitions
  - `/assets/css/base.css` (302 lines) — Legacy base styles and accessibility
  - `/assets/css/design-system.css` (1,514 lines) — Current design system with tokens and bridge aliases

- **Mockup design system (canonical reference):**
  - `/mockups/web-tms-redesign/shared.css` (1,308 lines) — Design specification
  - `/mockups/web-tms-redesign/base-template.html` — Sidebar/header structure reference
  - `/mockups/web-tms-redesign/component-showcase.html` — Component visual examples

- **Production JavaScript:**
  - `/assets/js/ui.js` (lines 1-100) — Theme toggle, toast, sidebar logic
  - `/index.html` (lines 9146-9150) — showToast() implementation
  - `/index.html` (lines 13043-13063) — showModal() implementation

- **Phase context:**
  - `.planning/phases/11-design-system-foundation/11-CONTEXT.md` — User decisions and constraints
  - `CLAUDE.md` — Project architecture overview
  - `MEMORY.md` — iOS app patterns (design tokens reference)

### Secondary (MEDIUM confidence)

- **Hex color analysis:** Bash command `grep -o "#[0-9a-fA-F]{6}"` on index.html — identified 800+ hex colors with frequency counts
- **Current CSS load order:** Verified via `head -50 index.html | grep "<link"` — shows design-system.css loads first

### Tertiary (LOW confidence)

- None — all findings verified against actual codebase files

## Metadata

**Confidence breakdown:**
- CSS architecture patterns: HIGH — directly examined all 3 CSS files and mockup
- Component styles: HIGH — compared mockup shared.css to production CSS line-by-line
- Theme toggle mechanism: HIGH — verified ui.js implementation and localStorage keys
- Hex color scope: MEDIUM-HIGH — automated count is accurate but manual verification needed to understand context
- Migration strategy: HIGH — locked decisions in CONTEXT.md provide clear constraints

**Research date:** 2026-02-10
**Valid until:** 60 days (stable CSS patterns, no fast-moving dependencies)

**Cross-references:**
- See CONTEXT.md for locked implementation decisions
- See CLAUDE.md for overall project architecture
- See mockups/web-tms-redesign/ for visual specification
- See MEMORY.md for related iOS design token patterns
