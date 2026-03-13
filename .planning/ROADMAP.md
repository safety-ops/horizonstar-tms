# Roadmap: Horizon Star TMS

## Milestones

- ✅ **v1.0 MVP** - Phases 1-5 (shipped 2024)
- ✅ **v1.1 UI Redesign Mockups** - Phases 6-10 (shipped 2026-02-10)
- ❌ **v1.2 Apply UI Redesign to Production** - Phases 11-15 (abandoned, reverted 2026-02-11)
- ❌ **v1.3 CSS Polish** - Phases 16-18 (abandoned, never started 2026-03-12)
- 🚧 **v1.4 Web TMS Restyle (Stripe/Linear)** - Phases 19-26 (in progress)

## Overview

v1.4 restyles every page of the Web TMS to a clean, flat, Stripe/Linear aesthetic. The work begins with a token foundation swap in CSS variables (60-70% instant visual shift), then sweeps through dispatch pages (where 80% of user time is spent), fleet/people pages, finance pages, operations pages, and finally shared chrome (sidebar, modals, login). Each phase delivers a fully restyled, visually consistent slice of the application. Quality gates are verified in the final phase after all pages match the target aesthetic.

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-5) - SHIPPED 2024</summary>

Phase 1-5 details collapsed. See git history for original v1.0 work.

</details>

<details>
<summary>✅ v1.1 UI Redesign Mockups (Phases 6-10) - SHIPPED 2026-02-10</summary>

### Phase 6: Dashboard Mockup
**Status**: Complete
**Plans**: 2/2 complete

### Phase 7: Core Dispatch Pages Mockup
**Status**: Complete
**Plans**: 4/4 complete

### Phase 8: People & Fleet Mockup
**Status**: Complete
**Plans**: 3/3 complete

### Phase 9: Financial Pages Mockup
**Status**: Complete
**Plans**: 4/4 complete

### Phase 10: Operations & Admin Pages Mockup
**Status**: Complete
**Plans**: 8/8 complete

**Milestone v1.1 Result**: 25 mockup HTML files + shared.css (1,308 lines) + base-template.html + component-showcase.html. Design system fully defined, approved, and ready for production application.

</details>

<details>
<summary>❌ v1.2 Apply UI Redesign to Production (Phases 11-15) - ABANDONED 2026-02-11</summary>

Phases 11-12 completed (13 plans), then entire milestone reverted (commit ae70551). Direction changed to flat/professional CSS polish instead of mockup-matching approach. Phases 13-15 never started.

</details>

<details>
<summary>❌ v1.3 CSS Polish (Phases 16-18) - ABANDONED 2026-03-12</summary>

Requirements and roadmap defined (16 requirements across 3 phases). Never started. Direction changed to full page-by-page restyle with CSS + JS changes allowed (v1.4).

</details>

## 🚧 v1.4 Web TMS Restyle (Stripe/Linear)

**Milestone Goal:** Incrementally restyle every page of the Web TMS to a clean, flat, Stripe/Linear aesthetic -- neutral/monochrome palette, dark slate buttons, minimal shadows, professional typography. Light mode only. No behavior changes.

- [x] **Phase 19: Token Foundation & Component Classes** - Swap CSS variables to Stripe/Linear values and build reusable component classes
- [x] **Phase 20: Dashboard Restyle** - Restyle the landing page (KPI strip, main grid, sidebar, analytics)
- [x] **Phase 21: Orders Page Restyle** - Restyle orders page (card view, table view, filters, shared helpers)
- [x] **Phase 22: Trips & Load Board Restyle** - Restyle trips (dual view, density toggle) and load board
- [x] **Phase 23: People & Fleet Restyle** - Restyle drivers, local drivers, trucks, brokers, dispatchers pages
- [ ] **Phase 24: Finance Pages Restyle** - Restyle billing, payroll, financials, trip profitability, fuel, IFTA
- [ ] **Phase 25: Operations & Admin Restyle** - Restyle compliance, maintenance, settings, activity log, tasks, team chat, executive dashboard
- [ ] **Phase 26: Shared Chrome & Quality Verification** - Restyle sidebar, topbar, modals, login page and verify full-app quality

---

### Phase 19: Token Foundation & Component Classes

**Goal**: The CSS token layer and component class library produce the Stripe/Linear aesthetic globally -- neutral surfaces, restrained shadows, tighter radius, medium-weight typography, dark slate buttons, and flat component patterns ready for page sweeps.

**Depends on**: Nothing (first phase of v1.4)

**Requirements**: TOK-01, TOK-02, TOK-03, TOK-04, TOK-05, CMP-01, CMP-02, CMP-03, CMP-04, CMP-05, CMP-06

**Success Criteria** (what must be TRUE):
1. Opening any page in the app shows a neutral slate-gray surface hierarchy instead of the previous warm/zinc tones -- background, cards, and borders all use the Tailwind Slate palette
2. Shadows across the app are barely visible -- near-invisible 1px box-shadows at 3 depth levels (xs/sm/md), no glow or color-tinted shadows anywhere
3. All primary buttons display as dark slate (#0f172a) with white text, secondary buttons are gray/outlined, and no button anywhere has a gradient fill or gradient hover effect
4. Decorative animations (particle rain, shimmer, float, bounce, driveTruck, etc.) are gone -- only spinner, toast slide-in, and skeleton pulse remain
5. A set of reusable component classes exists (flat cards, clean tables, desaturated badges, subtle hover states) that page-level sweeps can adopt in subsequent phases

**Plans**: 3 plans

Plans:
- [x] 19-01-PLAN.md -- Token swap (variables.css) + inline style block neutralization
- [x] 19-02-PLAN.md -- Component class flattening + new component library (base.css)
- [x] 19-03-PLAN.md -- Decorative animation removal + hover effect cleanup (index.html)

---

### Phase 20: Dashboard Restyle

**Goal**: The dashboard landing page matches the Stripe/Linear aesthetic -- clean stat cards, flat surfaces, whitespace-organized sections, no gradients or heavy shadows.

**Depends on**: Phase 19

**Requirements**: DSP-01

**Success Criteria** (what must be TRUE):
1. KPI stat cards use the label-above-number pattern with flat backgrounds and subtle borders -- no icon boxes, no gradient hero cards, no glow effects
2. The attention strip, main content grid, and sidebar all use consistent neutral surfaces with whitespace as the primary section separator
3. Dashboard analytics section (charts, sparklines) displays with clean flat styling consistent with the rest of the page

**Plans**: 2 plans

Plans:
- [x] 20-01-PLAN.md -- CSS classes + dashboard top section restyle (header, attention strip, KPI cards, recent trips, profitability)
- [x] 20-02-PLAN.md -- Dashboard bottom section restyle (sidebar cards, collapsible analytics)

---

### Phase 21: Orders Page Restyle

**Goal**: The orders page -- the most-used page in the app -- displays with clean flat cards, refined tables, and desaturated badges in both card and table view modes.

**Depends on**: Phase 20

**Requirements**: DSP-02

**Success Criteria** (what must be TRUE):
1. Order cards in card view use flat backgrounds with subtle borders -- no gradients, no glow, no heavy shadows -- and status badges use desaturated tint backgrounds
2. Order table view uses hairline borders, refined headers, and subtle row separation -- no heavy zebra striping
3. Filter bar, pagination controls, and order detail modals all follow the Stripe/Linear aesthetic established in Phase 19
4. Shared helpers (renderOrderPreviewCard, renderPaginationControls) are restyled so downstream pages automatically inherit the new look

**Plans**: 2 plans

Plans:
- [x] 21-01-PLAN.md -- Restyle shared helpers (renderOrderPreviewCard, renderPaginationControls) + badge CSS rules
- [x] 21-02-PLAN.md -- Restyle orders page (header, filters, table view, button hierarchy)

---

### Phase 22: Trips & Load Board Restyle

**Goal**: Trips page (both table and card views, density toggle) and Load Board page match the Stripe/Linear aesthetic, completing the full dispatch section restyle.

**Depends on**: Phase 21

**Requirements**: DSP-03, DSP-04

**Success Criteria** (what must be TRUE):
1. Trips table view uses clean hairline borders and refined headers, and trips card view uses flat cards with subtle borders -- consistent across all density settings (compact/default/comfortable)
2. Truck tabs on the trips page display with clean, flat styling -- no gradient backgrounds or heavy active states
3. Load Board page uses flat cards and clean filters matching the orders page treatment

**Plans**: 3 plans

Plans:
- [x] 22-01-PLAN.md -- CSS components: segmented control, trip card, density overrides
- [x] 22-02-PLAN.md -- Trips page restyle (truck tabs, status filter, density toggle, table, mobile cards)
- [x] 22-03-PLAN.md -- Load board page restyle (category tabs, stats, section headers)

---

### Phase 23: People & Fleet Restyle

**Goal**: All people and fleet management pages (drivers, local drivers, trucks, brokers, dispatchers) display with consistent flat card grids, clean tables, and the Stripe/Linear aesthetic.

**Depends on**: Phase 22

**Requirements**: PFL-01, PFL-02, PFL-03, PFL-04, PFL-05

**Success Criteria** (what must be TRUE):
1. Driver and local driver cards use flat backgrounds with subtle borders, compact layout, and desaturated status badges -- no gradient fills or glow effects
2. Trucks page table uses clean hairline borders and refined headers with consistent row styling
3. Broker cards display revenue/profit metrics with flat surfaces and the label-above-number pattern -- no gradient metric cards
4. Dispatchers page uses the same flat card/table treatment as other people pages

**Plans**: 3 plans

Plans:
- [x] 23-01-PLAN.md -- Restyle Drivers page (renderDrivers + viewDriverProfile)
- [x] 23-02-PLAN.md -- Restyle Local Drivers + Trucks pages (renderLocalDrivers + viewLocalDriverDetails + renderTrucks)
- [x] 23-03-PLAN.md -- Restyle Brokers + Dispatchers pages (renderBrokers + viewBrokerDetails + renderDispatchers + renderDispatcherRanking)

---

### Phase 24: Finance Pages Restyle

**Goal**: All finance pages (billing, payroll, financials, trip profitability, fuel, IFTA) display with clean flat surfaces, consistent tab treatments, and refined data tables.

**Depends on**: Phase 23

**Requirements**: FIN-01, FIN-02, FIN-03, FIN-04, FIN-05, FIN-06

**Success Criteria** (what must be TRUE):
1. Billing page aging summary uses flat bars and clean stat cards -- no gradient fills -- and invoice tables use hairline borders
2. Payroll driver cards and period summary use flat surfaces with consistent typography weights
3. Financials, trip profitability, fuel, and IFTA pages all use clean tab treatments, flat stat cards, and refined tables matching the established aesthetic
4. Print preview for billing/payroll renders correctly after restyle changes

**Plans**: TBD

---

### Phase 25: Operations & Admin Restyle

**Goal**: All operations and admin pages (compliance, maintenance, settings, activity log, tasks, team chat, executive dashboard) match the Stripe/Linear aesthetic, achieving full-app page coverage.

**Depends on**: Phase 24

**Requirements**: OPS-01, OPS-02, OPS-03, OPS-04, OPS-05, OPS-06, OPS-07

**Success Criteria** (what must be TRUE):
1. Executive dashboard is fully restyled -- all gradient references replaced with flat surfaces, clean stat cards, and refined charts
2. Compliance and maintenance pages use clean tab treatments and flat card/table layouts
3. Settings, activity log, and tasks pages use consistent flat styling with no visual outliers
4. Team chat uses flat message bubbles and clean input styling -- no gradient or glow effects

**Plans**: TBD

---

### Phase 26: Shared Chrome & Quality Verification

**Goal**: Shared UI chrome (sidebar, topbar, modals, login) is restyled and the entire application passes quality verification -- consistent Stripe/Linear aesthetic, preserved functionality, intact status colors.

**Depends on**: Phase 25

**Requirements**: CHR-01, CHR-02, CHR-03, CHR-04, QUA-01, QUA-02, QUA-03, QUA-04

**Success Criteria** (what must be TRUE):
1. Sidebar has a light background with clean typography, minimal icons, and subtle active states -- no gradient or heavy highlight effects
2. Modals across the app use flat surfaces, consistent padding, and tighter border radius (12px max) -- no gradient headers or glow effects
3. Login page is a clean flat form on a simple background -- no particle rain, mesh background, or decorative animations
4. Status color coding (green/amber/red/blue badges) is intact and readable on every page that uses them
5. All existing functionality works unchanged -- no broken layouts, no missing interactions, no regressions from the restyle

**Plans**: TBD

---

## Progress

**Execution Order:**
Phases execute in numeric order: 19 → 20 → 21 → 22 → 23 → 24 → 25 → 26

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 6. Dashboard Mockup | v1.1 | 2/2 | Complete | 2026-02-10 |
| 7. Core Dispatch Mockup | v1.1 | 4/4 | Complete | 2026-02-10 |
| 8. People & Fleet Mockup | v1.1 | 3/3 | Complete | 2026-02-10 |
| 9. Financial Pages Mockup | v1.1 | 4/4 | Complete | 2026-02-10 |
| 10. Operations & Admin Mockup | v1.1 | 8/8 | Complete | 2026-02-10 |
| 11. Design System Foundation | v1.2 | 6/6 | Abandoned | 2026-02-11 |
| 12. Core Dispatch Pages | v1.2 | 6/6 | Abandoned | 2026-02-11 |
| 13-15. Remaining Pages | v1.2 | 0/0 | Abandoned | 2026-02-11 |
| 16-18. CSS Polish | v1.3 | 0/0 | Abandoned | 2026-03-12 |
| 19. Token Foundation & Component Classes | v1.4 | 3/3 | Complete | 2026-03-12 |
| 20. Dashboard Restyle | v1.4 | 2/2 | Complete | 2026-03-13 |
| 21. Orders Page Restyle | v1.4 | 2/2 | Complete | 2026-03-13 |
| 22. Trips & Load Board Restyle | v1.4 | 3/3 | Complete | 2026-03-13 |
| 23. People & Fleet Restyle | v1.4 | 3/3 | Complete | 2026-03-13 |
| 24. Finance Pages Restyle | v1.4 | 0/TBD | Not started | - |
| 25. Operations & Admin Restyle | v1.4 | 0/TBD | Not started | - |
| 26. Shared Chrome & Quality Verification | v1.4 | 0/TBD | Not started | - |

---

**Roadmap created**: 2026-02-10
**Last updated**: 2026-03-13 (Phase 23 complete: 3/3 plans, verified)
