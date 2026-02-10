# Phase 12: Core Dispatch Pages - Context

**Gathered:** 2026-02-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Apply approved v1.1 mockup styling to the 4 core dispatch pages: Dashboard, Load Board, Trips (list + detail), and Orders (list + detail). Purely visual transformation — restyle existing production elements with design system CSS. No JS logic changes, no behavior changes, no new DOM elements beyond what production already renders.

</domain>

<decisions>
## Implementation Decisions

### Page Rollout Strategy
- Claude decides plan split based on complexity and dependencies (user deferred to Claude's discretion)
- Pixel-perfect to mockup: every card, grid, spacing detail matches the mockup HTML exactly as designed
- Only style what production already renders — skip any mockup elements that don't exist in current render functions (no sparklines, no Top Performers cards, etc. unless production has them)
- Verification approach at Claude's discretion

### Dashboard Layout
- Restyle existing stat cards with mockup CSS classes — don't restructure into mockup's grid layout
- Apply mockup color coding to financial metrics: green=revenue, red=expenses, blue=profit
- Only style existing container elements — don't add new card wrappers where production doesn't have them
- Skip missing elements consistently — if production doesn't render it, don't add it (even for dashboard landing page)

### Table & Filter Styling
- Apply sticky right-side action columns to tables (position:sticky for Actions column)
- Restyle existing filter structures with design system tokens — don't restructure filters to match each mockup's specific pattern (keep production's current filter DOM)
- Match mockup's info bar styling for summary rows (elevated background, color-coded metrics) where production already renders summary stats
- Status badges use mockup's specific color scheme (green=active, amber=pending, blue=completed, etc.)
- Payment type badges use mockup colors (distinct colors for COD, COP, Bill, etc.)

### Detail Page Patterns
- Financial breakdowns: restyle existing layout with design system colors and tokens — don't restructure into mockup's multi-cell grid
- Route display: restyle existing route/direction layout — don't add A/B markers, colored bars, or arrow icons unless production already has them
- Timeline: restyle existing timeline with design system colors — don't restructure into mockup's dot-and-line pattern
- Inspection photos: match mockup's 4-image grid layout with pickup/delivery sections (exception to the general "restyle existing" pattern — user specifically wants mockup photo grid)

### Claude's Discretion
- Plan split strategy (how many plans, which pages grouped together)
- Verification approach for each page
- Specific CSS implementation details
- How to handle edge cases where production structure partially matches mockup

</decisions>

<specifics>
## Specific Ideas

- Phase 11 already established design-system.css with all tokens, component styles, and bridge aliases — build on this foundation
- Color coding is consistent across all pages: green=revenue/positive, red=expenses/negative, blue=profit/neutral
- Mockup badge colors are the authority for status and payment type badges
- Production sidebar nav order is preserved (decided in Phase 11)
- Sticky action columns improve usability on wide tables — apply consistently

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-core-dispatch-pages*
*Context gathered: 2026-02-10*
