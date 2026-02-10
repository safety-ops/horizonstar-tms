# Roadmap: v1.1 Web TMS UI Redesign Mockups

**Milestone:** v1.1
**Phases:** 6-10 (continues from v1.0)
**Goal:** Standalone HTML mockups for all major Web TMS pages, iOS v3 design system, light/dark mode

---

## Phase 6: Design System Foundation ✓

**Goal:** Create the shared design system CSS and base layout components (sidebar, header, shared styles) that all page mockups will use.

**Status:** Complete (2026-02-09)

**Requirements:** DS-01, DS-02, DS-03, DS-04, DS-05, DS-06, DS-07

**Plans:** 2/2 complete

Plans:
- [x] 06-01-PLAN.md — Shared CSS (tokens, base, typography, layout) + base template HTML
- [x] 06-02-PLAN.md — UI components (buttons, cards, badges, tables, forms, modals) + component showcase

**Output:** `mockups/web-tms-redesign/shared.css` (1,308 lines) + `base-template.html` (286 lines) + `component-showcase.html` (864 lines)

**Success Criteria:**
1. ✓ CSS file contains all iOS v3 color tokens (dark/light variants)
2. ✓ Light/dark toggle works with smooth CSS transition
3. ✓ Sidebar renders with all navigation items matching current TMS structure
4. ✓ Header bar with avatar, search bar, theme toggle renders correctly
5. ✓ Card, table, stat-card, badge, button, form, and modal components are styled and documented in a component showcase page

---

## Phase 7: Core Dispatch Pages ✓

**Goal:** Mockup the 4 most-used daily pages (Dashboard, Load Board, Trips, Orders) + 2 detail views (Trip Detail, Order Detail) using the Phase 6 design system.

**Status:** Complete (2026-02-09)

**Requirements:** CORE-01, CORE-02, CORE-03, CORE-04, CORE-05, CORE-06

**Depends on:** Phase 6 (shared CSS)

**Plans:** 6/6 complete

Plans:
- [x] 07-01-PLAN.md — Dashboard mockup (all 9 sections in production order)
- [x] 07-02-PLAN.md — Load Board mockup (7 category tabs, vehicle table)
- [x] 07-03-PLAN.md — Trips list mockup (status filters, truck tabs, trip table)
- [x] 07-04-PLAN.md — Trip Detail mockup (financials, vehicle directions, expenses)
- [x] 07-05-PLAN.md — Orders list mockup (filter bar, checkboxes, order table)
- [x] 07-06-PLAN.md — Order Detail mockup (vehicle info, route, payments, timeline)

**Output:**
- `mockups/web-tms-redesign/dashboard.html` (820 lines)
- `mockups/web-tms-redesign/load-board.html`
- `mockups/web-tms-redesign/trips.html`
- `mockups/web-tms-redesign/trip-detail.html`
- `mockups/web-tms-redesign/orders.html`
- `mockups/web-tms-redesign/order-detail.html`

**Success Criteria:**
1. ✓ Dashboard shows all 9 sections in exact production order with realistic data
2. ✓ Load Board shows 7 colored category tabs, subcategory pills, and vehicle table
3. ✓ Trips page shows status filter tabs, truck tabs, and trip table with financials
4. ✓ Trip Detail shows financials card, colored vehicle direction sections, and expenses
5. ✓ Orders page shows filter bar, checkboxes, order table, and pagination
6. ✓ Order Detail shows vehicle info, route, payments, inspection photos, and timeline
7. ✓ All pages use shared.css design system with working light/dark toggle
8. ✓ Layout matches current TMS structure (same sections, same data relationships)

---

## Phase 8: People & Fleet Pages ✓

**Goal:** Mockup Drivers, Local Drivers, Trucks, Brokers, and Dispatchers pages.

**Status:** Complete (2026-02-09)

**Requirements:** PEOPLE-01, PEOPLE-02, PEOPLE-03, PEOPLE-04, PEOPLE-05, PEOPLE-06, PEOPLE-07

**Depends on:** Phase 6 (shared CSS)

**Plans:** 5/5 complete

Plans:
- [x] 08-01-PLAN.md — Drivers list (card grid + doc expiration alerts) + Driver detail (qual files, personal files, custom folders, compliance records)
- [x] 08-02-PLAN.md — Local Drivers list (year selector, stats, pending pickup/delivery with 5-state row colors) + Local Driver detail
- [x] 08-03-PLAN.md — Trucks (Fleet) table (compliance status, ownership badges, trailer support) + Truck detail (compliance files, maintenance records)
- [x] 08-04-PLAN.md — Brokers list (gradient summary cards, ranked broker cards with reliability scores, medals, activity badges)
- [x] 08-05-PLAN.md — Dispatchers table (simple Code/Name/Cars/Revenue/Actions)

**Output:**
- `mockups/web-tms-redesign/drivers.html` (1,242 lines — includes driver detail)
- `mockups/web-tms-redesign/local-drivers.html` (1,055 lines — includes local driver detail)
- `mockups/web-tms-redesign/trucks.html` (850 lines — includes truck detail)
- `mockups/web-tms-redesign/brokers.html` (789 lines)
- `mockups/web-tms-redesign/dispatchers.html` (356 lines)

**Success Criteria:**
1. ✓ Drivers list shows driver cards with status, earnings, file counts, doc expiration alerts banner
2. ✓ Driver detail shows stats, qualification files (10 types), personal files (3 types), custom folders, compliance records
3. ✓ Local Drivers shows year selector, stats, pending pickup/delivery tables with 5-state row background colors
4. ✓ Local Driver detail shows stats, driver info, assigned orders table
5. ✓ Trucks table shows compliance status (OK/Issues), ownership badges, trailer support
6. ✓ Truck detail shows compliance files (8 types), custom folders, maintenance records
7. ✓ Brokers shows gradient summary cards, ranked broker cards with reliability scores, medals, activity badges
8. ✓ Dispatchers shows simple table matching production simplicity
9. ✓ All pages use shared.css with working light/dark toggle

---

## Phase 9: Financial Pages ✓

**Goal:** Mockup Payroll, Billing, Financials, and Trip Profitability pages.

**Status:** Complete (2026-02-09)

**Requirements:** FIN-01, FIN-02, FIN-03, FIN-04

**Depends on:** Phase 6 (shared CSS)

**Plans:** 4/4 complete

Plans:
- [x] 09-01-PLAN.md — Payroll (settlement table, paystub modal, settlement modal)
- [x] 09-02-PLAN.md — Billing/Receivables (3 tabs: Overview, Brokers, Invoices with aging bars)
- [x] 09-03-PLAN.md — Consolidated Financials (8 sub-tabs: Executive, Analysis, Overview, Costs, By Trip/Driver/Broker/Lane)
- [x] 09-04-PLAN.md — Trip Profitability (filters, performers, sortable table, comparison modal)

**Output:**
- `mockups/web-tms-redesign/payroll.html` (1,193 lines — includes both modal variants)
- `mockups/web-tms-redesign/billing.html` (800+ lines — 3 tabs with aging visualization)
- `mockups/web-tms-redesign/financials.html` (1,869 lines — all 8 sub-tabs)
- `mockups/web-tms-redesign/trip-profitability.html` (600+ lines — filters, performers, comparison)

**Success Criteria:**
1. ✓ Payroll shows year selector, driver settlement table, payment actions
2. ✓ Billing shows invoice list with status badges, segmented tabs, totals
3. ✓ Financials shows all 8 tabs with charts and summary cards
4. ✓ Trip Profitability shows sortable table with revenue, margin, RPM metrics
5. ✓ All financial numbers use monospaced formatting
6. ✓ All pages use shared.css with working light/dark toggle

---

## Phase 10: Operations & Admin Pages

**Goal:** Mockup remaining operations and admin pages: Fuel, IFTA, Compliance, Maintenance, Tasks, Settings, Activity Log, Team Chat.

**Requirements:** OPS-01, OPS-02, OPS-03, OPS-04, ADMIN-01, ADMIN-02, ADMIN-03, ADMIN-04

**Depends on:** Phase 6 (shared CSS)

**Plans:** 4 plans

Plans:
- [ ] 10-01-PLAN.md — Fuel Tracking (4 analytics tabs, Samsara integration, drill-down) + IFTA (state mileage, tax calculations)
- [ ] 10-02-PLAN.md — Compliance Hub (7 sub-tabs: Dashboard, Tasks, Driver Files, Truck Files, Company Files, Tickets, Accidents)
- [ ] 10-03-PLAN.md — Maintenance (records table with type badges) + Tasks (stat filters, priority-based task cards)
- [ ] 10-04-PLAN.md — Settings (4 integration cards) + Activity Log (filterable table, detail modal) + Team Chat (messages, @ mentions)

**Output:**
- `mockups/web-tms-redesign/fuel.html`
- `mockups/web-tms-redesign/ifta.html`
- `mockups/web-tms-redesign/compliance.html`
- `mockups/web-tms-redesign/maintenance.html`
- `mockups/web-tms-redesign/tasks.html`
- `mockups/web-tms-redesign/settings.html`
- `mockups/web-tms-redesign/activity-log.html`
- `mockups/web-tms-redesign/team-chat.html`

**Success Criteria:**
1. Fuel tracking shows transaction table with fuel card data
2. IFTA shows state-by-state mileage breakdown
3. Compliance shows driver files with expiration alerts, document upload areas
4. Maintenance shows records table with status tracking
5. Tasks, Settings, Activity Log, Team Chat render with appropriate layouts
6. All pages use shared.css with working light/dark toggle

---

## Phase Summary

| Phase | Name | Requirements | Mockup Files |
|-------|------|-------------|--------------|
| 6 | Design System Foundation ✓ | DS-01 to DS-07 (7) | shared.css + component showcase |
| 7 | Core Dispatch Pages ✓ | CORE-01 to CORE-06 (6) | 6 HTML files |
| 8 | People & Fleet Pages ✓ | PEOPLE-01 to PEOPLE-07 (7) | 5 HTML files |
| 9 | Financial Pages ✓ | FIN-01 to FIN-04 (4) | 4 HTML files |
| 10 | Operations & Admin Pages | OPS + ADMIN (8) | 8 HTML files |

**Total:** 5 phases, 31 requirements, ~22 mockup files

---
*Roadmap created: 2026-02-09*
