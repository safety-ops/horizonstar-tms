# Roadmap: Horizon Star TMS

## Milestones

- ✅ **v1.0 MVP** - Phases 1-5 (shipped 2024)
- ✅ **v1.1 UI Redesign Mockups** - Phases 6-10 (shipped 2026-02-10)
- ❌ **v1.2 Apply UI Redesign to Production** - Phases 11-15 (abandoned, reverted 2026-02-11)
- 🚧 **v1.3 CSS Polish (Flat & Professional)** - Phases 16-18 (in progress)

## Overview

v1.3 strips all visual noise from the production Web TMS -- gradients, glow effects, heavy shadows, glass effects, and decorative animations -- leaving a clean, flat, professional interface. The work moves through three phases: first cleaning the CSS token layer (variables.css, base.css), then scrubbing the massive index.html of inline effects, and finally verifying that nothing broke and the result looks professional across all pages and themes.

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

## 🚧 v1.3 CSS Polish (Flat & Professional)

**Milestone Goal:** Strip gradients, glow effects, heavy shadows, glass effects, and decorative animations from production. Deliver clean, flat, Stripe-dashboard-tier styling across all pages in both light and dark themes.

- [ ] **Phase 16: Design Token Cleanup** - Replace gradient/glow/glass CSS variables with solid, flat equivalents
- [ ] **Phase 17: Production Style Cleanup** - Strip gradients, heavy shadows, glow effects, decorative animations, and scale transforms from index.html
- [ ] **Phase 18: Quality Verification** - Verify status colors, theme toggle, layout integrity, and professional appearance across all pages

---

### Phase 16: Design Token Cleanup

**Goal**: CSS token layer produces only solid colors, clean shadows, and flat backgrounds -- no gradients, glow, or glass at the variable level.

**Depends on**: Nothing (first phase of v1.3)

**Requirements**: TOK-01, TOK-02, TOK-03, TOK-04, TOK-05

**Success Criteria** (what must be TRUE):
1. Every gradient CSS variable in variables.css resolves to a single solid color value
2. Shadow variables provide exactly 3 depth levels (sm, md, lg) with neutral colors -- no color-tinted shadows, no glow effects
3. Glass, glow, and inner-glow CSS variables are removed from variables.css entirely, and base.css references to them are cleaned up
4. Both light and dark themes render clean solid backgrounds with no radial gradients, mesh backgrounds, or glow pseudo-elements

**Plans:** 1 plan

Plans:
- [ ] 16-01-PLAN.md -- Replace gradients with solid colors, simplify shadows to 3 levels, neutralize glass/glow, remove dark theme glow pseudo-element

---

### Phase 17: Production Style Cleanup

**Goal**: The production index.html contains zero gradient backgrounds, zero glow/glass effects, minimal shadows, no decorative animations, and no scale-transform hover effects.

**Depends on**: Phase 16 (clean tokens must be in place first)

**Requirements**: STY-01, STY-02, STY-03, STY-04, STY-05, STY-06, STY-07

**Success Criteria** (what must be TRUE):
1. Every element that previously used a gradient background (buttons, cards, headers, sidebar, chat bubbles, login page) now shows a solid color -- across both the inline style block and JS render functions
2. No text-shadow glow effects or backdrop-filter/glass effects remain anywhere in index.html -- overlays use solid semi-transparent backgrounds instead
3. All decorative animations are gone (particle rain, shimmer, float, bounce, driveTruck, etc.) while spinner, toast slide-in, and skeleton pulse continue to work
4. Hover states across the application use subtle effects only -- no scale transforms above 1.01x, no glow, no gradient transitions

**Plans**: TBD

Plans: (will be created during planning phase)

---

### Phase 18: Quality Verification

**Goal**: The cleaned-up production TMS is visually correct, functionally intact, and professionally polished across every page and both themes.

**Depends on**: Phase 17 (all cleanup work complete)

**Requirements**: QUA-01, QUA-02, QUA-03, QUA-04

**Success Criteria** (what must be TRUE):
1. Status color coding is intact -- green, amber, red, and blue badges and indicators display correctly on every page that uses them (orders, trips, drivers, trucks, load board)
2. Theme toggle switches cleanly between light and dark modes with no visual artifacts, missing colors, or leftover gradient references -- and preference persists across refresh
3. No page has broken layout caused by removed effects -- all cards, tables, modals, forms, and navigation render with correct spacing and alignment
4. The overall visual impression across all pages is clean, muted, and professional -- consistent with flat dashboard aesthetics (no lingering glow, shimmer, or heavy shadow anywhere)

**Plans**: TBD

Plans: (will be created during planning phase)

---

## Progress

**Execution Order:**
Phases execute in numeric order: 16 → 17 → 18

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
| 16. Design Token Cleanup | v1.3 | 0/1 | Planned | - |
| 17. Production Style Cleanup | v1.3 | 0/TBD | Not started | - |
| 18. Quality Verification | v1.3 | 0/TBD | Not started | - |

---

**Roadmap created**: 2026-02-10
**Last updated**: 2026-02-11 (v1.3 roadmap added, v1.2 marked abandoned)
