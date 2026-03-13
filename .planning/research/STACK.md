# Technology Stack: Stripe/Linear Dashboard Restyle

**Project:** Horizon Star TMS — CSS Restyle
**Researched:** 2026-03-12
**Constraint:** Pure CSS custom properties + vanilla JS. No build tools, no frameworks, no preprocessors.

---

## Executive Decision

**Keep Inter font. Replace the entire color system with a cool-gray (slate) neutral palette. Flatten all shadows to 1-2 subtle levels. Remove all gradients, glows, and glass effects. Reduce border-radius. Eliminate decorative animations.**

The current system already uses CSS custom properties in `variables.css`, which is the correct architecture. The restyle is a token-value swap plus targeted CSS overrides, not a structural change.

---

## 1. Color System

### Philosophy

Stripe and Linear dashboards share a defining trait: **monochrome dominance**. The UI is 95%+ neutral grays. Color appears only for:
- Status indicators (green/red/amber/blue)
- Interactive elements on hover/focus
- Data visualization

The current system uses Tailwind Zinc grays. The restyle should shift to **Tailwind Slate** (cool-tinted gray with a slight blue undertone), which matches the Stripe dashboard feel more precisely.

### Neutral/Gray Scale (Slate — Primary Palette)

These are the workhorse colors. Every surface, text element, and border uses this scale.

| Token | Hex | Usage |
|-------|-----|-------|
| `--gray-50` | `#f8fafc` | Page background |
| `--gray-100` | `#f1f5f9` | Card hover, subtle surface |
| `--gray-200` | `#e2e8f0` | Borders, dividers |
| `--gray-300` | `#cbd5e1` | Disabled text, subtle icons |
| `--gray-400` | `#94a3b8` | Placeholder text |
| `--gray-500` | `#64748b` | Secondary/muted text |
| `--gray-600` | `#475569` | Body text (secondary) |
| `--gray-700` | `#334155` | Strong secondary text |
| `--gray-800` | `#1e293b` | Headings, primary text |
| `--gray-900` | `#0f172a` | High-emphasis text |
| `--gray-950` | `#020617` | Maximum contrast text |

**Confidence: HIGH** — Values sourced directly from Tailwind CSS v3/v4 Slate scale, which is the industry standard neutral palette used by shadcn/ui and similar Stripe-inspired design systems.

### Mapped to Existing Tokens

The restyle remaps existing `variables.css` tokens to new values:

```css
:root {
  /* Backgrounds */
  --bg-primary: #f8fafc;        /* was #f5f5f7 (zinc) → now slate-50 */
  --bg-secondary: #ffffff;       /* stays white */
  --bg-tertiary: #f1f5f9;       /* was #f0f0f2 → now slate-100 */
  --bg-card: #ffffff;            /* stays white */
  --bg-card-hover: #f8fafc;     /* was #f3f4f6 → now slate-50 */
  --bg-hover: #f1f5f9;          /* slate-100 */
  --bg-darker: #e2e8f0;         /* slate-200 */
  --bg-elevated: #f1f5f9;       /* slate-100 */

  /* Text */
  --text-primary: #0f172a;      /* was #111827 → now slate-900 */
  --text-secondary: #64748b;    /* was #4b5563 → now slate-500 */
  --text-muted: #94a3b8;        /* was #9ca3af → now slate-400 */

  /* Borders */
  --border: #e2e8f0;            /* was rgba(0,0,0,0.08) → now slate-200 solid */
  --border-light: #f1f5f9;      /* was rgba(0,0,0,0.04) → now slate-100 */
}
```

**Key change:** Borders move from `rgba()` transparency to **solid hex values**. This is a Stripe pattern — they use opaque gray borders, not alpha-transparent ones. It produces crisper lines and avoids visual noise from layered transparency.

### Accent Colors (Restrained Use)

Keep the existing semantic colors but use them **sparingly** — only for status badges, alerts, and interactive states. Desaturate slightly for the flat aesthetic.

| Token | Current | New | Usage |
|-------|---------|-----|-------|
| `--primary` | `#22c55e` | `#16a34a` | Primary actions only (buttons, links) |
| `--primary-hover` | `#16a34a` | `#15803d` | Button hover |
| `--primary-light` | `rgba(34,197,94,0.12)` | `rgba(22,163,74,0.08)` | Subtle tint backgrounds (reduce opacity) |
| `--success` | `#22c55e` | `#16a34a` | Status: completed |
| `--warning` | `#f59e0b` | `#d97706` | Status: attention needed |
| `--danger` | `#ef4444` | `#dc2626` | Status: error, overdue |
| `--info` | `#3b82f6` | `#2563eb` | Status: in progress |

**Rationale:** Slightly darker, less saturated accent colors feel more professional and integrate better with the cool-gray palette. The current `#22c55e` green is quite vivid — `#16a34a` is one step darker and reads as more "serious business tool" than "consumer app."

### Color Usage Rules

1. **No colored backgrounds on cards.** Cards are always white (`#ffffff`) on slate-50 page background.
2. **No gradient backgrounds.** Flat solid colors only.
3. **Color in text/icons, not surfaces.** A green number is better than a green card.
4. **Status badges:** Tinted background + colored text (keep existing `--green-dim` pattern but reduce to 6-8% opacity).
5. **Active/selected states:** Use `--primary-light` (8% opacity tint), not a colored border-left or gradient.

---

## 2. Typography

### Font Stack

**Keep Inter.** It is the exact font Stripe uses in their Elements system and is the de facto standard for data-dense dashboard UIs. No change needed.

```css
--font-sans: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
--font-mono: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
```

### Type Scale

The current scale is correct for a dashboard. Minor adjustments to weight usage:

| Token | Size | Weight | Line Height | Usage |
|-------|------|--------|-------------|-------|
| `--text-xs` | `11px` | 500 | 1.45 | Badges, captions, metadata |
| `--text-sm` | `13px` | 400 | 1.5 | Table cells, secondary info |
| `--text-base` | `14px` | 400 | 1.5 | Body text, form labels |
| `--text-lg` | `16px` | 500 | 1.5 | Section headers, card titles |
| `--text-xl` | `20px` | 600 | 1.3 | Page titles |
| `--text-2xl` | `24px` | 600 | 1.2 | Dashboard stat values |
| `--text-3xl` | `28px` | 600 | 1.2 | Hero numbers (rare) |

### Weight Changes

**Reduce heavy weights.** The Stripe/Linear aesthetic uses weight 500 (medium) as the workhorse, not 600-800.

| Token | Current | New | Rationale |
|-------|---------|-----|-----------|
| `--weight-normal` | 400 | 400 | No change |
| `--weight-medium` | 500 | 500 | No change — this becomes the primary "emphasis" weight |
| `--weight-semibold` | 600 | 600 | Use only for page titles and stat values |
| `--weight-bold` | 700 | 600 | **Reduce.** 700 is too heavy for flat UI. Map to 600. |
| `--weight-heavy` | 800 | 600 | **Reduce.** 800 is never used in Stripe/Linear. Eliminate. |

**Key typography rules:**
- Page titles: 20px / 600 weight (not 28px / 800)
- Card section headers: 13px / 500 weight, uppercase, letter-spacing 0.5px, slate-500 color
- Table headers: 11px / 500 weight, uppercase, letter-spacing 0.5px, slate-400 color
- Body: 14px / 400 weight
- Numbers/money: `font-variant-numeric: tabular-nums` on monospace

### Letter Spacing

Add a token for the common uppercase-label pattern:

```css
--tracking-wide: 0.05em;    /* Uppercase labels, table headers */
--tracking-normal: 0;        /* Body text */
```

---

## 3. Shadow System

### Philosophy

Stripe uses **near-invisible shadows**. The purpose is barely-perceptible depth separation, not decorative effect. Their documented shadow value from the Elements API is:

```
0px 1px 1px rgba(0, 0, 0, 0.03), 0px 3px 6px rgba(18, 42, 66, 0.02)
```

Note the second layer uses a **blue-tinted dark** (`rgb(18, 42, 66)`) not pure black, which produces a cooler, more refined shadow.

**Confidence: HIGH** — This exact value is documented in Stripe's Elements Appearance API.

### Shadow Scale (3 levels)

| Token | Value | Usage |
|-------|-------|-------|
| `--shadow-xs` | `0 1px 2px rgba(0,0,0,0.04)` | Default card resting state |
| `--shadow-sm` | `0 1px 3px rgba(16,24,40,0.06), 0 1px 2px rgba(16,24,40,0.03)` | Card hover, dropdowns |
| `--shadow-md` | `0 4px 8px -2px rgba(16,24,40,0.08), 0 2px 4px -2px rgba(16,24,40,0.04)` | Modals, popovers, floating elements |

**Remove entirely:**
- `--shadow-lg` — Too heavy for flat UI
- `--shadow-xl` — Same
- `--shadow-glow-green` — Already `none`, confirm removed
- `--shadow-glow-blue` — Same
- `--shadow-inner-glow` — Same
- `--shadow-float` — Replace with `--shadow-md`

### Shadow Rules

1. **Cards at rest: `--shadow-xs` only.** Most cards should rely on border (`1px solid --border`) for definition, with shadow as barely-visible secondary cue.
2. **Cards on hover: `--shadow-sm`.** Subtle lift. No `transform: translateY()`.
3. **Floating elements (modals, dropdowns, command palette): `--shadow-md`.** This is the maximum depth.
4. **No colored shadows.** No `box-shadow` with brand colors.
5. **No inset shadows.**

---

## 4. Border Radius

### Stripe/Linear Pattern

Both use **smaller radii** than the current system. Stripe inputs are 6px. Cards are 8px. Modals are 12px max.

| Token | Current | New | Usage |
|-------|---------|-----|-------|
| `--radius-sm` | `8px` | `6px` | Inputs, buttons, badges, small elements |
| `--radius` | `12px` | `8px` | Cards, dropdowns, section containers |
| `--radius-lg` | `16px` | `12px` | Modals, command palette, large panels |
| `--radius-xl` | `20px` | `12px` | **Eliminate distinction.** 20px is too rounded for flat UI. |

**Rule:** Nothing should exceed 12px border-radius except full-round pills (avatar, status dots use `border-radius: 9999px`).

---

## 5. Spacing System

### Current System is Good

The existing 4px-base spacing scale is correct and matches Stripe/Linear patterns. **No changes needed to the scale itself.**

```css
--space-1: 4px;    --space-2: 8px;    --space-3: 12px;
--space-4: 16px;   --space-5: 20px;   --space-6: 24px;
--space-8: 32px;   --space-10: 40px;
```

### Spacing Usage Changes

The restyle should **tighten internal spacing** on most components:

| Component | Current Padding | New Padding | Rationale |
|-----------|----------------|-------------|-----------|
| Cards | `16px` | `16px` | Keep — already correct |
| Stat cards | `14px 16px` | `12px 16px` | Tighten vertical slightly |
| Table cells | `10px 14px` | `8px 12px` | Denser data tables (Stripe pattern) |
| Table headers | `10px 14px` | `8px 12px` | Match cells |
| Modal body | `20px` | `24px` | Keep generous for forms |
| Page padding | varies | `24px` | Consistent page margin |
| Section gap | `20-24px` | `24px` | Standardize |
| Card gap in grids | `12-16px` | `16px` | Standardize |

---

## 6. Borders

### Stripe Border Pattern

Stripe uses **opaque 1px borders** as the primary visual separator, not shadows. This is the most important pattern to adopt.

```css
--border: #e2e8f0;           /* slate-200 — primary border */
--border-light: #f1f5f9;     /* slate-100 — subtle dividers within cards */
--border-strong: #cbd5e1;    /* slate-300 — emphasized borders (active states) */
--border-active: #2563eb;    /* blue-600 — focus ring, active input */
```

### Border Rules

1. **Every card has a 1px border.** This replaces shadow as the primary depth cue.
2. **Table row dividers:** `1px solid var(--border-light)` (very subtle).
3. **Active/focused inputs:** `1px solid var(--border-active)` with `0 0 0 3px rgba(37,99,235,0.1)` focus ring.
4. **No colored left-borders on cards** (current hero-card pattern). Replace with flat cards.
5. **No double borders** (border + shadow creating visual heaviness).

---

## 7. Animations and Transitions

### What to Keep

```css
--duration-fast: 150ms;       /* Hover states, color changes */
--ease-smooth: cubic-bezier(0.4, 0, 0.2, 1);  /* Standard easing */
```

### What to Remove

| Current | Action | Reason |
|---------|--------|--------|
| `--ease-spring` | Remove | Bouncy animations are anti-Stripe |
| `--ease-bounce` | Remove | Same — no bounce in flat UI |
| `--ease-out-expo` | Remove | Overshoot easing is decorative |
| `--duration-slow: 400ms` | Reduce to `250ms` | Nothing should animate for 400ms |
| `stagger-enter` animations | Remove | Staggered card entrance is decorative |
| `syncPulse` glow animation | Simplify | Just opacity fade, no box-shadow pulse |
| Page cross-fade | Keep but simplify | `opacity 0→1` only, no `translateY` |
| 47 animation keyframes in index.html | Audit and remove most | Keep only: `spin`, `fadeIn`, `skeleton-shimmer` |

### Transition Pattern

```css
/* The only transition needed for most elements */
transition: background-color 150ms ease, border-color 150ms ease, box-shadow 150ms ease;
```

**Do NOT use `transition: all`.** It causes jank on layout properties. Explicitly list only the properties that change.

---

## 8. Component Patterns

### Cards (Flat)

```css
.card {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  padding: 16px;
  box-shadow: 0 1px 2px rgba(0,0,0,0.04);
}
.card:hover {
  box-shadow: 0 1px 3px rgba(16,24,40,0.06), 0 1px 2px rgba(16,24,40,0.03);
}
```

**No gradient backgrounds. No colored left-borders. No hero-card pattern.**

### Tables (Dense, Clean)

```css
.data-table th {
  padding: 8px 12px;
  font-size: 11px;
  font-weight: 500;
  color: #64748b;           /* slate-500, not muted */
  text-transform: uppercase;
  letter-spacing: 0.05em;
  background: #f8fafc;      /* slate-50 */
  border-bottom: 1px solid #e2e8f0;
}
.data-table td {
  padding: 8px 12px;
  font-size: 13px;
  border-bottom: 1px solid #f1f5f9;  /* very subtle row divider */
}
/* NO alternating row tint — Stripe does not use zebra striping */
```

### Buttons

```css
/* Primary */
.btn-primary {
  background: #0f172a;      /* slate-900 — dark button, not green */
  color: #ffffff;
  border: 1px solid #0f172a;
  border-radius: 6px;
  padding: 8px 16px;
  font-size: 14px;
  font-weight: 500;
}

/* Secondary */
.btn-secondary {
  background: #ffffff;
  color: #0f172a;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
}

/* Ghost */
.btn-ghost {
  background: transparent;
  color: #64748b;
  border: none;
}
```

**Note on primary button color:** Stripe uses dark (near-black) primary buttons, not their brand purple. Linear uses dark buttons too. For this TMS, **primary buttons should be dark slate (#0f172a)** for the flat look. The green brand color (`--primary`) stays for status indicators and links but NOT for primary button backgrounds. This is the single most impactful change for achieving the Stripe aesthetic.

### Status Badges

```css
.badge {
  font-size: 11px;
  font-weight: 500;
  padding: 2px 8px;
  border-radius: 4px;        /* NOT pill-shaped (20px). Square-ish badges. */
  letter-spacing: 0.02em;
}
.badge-success {
  background: rgba(22,163,74,0.08);
  color: #16a34a;
}
```

### Inputs

```css
input, select, textarea {
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  padding: 8px 12px;
  font-size: 14px;
  background: #ffffff;
  color: #0f172a;
  transition: border-color 150ms ease, box-shadow 150ms ease;
}
input:focus {
  border-color: #2563eb;
  box-shadow: 0 0 0 3px rgba(37,99,235,0.1);
  outline: none;
}
```

---

## 9. What NOT to Add

| Do NOT Add | Why |
|------------|-----|
| CSS framework (Tailwind, Bootstrap) | Unnecessary overhead. CSS custom properties already provide the token system. |
| CSS preprocessor (Sass, PostCSS) | No build tooling exists. Pure CSS custom properties are sufficient. |
| CSS-in-JS | No framework to support it. |
| CSS Houdini / `@property` | Browser support inconsistent. Not needed. |
| OKLCH color space | Requires color-mix() support investigation. Hex values are simpler and universally supported. |
| Container queries | Not needed for this restyle. Media queries are fine. |
| View Transitions API | Too cutting-edge. Simple opacity transitions suffice. |
| Custom fonts beyond Inter | Inter is already correct. Adding Sohne (Stripe's brand font) would be unnecessary and expensive. |
| CSS layers (`@layer`) | Adds complexity without benefit for a single-file architecture. |

---

## 10. What to Remove from Current CSS

### From `variables.css`

| Remove | Reason |
|--------|--------|
| `--gradient-*` tokens (all 7) | No gradients in flat UI. Replace with flat solid values. |
| `--glass-*` tokens (all 3) | No glassmorphism. |
| `--ease-spring` | No spring animations. |
| `--ease-bounce` | No bounce animations. |
| `--ease-out-expo` | Unnecessary. |
| `--shadow-lg` through `--shadow-xl` | Too heavy. Only xs/sm/md needed. |
| `--weight-heavy: 800` | Never used in flat UI. |
| `--radius-xl: 20px` | Too rounded. Cap at 12px. |

### From `base.css`

| Remove/Simplify | Reason |
|-----------------|--------|
| `.hero-card` gradient backgrounds | No colored gradient cards. Flat white only. |
| `.stagger-enter` animation delays | Decorative. |
| `.sync-dot` glow keyframe | Simplify to opacity pulse. |
| `backdrop-filter: blur(8px)` on table headers | Unnecessary glass effect. Use opaque background. |
| `.mobile-record-card` gradient background | Flat white. |
| `color-mix()` on alternating rows | Remove zebra striping. |

### From `index.html` Inline Styles

This is the big job. The 38K-line `index.html` contains:
- ~47 `@keyframes` definitions (keep 3: `spin`, `fadeIn`, `skeleton-shimmer`)
- Gradient backgrounds in render functions
- Heavy shadows in inline styles
- `font-weight: 800` and `font-weight: 700` scattered throughout
- Colored left-borders on cards
- `border-radius: 20px`+ values

---

## 11. Implementation Order

Based on this research, the restyle should proceed in this order:

1. **Token swap in `variables.css`** — Replace all color, shadow, radius values. This alone changes 60-70% of the visual appearance instantly.
2. **`base.css` component overrides** — Flatten cards, tables, badges, buttons.
3. **`index.html` inline style audit** — Find and replace gradient backgrounds, heavy shadows, decorative animations in render functions.
4. **Button restyle** — Dark primary buttons (most impactful single change after colors).
5. **Animation purge** — Remove 44 of 47 keyframes, simplify transitions.

---

## Sources

- [Stripe Elements Appearance API](https://docs.stripe.com/elements/appearance-api) — Shadow values, color tokens, font configuration
- [Stripe Accessible Color Systems](https://stripe.com/blog/accessible-color-systems) — Color philosophy, perceptual uniformity approach
- [Stripe Brand Colors (Mobbin)](https://mobbin.com/colors/brand/stripe) — Primary brand hex values (#0A2540, #F6F9FC, #635BFF)
- [Radix UI Scale Usage](https://www.radix-ui.com/colors/docs/palette-composition/understanding-the-scale) — 12-step color scale methodology (backgrounds/borders/text)
- [Linear UI Redesign](https://linear.app/now/how-we-redesigned-the-linear-ui) — LCH color space, surface elevation approach
- [Linear Design Trend (LogRocket)](https://blog.logrocket.com/ux-design/linear-design/) — Shadow values, typography patterns, spacing
- [Vercel Geist Colors](https://vercel.com/geist/colors) — Gray scale token naming (`--ds-gray-100` through `--ds-gray-1000`)
- [Tailwind CSS Colors (v4)](https://tailwindcss.com/docs/colors) — Slate and Zinc hex values
- [shadcn/ui Theming](https://ui.shadcn.com/docs/theming) — CSS variable patterns for neutral palettes
