# Phase 23: People & Fleet Restyle - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Restyle all 5 people and fleet management pages (drivers, local drivers, trucks, brokers, dispatchers) to the Stripe/Linear aesthetic established in Phases 19-22. CSS + JS render function changes. No behavior changes. Light mode only.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion

User granted full discretion across all areas. Follow established v1.4 patterns:

- **Card layouts**: Use flat cards with subtle borders (existing card/card-compact classes), desaturated badges, neutral colors
- **Table layouts**: Use .data-table class with .card-flush wrapper (same as orders/trips tables)
- **Page headers**: 18px/600 weight heading text, no emoji icons, btn-primary for primary action only, btn-secondary for others
- **Stats/metrics**: Use .stat-flat class with .stat-card-label/.stat-card-value, --font-mono on numeric values
- **Badges**: Use getBadge() CSS classes (badge-green/amber/blue/red/gray)
- **Controls**: Use .segmented-control for any tab/toggle patterns, .select/.input for form elements
- **Button hierarchy**: One btn-primary per page (the main create action), everything else btn-secondary/btn-ghost
- **Empty states**: Use renderEmptyState() helper
- **Remove all hardcoded hex colors** from render functions, replace with CSS tokens
- **Font weights**: Cap at 600 (no 700/800)
- **Keep existing page layouts** (cards vs tables) -- don't restructure, just restyle

</decisions>

<specifics>
## Specific Ideas

No specific requirements -- follow the Stripe/Linear patterns proven in Phases 19-22 (dashboard, orders, trips, load board).

</specifics>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope.

</deferred>

---

*Phase: 23-people-fleet-restyle*
*Context gathered: 2026-03-13*
