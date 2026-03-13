# Phase 22: Trips & Load Board Restyle - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Restyle the trips page (table view, card view, density toggle, truck tabs) and load board page to match the Stripe/Linear aesthetic established in Phases 19-21. No behavior changes — purely visual restyling of existing elements.

</domain>

<decisions>
## Implementation Decisions

### Truck tabs styling
- Use segmented control pattern (all tabs inside a shared container with background highlight on active)
- Show truck number only — no trip counts or other metadata on tabs
- Claude's discretion on active tab indicator style (dark slate fill vs white card lift)
- Claude's discretion on overflow handling (horizontal scroll vs wrap)

### Density toggle treatment
- Use the same segmented control style as truck tabs — consistent UI pattern
- Claude's discretion on positioning relative to truck tabs
- Claude's discretion on label text (current Compact/Default/Comfy or shorter alternatives)

### Trip cards (card view)
- Different layout from order cards — trips have different data (truck, driver, multiple stops) so need their own card structure
- Status displayed as desaturated badge in header row (top-right), same badge system as order cards
- Key info on card: trip number + truck, driver name
- Show order count only (e.g., "4 orders" badge), not individual order numbers
- Flat card with subtle border, no gradients or glow — consistent with Phase 19 component library

### Load board cards
- Reuse the same renderOrderPreviewCard component from Phase 21 — already restyled, maintains consistency
- Keep existing filtering/sorting controls, just restyle them to match the aesthetic
- Show count per category in each category header (not a global total)
- Claude's discretion on category grouping style (section headers, collapsible sections, or columns)

### Claude's Discretion
- Truck tab active indicator style (dark slate or white card lift)
- Truck tab overflow behavior (scroll or wrap)
- Density toggle position relative to truck tabs
- Density toggle label text
- Load board category grouping visual pattern
- Trip card internal layout structure (adapting trip data into flat card format)
- Table view styling (follow established data-table patterns from Phase 21)

</decisions>

<specifics>
## Specific Ideas

- Segmented control should feel like a native OS control — contained, clean, unified
- Trip cards need their own structure because trip data differs from order data (truck, driver, stops vs vehicle, route, broker)
- Load board should feel like a "staging area" — unassigned orders waiting for assignment

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 22-trips-load-board-restyle*
*Context gathered: 2026-03-13*
