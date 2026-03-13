# Requirements: Horizon Star TMS -- v1.4

**Defined:** 2026-03-12
**Core Value:** Dispatchers can efficiently manage the full lifecycle of vehicle transport orders in a single system.

## v1.4 Requirements

Requirements for restyling the entire Web TMS to a Stripe/Linear aesthetic. Page-by-page incremental restyle with CSS + JS render function changes. Light mode only (dark theme deferred).

### Design Tokens

- [ ] **TOK-01**: Color palette switched to Tailwind Slate scale (cool blue-gray neutrals)
- [ ] **TOK-02**: Shadow system reduced to 3 levels (xs/sm/md) with near-invisible values
- [ ] **TOK-03**: Typography weights capped at 600, medium (500) as primary emphasis
- [ ] **TOK-04**: Border radius tightened (cards 8px, inputs 6px, modals 12px max)
- [ ] **TOK-05**: Primary button color changed to dark slate (#0f172a)

### Component Patterns

- [ ] **CMP-01**: All card surfaces use solid flat backgrounds with subtle border -- no gradients, glass, or glow
- [ ] **CMP-02**: Buttons use flat solid fills -- dark slate primary, gray secondary, no gradient hovers
- [ ] **CMP-03**: Tables use subtle borders and refined headers -- no heavy zebra striping
- [ ] **CMP-04**: Status badges use desaturated backgrounds with readable text -- status colors preserved
- [ ] **CMP-05**: All decorative animations removed -- keep only spinner, toast, and skeleton shimmer
- [ ] **CMP-06**: Hover states are subtle (opacity/background shift) -- no scale transforms, no glow

### Page Restyles -- Dispatch

- [ ] **DSP-01**: Dashboard restyled to Stripe/Linear aesthetic
- [ ] **DSP-02**: Orders page restyled
- [ ] **DSP-03**: Trips page restyled
- [ ] **DSP-04**: Load Board restyled

### Page Restyles -- People & Fleet

- [ ] **PFL-01**: Drivers page restyled
- [ ] **PFL-02**: Local Drivers page restyled
- [ ] **PFL-03**: Trucks page restyled
- [ ] **PFL-04**: Brokers page restyled
- [ ] **PFL-05**: Dispatchers page restyled

### Page Restyles -- Finance

- [ ] **FIN-01**: Billing page restyled
- [ ] **FIN-02**: Payroll page restyled
- [ ] **FIN-03**: Financials page restyled
- [ ] **FIN-04**: Trip Profitability page restyled
- [ ] **FIN-05**: Fuel page restyled
- [ ] **FIN-06**: IFTA page restyled

### Page Restyles -- Operations & Admin

- [ ] **OPS-01**: Compliance page restyled
- [ ] **OPS-02**: Maintenance page restyled
- [ ] **OPS-03**: Settings page restyled
- [ ] **OPS-04**: Activity Log page restyled
- [ ] **OPS-05**: Tasks page restyled
- [ ] **OPS-06**: Team Chat restyled
- [ ] **OPS-07**: Executive Dashboard restyled

### Shared Chrome

- [ ] **CHR-01**: Sidebar restyled -- light background, clean typography, minimal icons
- [ ] **CHR-02**: Top header bar restyled
- [ ] **CHR-03**: Modals restyled -- flat surfaces, consistent padding, tighter radius
- [ ] **CHR-04**: Login page restyled -- no particle rain, no mesh background, clean flat form

### Quality Gates

- [ ] **QUA-01**: Status color coding preserved (green/amber/red/blue badges) across all pages
- [ ] **QUA-02**: No broken layouts from restyle changes
- [ ] **QUA-03**: All existing functionality works unchanged
- [ ] **QUA-04**: Professional, muted, Stripe-tier appearance across all pages

## Future Requirements

- Dark theme restyle (v1.5) -- after all pages use CSS variables consistently
- Mobile-responsive layout adjustments (v1.5+)
- Print stylesheet updates to match new design (v1.5+)
- Chrome Extension UI alignment with new design system (v1.5+)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Dark theme | Deferred -- get light mode perfect first |
| New features or functionality | Restyle only -- no behavior changes |
| iOS app changes | Web TMS only for this milestone |
| Layout/structural changes | Keep existing page structure, change visual treatment |
| Applying v1.1 mockup designs | Abandoned approach -- Stripe/Linear aesthetic instead |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TOK-01 | Phase 19 | Pending |
| TOK-02 | Phase 19 | Pending |
| TOK-03 | Phase 19 | Pending |
| TOK-04 | Phase 19 | Pending |
| TOK-05 | Phase 19 | Pending |
| CMP-01 | Phase 19 | Pending |
| CMP-02 | Phase 19 | Pending |
| CMP-03 | Phase 19 | Pending |
| CMP-04 | Phase 19 | Pending |
| CMP-05 | Phase 19 | Pending |
| CMP-06 | Phase 19 | Pending |
| DSP-01 | Phase 20 | Pending |
| DSP-02 | Phase 21 | Pending |
| DSP-03 | Phase 22 | Pending |
| DSP-04 | Phase 22 | Pending |
| PFL-01 | Phase 23 | Pending |
| PFL-02 | Phase 23 | Pending |
| PFL-03 | Phase 23 | Pending |
| PFL-04 | Phase 23 | Pending |
| PFL-05 | Phase 23 | Pending |
| FIN-01 | Phase 24 | Pending |
| FIN-02 | Phase 24 | Pending |
| FIN-03 | Phase 24 | Pending |
| FIN-04 | Phase 24 | Pending |
| FIN-05 | Phase 24 | Pending |
| FIN-06 | Phase 24 | Pending |
| OPS-01 | Phase 25 | Pending |
| OPS-02 | Phase 25 | Pending |
| OPS-03 | Phase 25 | Pending |
| OPS-04 | Phase 25 | Pending |
| OPS-05 | Phase 25 | Pending |
| OPS-06 | Phase 25 | Pending |
| OPS-07 | Phase 25 | Pending |
| CHR-01 | Phase 26 | Pending |
| CHR-02 | Phase 26 | Pending |
| CHR-03 | Phase 26 | Pending |
| CHR-04 | Phase 26 | Pending |
| QUA-01 | Phase 26 | Pending |
| QUA-02 | Phase 26 | Pending |
| QUA-03 | Phase 26 | Pending |
| QUA-04 | Phase 26 | Pending |

**Coverage:**
- v1.4 requirements: 35 total
- Mapped to phases: 35
- Unmapped: 0

---
*Requirements defined: 2026-03-12*
*Last updated: 2026-03-12 -- traceability updated with phase mappings*
