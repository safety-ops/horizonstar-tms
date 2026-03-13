# Phase 19: Token Foundation & Component Classes - Research

**Researched:** 2026-03-12
**Domain:** CSS design tokens + component class library for Stripe/Linear aesthetic
**Confidence:** HIGH

## Summary

Phase 19 transforms the CSS token layer and component classes to produce the Stripe/Linear aesthetic globally. The work spans three files: `assets/css/variables.css` (154 lines), `assets/css/base.css` (1534 lines), and the first inline `<style>` block in `index.html` (lines 35-9600+). The existing CSS variable system is well-architected for a token swap. The primary challenge is that the first `<style>` block in index.html contains ~9,500 lines of CSS that overrides variables.css and base.css -- including 47 animation keyframes, a competing typography system (Space Grotesk/IBM Plex), and extensive decorative animations that directly contradict the target aesthetic.

The research from STACK.md and FEATURES.md provides exact token values (Tailwind Slate scale, shadow levels, border-radius). This phase is a token-value swap in variables.css, a component class update in base.css, and a surgical cleanup of the inline style block to remove competing declarations and decorative animations.

**Primary recommendation:** Update variables.css tokens first (instant 30% visual shift), then update base.css component classes, then neutralize the inline style block's competing font/color/animation declarations. Do NOT touch individual render functions in this phase -- that is for page sweep phases.

## Current State Analysis

### variables.css (154 lines) -- Complete Variable Inventory

Every variable and its current value, grouped by function:

**Brand Colors:**
| Variable | Current Value | New Value | Change Reason |
|----------|--------------|-----------|---------------|
| `--primary` | `#22c55e` | `#16a34a` | Slightly darker, more professional green |
| `--primary-hover` | `#16a34a` | `#15803d` | One step darker |
| `--primary-light` | `rgba(34,197,94,0.12)` | `rgba(22,163,74,0.08)` | Reduce opacity from 12% to 8% |
| `--primary-dark` | `#15803d` | `#15803d` | Keep |
| `--secondary` | `#64748b` | `#64748b` | Already slate-500 |
| `--purple` | `#a855f7` | `#a855f7` | Keep |

**Semantic Colors:**
| Variable | Current Value | New Value | Change Reason |
|----------|--------------|-----------|---------------|
| `--green` | `#22c55e` | `#16a34a` | Match primary |
| `--green-dim` | `rgba(34,197,94,0.12)` | `rgba(22,163,74,0.08)` | Reduce to 8% |
| `--blue` | `#3b82f6` | `#2563eb` | One step darker |
| `--blue-dim` | `rgba(59,130,246,0.12)` | `rgba(37,99,235,0.08)` | Reduce to 8% |
| `--amber` | `#f59e0b` | `#d97706` | Slightly darker |
| `--amber-dim` | `rgba(245,158,11,0.12)` | `rgba(217,119,6,0.08)` | Reduce to 8% |
| `--red` | `#ef4444` | `#dc2626` | One step darker |
| `--red-dim` | `rgba(239,68,68,0.12)` | `rgba(220,38,38,0.08)` | Reduce to 8% |
| `--purple-dim` | `rgba(168,85,247,0.12)` | `rgba(168,85,247,0.08)` | Reduce to 8% |

**Status Aliases:**
| Variable | Current Value | New Value |
|----------|--------------|-----------|
| `--success` | `#22c55e` | `#16a34a` |
| `--success-light` | `rgba(34,197,94,0.12)` | `rgba(22,163,74,0.08)` |
| `--warning` | `#f59e0b` | `#d97706` |
| `--warning-light` | `rgba(245,158,11,0.12)` | `rgba(217,119,6,0.08)` |
| `--danger` | `#ef4444` | `#dc2626` |
| `--danger-light` | `rgba(239,68,68,0.12)` | `rgba(220,38,38,0.08)` |
| `--info` | `#3b82f6` | `#2563eb` |
| `--info-light` | `rgba(59,130,246,0.12)` | `rgba(37,99,235,0.08)` |

**Background Colors (Zinc -> Slate):**
| Variable | Current Value | New Value | Slate Step |
|----------|--------------|-----------|------------|
| `--bg-primary` | `#f5f5f7` | `#f8fafc` | slate-50 |
| `--bg-secondary` | `#ffffff` | `#ffffff` | white (keep) |
| `--bg-tertiary` | `#f0f0f2` | `#f1f5f9` | slate-100 |
| `--bg-card` | `#ffffff` | `#ffffff` | white (keep) |
| `--bg-card-hover` | `#f3f4f6` | `#f8fafc` | slate-50 |
| `--bg-hover` | `#f5f5f7` | `#f1f5f9` | slate-100 |
| `--bg-darker` | `#e5e5e7` | `#e2e8f0` | slate-200 |
| `--bg-elevated` | `#e5e7eb` | `#f1f5f9` | slate-100 |
| `--bg-float` | `#d4d4d8` | `#e2e8f0` | slate-200 |

**Text Colors:**
| Variable | Current Value | New Value | Slate Step |
|----------|--------------|-----------|------------|
| `--text-primary` | `#111827` | `#0f172a` | slate-900 |
| `--text-secondary` | `#4b5563` | `#64748b` | slate-500 |
| `--text-muted` | `#9ca3af` | `#94a3b8` | slate-400 |

**Borders (rgba -> solid hex):**
| Variable | Current Value | New Value | Reason |
|----------|--------------|-----------|--------|
| `--border` | `rgba(0,0,0,0.08)` | `#e2e8f0` | Solid slate-200, crisper lines |
| `--border-light` | `rgba(0,0,0,0.04)` | `#f1f5f9` | Solid slate-100 |
| `--border-active` | `rgba(34,197,94,0.4)` | `#2563eb` | Blue-600 focus ring (not green) |

**Shadows (flatten to 3 levels):**
| Variable | Current Value | New Value |
|----------|--------------|-----------|
| `--shadow-xs` | `var(--shadow-sm)` | `0 1px 2px rgba(0,0,0,0.04)` |
| `--shadow-sm` | `0 1px 3px rgba(0,0,0,0.04), 0 1px 2px rgba(0,0,0,0.03)` | `0 1px 3px rgba(16,24,40,0.06), 0 1px 2px rgba(16,24,40,0.03)` |
| `--shadow-md` | `0 4px 6px -1px rgba(0,0,0,0.07), 0 2px 4px -2px rgba(0,0,0,0.05)` | `0 4px 8px -2px rgba(16,24,40,0.08), 0 2px 4px -2px rgba(16,24,40,0.04)` |
| `--shadow-lg` | `0 10px 15px -3px rgba(0,0,0,0.08), 0 4px 6px -4px rgba(0,0,0,0.04)` | `var(--shadow-md)` | Collapse to md |
| `--shadow` | `var(--shadow-sm)` | `var(--shadow-xs)` | Default = xs |
| `--shadow-xl` | `var(--shadow-lg)` | `var(--shadow-md)` | Collapse |
| `--shadow-card` | `var(--shadow-sm)` | `var(--shadow-xs)` | Cards barely shadowed |
| `--shadow-card-hover` | `var(--shadow-md)` | `var(--shadow-sm)` | Subtle lift |
| `--shadow-float` | `var(--shadow-lg)` | `var(--shadow-md)` | Max depth |
| `--shadow-inset` | `none` | `none` | Keep none |
| `--shadow-glow-green` | `none` | `none` | Keep none |
| `--shadow-glow-blue` | `none` | `none` | Keep none |
| `--shadow-inner-glow` | `none` | `none` | Keep none |

**Gradients (flatten to solid):**
| Variable | Current Value | New Value |
|----------|--------------|-----------|
| `--accent-gradient` | `#22c55e` | `#16a34a` |
| `--gradient-primary` | `#22c55e` | `#16a34a` |
| `--gradient-primary-hover` | `#16a34a` | `#15803d` |
| `--gradient-secondary` | `#3b82f6` | `#2563eb` |
| `--gradient-warning` | `#f59e0b` | `#d97706` |
| `--gradient-danger` | `#ef4444` | `#dc2626` |
| `--gradient-purple` | `#a855f7` | `#a855f7` |
| `--gradient-sidebar` | `#111113` | `#0f172a` | Slate-900 |
| `--gradient-card` | `var(--bg-card)` | `var(--bg-card)` | Keep |

**Glass (already neutralized, keep):**
| Variable | Current Value | New Value |
|----------|--------------|-----------|
| `--glass-bg` | `var(--bg-card)` | `var(--bg-card)` |
| `--glass-border` | `var(--border)` | `var(--border)` |
| `--glass-blur` | `none` | `none` |

**Border Radius (tighten):**
| Variable | Current Value | New Value | Usage |
|----------|--------------|-----------|-------|
| `--radius-sm` | `8px` | `6px` | Inputs, buttons, badges |
| `--radius` | `12px` | `8px` | Cards, dropdowns |
| `--radius-lg` | `16px` | `12px` | Modals, panels |
| `--radius-xl` | `20px` | `12px` | Collapse to match lg |

**Typography (weight reduction):**
| Variable | Current Value | New Value | Reason |
|----------|--------------|-----------|--------|
| `--weight-bold` | `700` | `600` | Max weight = 600 |
| `--weight-heavy` | `800` | `600` | Eliminate 800 |
| All others | unchanged | unchanged | 400/500/600 scale is correct |

**Animation (simplify):**
| Variable | Current Value | New Value | Reason |
|----------|--------------|-----------|--------|
| `--transition` | `all 0.2s cubic-bezier(0.4, 0, 0.2, 1)` | `background-color 150ms ease, border-color 150ms ease, box-shadow 150ms ease, color 150ms ease` | Explicit properties, no `all` |
| `--ease-spring` | `cubic-bezier(0.34, 1.56, 0.64, 1)` | Remove or set to `var(--ease-smooth)` | No bounce |
| `--ease-bounce` | `cubic-bezier(0.68, -0.55, 0.265, 1.55)` | Remove or set to `var(--ease-smooth)` | No bounce |
| `--ease-out-expo` | `cubic-bezier(0.16, 1, 0.3, 1)` | Remove or set to `var(--ease-smooth)` | Unnecessary |
| `--duration-slow` | `400ms` | `250ms` | Nothing 400ms |

**New Tokens to Add:**
| Variable | Value | Purpose |
|----------|-------|---------|
| `--tracking-wide` | `0.05em` | Uppercase label letter-spacing |
| `--btn-primary-bg` | `#0f172a` | Dark slate primary buttons |
| `--btn-primary-color` | `#ffffff` | Button text |
| `--btn-primary-hover` | `#1e293b` | Button hover (slate-800) |
| `--border-strong` | `#cbd5e1` | Emphasized borders (slate-300) |
| `--focus-ring` | `0 0 0 3px rgba(37,99,235,0.1)` | Blue focus ring shadow |
| `--focus-border` | `#2563eb` | Focus border color (blue-600) |

### base.css -- Key Classes to Modify

**Cards (.card):** Change `border-radius: 12px` to `var(--radius)` (now 8px). Shadow already uses variable. Remove `.card:hover` transform. Remove `.card::after` radial gradient pseudo-element (line 8786 in index.html).

**Stat cards (.stat-card):** Reduce `.stat-value` from `font-weight: 800` to `600`. Remove `.stat-icon` 44px colored boxes (or leave class but page sweeps will stop using them). Change `font-size: var(--text-2xl)` display.

**Hero cards (.hero-card):** Remove gradient backgrounds entirely. Keep border-left accent but remove `linear-gradient()` from `.hero-card.green/.blue/.amber/.red/.purple`. Flat white background.

**Status badges (.status-badge):** Change `border-radius: 12px` to `var(--radius-sm)` (6px). Reduce `font-weight: 600` to `500`. Dim backgrounds will auto-update via variable change to 8%.

**Tables (.data-table):** Remove zebra striping (`tbody tr:nth-child(even)` background). Remove `backdrop-filter: blur(8px)` from thead. Change th weight from `600` to `500`. Add opaque bg to th.

**Section tabs (.section-tab):** Already well-structured. `border-radius: var(--radius-sm)` will tighten automatically.

**Filter chips (.filter-chip):** Change `border-radius: 20px` to `var(--radius-sm)` (6px). Not pill-shaped.

**Page header (.page-header h1/h2):** Change `font-weight: 700` to `600`.

**Headings (h1-h6):** Change `font-weight: 600` to keep (600 is target max). Add `letter-spacing: -0.01em` for tighter tracking.

### Animation Keyframes Inventory (47 total in index.html)

**KEEP (functional, not decorative):**
| Keyframe | Line | Purpose |
|----------|------|---------|
| `spin` | 3966, 9541 | Spinner rotation -- essential |
| `skeleton-pulse` | 9546 | Skeleton loading -- essential |
| `fadeIn` | 1929 | Basic opacity fade -- used by command palette, overlays |
| `toastSlideIn` / `toastIn` / `toastOut` | 8676, 9138, 9148 | Toast notifications -- keep slide-in |
| `overlayFadeIn` | 8133 | Modal overlay -- simplify to opacity only (remove blur) |
| `modalSlideIn` | 8154 | Modal entrance -- keep but simplify |
| `skeleton-shimmer` (base.css) | base.css:995 | Shimmer loading -- essential |

**REMOVE (decorative, anti-Stripe):**
| Keyframe | Line | What It Does | Why Remove |
|----------|------|--------------|------------|
| `slideInUp` | 517 | Mini-chat slide up | Decorative |
| `slideUp` | 1930, 5343 | Slide + scale entrance | Decorative |
| `pulse` | 3937 | Scale + opacity pulse | Decorative |
| `chatPulse` | 4844 | Chat icon pulse | Decorative |
| `live-dot-breathe` | 6571 | Live map dot breathing | Decorative |
| `kpi-pulse-green` | 6611 | Green glow pulse on KPI | Colored glow |
| `fleet-card-enter` | 6926 | Card entrance animation | Decorative |
| `marker-pulse` | 7071 | Map marker pulse | Decorative |
| `driveTruck` | 7364 | Loading animation (truck driving) | Decorative |
| `roadMove` | 7392 | Loading road animation | Decorative |
| `loadingBounce` | 7422 | Loading dots bounce | Decorative |
| `loadingFadeInUp` | 7427 | Loading fade up | Decorative |
| `fadeInUp` | 7437 | Fade + translate up | Decorative |
| `fadeInScale` | 7442 | Fade + scale in | Decorative |
| `slideInRight` | 7447 | Slide from right | Decorative (conflicts with base.css) |
| `slideInLeft` | 7452 | Slide from left | Decorative |
| `scaleIn` | 7457 | Scale in | Decorative |
| `shimmer` | 7462 | Duplicate of skeleton-shimmer | Redundant |
| `pulse-soft` | 7467 | Soft opacity pulse | Decorative |
| `float` | 7472 | Floating Y animation | Decorative |
| `ripple` | 7477 | Click ripple effect | Decorative |
| `gradient-shift` | 7482 | Gradient background animation | Anti-flat |
| `pageEnter` | 7494 | Page slide up entrance | Keep simplified (opacity only) |
| `staggerFadeIn` | 8611 | Stagger entrance | Decorative |
| `cardEnter` | 8622 | Card slide+scale entrance | Decorative (most impactful removal) |
| `numberPop` | 8660 | Stat number scale pop | Decorative |
| `titleEnter` | 8692 | Title slide down | Decorative |
| `rowSlideIn` | 8704 | Table row slide in | Decorative |
| `iconBounce` | 8934 | Icon bounce on hover | Decorative |
| `searchPulse` | 8994 | Search pulse | Decorative |
| `modalContentIn` | 9005 | Modal content entrance | Redundant with modalSlideIn |
| `badgeBounce` | 9066 | Badge bounce | Decorative |
| `tabActivate` | 9087 | Tab activation | Decorative |
| `progressFill` | 9100 | Progress bar fill | Keep (functional) |
| `dropdownIn` | 9160 | Dropdown entrance | Simplify to opacity |
| `toggleOn` | 9261 | Toggle switch animation | Keep (functional) |
| `billingSlideUp` | 31089 | Billing toast slide | Decorative |
| `typingBounce` | 47009 | AI typing indicator | Keep (functional) |

### Inline Style Block #1 (lines 35-80) -- Critical Override Problem

The first `<style>` block in index.html (starting line 35) **overrides variables.css** with:
- A competing typography system: `--font-display: 'Space Grotesk'` and `--font-body: 'IBM Plex Sans'`
- Rem-based text sizes that override the px-based variables.css scale
- Extended indigo primary spectrum (`--primary-50` through `--primary-900`) that is unused by the Stripe restyle
- Gradient variables (`--gradient-surface`, `--gradient-glow`, `--gradient-mesh`) that are anti-flat

**This block MUST be neutralized.** The font variables need to be removed (Inter is the target font). The rem text sizes should be replaced with the px-based scale from variables.css.

### Inline Style Block #2 (line 34801) -- Paystub Template

This is inside a template literal generating a standalone HTML document for earnings statements. It uses its own hardcoded styles. **Do NOT modify** -- it is a print document, not the app UI.

### Inline Style Block #3 (line 37040) -- Tracking Portal

Scoped to `.tracking-portal` class. A standalone tracking page. **Low priority** for this phase -- can be addressed in page sweeps.

### Inline Style Block #4 (line 47007) -- AI Advisor

Small block (6 lines). Contains `typingBounce` keyframe (keep) and `.goal-card` styling. **Low priority** -- update in page sweeps.

### Decorative CSS in Inline Block (lines 8600-8970) -- Must Remove

This section contains the most impactful decorative CSS that contradicts Stripe/Linear:

- **Card animations:** `.card { animation: cardEnter 0.5s ... }` -- every card bounces in (line 8650)
- **Stat card stagger:** 6 stat cards with cascading delays (lines 8634-8638)
- **Driver card stagger:** Same (lines 8641-8647)
- **Number pop:** `.stat-card .value { animation: numberPop }` (line 8657)
- **Row slide-in:** Every table row slides from left (lines 8709-8722)
- **Row hover scale:** `tbody tr:hover { transform: scale(1.005) }` (line 8730)
- **Card hover glow:** `.card::after` radial gradient pseudo-element (lines 8786-8799)
- **Order card spring animation:** `.order-list-item` uses spring cubic-bezier (line 8835)
- **Order card hover lift:** `transform: translateY(-3px) scale(1.004)` (line 8840)
- **Icon bounce on stat hover:** (line 8930)
- **Driver avatar rotate on hover:** (line 8945)
- **Badge hover translate:** (line 8956)
- **Nav icon rotate on hover:** `.nav-item:hover .icon { transform: scale(1.15) rotate(-3deg) }` (line 8772)
- **Action button lift:** `.action-btn:hover { transform: translateY(-2px) scale(1.02) }` (line 8758)

## Standard Stack

No external libraries needed. This is pure CSS custom property changes.

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| CSS Custom Properties | native | Token system | Already in place |
| Tailwind Slate scale | reference only | Color values | Industry standard cool-gray |
| Inter font | already loaded | Typography | Stripe/Linear standard |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual CSS | Tailwind CSS framework | Adds build step, unnecessary for token swap |
| Hex colors | OKLCH | Better perceptual uniformity, worse browser compat |

## Architecture Patterns

### Token Update Order

```
1. variables.css    -- Swap all token values (colors, shadows, radius, weights)
2. base.css         -- Update component class definitions
3. index.html :35   -- Neutralize competing font/color/gradient declarations
4. index.html 8600+ -- Remove decorative animation keyframes and animation rules
```

### Pattern: Token Value Swap (variables.css)

**What:** Replace hex/rgba values in `:root` block while preserving variable names.
**When to use:** Every token change.
**Example:**
```css
/* BEFORE */
--bg-primary: #f5f5f7;
--border: rgba(0,0,0,0.08);
--radius: 12px;

/* AFTER */
--bg-primary: #f8fafc;
--border: #e2e8f0;
--radius: 8px;
```

### Pattern: Component Class Flattening (base.css)

**What:** Remove gradients, reduce shadows, tighten radius in existing component classes.
**Example:**
```css
/* BEFORE */
.hero-card.green {
  border-left-color: var(--green);
  background: linear-gradient(to right, var(--green-dim), var(--bg-card) 40%);
}

/* AFTER */
.hero-card.green {
  border-left-color: var(--green);
  background: var(--bg-card);
}
```

### Pattern: Animation Neutralization (index.html)

**What:** Replace decorative keyframes with `/* removed v1.4 */` comment. Override animation rules with `animation: none`.
**Example:**
```css
/* BEFORE */
.card { animation: cardEnter 0.5s cubic-bezier(0.16, 1, 0.3, 1) both; }

/* AFTER */
.card { animation: none; }
```

### Pattern: New Component Classes (base.css)

**What:** Add reusable classes that page sweeps can reference.
**Classes to create:**

```css
/* Primary button -- dark slate */
.btn-primary {
  background: var(--btn-primary-bg);
  color: var(--btn-primary-color);
  border: 1px solid var(--btn-primary-bg);
  border-radius: var(--radius-sm);
  padding: 8px 16px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 150ms ease, border-color 150ms ease;
}
.btn-primary:hover {
  background: var(--btn-primary-hover);
  border-color: var(--btn-primary-hover);
}

/* Secondary button -- outlined */
.btn-secondary {
  background: var(--bg-card);
  color: var(--text-primary);
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  padding: 8px 16px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 150ms ease, border-color 150ms ease;
}
.btn-secondary:hover {
  background: var(--bg-hover);
  border-color: var(--border-strong);
}

/* Ghost button */
.btn-ghost {
  background: transparent;
  color: var(--text-secondary);
  border: none;
  border-radius: var(--radius-sm);
  padding: 8px 16px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: background-color 150ms ease, color 150ms ease;
}
.btn-ghost:hover {
  background: var(--bg-hover);
  color: var(--text-primary);
}

/* Danger button */
.btn-danger {
  background: transparent;
  color: var(--danger);
  border: 1px solid var(--danger);
  border-radius: var(--radius-sm);
  padding: 8px 16px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
}
.btn-danger:hover {
  background: rgba(220,38,38,0.08);
}

/* Input styling */
.input, .select, .textarea {
  border: 1px solid var(--border);
  border-radius: var(--radius-sm);
  padding: 8px 12px;
  font-size: 14px;
  font-family: inherit;
  background: var(--bg-card);
  color: var(--text-primary);
  transition: border-color 150ms ease, box-shadow 150ms ease;
  width: 100%;
}
.input:focus, .select:focus, .textarea:focus {
  border-color: var(--focus-border);
  box-shadow: var(--focus-ring);
  outline: none;
}

/* Badge (square-ish, not pill) */
.badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 11px;
  font-weight: 500;
  padding: 2px 8px;
  border-radius: 4px;
  letter-spacing: 0.02em;
}
.badge-success { background: var(--green-dim); color: var(--green); }
.badge-warning { background: var(--amber-dim); color: var(--amber); }
.badge-danger { background: var(--red-dim); color: var(--red); }
.badge-info { background: var(--blue-dim); color: var(--blue); }
.badge-neutral { background: var(--bg-tertiary); color: var(--text-secondary); }

/* Flat stat card (label above value, no icon box) */
.stat-flat {
  padding: 16px;
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius);
}
.stat-flat-label {
  font-size: 13px;
  font-weight: 500;
  color: var(--text-secondary);
  margin-bottom: 4px;
}
.stat-flat-value {
  font-size: 24px;
  font-weight: 600;
  color: var(--text-primary);
  font-variant-numeric: tabular-nums;
}
.stat-flat-delta {
  font-size: 12px;
  font-weight: 500;
  margin-top: 4px;
}
.stat-flat-delta.positive { color: var(--green); }
.stat-flat-delta.negative { color: var(--red); }
```

### Anti-Patterns to Avoid

- **Do NOT use `!important`** to override inline styles. If a variable.css change is not visible, the inline style block is the culprit -- fix it there.
- **Do NOT add a new CSS file.** Modify variables.css and base.css in place.
- **Do NOT touch render functions in this phase.** That is for page sweeps.
- **Do NOT remove `.dark-theme` rules.** Dark mode is deferred but the class toggle must continue working.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Color palette | Custom color picker | Tailwind Slate hex values | Perceptually balanced, industry standard |
| Shadow system | Custom shadow values | Documented 3-level system from STACK.md | Already researched and verified |
| Button hierarchy | Per-page button styles | `.btn-primary`/`.btn-secondary`/`.btn-ghost` classes | Consistency across all pages |
| Badge styles | Inline badge colors | `.badge-success`/`.badge-warning`/etc. classes | Same colors everywhere |
| Focus rings | Custom focus styles | `var(--focus-ring)` + `var(--focus-border)` | Blue focus, consistent |

## Common Pitfalls

### Pitfall 1: Inline Style Block Overrides Variables.css
**What goes wrong:** Change `--bg-primary` in variables.css but the inline `<style>` at line 35 re-declares `:root` with different values, winning by cascade order (later = higher priority).
**Why it happens:** The `<style>` block at line 35 comes after the `<link>` to variables.css in the document, so its declarations take precedence.
**How to avoid:** The inline `<style>` block at line 35 must be updated simultaneously with variables.css. Remove or neutralize competing declarations there.
**Warning signs:** Changes to variables.css have no visible effect.

### Pitfall 2: Font Family Competition
**What goes wrong:** variables.css sets `--font-sans: 'Inter'`, but line 49 of index.html sets `--font-body: 'IBM Plex Sans'` and line 89 uses `font-family: var(--font-body)`. Body text renders in IBM Plex Sans, not Inter.
**How to avoid:** Remove `--font-display` and `--font-body` declarations from the inline style block. Ensure body uses `var(--font-sans)`.

### Pitfall 3: cardEnter Animation on Every .card
**What goes wrong:** Line 8650-8652 applies `animation: cardEnter 0.5s` to every `.card` element. Even after removing the keyframe definition, this rule causes cards to start invisible (the `both` fill mode with a missing keyframe = broken).
**How to avoid:** Remove the animation rule itself (`animation: none`), not just the keyframe definition.

### Pitfall 4: Removing Too Many Animations at Once
**What goes wrong:** Removing all 47 keyframes in one pass introduces risk of breaking functional animations (spinner, skeleton, toast).
**How to avoid:** Categorize as KEEP/REMOVE before touching code. Test spinner and toast after changes.

### Pitfall 5: The `.dark-theme` Class
**What goes wrong:** Changing `:root` token values without checking if `.dark-theme` overrides exist. Dark mode may be deferred but the toggle still exists and users may have it active.
**How to avoid:** For this phase, set `.dark-theme` overrides to reasonable values OR set them to mirror the light values (effectively making dark mode identical to light mode temporarily). Do NOT break dark mode silently.

## Code Examples

### Complete variables.css After Token Swap

```css
:root {
  /* Brand Colors */
  --primary: #16a34a;
  --primary-hover: #15803d;
  --primary-light: rgba(22,163,74,0.08);
  --primary-dark: #15803d;
  --secondary: #64748b;
  --purple: #a855f7;

  /* Semantic Colors */
  --green: #16a34a;
  --green-dim: rgba(22,163,74,0.08);
  --blue: #2563eb;
  --blue-dim: rgba(37,99,235,0.08);
  --amber: #d97706;
  --amber-dim: rgba(217,119,6,0.08);
  --red: #dc2626;
  --red-dim: rgba(220,38,38,0.08);
  --purple-dim: rgba(168,85,247,0.08);

  /* Status Aliases */
  --success: #16a34a;
  --success-light: rgba(22,163,74,0.08);
  --warning: #d97706;
  --warning-light: rgba(217,119,6,0.08);
  --danger: #dc2626;
  --danger-light: rgba(220,38,38,0.08);
  --info: #2563eb;
  --info-light: rgba(37,99,235,0.08);

  /* Backgrounds — Slate scale */
  --bg-primary: #f8fafc;
  --bg-secondary: #ffffff;
  --bg-tertiary: #f1f5f9;
  --bg-card: #ffffff;
  --bg-card-hover: #f8fafc;
  --bg-hover: #f1f5f9;
  --bg-darker: #e2e8f0;
  --bg-elevated: #f1f5f9;
  --bg-float: #e2e8f0;
  --bg-app: var(--bg-primary);

  /* Text — Slate */
  --text-primary: #0f172a;
  --text-secondary: #64748b;
  --text-muted: #94a3b8;

  /* Borders — Solid hex */
  --border: #e2e8f0;
  --border-light: #f1f5f9;
  --border-strong: #cbd5e1;
  --border-active: #2563eb;

  /* Shadows — 3 levels, near-invisible */
  --shadow-xs: 0 1px 2px rgba(0,0,0,0.04);
  --shadow-sm: 0 1px 3px rgba(16,24,40,0.06), 0 1px 2px rgba(16,24,40,0.03);
  --shadow-md: 0 4px 8px -2px rgba(16,24,40,0.08), 0 2px 4px -2px rgba(16,24,40,0.04);
  --shadow: var(--shadow-xs);
  --shadow-lg: var(--shadow-md);
  --shadow-xl: var(--shadow-md);
  --shadow-card: var(--shadow-xs);
  --shadow-card-hover: var(--shadow-sm);
  --shadow-float: var(--shadow-md);
  --shadow-inset: none;
  --shadow-glow-green: none;
  --shadow-glow-blue: none;
  --shadow-inner-glow: none;

  /* Gradients — Flat solid values */
  --accent-gradient: #16a34a;
  --gradient-primary: #16a34a;
  --gradient-primary-hover: #15803d;
  --gradient-secondary: #2563eb;
  --gradient-warning: #d97706;
  --gradient-danger: #dc2626;
  --gradient-purple: #a855f7;
  --gradient-sidebar: #0f172a;
  --gradient-card: var(--bg-card);

  /* Glass — None */
  --glass-bg: var(--bg-card);
  --glass-border: var(--border);
  --glass-blur: none;

  /* Border Radius — Tighter */
  --radius-sm: 6px;
  --radius: 8px;
  --radius-lg: 12px;
  --radius-xl: 12px;

  /* Layout (unchanged) */
  --sidebar-width: 240px;
  --sidebar-collapsed-width: 72px;
  --header-height: 64px;

  /* Spacing (unchanged) */
  --space-0-5: 2px;
  --space-1: 4px;
  --space-1-5: 6px;
  --space-2: 8px;
  --space-2-5: 10px;
  --space-3: 12px;
  --space-3-5: 14px;
  --space-4: 16px;
  --space-5: 20px;
  --space-6: 24px;
  --space-7: 28px;
  --space-8: 32px;
  --space-10: 40px;

  /* Typography (sizes unchanged) */
  --text-xs: 11px;
  --text-sm: 13px;
  --text-base: 14px;
  --text-lg: 16px;
  --text-xl: 20px;
  --text-2xl: 24px;
  --text-3xl: 28px;

  --weight-normal: 400;
  --weight-medium: 500;
  --weight-semibold: 600;
  --weight-bold: 600;
  --weight-heavy: 600;

  --font-sans: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  --font-mono: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;

  --leading-tight: 1.2;
  --leading-normal: 1.5;
  --leading-relaxed: 1.6;

  --tracking-wide: 0.05em;

  /* Animation — Simplified */
  --transition: background-color 150ms ease, border-color 150ms ease, box-shadow 150ms ease, color 150ms ease;
  --ease-spring: ease;
  --ease-smooth: cubic-bezier(0.4, 0, 0.2, 1);
  --ease-bounce: ease;
  --ease-out-expo: ease;
  --duration-instant: 100ms;
  --duration-fast: 150ms;
  --duration-normal: 200ms;
  --duration-slow: 250ms;

  /* Buttons */
  --btn-primary-bg: #0f172a;
  --btn-primary-color: #ffffff;
  --btn-primary-hover: #1e293b;

  /* Focus */
  --focus-ring: 0 0 0 3px rgba(37,99,235,0.1);
  --focus-border: #2563eb;

  /* Icon defaults */
  --icon-default: var(--text-secondary);
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Zinc gray palette | Tailwind Slate (cool blue-gray) | v1.4 | All surfaces shift from warm to cool neutral |
| rgba() borders | Solid hex borders | v1.4 | Crisper lines, no transparency stacking issues |
| 12px card radius | 8px card radius | v1.4 | Professional tool vs consumer app feel |
| Green primary buttons | Dark slate (#0f172a) buttons | v1.4 | Single most impactful visual change |
| font-weight: 700-800 | Max weight: 600 | v1.4 | Confident not heavy typography |
| Decorative animations everywhere | Functional animations only | v1.4 | Professional, precise feel |

## Open Questions

1. **How many inline styles reference `--ease-spring` or `--ease-bounce` directly?**
   - What we know: These are referenced via CSS variables, not hardcoded
   - What's unclear: Whether any inline JS uses these values directly
   - Recommendation: Setting variables to `ease` effectively neutralizes them

2. **Should `.dark-theme` be temporarily set to mirror light theme?**
   - What we know: Dark mode is deferred to later phase
   - What's unclear: How many users currently use dark mode
   - Recommendation: Keep `.dark-theme` rules but update values to use new Slate tokens with dark equivalents

3. **What about the `body { font-family: var(--font-body) }` at line 89?**
   - What we know: This references `--font-body` (IBM Plex Sans) from the inline style block
   - What's unclear: Whether removing `--font-body` and switching to `var(--font-sans)` will cause layout shifts
   - Recommendation: Replace `--font-body` with `var(--font-sans)` in the inline block, remove Space Grotesk and IBM Plex references

## Sources

### Primary (HIGH confidence)
- `assets/css/variables.css` -- Complete current token inventory (154 lines)
- `assets/css/base.css` -- All component classes (1534 lines)
- `index.html` lines 35-9600 -- First inline style block with competing declarations and animations
- `.planning/research/STACK.md` -- Tailwind Slate values, shadow system, button patterns
- `.planning/research/FEATURES.md` -- Stripe/Linear visual patterns and anti-patterns
- `.planning/research/PITFALLS.md` -- Known failure modes from v1.2 and v1.3

### Secondary (MEDIUM confidence)
- Tailwind CSS Slate scale values (verified via STACK.md research)
- Stripe Elements Appearance API shadow values (verified via STACK.md)

## Metadata

**Confidence breakdown:**
- Token values: HIGH -- exact hex values from Tailwind Slate, documented in STACK.md
- Component classes: HIGH -- patterns directly observed in base.css
- Animation inventory: HIGH -- complete grep of all 47 keyframes with line numbers
- Inline style block analysis: HIGH -- directly read all 4 blocks
- Migration strategy: HIGH -- informed by v1.2/v1.3 failure analysis in PITFALLS.md

**Research date:** 2026-03-12
**Valid until:** 2026-04-12 (stable -- CSS values do not change)
