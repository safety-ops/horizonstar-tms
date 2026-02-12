# Requirements: Horizon Star TMS — v1.3

**Defined:** 2026-02-11
**Core Value:** Dispatchers can efficiently manage the full lifecycle of vehicle transport orders in a single system.

## v1.3 Requirements

Requirements for stripping visual noise from production and delivering clean, flat, professional styling. CSS-only — no layout changes, no behavior changes.

### Design Token Cleanup

- [ ] **TOK-01**: All gradient CSS variables replaced with solid color equivalents
- [ ] **TOK-02**: Shadow variables simplified to 3 levels (sm, md, lg) with subtle values — no color-tinted shadows, no glow
- [ ] **TOK-03**: Glass/glow/inner-glow variables removed
- [ ] **TOK-04**: Dark theme background glow pseudo-element removed
- [ ] **TOK-05**: Both themes use clean, solid backgrounds — no mesh gradients

### Style Cleanup

- [ ] **STY-01**: All gradient backgrounds replaced with solid colors (buttons, cards, headers, sidebar, chat, login)
- [ ] **STY-02**: All text-shadow glow effects removed
- [ ] **STY-03**: All backdrop-filter/glass effects replaced with solid semi-transparent overlays
- [ ] **STY-04**: Heavy box-shadows (>3px blur) reduced to minimal depth shadows
- [ ] **STY-05**: All decorative animations removed — keep only spinner, toast slide, and functional transitions
- [ ] **STY-06**: Hover scale transforms removed or capped at 1.01x max
- [ ] **STY-07**: Login page cleaned up (no particle rain, no mesh background, no floating glow)

### Quality Gates

- [ ] **QUA-01**: Status color coding preserved (green/amber/red/blue badges and indicators)
- [ ] **QUA-02**: Theme toggle works correctly in both directions
- [ ] **QUA-03**: No broken layouts from removed effects
- [ ] **QUA-04**: Professional, muted appearance across all pages

## Future Requirements

- Mobile-responsive layout adjustments (v1.4+)
- Print stylesheet updates to match new design (v1.4+)
- Chrome Extension UI alignment with new design system (v1.4+)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Layout/structural changes | v1.3 is CSS polish only — same DOM structure |
| New features or functionality | No JS logic changes |
| Applying v1.1 mockup designs | Direction changed — flat polish instead |
| iOS app changes | Web TMS only for this milestone |
| New pages or sections | Only clean existing pages |
| Color scheme changes | Keep existing color palette, just remove gradients/effects |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| TOK-01 | TBD | Pending |
| TOK-02 | TBD | Pending |
| TOK-03 | TBD | Pending |
| TOK-04 | TBD | Pending |
| TOK-05 | TBD | Pending |
| STY-01 | TBD | Pending |
| STY-02 | TBD | Pending |
| STY-03 | TBD | Pending |
| STY-04 | TBD | Pending |
| STY-05 | TBD | Pending |
| STY-06 | TBD | Pending |
| STY-07 | TBD | Pending |
| QUA-01 | TBD | Pending |
| QUA-02 | TBD | Pending |
| QUA-03 | TBD | Pending |
| QUA-04 | TBD | Pending |

**Coverage:**
- v1.3 requirements: 16 total
- Mapped to phases: 0 (pending roadmap)
- Unmapped: 16

---
*Requirements defined: 2026-02-11*
*Last updated: 2026-02-11 — initial definition*
