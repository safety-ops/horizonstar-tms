# Roadmap: v1.1 Web TMS UI Redesign Mockups

**Milestone:** v1.1
**Phases:** 6-10 (continues from v1.0)
**Goal:** Standalone HTML mockups for all major Web TMS pages, iOS v3 design system, light/dark mode

---

## Phase 6: Design System Foundation

**Goal:** Create the shared design system CSS and base layout components (sidebar, header, shared styles) that all page mockups will use.

**Requirements:** DS-01, DS-02, DS-03, DS-04, DS-05, DS-06, DS-07

**Plans:** 2 plans

Plans:
- [ ] 06-01-PLAN.md — Shared CSS (tokens, base, typography, layout) + base template HTML
- [ ] 06-02-PLAN.md — UI components (buttons, cards, badges, tables, forms, modals) + component showcase

**Output:** `mockups/web-tms-redesign/shared.css` + a base template HTML file + component showcase

**Success Criteria:**
1. CSS file contains all iOS v3 color tokens (dark/light variants)
2. Light/dark toggle works with smooth CSS transition
3. Sidebar renders with all navigation items matching current TMS structure
4. Header bar with avatar, search bar, theme toggle renders correctly
5. Card, table, stat-card, badge, button, form, and modal components are styled and documented in a component showcase page

---

## Phase 7: Core Dispatch Pages

**Goal:** Mockup the 4 most-used daily pages: Dashboard, Load Board, Trips, and Orders.

**Requirements:** CORE-01, CORE-02, CORE-03, CORE-04, CORE-05, CORE-06

**Depends on:** Phase 6 (shared CSS)

**Output:**
- `mockups/web-tms-redesign/dashboard.html`
- `mockups/web-tms-redesign/loadboard.html`
- `mockups/web-tms-redesign/trips.html` (includes trip detail view)
- `mockups/web-tms-redesign/orders.html` (includes edit modal)

**Success Criteria:**
1. Dashboard shows stat cards, revenue chart, recent activity, and quick stats
2. Load Board shows category tabs, order cards with vehicle info, and assign modal
3. Trips page shows status filter tabs, trip table/cards, and trip detail with financials
4. Orders page shows search/filter bar, order table, and edit modal overlay
5. All pages use shared.css design system with working light/dark toggle
6. Layout matches current TMS structure (same sections, same data relationships)

---

## Phase 8: People & Fleet Pages

**Goal:** Mockup Drivers, Local Drivers, Trucks, Brokers, and Dispatchers pages.

**Requirements:** PEOPLE-01, PEOPLE-02, PEOPLE-03, PEOPLE-04, PEOPLE-05, PEOPLE-06, PEOPLE-07

**Depends on:** Phase 6 (shared CSS)

**Output:**
- `mockups/web-tms-redesign/drivers.html` (includes driver detail)
- `mockups/web-tms-redesign/local-drivers.html` (includes driver detail)
- `mockups/web-tms-redesign/trucks.html`
- `mockups/web-tms-redesign/brokers.html`
- `mockups/web-tms-redesign/dispatchers.html` (includes ranking)

**Success Criteria:**
1. Drivers list shows driver cards with status, earnings, file counts
2. Driver detail shows trip history, document files, earnings summary
3. Local Drivers shows pending delivery/pickup sections, driver stats, assigned orders
4. Local Driver detail shows order table with status, fees, actions
5. Trucks, Brokers, Dispatchers pages render with appropriate card/table layouts
6. All pages use shared.css with working light/dark toggle

---

## Phase 9: Financial Pages

**Goal:** Mockup Payroll, Billing, Financials, and Trip Profitability pages.

**Requirements:** FIN-01, FIN-02, FIN-03, FIN-04

**Depends on:** Phase 6 (shared CSS)

**Output:**
- `mockups/web-tms-redesign/payroll.html`
- `mockups/web-tms-redesign/billing.html`
- `mockups/web-tms-redesign/financials.html`
- `mockups/web-tms-redesign/trip-profitability.html`

**Success Criteria:**
1. Payroll shows period selector, driver settlement table, payment actions
2. Billing shows invoice list with status badges, segmented tabs, totals
3. Financials shows overview/costs/trips tabs with charts and summary cards
4. Trip Profitability shows sortable table with revenue, margin, RPM metrics
5. All financial numbers use monospaced formatting
6. All pages use shared.css with working light/dark toggle

---

## Phase 10: Operations & Admin Pages

**Goal:** Mockup remaining operations and admin pages: Fuel, IFTA, Compliance, Maintenance, Tasks, Settings, Activity Log, Team Chat.

**Requirements:** OPS-01, OPS-02, OPS-03, OPS-04, ADMIN-01, ADMIN-02, ADMIN-03, ADMIN-04

**Depends on:** Phase 6 (shared CSS)

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
| 6 | Design System Foundation | DS-01 to DS-07 (7) | shared.css + component showcase |
| 7 | Core Dispatch Pages | CORE-01 to CORE-06 (6) | 4 HTML files |
| 8 | People & Fleet Pages | PEOPLE-01 to PEOPLE-07 (7) | 5 HTML files |
| 9 | Financial Pages | FIN-01 to FIN-04 (4) | 4 HTML files |
| 10 | Operations & Admin Pages | OPS + ADMIN (8) | 8 HTML files |

**Total:** 5 phases, 31 requirements, ~22 mockup files

---
*Roadmap created: 2026-02-09*
