# Project Research Summary

**Project:** Horizon Star TMS v1.4 -- Web TMS Restyle to Stripe/Linear Aesthetic
**Domain:** Incremental CSS + JS visual restyle of a 38K-line single-file vanilla JS SPA
**Researched:** 2026-03-12
**Confidence:** HIGH

## Executive Summary

The v1.4 restyle targets a Stripe/Linear dashboard aesthetic: monochrome surfaces, restrained color, flat shadows, tighter border-radius, and medium-weight typography. The existing CSS custom property system in `variables.css` is architecturally sound and maps directly to the target tokens -- the restyle is primarily a value-swap at the token layer plus systematic inline-style replacement in render functions. Two prior restyle attempts failed: v1.2 was too ambitious (full mockup match, reverted entirely) and v1.3 was too conservative (CSS-only, stalled because 4,344 inline styles override CSS classes). The v1.4 approach must sit in the Goldilocks zone: token foundation first for global impact, then page-by-page render function sweeps replacing cosmetic inline styles with classes, committing after each page.

The single most important finding across all research dimensions is that **CSS variable changes alone are necessary but insufficient**. The 4,344 inline `style=` attributes in index.html bypass the variable system entirely. Every phase must include JS template literal edits alongside CSS changes. The second critical insight is that the restyle must be strictly cosmetic -- no logic refactoring, no feature additions, no HTML restructuring during style sweeps. v1.2 died from scope creep. The third is ordering: token layer first (60-70% visual shift instantly), dispatch pages second (80% of user time), shared chrome last (sidebar, modals).

Key risks are the Frankenapp problem (mixed old/new aesthetics during rollout), inline style whack-a-mole (manual per-function edits required, no safe regex), and gradient removal creating "flat = boring" if visual hierarchy is not replaced with typography weight and spacing. All three are well-understood with concrete prevention strategies.

## Key Findings

### Recommended Stack

No new technologies. The restyle operates within the existing vanilla JS + CSS custom properties architecture. Inter font stays (it is Stripe's font). No build tools, preprocessors, or frameworks needed.

**Core design token changes:**
- **Color palette:** Shift from Tailwind Zinc to Tailwind Slate (cool blue-gray undertone). Solid hex borders replace `rgba()` transparency.
- **Shadows:** Reduce to 3 levels (xs/sm/md). Remove all glow, float, lg, xl shadows. Stripe uses near-invisible 1px shadows.
- **Border-radius:** Reduce scale: 6px inputs/buttons, 8px cards, 12px modals. Nothing above 12px except full-round pills.
- **Typography:** Reduce heading weights from 700-800 to 500-600. Add negative letter-spacing on headings.
- **Primary buttons:** Dark slate (`#0f172a`) instead of green -- the single most impactful component change for the Stripe feel.

### Expected Features

**Must have (table stakes):**
- Neutral/monochrome surface hierarchy (95% gray, color only for status)
- Reduced border-radius (6-8px cards, not 12-16px)
- Shadow restraint (border-primary, shadow-secondary)
- Typography weight reduction (500 medium as workhorse, not 600-800)
- Color restraint (8% opacity badge tints, monochrome icons, no gradient cards)
- Clean tables (no zebra striping, sentence-case headers, hairline dividers)
- Three-level button hierarchy (primary dark, secondary outlined, ghost)

**Should have (differentiators):**
- Monochrome icons (single-weight, not dual-tone)
- Label-above-number stat card pattern (Stripe layout)
- Whitespace as primary section organizer (32px gaps replace borders)
- Refined sidebar (dimmer, tighter, less prominent active states)
- Skeleton shimmer as default loading state (not spinners)
- Blue focus rings (not green)

**Defer (post-restyle):**
- Dark theme parity (restyle light mode fully first, then add `body.dark-theme` block)
- Mobile-specific refinements (desktop first)
- New components or features
- Icon replacement (assess compatibility, execute separately if needed)

### Architecture Approach

Three-layer strategy: (1) Token foundation in `variables.css` for instant global shift, (2) Component class library for reusable patterns replacing the most common inline style clusters, (3) Page-by-page render function sweeps in `index.html`. Each render function is a self-contained unit that can be restyled independently without risk to other pages.

**Major components:**
1. **Token Layer** (`variables.css`) -- Global aesthetic values. One-time change, zero functional risk, 60-70% visual impact.
2. **Component Classes** (`base.css` modifications or new `restyle.css`) -- Reusable classes replacing top inline style patterns (~25 classes covering flex layouts, grids, typography, cards, tables, badges, filters).
3. **Render Function Sweeps** (`index.html`) -- Per-function replacement of cosmetic inline styles with classes. ~21 render functions across 5 priority tiers.

**Key architectural decision (researchers agree):** Modify `variables.css` and `base.css` in place rather than adding a fourth CSS layer. A separate `restyle.css` was considered but risks specificity conflicts. The PITFALLS researcher explicitly warns against adding a fourth CSS file. The ARCHITECTURE researcher suggests it for rollback safety. **Recommendation: start in-place, extract to separate file only if rollback becomes necessary.**

### Critical Pitfalls

1. **Frankenapp Problem** -- Mixed old/new aesthetic during rollout. Prevent by restyling tokens first (global baseline), then highest-traffic pages (Dashboard, Orders, Trips), and shared chrome (sidebar, modals) last.
2. **Inline Style Whack-a-Mole** -- 4,344 inline styles cannot be regex-replaced safely (embedded in JS template literals with ternaries). Each render function requires manual review. Separate cosmetic from structural styles.
3. **Scope Creep per Page** -- v1.2 died here. Strict rule: style-only changes per render function. No logic refactoring. No HTML restructuring. Time-box each page. Commit after each page.
4. **"Just CSS Variables" Illusion** -- v1.3 died here. Variable changes affect only ~300 lines of base.css consumers. The 4,344 inline styles are untouched. Accept upfront that JS edits are required.
5. **Flat = Boring** -- Removing gradients/shadows without adding alternative hierarchy (typography weight contrast, borders, spacing) makes pages look like unstyled HTML. Replace each removed gradient with a specific hierarchy cue.

## Implications for Roadmap

### Phase 1: Token Foundation and Class Library
**Rationale:** Highest-leverage change. One file edit shifts 60-70% of the global aesthetic. Creates the baseline that all subsequent page sweeps build on. Must come first per all four research dimensions.
**Delivers:** Updated `variables.css` (colors, shadows, radius, typography weights, borders). Core component classes added to `base.css` (flex utilities, section-header, metric-value, stripe-card, stripe-table, pill-filter). Animation purge (remove 44 of 47 keyframes, keep spin/fadeIn/skeleton-shimmer).
**Addresses:** Neutral surface hierarchy, shadow restraint, border-radius reduction, typography weight, border solidification.
**Avoids:** "Just CSS Variables" illusion -- phase explicitly includes the class library so subsequent pages have classes to adopt.

### Phase 2: Dashboard Restyle
**Rationale:** Landing page, first thing users see. Sets the tone for the entire restyle. Complex page (KPI strip, main grid, sidebar, analytics) but high visibility justifies the effort.
**Delivers:** Fully restyled dashboard with label-above-number stat cards, flat KPI cards (no icon boxes), simplified attention strip, tighter sidebar cards.
**Addresses:** Stat card redesign, whitespace as organizer, gradient removal from hero cards.
**Avoids:** Scope creep -- split into sub-sections (KPI strip, main grid, sidebar, analytics). Dashboard has ~180 inline styles.

### Phase 3: Orders Page Restyle
**Rationale:** Most-used page, ~250 inline styles, card + table dual view. Includes shared helpers (`renderOrderPreviewCard`, `renderPaginationControls`) that propagate to other pages.
**Delivers:** Flat order cards, clean table view, restyled filter bar, updated pagination controls.
**Addresses:** Card simplification, table refinement, badge styling, filter pill treatment.
**Avoids:** Inline style whack-a-mole -- orders page has deep ternary-embedded styles (lines 22401-22482). Map all inline styles before editing.

### Phase 4: Trips and Load Board Restyle
**Rationale:** Second most-used page. Trips has dual view modes (table + cards) and density toggle. Load Board shares orders workflow patterns.
**Delivers:** Clean trip table with hairline borders, restyled card view, simplified density toggle, flat load board.
**Addresses:** Table refinement, dual-view consistency.
**Avoids:** Frankenapp -- by this point Dashboard + Orders + Trips covers 80% of user time.

### Phase 5: People and Fleet Pages (Drivers, Trucks, Brokers)
**Rationale:** Card grids and table layouts. Lower complexity, follows patterns established in Phases 2-4.
**Delivers:** Flat driver cards, clean truck table, simplified broker metric cards.
**Addresses:** Card grid layout, metric display patterns.
**Avoids:** Typography drift -- reference the token scale, do not eyeball.

### Phase 6: Finance Pages (Billing, Payroll, Financials)
**Rationale:** Complex multi-tab layouts. Billing has aging bars and invoice tables. Payroll has print dependencies.
**Delivers:** Restyled billing tabs, flat aging summary, clean payroll cards, unified financial views.
**Addresses:** Multi-tab treatment, stat card consistency.
**Avoids:** Print layout breakage -- test print preview after restyling payroll/billing.

### Phase 7: Operations, Admin, and Long Tail
**Rationale:** Lower-traffic pages. Includes the Executive Dashboard (62 gradient references -- heaviest cleanup). Compliance, Settings, Fuel, IFTA, Reports, AI Advisor, Dealer Portal, Live Map, Team Chat.
**Delivers:** Full app consistency. All pages match the Stripe/Linear aesthetic.
**Addresses:** Gradient cleanup (executive dashboard), remaining inline styles.
**Avoids:** Stale CSS -- audit base.css for orphaned rules after final page.

### Phase 8: Shared Chrome and Polish
**Rationale:** Sidebar, topbar, modals, toasts must be restyled LAST so they do not clash with unrested pages during rollout.
**Delivers:** Dimmer sidebar, refined topbar, flat modals (12px radius, tighter padding), updated toast styling, blue focus rings, transition curve updates.
**Addresses:** Sidebar refinement, modal treatment, micro-interactions, focus ring color.
**Avoids:** Frankenapp -- shared chrome changes only after all page content is restyled.

### Phase 9 (Optional): Dark Theme
**Rationale:** No dark theme CSS currently exists. Light mode must be complete first. Dark theme is a single `body.dark-theme {}` block in variables.css IF all pages use CSS variables (not hardcoded hex).
**Delivers:** Full dark theme support.
**Addresses:** Dark mode parity.
**Avoids:** Dark mode afterthought -- verify no hardcoded colors crept in during light-mode restyle.

### Phase Ordering Rationale

- **Tokens first** because they are highest-leverage (1 line = hundreds of elements) and lowest-risk
- **Dashboard before Orders** because it is the landing page and simpler to restyle
- **Orders before Trips** because shared helpers (`renderOrderPreviewCard`) propagate downstream
- **Finance after Fleet** because finance pages are lower-traffic and more complex
- **Shared chrome last** because restyling sidebar/modals before all pages creates the Frankenapp problem
- **Dark theme only after light mode is fully complete** to avoid doubling every decision

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Dashboard):** Complex page with multiple sub-sections. Needs sub-task decomposition before execution.
- **Phase 3 (Orders):** Deep ternary-embedded inline styles need mapping before edit. Riskiest render function.
- **Phase 7 (Long Tail):** Executive Dashboard has 62 gradient references. Needs a gradient-to-flat replacement strategy.

Phases with standard patterns (skip research):
- **Phase 1 (Tokens):** Pure value swap. Well-documented target values in STACK.md.
- **Phase 5 (People/Fleet):** Follows patterns established in Phases 2-4. Straightforward card/table restyling.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Target values sourced from Stripe Elements API docs, Tailwind Slate scale, Linear redesign blog. Exact hex values documented. |
| Features | HIGH | Table stakes verified across multiple sources (Stripe, Linear, shadcn/ui). Anti-features well-documented with specific "do this instead" guidance. |
| Architecture | HIGH | Based on direct codebase analysis (4,344 inline styles counted, 133 render functions mapped, line numbers identified). Not speculative. |
| Pitfalls | HIGH | Grounded in two prior failed attempts (v1.2 and v1.3) with specific failure modes documented. Prevention strategies are concrete. |

**Overall confidence:** HIGH

### Gaps to Address

- **Dark theme variable completeness:** No dark theme CSS exists. When it is time for Phase 9, a full audit of every CSS variable will be needed to ensure dark-mode values exist.
- **Icon compatibility:** The 136 dual-tone SVG icons may clash with the monochrome flat aesthetic. Assess during Phase 1 but do not block restyle on icon replacement.
- **Print stylesheet impact:** The 491-line `print.css` has not been audited against restyle changes. Verify during Phase 6 (Billing/Payroll).
- **`<style>` blocks in index.html:** Four inline `<style>` blocks exist at lines 35, 34801, 37040, and 47007. These need auditing in Phase 1 to determine if they conflict with restyle classes.
- **restyle.css vs base.css in-place:** Researchers disagree on whether to create a new CSS file or modify base.css. Recommend starting in-place; extract if rollback is needed.

## Sources

### Primary (HIGH confidence)
- [Stripe Elements Appearance API](https://docs.stripe.com/elements/appearance-api) -- Shadow values, color tokens, font configuration
- [Stripe Accessible Color Systems](https://stripe.com/blog/accessible-color-systems) -- Color philosophy, contrast approach
- [Linear: How we redesigned the Linear UI](https://linear.app/now/how-we-redesigned-the-linear-ui) -- Inter Display, LCH color, contrast refinement
- [Linear: Behind the latest design refresh](https://linear.app/now/behind-the-latest-design-refresh) -- Sidebar dimming, border softening
- [Tailwind CSS Colors v4](https://tailwindcss.com/docs/colors) -- Slate hex values (industry standard neutral palette)
- [shadcn/ui Theming](https://ui.shadcn.com/docs/theming) -- CSS variable patterns for neutral palettes

### Secondary (MEDIUM confidence)
- [925 Studios: Linear Design Breakdown](https://www.925studios.co/blog/linear-design-breakdown) -- Specific CSS values, transition curves
- [LogRocket: Linear Design SaaS Trend](https://blog.logrocket.com/ux-design/linear-design/) -- Typography patterns, spacing systems
- [Radix UI Scale Usage](https://www.radix-ui.com/colors/docs/palette-composition/understanding-the-scale) -- 12-step color methodology
- [Smashing Magazine: Refactoring CSS](https://www.smashingmagazine.com/2021/08/refactoring-css-strategy-regression-testing-maintenance-part2/) -- Large-scale CSS refactoring strategy

### Tertiary (LOW confidence)
- [Stripe Brand Colors via Mobbin](https://mobbin.com/colors/brand/stripe) -- Brand hex values (secondary source)
- [Vercel Geist Colors](https://vercel.com/geist/colors) -- Gray scale naming conventions (contextual reference)

---
*Research completed: 2026-03-12*
*Ready for roadmap: yes*
