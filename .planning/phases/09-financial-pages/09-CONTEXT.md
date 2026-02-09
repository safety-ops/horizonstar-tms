# Phase 9: Financial Pages - Context

**Gathered:** 2026-02-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Mockup 4 financial pages — Payroll, Billing (Receivables), Financials (Financial Analysis), and Trip Profitability — using the Phase 6 design system. Each mockup must match the exact production page structure (same sections, same tabs, same data relationships) with realistic sample data. This is visual/CSS design only — no changes to production logic or behavior.

</domain>

<decisions>
## Implementation Decisions

### Number Presentation
- Green for positive money values, red for negative — classic financial convention
- Negative amounts use accounting parentheses format: ($1,234.56) not -$1,234.56
- Percentages (margins, rates) get 3-tier color-coded thresholds: green (healthy), amber (warning zone), red (concern) — matching production behavior
- Claude's discretion on monospace font usage — pick the right balance per context (tables vs hero cards vs summary text)

### Summary Cards & KPIs
- Stat cards use colored-dot indicator style (small colored circle next to label) — consistent across all 4 financial pages
- Cards are clickable/interactive where production has filtering behavior (e.g., click "Overdue" filters to overdue invoices)
- Keep formula/explanation callout boxes where they exist in production (e.g., Payroll's Net Pay formula)
- Claude's discretion on hero banner vs card grid treatment per page

### Table-Heavy Layouts
- Financials page: all 8 sub-tabs (Executive, Analysis, Overview, Costs, By Trip, By Driver, By Broker, By Lane) with full content and realistic data
- Payroll page: include both paystub modal (company driver) and settlement modal (owner-operator) with deductions, bonuses, print/email actions
- All tabbed pages use segmented pill-style tab bar (matching Billing production style) — even Financials with 8 tabs
- Claude's discretion on sticky headers/columns behavior per table

### Aging & Profitability Visuals
- Billing aging bar keeps 5-color gradient: Green (Current) → Yellow (1-30) → Orange (31-60) → Red (61-90) → Dark Red (90+)
- Car volume bar charts (weekly/monthly/quarterly/yearly) included with realistic sample data — not placeholders
- Alert/action banners included (e.g., "Needs Invoice", overdue warnings) — these are important UX elements that drive user action
- Claude's discretion on profit/loss indicator prominence (status pills, colored borders, row tinting)

### Claude's Discretion
- Monospace font application (everywhere vs tables-only vs contextual)
- Hero banner treatment on Financials page vs uniform card grid
- Sticky header/column behavior per table based on column count
- Profit/loss visual prominence (bold vs subtle) per page context
- Table scroll behavior and max-height decisions

</decisions>

<specifics>
## Specific Ideas

- Production Financials page has a dark gradient "Financial Health Dashboard" hero with PROFITABLE/NEEDS ATTENTION status pill — evaluate whether this fits the redesigned design system
- Billing uses mini aging bar charts per broker row — maintain this pattern in the redesign
- Trip Profitability has a trip comparison feature (select up to 3 trips) — include this in the mockup
- Payroll distinguishes company drivers (paystub) from owner-operators (settlement) with different modal flows — both must be mocked up
- Production Billing has segmented tab bar styling that already uses CSS variables — good candidate for consistent tab component

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 09-financial-pages*
*Context gathered: 2026-02-09*
