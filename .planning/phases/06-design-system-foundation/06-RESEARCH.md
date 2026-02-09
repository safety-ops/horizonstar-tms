# Phase 6: Design System Foundation - Research

**Researched:** 2026-02-09
**Domain:** CSS Design Systems, Standalone HTML Mockups, iOS-to-Web Design Translation
**Confidence:** HIGH

## Summary

This research investigated best practices for creating a shared CSS design system for standalone HTML mockups that translates the iOS v3 driver app aesthetic to desktop web. The primary challenge is architecting a maintainable CSS system that serves ~22 independent HTML files with consistent theming, components, and responsive behavior.

Key findings show that modern CSS architecture (2026) strongly favors layered structure over monolithic single files, using CSS cascade layers for specificity management. For theme toggling in standalone HTML, the `data-theme` attribute on `<html>` with localStorage persistence is the established pattern. The current TMS uses inline SVG icons defined in JavaScript, while iOS v3 uses Lucide CDN—for standalone mockups, Lucide CDN offers the best balance of consistency, performance (with tree-shaking via CDN), and developer experience.

The current TMS has extensive component patterns: 4 button variants, 3 stat-card types, 5 badge styles, comprehensive form components, and modal/table styling. The sidebar should maintain both collapsed/expanded states (240px/72px) with mobile responsiveness, following the navigation structure of 7 sections (MAIN, FLEET, PARTNERS, FINANCIALS, OPERATIONS, SETTINGS, plus standalone items).

**Primary recommendation:** Use a layered CSS architecture (tokens → base → components → utilities) in a single `shared.css` file with clear section comments, implement `data-theme="dark|light"` on `<html>` with localStorage, adopt Lucide icons via CDN for consistency with iOS v3, and create a component showcase HTML file documenting all design system patterns.

## Standard Stack

### Core Technologies
| Library/Tool | Version | Purpose | Why Standard |
|--------------|---------|---------|--------------|
| CSS Variables | CSS3 | Design tokens, theming | Native browser support, no build step required |
| CSS Cascade Layers | CSS3 (@layer) | Specificity management | 2026 best practice for controlling style precedence |
| Lucide Icons | 0.344.0+ | Icon system | Consistent with iOS v3, CDN-hosted, tree-shakeable |
| localStorage API | Web Storage | Theme persistence | Standard browser API, works in standalone HTML |
| Inter Font | Google Fonts | Typography | Used by both current TMS and iOS v3 |

### Supporting Tools
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| CSS Reset | Custom | Normalize browser defaults | Include in base layer |
| @media queries | CSS3 | Responsive breakpoints | Mobile sidebar collapse, responsive grids |
| :root + [data-theme] | CSS3 | Theme variables | Light/dark mode switching |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Single CSS file | Multiple CSS files (tokens.css, components.css, etc.) | Multiple files require coordination across 22 HTML mockups; single file is simpler for standalone HTML |
| Lucide CDN | Inline SVG library (like current TMS) | Inline SVG works but requires maintaining icon definitions; Lucide CDN matches iOS v3 and is easier to maintain |
| data-theme attribute | .dark-theme class on body | Both work; data-theme is semantic and cleaner for multiple themes |

**Installation:**
```html
<!-- In each mockup HTML file -->
<link rel="stylesheet" href="./shared.css">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<script src="https://unpkg.com/lucide@0.344.0/dist/umd/lucide.min.js"></script>
```

## Architecture Patterns

### Recommended CSS Structure (Single File with Layers)
```
shared.css
├── /* ===== DESIGN TOKENS ===== */
│   ├── :root (light theme defaults)
│   ├── [data-theme="dark"] (dark theme overrides)
│   └── Layout constants (--sidebar-width, --header-height, etc.)
│
├── /* ===== BASE STYLES ===== */
│   ├── CSS Reset (* { margin: 0; ... })
│   ├── body, html
│   ├── Typography (h1-h6, p, a)
│   └── Scrollbar styling
│
├── /* ===== LAYOUT COMPONENTS ===== */
│   ├── Sidebar (.sidebar, .sidebar.collapsed)
│   ├── Header bar (.header)
│   ├── Main content area (.main-content)
│   └── Responsive breakpoints (@media)
│
├── /* ===== UI COMPONENTS ===== */
│   ├── Buttons (.btn-primary, .btn-secondary, .btn-sm, .btn-icon)
│   ├── Cards (.card, .stat-card, .hero-card)
│   ├── Badges (.badge, .badge-green, .badge-amber, etc.)
│   ├── Tables (.table, th, td, .table-hover)
│   ├── Forms (.form-group, input, select, textarea)
│   └── Modals (.modal, .modal-overlay, .modal-header)
│
├── /* ===== UTILITY CLASSES ===== */
│   ├── Spacing (.m-*, .p-*, .gap-*)
│   ├── Text (.text-primary, .font-bold, .text-center)
│   ├── Display (.flex, .grid, .hidden)
│   └── Colors (.text-success, .bg-card-hover)
│
└── /* ===== ICON SYSTEM ===== */
    └── Lucide sizing classes (.ico, .ico-sm, .ico-lg, etc.)
```

**Why single file with section comments over multiple files:**
- Standalone HTML mockups are easier to manage with one CSS import
- Section comments provide clear organization without file coordination overhead
- Browser caching benefits (one HTTP request instead of 4-5)
- Easier to search/find styles in one file during mockup development

Source: [CSS Architecture for Design Systems](https://bradfrost.com/blog/post/css-architecture-for-design-systems/), [Organizing your CSS - MDN](https://developer.mozilla.org/en-US/docs/Learn/CSS/Building_blocks/Organizing)

### Pattern 1: Theme Toggle with localStorage
**What:** Persist user theme preference across standalone HTML pages using localStorage
**When to use:** Every mockup HTML file should include this pattern
**Example:**
```javascript
// In <head> BEFORE stylesheet to prevent FART (Flash of Altered Runtime Theme)
<script>
  (function() {
    const theme = localStorage.getItem('theme') || 'dark'; // default dark to match iOS v3
    document.documentElement.setAttribute('data-theme', theme);
  })();
</script>

// In body - theme toggle button handler
function toggleTheme() {
  const html = document.documentElement;
  const current = html.getAttribute('data-theme');
  const next = current === 'dark' ? 'light' : 'dark';
  html.setAttribute('data-theme', next);
  localStorage.setItem('theme', next);
}
```

**Why this pattern:**
- Setting theme in `<head>` before CSS loads prevents flash of wrong theme
- `data-theme` on `<html>` allows CSS variables to cascade properly
- localStorage persists across page navigations in browser
- All 22 mockup HTML files will share theme preference

Sources: [The best light/dark mode theme toggle in JavaScript](https://whitep4nth3r.com/blog/best-light-dark-mode-theme-toggle-javascript/), [Theme Switching Using Local Storage - DEV Community](https://dev.to/mritunjaysaha/theme-switching-using-local-storage-13i)

### Pattern 2: Responsive Sidebar (Expanded/Collapsed/Mobile)
**What:** Desktop sidebar with toggle between 240px (expanded) and 72px (collapsed), mobile hamburger overlay
**When to use:** Layout-based mockups (Dashboard, Load Board, etc.)
**Example:**
```css
.sidebar {
  width: var(--sidebar-width); /* 240px */
  transition: width 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.sidebar.collapsed {
  width: var(--sidebar-collapsed-width); /* 72px */
}

.sidebar.collapsed .nav-label {
  display: none; /* Hide text labels, show only icons */
}

/* Mobile: Overlay sidebar */
@media (max-width: 768px) {
  .sidebar {
    position: fixed;
    left: -100%;
    width: 280px;
    z-index: 1000;
  }

  .sidebar.open {
    left: 0;
  }
}
```

**Why this pattern:**
- Current TMS uses 240px/72px widths - maintain consistency
- Smooth transitions provide polished feel matching iOS v3 animations
- Mobile overlay pattern is 2026 standard (not push-content pattern)
- Icon-only collapsed state saves space while maintaining navigation access

Sources: [Mobile Navigation Patterns That Work in 2026](https://phone-simulator.com/blog/mobile-navigation-patterns-in-2026), [How To Create a Responsive Sidebar](https://www.w3schools.com/howto/howto_css_sidebar_responsive.asp)

### Pattern 3: Lucide Icon Integration
**What:** Use Lucide icons via CDN with consistent sizing classes
**When to use:** All icons in mockups (navigation, buttons, stat cards, etc.)
**Example:**
```html
<!-- In <head> -->
<script src="https://unpkg.com/lucide@0.344.0/dist/umd/lucide.min.js"></script>

<!-- In HTML -->
<i data-lucide="truck" class="ico"></i>
<i data-lucide="dollar-sign" class="ico-lg ico-green"></i>

<!-- Before </body> - Initialize icons -->
<script>lucide.createIcons();</script>
```

```css
/* Icon sizing system */
[data-lucide] {
  display: inline-block;
  vertical-align: middle;
  color: var(--icon-default);
}
.ico { width: 18px; height: 18px; }
.ico-sm { width: 15px; height: 15px; }
.ico-lg { width: 22px; height: 22px; }
.ico-xl { width: 28px; height: 28px; }
.ico-green { color: var(--green) !important; }
.ico-blue { color: var(--blue) !important; }
```

**Why Lucide over inline SVG:**
- iOS v3 already uses Lucide - design consistency
- CDN is tree-shakeable (only icons used are loaded)
- No need to maintain icon definitions across 22 HTML files
- Better performance than inline SVG library (current TMS pattern)
- 2026 best practice for standalone HTML

Sources: [Lucide Icons - Static Usage](https://lucide.dev/guide/packages/lucide-static), [25+ Best Open Source Icon Libraries in 2026](https://lineicons.com/blog/best-open-source-icon-libraries)

### Anti-Patterns to Avoid
- **Hardcoded hex colors in components:** Use CSS variables for all colors to enable theming
- **Class names on `<body>` for theme:** Use `data-theme` attribute on `<html>` instead (cleaner, semantic)
- **Multiple CSS files for small mockup set:** Adds coordination overhead; single file is simpler
- **Loading all Lucide icons via font file:** Use CDN with `createIcons()` for tree-shaking
- **Inconsistent spacing scale:** Define --space-* variables and use them consistently

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Icon library | Custom SVG sprite system | Lucide CDN | Maintains iOS v3 consistency, CDN handles optimization |
| Theme toggle logic | Custom state management | localStorage + data-theme pattern | Well-tested, works across pages, prevents FART |
| CSS reset | Custom normalization | Modern CSS reset (from current TMS) | Handles browser quirks comprehensively |
| Color system | Random color choices | iOS v3 exact color tokens | Design consistency, already tested in iOS app |
| Responsive breakpoints | Ad-hoc media queries | Standard breakpoints (768px, 1024px, 1280px) | Industry standard, matches device landscape |

**Key insight:** The iOS v3 driver app prototype already solved most design system problems. Don't reinvent—translate iOS v3 tokens to web CSS variables and use proven web patterns (localStorage, Lucide CDN) for web-specific needs.

## Common Pitfalls

### Pitfall 1: Flash of Unstyled Theme (FART)
**What goes wrong:** Page loads in default theme, then flickers to user's saved theme
**Why it happens:** localStorage check happens after CSS loads
**How to avoid:** Inline theme-detection script in `<head>` BEFORE `<link rel="stylesheet">`
**Warning signs:** Theme "flicker" on page load in dev testing

**Prevention:**
```html
<head>
  <script>
    (function() {
      const theme = localStorage.getItem('theme') || 'dark';
      document.documentElement.setAttribute('data-theme', theme);
    })();
  </script>
  <link rel="stylesheet" href="./shared.css">
</head>
```

Source: [The best light/dark mode theme toggle in JavaScript](https://whitep4nth3r.com/blog/best-light-dark-mode-theme-toggle-javascript/)

### Pitfall 2: Inconsistent Color Token Usage
**What goes wrong:** Mockups use different shades of green/blue/amber across pages
**Why it happens:** Copying hex codes instead of using CSS variables
**How to avoid:** Define ALL colors in `:root`, reference via `var(--color-name)` only
**Warning signs:** Colors that "look close but not quite right" across mockups

**Prevention:**
```css
/* GOOD - Reference variable */
.btn-primary { background: var(--green); }

/* BAD - Hardcoded hex */
.btn-primary { background: #22c55e; }
```

### Pitfall 3: Lucide Icons Not Rendering
**What goes wrong:** Icons show as empty `<i>` tags
**Why it happens:** Forgot `lucide.createIcons()` call or script loaded after DOM
**How to avoid:** Always call `lucide.createIcons()` in script before `</body>`
**Warning signs:** Empty space where icons should be, console error about Lucide undefined

**Prevention:**
```html
<body>
  <!-- Your mockup content -->
  <script src="https://unpkg.com/lucide@0.344.0/dist/umd/lucide.min.js"></script>
  <script>lucide.createIcons();</script>
</body>
```

### Pitfall 4: Sidebar Doesn't Work on Mobile
**What goes wrong:** 240px sidebar covers content on mobile, no way to dismiss
**Why it happens:** No mobile breakpoint or overlay pattern implemented
**How to avoid:** Use `position: fixed` + `left: -100%` pattern with `.open` toggle on mobile
**Warning signs:** Horizontal scrolling on mobile viewport, can't access main content

**Prevention:**
```css
@media (max-width: 768px) {
  .sidebar {
    position: fixed;
    left: -100%;
    width: 280px;
    transition: left 0.3s;
  }
  .sidebar.open { left: 0; }
  .sidebar-overlay { /* dim overlay to close sidebar */ }
}
```

Source: [Mobile Navigation Patterns That Work in 2026](https://phone-simulator.com/blog/mobile-navigation-patterns-in-2026)

### Pitfall 5: Typography Scale Inconsistency
**What goes wrong:** Font sizes vary randomly (13px, 14px, 15px all used for body text)
**Why it happens:** No defined type scale, developers eyeball sizes
**How to avoid:** Define type scale in variables, use semantic names
**Warning signs:** Mockups that "feel off" typographically, inconsistent hierarchy

**Prevention:**
```css
:root {
  /* Type scale */
  --text-xs: 11px;
  --text-sm: 13px;
  --text-base: 14px;
  --text-lg: 16px;
  --text-xl: 20px;
  --text-2xl: 24px;
  --text-3xl: 28px;

  /* Weights */
  --weight-normal: 400;
  --weight-medium: 500;
  --weight-semibold: 600;
  --weight-bold: 700;
  --weight-heavy: 800;
}

/* Use semantically */
body { font-size: var(--text-base); }
h1 { font-size: var(--text-3xl); font-weight: var(--weight-heavy); }
```

## Code Examples

Verified patterns from iOS v3 and current TMS:

### iOS v3 Color Tokens (Exact Translation)
```css
/* DARK THEME (default) */
:root {
  /* Backgrounds */
  --bg-app: #09090b;
  --bg-card: #18181b;
  --bg-card-hover: #1f1f23;
  --bg-elevated: #27272a;

  /* Borders */
  --border: rgba(255,255,255,0.06);
  --border-active: rgba(34,197,94,0.4);

  /* Brand Colors */
  --green: #22c55e;
  --green-dim: rgba(34,197,94,0.12);
  --blue: #3b82f6;
  --blue-dim: rgba(59,130,246,0.12);
  --amber: #f59e0b;
  --amber-dim: rgba(245,158,11,0.12);
  --red: #ef4444;
  --red-dim: rgba(239,68,68,0.12);
  --purple: #a855f7;
  --purple-dim: rgba(168,85,247,0.12);

  /* Text */
  --text-primary: #fafafa;
  --text-secondary: #a1a1aa;
  --text-muted: #52525b;

  /* Shadows */
  --shadow-card: 0 1px 3px rgba(0,0,0,0.4);
}

/* LIGHT THEME */
[data-theme="light"] {
  --bg-app: #f8f9fa;
  --bg-card: #ffffff;
  --bg-card-hover: #f3f4f6;
  --bg-elevated: #e5e7eb;
  --border: rgba(0,0,0,0.08);
  --border-active: rgba(22,163,74,0.4);
  --green: #16a34a;
  --green-dim: rgba(22,163,74,0.1);
  --blue: #2563eb;
  --blue-dim: rgba(37,99,235,0.1);
  --amber: #d97706;
  --amber-dim: rgba(217,119,6,0.1);
  --red: #dc2626;
  --red-dim: rgba(220,38,38,0.1);
  --purple: #9333ea;
  --purple-dim: rgba(147,51,234,0.1);
  --text-primary: #111827;
  --text-secondary: #4b5563;
  --text-muted: #9ca3af;
  --shadow-card: 0 1px 3px rgba(0,0,0,0.08);
}
```

Source: `/Users/reepsy/Desktop/OG TMS CLAUDE/mockups/ui_concept_4_driver_app_v3.html`

### Current TMS Component Patterns
```css
/* Button variants (from index.html) */
.btn-primary {
  background: var(--gradient-primary);
  color: white;
  padding: 12px 24px;
  border-radius: var(--radius);
  font-weight: 600;
  transition: all 0.2s var(--ease-smooth);
}

.btn-secondary {
  background: var(--bg-card);
  color: var(--text-primary);
  border: 1px solid var(--border);
}

.btn-sm { padding: 8px 14px; font-size: 13px; }

.btn-icon {
  width: 36px;
  height: 36px;
  padding: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: var(--radius-sm);
}

/* Stat card variants */
.stat-card {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius-lg);
  padding: 20px;
  box-shadow: var(--shadow-card);
  transition: all 0.2s var(--ease-smooth);
}

.stat-card:hover {
  box-shadow: var(--shadow-card-hover);
  transform: translateY(-2px);
}

.stat-card .stat-icon {
  width: 48px;
  height: 48px;
  border-radius: var(--radius);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 12px;
}

.stat-card .stat-icon.green {
  background: var(--success-light);
  color: var(--success);
}

/* Badge variants */
.badge {
  display: inline-block;
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.badge-green {
  background: #dcfce7;
  color: #15803d;
}

.badge-amber {
  background: transparent;
  border: 1px solid #f59e0b;
  color: #f59e0b;
}

/* Form components */
.form-group {
  margin-bottom: 20px;
}

.form-group label {
  display: block;
  font-weight: 600;
  font-size: 13px;
  color: var(--text-secondary);
  margin-bottom: 8px;
}

.form-group input,
.form-group select,
.form-group textarea {
  width: 100%;
  padding: 12px 14px;
  border: 1px solid var(--border);
  border-radius: var(--radius);
  background: var(--bg-card);
  color: var(--text-primary);
  font-size: 14px;
  transition: all 0.2s;
}

.form-group input:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: 0 0 0 3px var(--primary-light);
}
```

Source: Current TMS `index.html` grep results

### Navigation Structure (7 Sections)
```javascript
// From current TMS navItems array
const navItems = [
  // MAIN section
  { id: 'dashboard', label: 'Dashboard', icon: 'dashboard', section: 'MAIN' },
  { id: 'live_map', label: 'Live Map', icon: 'map', section: 'MAIN' },
  { id: 'team_chat', label: 'Team Chat', icon: 'message-square', section: 'MAIN' },
  { id: 'trips', label: 'Trips', icon: 'truck', section: 'MAIN' },
  { id: 'orders', label: 'Orders', icon: 'package', section: 'MAIN' },
  { id: 'loadboard', label: 'Load Board', icon: 'clipboard-list', section: 'MAIN' },
  { id: 'tasks', label: 'Tasks', icon: 'check-square', section: 'MAIN' },

  // FLEET section
  { id: 'drivers', label: 'Drivers', icon: 'users', section: 'FLEET' },
  { id: 'trucks', label: 'Trucks', icon: 'truck', section: 'FLEET' },
  { id: 'local_drivers', label: 'Local Drivers', icon: 'user', section: 'FLEET' },

  // PARTNERS section
  { id: 'brokers', label: 'Brokers', icon: 'briefcase', section: 'PARTNERS' },
  { id: 'dealers', label: 'Dealers', icon: 'building', admin: true, section: 'PARTNERS' },
  { id: 'dispatchers', label: 'Dispatchers', icon: 'phone', section: 'PARTNERS' },
  { id: 'dispatcher_ranking', label: 'Dispatcher Ranking', icon: 'star', section: 'PARTNERS' },

  // FINANCIALS section (restricted to ADMIN/MANAGER)
  { id: 'financials', label: 'Financials', icon: 'dollar-sign', restricted: true, section: 'FINANCIALS' },
  { id: 'billing', label: 'Billing', icon: 'file-text', restricted: true, section: 'FINANCIALS' },
  { id: 'trip_profitability', label: 'Trip Profitability', icon: 'trending-up', restricted: true, section: 'FINANCIALS' },
  { id: 'payroll', label: 'Payroll', icon: 'credit-card', restricted: true, section: 'FINANCIALS' },
  { id: 'fuel', label: 'Fuel', icon: 'droplet', restricted: true, section: 'FINANCIALS' },
  { id: 'ifta', label: 'IFTA', icon: 'file', restricted: true, section: 'FINANCIALS' },
  { id: 'reports', label: 'Reports', icon: 'bar-chart-2', restricted: true, section: 'FINANCIALS' },
  { id: 'ai_advisor', label: 'AI Advisor', icon: 'brain', restricted: true, section: 'FINANCIALS' },

  // OPERATIONS section
  { id: 'maintenance', label: 'Maintenance', icon: 'wrench', section: 'OPERATIONS' },
  { id: 'compliance', label: 'Compliance', icon: 'shield-check', section: 'OPERATIONS' },
  { id: 'applications', label: 'Applications', icon: 'file-plus', admin: true, section: 'OPERATIONS' },

  // SETTINGS section (admin only)
  { id: 'settings', label: 'Settings', icon: 'settings', admin: true, section: 'SETTINGS' },
  { id: 'users', label: 'Users', icon: 'users', admin: true, section: 'SETTINGS' },
  { id: 'activity_log', label: 'Activity Log', icon: 'activity', admin: true, section: 'SETTINGS' }
];
```

Source: Current TMS `index.html` line 13080

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Separate CSS files per component | Single CSS file with layer comments | 2026 best practice | Simpler for standalone HTML, one HTTP request |
| Class toggle on body (.dark-theme) | data-theme attribute on html | 2024-2025 | Semantic, cleaner API, better CSS cascade |
| Icon fonts | SVG icon libraries (Lucide) | 2023-2024 | Better scalability, accessibility, performance |
| Hardcoded colors | CSS variables + design tokens | 2020+ | Theming, consistency, maintainability |
| !important specificity wars | CSS cascade layers (@layer) | 2022+ (widespread 2025-2026) | Predictable specificity, no hacks |

**Deprecated/outdated:**
- **Icon fonts:** Replaced by SVG libraries. Icon fonts have rendering issues, accessibility problems, and include all icons regardless of usage.
- **SASS/LESS for design tokens:** CSS variables are native and sufficient for theming without build step.
- **BEM naming with deep nesting:** CSS cascade layers solve specificity without naming ceremony.

Sources: [The Modern CSS Toolkit: What Actually Matters in 2026](https://www.nickpaolini.com/blog/modern-css-toolkit-2026), [Tailwind CSS Best Practices 2025-2026](https://www.frontendtools.tech/blog/tailwind-css-best-practices-design-system-patterns)

## Component Inventory (from Current TMS)

Based on analysis of `index.html`, the design system must support:

### Buttons (4 variants)
- `.btn-primary` - Green gradient, primary actions
- `.btn-secondary` - Outline/ghost, secondary actions
- `.btn-sm` - Smaller padding, compact UI
- `.btn-icon` - Icon-only, square, 36x36px

### Cards (3 types)
- `.card` - Generic content card
- `.stat-card` - Dashboard statistics with icon, value, label
- `.hero-card` - Larger feature cards (from fleet analytics mockup)

### Badges (5 styles)
- `.badge-green` - Success states
- `.badge-amber` - Warnings, pending states
- `.badge-blue` - Info, neutral states
- `.badge-red` - Errors, critical states
- `.badge-gray` - Inactive, disabled states

### Tables
- `.table` - Standard data table
- `thead`, `tbody`, `tr`, `th`, `td` - Semantic table elements
- `.table tbody tr:hover` - Row hover state

### Forms
- `.form-group` - Form field container
- `label`, `input`, `select`, `textarea` - Form elements
- `.form-row` - Two-column form layout
- Focus states, error states

### Modals
- `.modal-overlay` - Backdrop
- `.modal` - Modal container
- `.modal-header`, `.modal-body`, `.modal-footer` - Modal sections
- `.modal-close` - Close button

### Layout
- `.sidebar` - Navigation sidebar (240px default, 72px collapsed)
- `.sidebar.collapsed` - Collapsed state
- `.header` - Top header bar
- `.main-content` - Page content area

### Utility Classes
- Spacing: `.m-*`, `.p-*`, `.gap-*`
- Text: `.text-primary`, `.text-secondary`, `.text-muted`, `.font-bold`
- Display: `.flex`, `.grid`, `.hidden`, `.items-center`, `.justify-between`
- Colors: `.text-success`, `.text-danger`, `.bg-card-hover`

Source: grep analysis of current TMS `index.html`

## Open Questions

1. **Should component showcase be interactive or static?**
   - What we know: Need documentation of all components for reference during mockup creation
   - What's unclear: Whether showcasepage should be fully functional (theme toggle, interactive buttons) or just visual reference
   - Recommendation: Make it fully functional with theme toggle to serve as living documentation and test environment

2. **Typography scale alignment between iOS v3 and current TMS**
   - What we know: iOS v3 uses 10px-28px scale, current TMS uses 11px-28px scale with some gaps
   - What's unclear: Whether to adopt iOS v3 scale exactly or merge best of both
   - Recommendation: Use iOS v3 scale as source of truth (it's the approved design), document mapping for reference

3. **Mobile breakpoints for responsive behavior**
   - What we know: Sidebar should collapse on mobile, iOS v3 is 390px iPhone frame
   - What's unclear: Exact breakpoints (768px tablet? 1024px desktop?)
   - Recommendation: Use standard breakpoints: 640px (mobile), 768px (tablet), 1024px (desktop), 1280px (large desktop)

4. **Animation/transition timing values**
   - What we know: Current TMS has `--ease-spring`, `--ease-smooth`, etc. iOS v3 uses 0.2s-0.35s transitions
   - What's unclear: Whether to keep TMS easing functions or adopt iOS v3 timings
   - Recommendation: Keep TMS easing functions (well-tested), use iOS v3 duration values (0.2s standard, 0.35s for complex)

## Sources

### Primary (HIGH confidence)
- Current TMS codebase analysis (`/Users/reepsy/Desktop/OG TMS CLAUDE/index.html`, `assets/css/variables.css`, `assets/css/base.css`)
- iOS v3 prototype (`/Users/reepsy/Desktop/OG TMS CLAUDE/mockups/ui_concept_4_driver_app_v3.html`)
- Fleet Analytics mockup (`/Users/reepsy/Desktop/OG TMS CLAUDE/mockups/ui_concept_5_fleet_analytics.html`)
- [Lucide Icons Official Documentation](https://lucide.dev/guide/packages/lucide-static)
- [MDN: Organizing your CSS](https://developer.mozilla.org/en-US/docs/Learn/CSS/Building_blocks/Organizing)

### Secondary (MEDIUM confidence)
- [The best light/dark mode theme toggle in JavaScript](https://whitep4nth3r.com/blog/best-light-dark-mode-theme-toggle-javascript/) - localStorage pattern verified with web.dev
- [Brad Frost: CSS Architecture for Design Systems](https://bradfrost.com/blog/post/css-architecture-for-design-systems/) - Industry standard reference
- [Mobile Navigation Patterns That Work in 2026](https://phone-simulator.com/blog/mobile-navigation-patterns-in-2026) - Current mobile UX patterns
- [25+ Best Open Source Icon Libraries in 2026 | Lineicons](https://lineicons.com/blog/best-open-source-icon-libraries) - Lucide confirmed as top choice
- [W3Schools: Responsive Sidebar](https://www.w3schools.com/howto/howto_css_sidebar_responsive.asp) - Standard responsive pattern

### Tertiary (LOW confidence, for context only)
- [The Modern CSS Toolkit: What Actually Matters in 2026](https://www.nickpaolini.com/blog/modern-css-toolkit-2026) - CSS trends overview
- [Tailwind CSS Best Practices 2025-2026](https://www.frontendtools.tech/blog/tailwind-css-best-practices-design-system-patterns) - Design system patterns (not using Tailwind but patterns apply)

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** - All libraries verified in official docs, patterns from existing codebase
- Architecture: **HIGH** - Layered CSS is 2026 standard, data-theme pattern is proven, Lucide matches iOS v3
- Component inventory: **HIGH** - Direct analysis of current TMS codebase
- Pitfalls: **MEDIUM** - Based on common web dev issues and best practice articles

**Research date:** 2026-02-09
**Valid until:** 2026-04-09 (60 days - CSS/web standards are stable)

**Key takeaway:** The design system is a *translation* problem (iOS v3 to web) not a *creation* problem. Use iOS v3 design tokens as the single source of truth, apply established web patterns (localStorage, Lucide CDN, responsive sidebar), and document thoroughly in a component showcase for mockup developers.
