# Phase 20: Dashboard Restyle - Context

**Gathered:** 2026-03-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Restyle the dashboard landing page to the Stripe/Linear aesthetic. This covers the KPI stat strip, main content grid, sidebar, and analytics section. No new features or capabilities — purely visual restyle of existing dashboard elements using the token foundation and component classes established in Phase 19.

</domain>

<decisions>
## Implementation Decisions

### KPI stat cards
- 5-6 stat cards (more metric coverage than the minimal 4)
- Layout, sub-labels, and visual accents are Claude's discretion — pick what best fits Stripe/Linear reference
- Label-above-number pattern required (per roadmap success criteria)
- No icon boxes, no gradient hero cards, no glow effects

### Layout & spacing
- Overall layout (3-zone vs full-width) is Claude's discretion — pick what fits the Stripe/Linear aesthetic best
- Section separators (whitespace vs hairlines) are Claude's discretion
- Attention strip treatment (distinct vs merged) is Claude's discretion
- Section headers should include action links (e.g. "View all →") — label left, link right

### Analytics section
- Keep collapsible — user can expand/collapse "Detailed Analytics"
- Chart palette and sparkline placement are Claude's discretion
- Suggested Actions card treatment is Claude's discretion (keep/merge/remove based on layout)
- All chart/sparkline styling must be flat — no gradients, no glow

### Content & states
- Keep greeting header ("Good morning, John" with date)
- Empty dashboard shows onboarding prompt — clean card suggesting first steps ("Add a truck", "Create your first order")
- Sidebar keeps current content (recent activity, quick links, driver status) — just restyle to flat treatment
- Loading state approach (skeleton vs spinner) is Claude's discretion

### Claude's Discretion
- KPI card layout (horizontal strip vs grid)
- Sub-label inclusion per metric
- Visual accents on stat cards (colored borders or fully flat)
- Overall dashboard layout structure
- Section separator style
- Attention strip treatment
- Chart color palette
- Sparkline placement (inline on cards vs analytics section)
- Suggested Actions card fate
- Loading state pattern

</decisions>

<specifics>
## Specific Ideas

- Section headers with "View all →" links — standard Stripe pattern
- Onboarding prompt for empty state, not just zero-value stats
- Analytics section stays collapsible to keep default view clean
- Greeting with user's name stays — personal touch

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 20-dashboard-restyle*
*Context gathered: 2026-03-12*
