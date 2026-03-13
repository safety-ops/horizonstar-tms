# Phase 25: Operations & Admin Restyle - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Restyle all operations and admin pages (compliance, maintenance, settings, activity log, tasks, team chat, executive dashboard) to match the Stripe/Linear aesthetic. No behavior changes. Uses established component library from Phases 19-24.

</domain>

<decisions>
## Implementation Decisions

### Executive Dashboard
- KPI cards use stat-flat + stat-card--{color} accent border pattern — same as billing/payroll/financials, no larger or special treatment
- Charts sit in card-flush wrappers — no special chart containers
- Section separation via whitespace + section-header pattern (14px/600 text) — matches Phase 20 dashboard approach
- Rankings/leaderboard tables use data-table class with alternating row tint
- All gradient references replaced with flat surfaces

### Team Chat Styling
- Message bubbles keep distinct bubble shapes but flatten colors — remove gradients, use CSS variable backgrounds (bg-tertiary for sent, bg-card for received)
- Chat input area gets chat-specific styling — rounded pill input with integrated send button, messaging-app feel (not standard .input class)
- Presence indicators (online/away/offline dots) keep colored dots — just ensure they use CSS variables instead of hardcoded hex
- No glow effects on any chat elements

### Compliance & Maintenance
- Expiration warnings use accent border + badge pattern — left border accent (amber for warning, red for expired) on row/card + badge-amber/badge-red status badge
- Tab treatment: Claude's discretion on segmented-control vs segmented-control-scroll based on tab count per page
- Record display (work orders, maintenance records): Claude's discretion on data-table vs cards based on content density
- Document/file lists match driver profile pattern from Phase 23: card-flush + flat header (14px/600) + data-table

### Settings & Admin Pages (not discussed — follow established patterns)
- Settings forms: standard .input/.select component classes
- Activity log: data-table with alternating row tint
- Tasks page: flat card or data-table treatment matching established patterns
- Apply same Stripe/Linear aesthetic — no gradients, no glow, CSS variables throughout

### Claude's Discretion
- Chat entity link card treatment (inline vs current size) — pick what fits message flow best
- Compliance/maintenance tab component choice (segmented-control vs segmented-control-scroll) — based on tab count
- Maintenance records layout (data-table vs cards) — based on content density per record
- Settings, activity log, tasks page specifics — follow established patterns, no discussion needed

</decisions>

<specifics>
## Specific Ideas

- Executive dashboard should feel exactly like the main dashboard (Phase 20) — no elevated treatment just because it's "executive"
- Chat bubbles should feel more like Slack than iMessage — flat, clean, but still distinct shapes
- Compliance warnings should be immediately scannable — the accent border + badge combo makes urgency visible at a glance

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 25-operations-admin-restyle*
*Context gathered: 2026-03-13*
