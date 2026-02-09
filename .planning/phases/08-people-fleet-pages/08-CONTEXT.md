# Phase 8: People & Fleet Pages - Context

**Gathered:** 2026-02-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Mockup the 5 people and fleet management pages — Drivers (with detail), Local Drivers, Trucks (with detail), Brokers, and Dispatchers — using the Phase 6 design system. Each mockup must match the production page's exact sections, data fields, and relationships. UI-only redesign; no functional changes.

</domain>

<decisions>
## Implementation Decisions

### Card Layout & Density
- **Drivers cards: show ALL info** — avatar, name, status badge, driver type, cut%, file count badges (Qual/Pers/Exp), ticket/violation/claim counts, trip count, earnings. Dense but informative, matching production.
- **Brokers cards: show ALL info** — ranking medal, name, load/trip counts, activity status, reliability score bar, 4-stat grid (avg rate, avg fee, profit, revenue), loads/month, total fees, last order date. Keep everything visible.
- **Action buttons stay on cards** — View, Edit, Del buttons visible on every driver/broker card. Match production interaction pattern.

### Detail View Approach
- **Detail views within same HTML file** — drivers.html contains both list view and detail view as separate visible sections. Same for trucks.html. No separate detail files.
- **Realistic sample data mix** — file tables should show a mix of uploaded, missing, and expiring documents to demonstrate all visual states (green=current, amber=expiring, red=expired/missing).

### Local Drivers Layout
- **Current year (2026) realistic data** — summary stats and pending tables should show realistic 2026 numbers with varied pending statuses and amounts.

### Data Presentation Style
- **Brokers: keep ALL computed metrics** — reliability score (0-100) with colored progress bar, ranking medals (gold/silver/bronze), activity status badges (Active/Recent/Inactive/Dormant). These are key differentiators.
- **Dispatchers: keep it minimal** — simple table with Code, Name, Cars Booked, Revenue, Edit/Delete. Match production simplicity, no enhancement.
- **Money values: color-coded** — green for revenue/earnings, red for costs/fees. Monospace font for all financial numbers.

### Claude's Discretion
- **Document expiration alert banner** (Drivers page top) — Claude picks appropriate prominence level
- **Driver detail organization** — Claude decides between single scrollable page vs tabbed sections for the multi-section detail view (stats, qual files, personal files, custom folders, compliance records)
- **Truck detail organization** — Claude decides, may follow same pattern as driver detail or differ based on complexity
- **Local Drivers row coloring** — Claude decides whether to use full-row background tints by status (production approach) or status badges only
- **Local Drivers column density** — Claude decides how to handle 13+ column pending tables (all visible with scroll, or restructured)
- **Local Drivers status legend** — Claude decides whether to include the colored status legend bar above pending tables
- **Broker summary card style** — Claude decides whether to keep gradient backgrounds or use Phase 6 design system stat-card pattern for consistency

</decisions>

<specifics>
## Specific Ideas

- Production Drivers page has a document expiration alerts banner at top showing expiring/expired docs across all drivers — include this in mockup
- Brokers are ranked with medal emojis (gold/silver/bronze for top 3) — keep this gamification element
- Local Drivers has status indicator system with 5 states (Pending=blue, Scheduled=orange, Confirmed=yellow, Ready=green, Issue=red) — preserve this color system
- Truck compliance section tracks 8 specific document types with expiration dates
- Driver compliance tracks 10 qualification file types + 3 personal file types
- Custom folders in both driver and truck detail use accordion-style expandable sections

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 08-people-fleet-pages*
*Context gathered: 2026-02-09*
