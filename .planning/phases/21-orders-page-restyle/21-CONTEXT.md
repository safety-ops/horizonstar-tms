# Phase 21: Orders Page Restyle - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Restyle the orders page (card view, table view, filters, pagination, shared helpers) to match the Stripe/Linear aesthetic established in Phases 19-20. Both `renderOrderPreviewCard` and `renderPaginationControls` are shared helpers used across ~8 pages — restyling them here propagates automatically to downstream pages. No behavior changes, no new capabilities.

</domain>

<decisions>
## Implementation Decisions

### Order card treatment
- Scale order number down to ~14-16px — compact, data-dense feel like Stripe invoice rows instead of current 30px headline
- Revenue amount stays top-right of each card — easy to scan dollar amounts down the list
- Keep colored action buttons (dim-blue Assign, dim-amber Note, red Del) — functional color coding is valuable for dispatchers
- 4-row layout (header → vehicle → route → broker) retained but tightened

### Table view refinement
- Action buttons in table use same colored treatment as cards (dim-blue Assign, red Del) — consistent across views
- Table wraps remain in card container

### Filter bar & controls
- AI Import button changes from purple (#8b5cf6) to btn-secondary — only '+ New Order' gets btn-primary (dark slate)
- Export stays btn-secondary
- All header action buttons follow neutral hierarchy: primary for creation, secondary for everything else

### Status badges & chips
- (No specific user decisions — see Claude's Discretion below)

### Claude's Discretion
- Card surface treatment (border-left accent vs hairline border, background color)
- Table row separation (zebra striping vs bottom borders vs subtle alternating tint)
- Table header styling (uppercase small labels vs standard flat headers)
- Table card padding (edge-to-edge vs small inset)
- Filter bar label style (label-above vs inline, weight and color)
- View toggle active state (subtle gray vs dark slate fill)
- Pagination container style (simple inline vs flattened card)
- Status badge desaturation level (subtle pastel vs medium tint)
- Year/undated info chip styling
- Dispatcher notes indicator color treatment
- Badge sizing (font size and padding)

</decisions>

<specifics>
## Specific Ideas

- Order cards should feel like Stripe invoice rows — compact, data-dense, scannable
- The preview mockup selected shows a tight 4-row card with inline metadata, no large headline
- Revenue dollar amounts need to be easy to scan vertically down a list of cards

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 21-orders-page-restyle*
*Context gathered: 2026-03-13*
