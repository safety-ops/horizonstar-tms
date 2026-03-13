# Feature Landscape: Stripe/Linear Visual Restyle

**Domain:** Visual restyle of existing TMS dashboard to Stripe/Linear aesthetic
**Researched:** 2026-03-12
**Mode:** Ecosystem -- what visual components and patterns define the look

---

## Table Stakes

Features that MUST be present or the restyle will not read as "Stripe/Linear." Missing any of these means the result looks like a generic Bootstrap dashboard with a coat of paint.

### 1. Neutral/Monochrome Surface Hierarchy

| Attribute | Current State | Target State |
|-----------|--------------|--------------|
| Background | `#f5f5f7` (warm gray) | Pure white `#ffffff` or near-white `#fafafa` for content area |
| Card bg | `#ffffff` on `#f5f5f7` | Cards nearly invisible on background -- minimal contrast between card and page |
| Sidebar | `#111113` dark gradient | Muted sidebar -- either light gray (`#f7f7f8`) or very dark desaturated (`#1a1a1e`) |
| Border color | `rgba(0,0,0,0.08)` | Lighter still: `rgba(0,0,0,0.06)` or `#e5e5e5` -- borders should whisper, not speak |

**Why this matters:** Stripe and Linear both achieve their premium feel by making the chrome (navigation, borders, cards) recede so content dominates. The current TMS has good bones here but the contrast between `#f5f5f7` background and `#ffffff` cards creates visible "card rectangles" everywhere. Stripe makes cards nearly invisible on the page -- you see the content, not the container.

**Confidence:** HIGH -- verified via Stripe design docs and Linear's own design refresh blog post describing "dimmer sidebar" and "softened borders."

### 2. Typography: Inter Display for Headings, Tighter Tracking

| Attribute | Current State | Target State |
|-----------|--------------|--------------|
| Heading font | Inter 600-800 weight | Inter Display 600 weight (or Inter with `-0.02em` letter-spacing) |
| Body size | 14px base | 14px base (keep) |
| Heading weight | 700-800 (heavy) | 500-600 (medium-semibold) -- confidence, not shouting |
| Letter spacing | Default (0) | `-0.01em` to `-0.03em` on headings, `0` on body |
| Label style | 11px uppercase 600 weight, 0.5px tracking | 11px uppercase 500 weight, 0.05em tracking (slightly lighter weight) |
| Stat values | 24px 800 weight mono | 28-32px 500-600 weight, proportional (not mono for display numbers) |
| Line height | 1.5 body, 1.3 heading | 1.5 body (keep), 1.2 heading (tighter) |

**Why this matters:** Linear explicitly moved to Inter Display for headings to "add expression while maintaining readability." Stripe uses their custom Camphor but the principle is the same: headings are confident but not heavy. The current TMS uses 800 weight on stat values which reads as aggressive. Stripe's numbers are large but medium-weight, letting the size do the work instead of boldness.

**Confidence:** HIGH -- Linear's redesign blog explicitly documents the Inter Display choice. Stripe uses Camphor (custom) but Inter Display is the established open-source equivalent.

### 3. Reduced Border Radius

| Attribute | Current State | Target State |
|-----------|--------------|--------------|
| Card radius | 12px | 8px |
| Button radius | varies (8-20px) | 6px |
| Badge/pill radius | 12px (fully round) | 6px (softly rounded, not pill-shaped) |
| Input radius | varies | 6px |
| Modal radius | 16px | 10-12px |

**Why this matters:** The current TMS uses 12px+ radii everywhere, which creates a "bubbly" feel. Both Stripe and Linear use tighter radii -- typically 6-8px for cards, 4-6px for inputs and buttons. This single change shifts perception from "friendly consumer app" to "professional tool." Status badges in particular: the current pill shape (12px border-radius on a small element = fully rounded) reads as playful. Stripe uses subtle rounding (4-6px) on badges.

**Confidence:** HIGH -- observable on both Stripe dashboard and Linear UI.

### 4. Shadow Restraint and Hierarchy

| Attribute | Current State | Target State |
|-----------|--------------|--------------|
| Card shadow | `0 1px 2px rgba(0,0,0,0.04)` | `0 1px 3px rgba(0,0,0,0.04)` or NO shadow (border only) |
| Card hover shadow | `0 2px 8px rgba(0,0,0,0.08)` | `0 2px 4px rgba(0,0,0,0.06)` (barely perceptible lift) |
| Elevated shadow | `--shadow-lg` (10px blur) | Reserved for modals/dropdowns ONLY |
| Float shadow | `--shadow-lg` | Large shadow only for command palette, dropdowns, popovers |

**Why this matters:** Stripe barely uses shadows on cards. Most cards are defined by a thin border or even just whitespace. Shadows are reserved for elements that actually float above the page (modals, dropdowns). The current approach of shadows-on-everything flattens the hierarchy -- when everything has a shadow, nothing has elevation.

**Confidence:** HIGH -- Stripe's design system docs explicitly limit shadow usage.

### 5. Color Restraint with Purposeful Accent

| Attribute | Current State | Target State |
|-----------|--------------|--------------|
| Primary accent | `#22c55e` (bright green) | Keep for actions/CTAs but reduce surface area |
| Status colors | Green/amber/red/blue full saturation | Keep hues, slightly desaturate (e.g., green `#22c55e` -> `#34d399` or keep but use more sparingly) |
| Badge backgrounds | 12% opacity tints (`rgba(34,197,94,0.12)`) | 8% opacity tints -- even more subtle |
| Icon colors | Status-colored icons common | Most icons: `--text-muted` gray. Color only for status meaning |
| Hero cards | Gradient from status color 12% -> transparent | Remove gradient backgrounds entirely. Status indicated by small dot or thin left border only |
| Link color | `--primary` (green) | Neutral text color for navigation links, green only for actionable links |

**Why this matters:** Linear's refresh explicitly described "limiting how much chrome (blue in their case) was used." Stripe uses a mostly gray/neutral palette with their indigo appearing only for interactive elements (buttons, links, focus rings). The current TMS uses color generously -- colored stat icons, gradient hero cards, green everywhere. The restyle should make color rare and therefore meaningful.

**Confidence:** HIGH -- both Linear (blog post) and Stripe (accessible color system blog) explicitly document this approach.

### 6. Table Refinement

| Attribute | Current State | Target State |
|-----------|--------------|--------------|
| Header bg | `var(--bg-tertiary)` (visible gray) | Transparent or barely-there (`rgba(0,0,0,0.02)`) |
| Header text | 11px uppercase 600 weight | 12px sentence-case or small-caps, 500 weight, `--text-muted` |
| Row border | `1px solid var(--border)` on every row | Border only on header bottom. Rows separated by whitespace or very faint `rgba(0,0,0,0.03)` |
| Alternating rows | `color-mix 30% bg-tertiary` | Remove zebra striping entirely. Hover state is sufficient |
| Row hover | `var(--bg-card-hover)` | Very subtle `rgba(0,0,0,0.02)` highlight |
| Cell padding | `10px 14px` | `12px 16px` (slightly more breathing room) |
| Sticky header | Yes with backdrop-filter | Keep, but ensure background is opaque white, not blurred |

**Why this matters:** Stripe's tables are famously clean -- no zebra striping, almost invisible headers, generous padding. The data speaks for itself. The current TMS tables are functional but visually busy with visible header backgrounds, alternating row colors, and prominent borders. Removing these layers lets the data breathe.

**Confidence:** HIGH -- Stripe's table design is well-documented and widely referenced.

### 7. Button Hierarchy: Fewer Styles, Clearer Intent

| Attribute | Current State | Target State |
|-----------|--------------|--------------|
| Primary button | Green background, various sizes | Single primary style: solid fill with 6px radius, medium weight text |
| Secondary button | Various (outlined, ghost) | Ghost button: no border, subtle text, hover shows faint background |
| Destructive | Red variants | Red text or subtle red background, not solid red button |
| Icon buttons | Various treatments | Borderless, gray icon, hover shows faint circular background |
| Button padding | Various | Consistent: `8px 16px` standard, `6px 12px` compact |

**Why this matters:** Stripe has exactly 3 button levels: primary (solid), secondary (outlined), and ghost (text-only). The current TMS has many button variants which creates decision fatigue and visual noise. Fewer button styles = clearer action hierarchy.

**Confidence:** MEDIUM -- extrapolated from Stripe Apps component docs and observable patterns.

---

## Differentiators

Details that separate "looks like Stripe" from "could BE Stripe." Not required for the restyle to succeed, but these are what make people say "this feels premium."

### 1. Subtle Transition Curves

| Attribute | Current State | Target State |
|-----------|--------------|--------------|
| Default easing | `cubic-bezier(0.4, 0, 0.2, 1)` (Material) | `cubic-bezier(0.44, 0, 0.56, 1)` (Linear's curve -- smoother, less snappy) |
| Hover duration | 200ms | 150ms for color changes, 200ms for layout shifts |
| Page transitions | `fadeIn 0.2s` with 4px Y translate | Crossfade only (no Y movement) or minimal 2px Y |
| Stagger animation | 50ms between items | 30ms between items (faster cascade) |

**Why this matters:** Linear uses `cubic-bezier(0.44, 0, 0.56, 1)` throughout -- a symmetric ease that feels natural without the "bouncy" quality of Material Design curves. The current spring/bounce easings (`--ease-spring`, `--ease-bounce`) should be removed entirely. Premium tools feel precise, not playful.

**Confidence:** HIGH -- Linear's CSS was directly observed via 925 Studios analysis.

### 2. Monochrome Icons with Consistent Stroke Weight

| Attribute | Current State | Target State |
|-----------|--------------|--------------|
| Icon style | Dual-tone SVG (recently updated) | Single-color, 1.5px stroke weight, monochrome |
| Icon color | Various (colored per status) | Default: `--text-muted`. Active/selected: `--text-primary` |
| Icon size | Various (16-22px) | Standardize: 16px inline, 18px in nav, 20px standalone |
| Sidebar icons | Colored or dark | All `--text-muted`, active item only gets `--text-primary` |

**Why this matters:** Both Stripe and Linear use monochrome iconography. Linear's refresh explicitly "removed colored backgrounds on team icons." Icons should be informational, not decorative. The dual-tone SVG style (recently added to this TMS) actually pushes away from the target aesthetic.

**Confidence:** HIGH -- Linear explicitly documented removing colored icon backgrounds. Stripe dashboard uses monochrome Lucide-style icons.

### 3. Refined Sidebar Treatment

| Attribute | Current State | Target State |
|-----------|--------------|--------------|
| Sidebar bg | Dark (`#111113`) | Light: `#f8f8f8` (barely different from white) or dark: `#18181b` (zinc-900) |
| Active item | Green highlight background | Subtle: `font-weight: 600` + faint background `rgba(0,0,0,0.04)`. No colored indicator |
| Item text | 13px with icons | 13px, `--text-secondary` default, `--text-primary` when active |
| Section headers | Mixed treatment | 11px uppercase `--text-muted`, generous top margin (24px+) |
| Sidebar width | 240px | 220px (slightly tighter -- Linear is ~216px) |
| Item padding | Various | Consistent `8px 12px` with `4px` gap between items |
| Hover state | Various | `rgba(0,0,0,0.03)` background, no color change |

**Why this matters:** Linear's refresh made the sidebar "a few notches dimmer" with "smaller text sizing" and "reduced scale." The sidebar should be nearly invisible -- a quiet navigation rail, not a prominent design element. The current dark sidebar with green active states draws too much attention.

**Confidence:** HIGH -- Linear's design refresh blog explicitly describes these sidebar changes.

### 4. Stat Cards: Numbers Without Decoration

| Attribute | Current State | Target State |
|-----------|--------------|--------------|
| Icon treatment | 44px colored icon box (green/blue/amber dim bg) | No icon boxes. Small 16px monochrome icon inline with label, or no icon at all |
| Number size | 24px 800 weight mono | 28-32px 500 weight proportional, tabular-nums for alignment |
| Label position | Below number | Above number (label first, then value -- Stripe pattern) |
| Card padding | 14px 16px | 16px 20px (more breathing room) |
| Comparison/delta | N/A | Small `+12%` or arrow indicator next to number in muted green/red |

**Why this matters:** Stripe's stat cards are remarkably simple: a small gray label, a large number, and optionally a delta indicator. No colored icon boxes, no gradients, no hero cards. The label-above-number pattern creates clear scanning hierarchy: you read what the metric IS, then see its value. The current icon boxes (44px with colored backgrounds) add visual weight without information.

**Confidence:** HIGH -- directly observable on Stripe dashboard.

### 5. Whitespace as Primary Organizer

| Attribute | Current State | Target State |
|-----------|--------------|--------------|
| Section gap | `--space-5` (20px) / `--space-6` (24px) | 32px between major sections |
| Card gap | `--space-3` (12px) | 16px between cards in a grid |
| Page top padding | Varies | 32px consistent |
| Content max-width | None (full width) | Consider 1200px max-width for content area (optional) |
| Section dividers | Cards/borders | 32px+ whitespace gap replaces need for visible dividers |

**Why this matters:** Both Stripe and Linear use whitespace to create section boundaries instead of borders or cards. When you increase spacing between sections from 20px to 32px, you can often remove the border or card wrapper entirely. The content groups itself visually through proximity. This is the single highest-impact change after color restraint.

**Confidence:** HIGH -- Linear explicitly uses 8px scale (8/16/32/64) for spacing. Stripe uses equivalent spacing tokens.

### 6. Focus Ring Refinement

| Attribute | Current State | Target State |
|-----------|--------------|--------------|
| Focus ring | `2px solid var(--primary)` (green) | `2px solid #2563eb` (blue-600) or `2px solid --text-primary` |
| Focus offset | `2px` | `2px` (keep) |
| Focus visibility | On `:focus-visible` only | Keep (correct) |

**Why this matters:** Green focus rings are unusual and slightly jarring. Both Stripe and Linear use blue or neutral focus indicators. This is a small detail but it affects perceived polish for keyboard users.

**Confidence:** MEDIUM -- observed pattern, not explicitly documented.

### 7. Loading States: Skeleton Shimmer, Not Spinners

| Attribute | Current State | Target State |
|-----------|--------------|--------------|
| Primary loading | Spinner (`border-top` rotation) | Skeleton shimmer matching content layout |
| Skeleton pulse | Opacity pulse exists | Shimmer gradient (left-to-right sweep) -- already exists in base.css |
| Inline loading | `spinner-inline` | Small gray dot pulse or skeleton text |

**Why this matters:** The skeleton shimmer already exists in the CSS (`skeleton-shimmer` keyframe) but the primary loading pattern is still the spinner. Stripe and Linear both use layout-matching skeletons as the default loading state, with spinners only for in-progress actions (saving, submitting). This creates the feeling that the UI is "always there" even while loading.

**Confidence:** HIGH -- widely documented pattern for both products.

---

## Anti-Features

Common mistakes when attempting to copy the Stripe/Linear look. These will make the restyle look like a cheap imitation.

### 1. DO NOT: Add Glassmorphism / Heavy Blur Effects

**What people do:** Add `backdrop-filter: blur(12px)` everywhere, semi-transparent cards, frosted glass headers.

**Why it fails:** Neither Stripe nor Linear use glassmorphism in their web dashboards. Linear explored it for mobile (Liquid Glass) but the web app uses opaque surfaces. Blur effects tank performance on data-heavy pages, create contrast/accessibility issues, and look dated in 2026. The current TMS has `--glass-blur: none` which is correct -- keep it that way.

**What to do instead:** Opaque surfaces with near-zero contrast between layers.

### 2. DO NOT: Over-animate

**What people do:** Add entrance animations to everything, parallax effects, hover scale transforms, bouncy transitions.

**Why it fails:** The current TMS has `--ease-spring` and `--ease-bounce` easings. These feel playful and consumer-grade. Stripe animates almost nothing. Linear's animations are so subtle you barely notice them. The page transition (`fadeIn 0.2s`) is fine but adding `translateY(4px)` to it creates a "slide up" feel that reads as mobile-app-ish.

**What to do instead:** Opacity transitions only for page changes. Color/background transitions for hover states. No transform animations except for dropdown/modal open/close.

### 3. DO NOT: Use Colored Backgrounds on Status Badges

**What people do:** Bright colored pill badges with white text (e.g., solid green "ACTIVE" badge).

**Why it fails:** Stripe uses very subtle tinted backgrounds (5-8% opacity) with colored text. Solid colored badges create visual noise in tables and lists -- every row screams for attention. The current TMS badges use 12% opacity tints which is close but should go even more subtle.

**What to do instead:** Tinted backgrounds at 6-8% opacity with matching text color. Or even simpler: just colored text with a small dot indicator, no background at all.

### 4. DO NOT: Create Visual "Sections" with Different Background Colors

**What people do:** Alternate section backgrounds (white, then gray, then white) to create visual separation.

**Why it fails:** This is a legacy web design pattern. Stripe uses a single background color for the entire content area. Section separation comes from whitespace and typography hierarchy, not background color changes.

**What to do instead:** Consistent background. Use 32px+ spacing between sections. Use heading typography to introduce new sections.

### 5. DO NOT: Add Gradient Backgrounds to Cards

**What people do:** Subtle gradient fills on cards, colored left borders with gradient fades.

**Why it fails:** The current TMS has hero cards with `linear-gradient(to right, var(--green-dim), var(--bg-card) 40%)`. This is the opposite of the Stripe aesthetic. Stripe cards are flat white/gray with no gradients. A thin left border (2px, solid color) is acceptable but the gradient fade should go.

**What to do instead:** Flat backgrounds. If a card needs emphasis, use a slightly different background shade (e.g., `#f8fafc` vs `#ffffff`) or a thin colored left border. Never gradients.

### 6. DO NOT: Use Heavy Uppercase Labeling Everywhere

**What people do:** 11px UPPERCASE TRACKING 0.5px on every label, every table header, every stat label.

**Why it fails:** When everything is uppercase, nothing stands out as a label. The current TMS uses this treatment extensively (`.text-label`, `.stat-card .stat-label`, table headers). Stripe uses sentence case for most labels and reserves uppercase for very specific categorization headers.

**What to do instead:** Use uppercase sparingly -- section headers, category labels. Table headers should be sentence case with `--text-muted` color and 500 weight. Stat labels should be sentence case, 13px, `--text-secondary`.

### 7. DO NOT: Use Monospace Fonts for Dollar Amounts in Display Context

**What people do:** Apply `font-family: monospace` to all currency values.

**Why it fails:** Monospace is correct for tabular data (table columns where numbers should align). But for display stat values (the big "$42,850" on a dashboard card), monospace looks mechanical. Stripe uses their proportional typeface with `font-variant-numeric: tabular-nums` only where column alignment matters.

**What to do instead:** Proportional font for display numbers. `font-variant-numeric: tabular-nums` (NOT monospace) for table columns.

### 8. DO NOT: Keep the Colored "Dim" Icon Boxes

**What people do:** Wrap icons in colored background squares (green-dim bg with green icon).

**Why it fails:** The 44px colored icon boxes in stat cards are a popular pattern from 2022-era dashboards. Neither Stripe nor Linear uses them. They add visual weight and color noise to what should be clean, scannable metric cards. Every stat card with a colored icon box becomes a miniature hero element competing for attention.

**What to do instead:** Remove icon boxes entirely from stat cards. If an icon is needed, use a small (16px) monochrome icon inline with the label text.

---

## Feature Dependencies

```
Color restraint ──> Card/surface simplification (must reduce color BEFORE removing card borders)
Typography refinement ──> Stat card redesign (heading weight change affects metric display)
Border radius tightening ──> Badge/button updates (all interactive elements should match)
Shadow reduction ──> Whitespace increase (removing shadows requires more whitespace for grouping)
Table refinement ──> Row interaction patterns (removing zebra stripes requires clear hover state)
```

**Critical path:** Color restraint and typography are the foundation. Everything else builds on having the neutral palette and refined type hierarchy in place. If you change card shadows without first establishing the neutral color system, the cards will look broken rather than refined.

---

## MVP Recommendation (Phase Ordering)

For a visual restyle, prioritize in this order:

1. **Color system + Typography** -- Update CSS variables and font treatments. This alone shifts 60% of the perception.
   - Neutral surface hierarchy
   - Heading weight reduction (800 -> 500-600)
   - Letter-spacing on headings
   - Reduce badge/tint opacity from 12% to 8%

2. **Cards + Shadows + Borders** -- Remove visual containers.
   - Reduce border-radius to 6-8px
   - Remove card shadows (border-only or borderless)
   - Remove hero card gradients
   - Remove zebra striping from tables

3. **Components** -- Refine interactive elements.
   - Button hierarchy (3 levels only)
   - Table header treatment (sentence case, lighter)
   - Stat card simplification (remove icon boxes)
   - Badge refinement (subtler, not pill-shaped)

4. **Sidebar + Navigation** -- Update chrome.
   - Sidebar color and active states
   - Icon monochrome treatment
   - Whitespace increase between sections

5. **Micro-interactions** -- Polish.
   - Transition curve update
   - Remove spring/bounce easings
   - Skeleton loading as default
   - Focus ring color

**Defer to post-restyle:**
- Dark theme parity (restyle light theme first, then adapt dark)
- Mobile-specific refinements (get desktop right first)
- Any new components or features

---

## Applicable TMS Context

### Status Colors Must Survive

The TMS relies on green/amber/red color coding for operational status (trip status, payment status, delivery status). The restyle must preserve these semantic meanings while making them more subtle. Approach: desaturate slightly, reduce tint opacity, and use colored text + dots instead of colored background fills where possible.

### Data Density is Non-Negotiable

Dispatchers need to see many orders/trips at once. The Stripe aesthetic favors generous whitespace, but a TMS cannot sacrifice information density the way a payment dashboard can. Balance: tighter table rows (maintain current 10-14px cell padding), generous whitespace BETWEEN sections rather than within them.

### Existing CSS Variable System is an Asset

The current CSS variable system (`variables.css`) maps closely to what a Stripe/Linear restyle needs. Most changes can be achieved by updating variable values rather than rewriting component CSS. This is a significant advantage -- the token-based system was well-designed for exactly this kind of restyle.

---

## Sources

- [Linear: How we redesigned the Linear UI](https://linear.app/now/how-we-redesigned-the-linear-ui) -- Inter Display, LCH color space, contrast refinement
- [Linear: A calmer interface for a product in motion](https://linear.app/now/behind-the-latest-design-refresh) -- sidebar dimming, border softening, separator reduction
- [Stripe: Style your app](https://docs.stripe.com/stripe-apps/style) -- design tokens, spacing scale, limited custom styling
- [Stripe: Designing accessible color systems](https://stripe.com/blog/accessible-color-systems) -- accessible palette, contrast thresholds
- [LogRocket: Linear design SaaS trend](https://blog.logrocket.com/ux-design/linear-design/) -- monochrome shift, typography patterns, dark mode patterns
- [925 Studios: Linear Design Breakdown](https://www.925studios.co/blog/linear-design-breakdown) -- specific CSS values, spacing, transition curves, color tokens
- [LogRocket: Linear aesthetic UI libraries](https://blog.logrocket.com/ux-design/linear-design-ui-libraries-design-kits-layout-grid/) -- 8px spacing system, component modularity
