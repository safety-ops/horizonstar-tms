# Phase 24: Finance Pages Restyle - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Restyle all finance pages (billing, payroll, financials, trip profitability, fuel, IFTA) to match the Stripe/Linear aesthetic. Clean flat surfaces, consistent tab treatments, refined data tables. No behavior changes. Print styles audited and updated to match.

</domain>

<decisions>
## Implementation Decisions

### Stat cards & summaries
- Payroll period summary and driver stat cards use stat-flat pattern matching dashboard density (label above number, font-mono values, tight padding)
- Profitability metrics keep color coding: green for profit, red for loss — using CSS variable badge colors, not hardcoded hex
- Fuel and IFTA stat summaries use same stat-flat pattern as all other pages — consistent label-above-number, font-mono, flat card

### Data table treatment
- Totals/summary rows get bg-tertiary background with top border separator to visually separate from data rows
- Fuel transaction tables and all finance data-tables use alternating row tint (nth-child(even) pattern) — consistent with trucks and other data-table pages
- Trip profitability table keeps profitability-cell pattern from dashboard (green/amber/red background tints on margin cells)

### Tab & filter styling
- Filter bars match orders page pattern: .input/.select component classes with consistent gap spacing, same horizontal layout
- IFTA state-by-state breakdown uses collapsible sections — collapsed by default, expand on click for scannability

### Print preview
- Print output matches the flat Stripe/Linear restyle — clean tables, no gradients, consistent with screen appearance
- Existing company header/logo logic preserved — just ensure clean print rendering
- Color-coded elements (aging buckets, profitability cells, status badges) print in color — no grayscale conversion needed

### Claude's Discretion
- Billing aging bar: keep as visual element or convert to stat cards — whichever better fits established patterns
- Invoice table row actions: inline buttons vs hover reveal — pick based on each table's needs
- Period tabs (billing/payroll): segmented-control vs flat text tabs — pick based on tab count and context
- Finance section headers: 14px/600 vs 16px sizing — pick appropriate sizing per page

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. Follow patterns established in Phases 19-23 (stat-flat, data-table, segmented-control, card-flush, section-header).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 24-finance-pages-restyle*
*Context gathered: 2026-03-13*
