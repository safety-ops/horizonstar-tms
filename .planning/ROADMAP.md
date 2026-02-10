# Roadmap: Horizon Star TMS

## Milestones

- ✅ **v1.0 MVP** - Phases 1-5 (shipped 2024)
- ✅ **v1.1 UI Redesign Mockups** - Phases 6-10 (shipped 2026-02-10)
- 🚧 **v1.2 Apply UI Redesign to Production** - Phases 11-15 (in progress)

## Overview

v1.2 applies the approved v1.1 mockup designs to the production index.html. This is a visual-only transformation — no layout changes, no behavior changes, no JS logic changes. The milestone delivers a refreshed, modern UI across all 25+ pages while preserving the exact same functionality, DOM structure, and sidebar navigation order that dispatchers rely on daily.

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

## 🚧 v1.2 Apply UI Redesign to Production (In Progress)

**Milestone Goal**: Apply the approved v1.1 mockup designs to production index.html — purely visual changes, preserving all existing functionality and structure.

### Phase 11: Design System Foundation + Global Components

**Goal**: Production CSS contains the complete design system and all global components match mockup styling.

**Depends on**: Phase 10 (mockups complete)

**Requirements**: DSF-01, DSF-02, DSF-03, DSF-04, DSF-05, DSF-06, GLC-01, GLC-02, GLC-03, GLC-04, GLC-05, GLC-06, GLC-07, GLC-08, GLC-09, GLC-10

**Success Criteria** (what must be TRUE):
1. design-system.css contains all CSS tokens from mockup shared.css (colors, typography, spacing, shadows, borders, transitions)
2. Theme toggle switches between light and dark themes with all colors updating correctly and preference persisting across refresh
3. All hardcoded hex colors in index.html are replaced with CSS variable references
4. Sidebar navigation matches mockup styling with correct colors, hover states, active indicators, and icons while preserving production nav order
5. All global components (header, modals, toasts, tables, forms, buttons, badges, cards, pagination) visually match their mockup counterparts across both themes

**Plans:** 6 plans (5 original + 1 gap closure)

Plans:
- [x] 11-01-PLAN.md — Verify + complete all component styles in design-system.css
- [x] 11-02-PLAN.md — Replace hex colors in style block (lines 35-8049)
- [x] 11-03-PLAN.md — Replace hex colors in JS render functions (lines 8050-22000)
- [x] 11-04-PLAN.md — Replace hex colors in JS render functions (lines 22001-38085)
- [x] 11-05-PLAN.md — Final audit + visual verification checkpoint
- [x] 11-06-PLAN.md — Gap closure: remaining hex colors + nav class mismatch fix

---

### Phase 12: Core Dispatch Pages

**Goal**: Dashboard, Load Board, Trips, and Orders pages visually match their mockup designs.

**Depends on**: Phase 11

**Requirements**: DSP-01, DSP-02, DSP-03, DSP-04, DSP-05, DSP-06

**Success Criteria** (what must be TRUE):
1. Dashboard page displays metrics, recent activity, and quick actions with mockup styling (hero cards, stat grids, action tiles)
2. Load Board page shows available loads with mockup card layout, filters, and status indicators
3. Trips list and detail pages match mockup table styling, status badges, timeline views, and action buttons
4. Orders list and detail pages match mockup layout with vehicle cards, payment tracking, file attachments, and activity timelines

**Plans:** 6 plans

Plans:
- [ ] 12-01-PLAN.md -- Add sticky-col, summary-row, metric-cell, section-title CSS classes to design-system.css
- [ ] 12-02-PLAN.md -- Restyle Dashboard page (stat cards, section headers, metrics, Quick View)
- [ ] 12-03-PLAN.md -- Restyle Load Board + Trips list pages (tabs, filters, tables)
- [ ] 12-04-PLAN.md -- Restyle Trip Detail page (stat cards, pricing widget, vehicle tables)
- [ ] 12-05-PLAN.md -- Restyle Orders list page (filter bar, search, table)
- [ ] 12-06-PLAN.md -- Restyle Order Detail page + inspection photo 4-image grid

---

### Phase 13: People & Fleet Pages

**Goal**: Drivers, Trucks, Brokers, and Dispatchers pages visually match their mockup designs.

**Depends on**: Phase 11

**Requirements**: PPL-01, PPL-02, PPL-03, PPL-04, PPL-05

**Success Criteria** (what must be TRUE):
1. Drivers page displays driver cards/table with mockup styling, status indicators, and contact information layout
2. Local Drivers page matches mockup design for local driver tracking and assignment views
3. Trucks page shows fleet inventory with mockup card/table styling, status badges, and vehicle details layout
4. Brokers and Dispatchers pages match mockup table styling, contact cards, and action buttons

**Plans**: TBD

Plans: (will be created during planning phase)

---

### Phase 14: Financial Pages

**Goal**: Payroll, Billing, Financials, and Trip Profitability pages visually match their mockup designs.

**Depends on**: Phase 11

**Requirements**: FIN-01, FIN-02, FIN-03, FIN-04

**Success Criteria** (what must be TRUE):
1. Payroll page displays driver earnings with mockup table styling, summary cards, and payroll modals matching mockup design
2. Billing page shows customer invoices with mockup aging view, payment tracking tables, and status indicators
3. Financials page displays all financial tabs (revenue, expenses, cash flow) with mockup chart styling, summary cards, and data tables
4. Trip Profitability page shows trip-level P&L analysis with mockup layout, calculation breakdowns, and comparison views

**Plans**: TBD

Plans: (will be created during planning phase)

---

### Phase 15: Operations & Admin Pages

**Goal**: Fuel, IFTA, Compliance, Maintenance, Tasks, Settings, Activity Log, and Team Chat pages visually match their mockup designs.

**Depends on**: Phase 11

**Requirements**: OPS-01, OPS-02, OPS-03, OPS-04, OPS-05, OPS-06, OPS-07, OPS-08

**Success Criteria** (what must be TRUE):
1. Fuel page displays transaction history and analytics tabs with mockup styling, chart layouts, and MPG tracking views
2. IFTA page shows quarterly reports with mockup table styling, tax calculation displays, and export functionality layout
3. Compliance page displays all sub-tabs (claims, tickets, violations) with mockup card/table styling and status tracking
4. Maintenance page shows vehicle service records with mockup timeline views, due date indicators, and work order cards
5. Tasks, Settings, Activity Log, and Team Chat pages match mockup layouts with appropriate card styling, form layouts, and interaction patterns

**Plans**: TBD

Plans: (will be created during planning phase)

---

## Progress

**Execution Order:**
Phases execute in numeric order: 11 → 12 → 13 → 14 → 15

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 6. Dashboard Mockup | v1.1 | 2/2 | Complete | 2026-02-10 |
| 7. Core Dispatch Mockup | v1.1 | 4/4 | Complete | 2026-02-10 |
| 8. People & Fleet Mockup | v1.1 | 3/3 | Complete | 2026-02-10 |
| 9. Financial Pages Mockup | v1.1 | 4/4 | Complete | 2026-02-10 |
| 10. Operations & Admin Mockup | v1.1 | 8/8 | Complete | 2026-02-10 |
| 11. Design System Foundation | v1.2 | 6/6 | Complete | 2026-02-10 |
| 12. Core Dispatch Pages | v1.2 | 0/6 | Not started | - |
| 13. People & Fleet Pages | v1.2 | 0/TBD | Not started | - |
| 14. Financial Pages | v1.2 | 0/TBD | Not started | - |
| 15. Operations & Admin Pages | v1.2 | 0/TBD | Not started | - |

---

**Roadmap created**: 2026-02-10
**Last updated**: 2026-02-10 (Phase 11 complete)
