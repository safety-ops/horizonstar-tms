# Requirements: Horizon Star TMS — v1.2

**Defined:** 2026-02-10
**Core Value:** Dispatchers can efficiently manage the full lifecycle of vehicle transport orders in a single system.

## v1.2 Requirements

Requirements for applying the approved v1.1 UI redesign mockups to the production index.html. Visual-only — no layout changes, no behavior changes.

### Design System Foundation

- [x] **DSF-01**: Production design-system.css contains all CSS tokens from shared.css (colors, typography, spacing, shadows, borders)
- [x] **DSF-02**: Dark theme variables applied via `body.dark-theme` class matching mockup dark theme
- [x] **DSF-03**: Light theme variables applied as `:root` default matching mockup light theme
- [x] **DSF-04**: Theme toggle switch functional in production (persists across page refresh)
- [x] **DSF-05**: Bridge aliases map old variable names to new design tokens (backward compat for any unmigrated styles)
- [x] **DSF-06**: All hardcoded hex colors in index.html replaced with CSS variable references

### Global Components

- [x] **GLC-01**: Sidebar styled to match mockup (colors, hover states, active indicator, icons) — production nav order preserved
- [x] **GLC-02**: Top header/toolbar styled to match mockup (search bar, user menu, notifications)
- [x] **GLC-03**: Modal dialogs styled to match mockup (overlay, card, header, footer, close button)
- [x] **GLC-04**: Toast notifications styled to match mockup (success/error/warning/info variants)
- [x] **GLC-05**: Data tables styled to match mockup (header row, striped rows, hover, borders)
- [x] **GLC-06**: Form inputs styled to match mockup (text fields, selects, checkboxes, date pickers)
- [x] **GLC-07**: Buttons styled to match mockup (primary, secondary, danger, ghost variants)
- [x] **GLC-08**: Badges and status pills styled to match mockup (color-coded status indicators)
- [x] **GLC-09**: Cards and panels styled to match mockup (background, border, shadow, padding)
- [x] **GLC-10**: Pagination controls styled to match mockup

### Core Dispatch Pages

- [x] **DSP-01**: Dashboard page visually matches dashboard.html mockup
- [x] **DSP-02**: Load Board page visually matches load-board.html mockup
- [x] **DSP-03**: Trips list page visually matches trips.html mockup
- [x] **DSP-04**: Trip Detail page visually matches trip-detail.html mockup
- [x] **DSP-05**: Orders list page visually matches orders.html mockup
- [x] **DSP-06**: Order Detail page visually matches order-detail.html mockup

### People & Fleet Pages

- [ ] **PPL-01**: Drivers page visually matches drivers.html mockup
- [ ] **PPL-02**: Local Drivers page visually matches local-drivers.html mockup
- [ ] **PPL-03**: Trucks page visually matches trucks.html mockup
- [ ] **PPL-04**: Brokers page visually matches brokers.html mockup
- [ ] **PPL-05**: Dispatchers page visually matches dispatchers.html mockup

### Financial Pages

- [ ] **FIN-01**: Payroll page visually matches payroll.html mockup (including modals)
- [ ] **FIN-02**: Billing page visually matches billing.html mockup (including aging view)
- [ ] **FIN-03**: Financials page visually matches financials.html mockup (all tabs)
- [ ] **FIN-04**: Trip Profitability page visually matches trip-profitability.html mockup

### Operations & Admin Pages

- [ ] **OPS-01**: Fuel page visually matches fuel.html mockup (including analytics tabs)
- [ ] **OPS-02**: IFTA page visually matches ifta.html mockup (including tax tables)
- [ ] **OPS-03**: Compliance page visually matches compliance.html mockup (all sub-tabs)
- [ ] **OPS-04**: Maintenance page visually matches maintenance.html mockup
- [ ] **OPS-05**: Tasks page visually matches tasks.html mockup
- [ ] **OPS-06**: Settings page visually matches settings.html mockup
- [ ] **OPS-07**: Activity Log page visually matches activity-log.html mockup
- [ ] **OPS-08**: Team Chat page visually matches team-chat.html mockup

## Future Requirements

- Mobile-responsive layout adjustments (v1.3+)
- Print stylesheet updates to match new design (v1.3+)
- Chrome Extension UI alignment with new design system (v1.3+)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Layout/structural changes | v1.2 is visual-only — same DOM structure, same page sections |
| New features or functionality | No JS logic changes during redesign |
| Sidebar nav reordering | Production nav order confirmed as-is |
| iOS app changes | Web TMS only for this milestone |
| New pages or sections | Only restyle existing pages |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DSF-01 | Phase 11 | Complete |
| DSF-02 | Phase 11 | Complete |
| DSF-03 | Phase 11 | Complete |
| DSF-04 | Phase 11 | Complete |
| DSF-05 | Phase 11 | Complete |
| DSF-06 | Phase 11 | Complete |
| GLC-01 | Phase 11 | Complete |
| GLC-02 | Phase 11 | Complete |
| GLC-03 | Phase 11 | Complete |
| GLC-04 | Phase 11 | Complete |
| GLC-05 | Phase 11 | Complete |
| GLC-06 | Phase 11 | Complete |
| GLC-07 | Phase 11 | Complete |
| GLC-08 | Phase 11 | Complete |
| GLC-09 | Phase 11 | Complete |
| GLC-10 | Phase 11 | Complete |
| DSP-01 | Phase 12 | Complete |
| DSP-02 | Phase 12 | Complete |
| DSP-03 | Phase 12 | Complete |
| DSP-04 | Phase 12 | Complete |
| DSP-05 | Phase 12 | Complete |
| DSP-06 | Phase 12 | Complete |
| PPL-01 | Phase 13 | Pending |
| PPL-02 | Phase 13 | Pending |
| PPL-03 | Phase 13 | Pending |
| PPL-04 | Phase 13 | Pending |
| PPL-05 | Phase 13 | Pending |
| FIN-01 | Phase 14 | Pending |
| FIN-02 | Phase 14 | Pending |
| FIN-03 | Phase 14 | Pending |
| FIN-04 | Phase 14 | Pending |
| OPS-01 | Phase 15 | Pending |
| OPS-02 | Phase 15 | Pending |
| OPS-03 | Phase 15 | Pending |
| OPS-04 | Phase 15 | Pending |
| OPS-05 | Phase 15 | Pending |
| OPS-06 | Phase 15 | Pending |
| OPS-07 | Phase 15 | Pending |
| OPS-08 | Phase 15 | Pending |

**Coverage:**
- v1.2 requirements: 37 total
- Mapped to phases: 37 (100% coverage)
- Unmapped: 0

**Phase Distribution:**
- Phase 11 (Foundation): 16 requirements (DSF + GLC)
- Phase 12 (Core Dispatch): 6 requirements (DSP)
- Phase 13 (People & Fleet): 5 requirements (PPL)
- Phase 14 (Financial): 4 requirements (FIN)
- Phase 15 (Operations & Admin): 8 requirements (OPS)

---
*Requirements defined: 2026-02-10*
*Last updated: 2026-02-10 — Phase 12 requirements marked Complete (DSP-01 through DSP-06)*
