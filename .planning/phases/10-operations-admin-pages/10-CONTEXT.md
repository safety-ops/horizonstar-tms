# Phase 10: Operations & Admin Pages - Context

**Gathered:** 2026-02-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Mockup the 8 remaining pages — Fuel, IFTA, Compliance, Maintenance, Tasks, Settings, Activity Log, Team Chat — using the Phase 6 design system. All pages get standalone HTML files in `mockups/web-tms-redesign/`. Structure and data relationships must match production exactly (UI-only redesign constraint).

</domain>

<decisions>
## Implementation Decisions

### Page grouping & plan batching
- **4 plans**, executed sequentially 1→4:
  - **Plan 1:** Fuel (`fuel.html`) + IFTA (`ifta.html`) — related fuel data pages, separate files
  - **Plan 2:** Compliance (`compliance.html`) — complex 7-tab hub, gets its own plan, single HTML file with tab switching
  - **Plan 3:** Maintenance (`maintenance.html`) + Tasks (`tasks.html`) — simpler table-based pages
  - **Plan 4:** Settings (`settings.html`) + Activity Log (`activity-log.html`) + Team Chat (`team-chat.html`) — admin/utility pages

### Fuel page depth
- All 4 analytics tabs fully populated with realistic mock data: Overview, Analytics, Efficiency, Price Analysis
- Show Samsara mileage status card in "data uploaded" state (blue banner with truck count + total miles)
- Include truck drill-down view (per-truck filtered state with "Back to All Trucks" button)
- Show filter row with truck/state/product/driver dropdowns
- Stat cards: Total Diesel, Diesel Cost, Avg $/Gallon, Total Savings, Total DEF, Total Cost
- Efficiency metrics: Miles Traveled (Samsara source), MPG, Cost Per Mile, Fill-Ups, Avg Gal/Fill-Up, Avg Discount/Gal

### IFTA page depth
- Full data state with uploaded mileage — show IFTA calculation table populated with ~10 states
- Fuel-by-state table with gallons purchased
- Auto-calculated MPG info box (blue banner)
- Summary stats: Total Miles, Fleet MPG, Taxable Gallons, Fuel Purchased, Tax Owed, Tax Credit, Net Tax Due
- Quarter/Year selector and Fleet MPG input

### Compliance hub
- Single `compliance.html` with all 7 sub-tabs, tab switching via JS
- All 7 sub-tabs fully detailed with realistic mock data:
  1. **Dashboard:** Hero card with design system gradient (not hardcoded blue), 3 big stats (Open Tickets, Open Claims, Days Without Accidents), 6 upcoming-item cards (Driver Tasks, Birthdays, Vehicle Tasks, Company Files, Court Dates, Compliance Tasks)
  2. **Compliance Tasks:** IFTA due date banner, pre-populated table with ~10-15 default tasks (BOC-3, UCR, IFTA filings, IRP Renewal, etc.) with realistic statuses (some overdue, some done, some upcoming)
  3. **Driver Files:** Driver list view AND selected-driver detail view with 10 file types, upload areas, expiration dates
  4. **Truck Files:** Truck list view AND selected-truck detail view with 8 file types, expiration tracking
  5. **Company Files:** Company documents with categories and expiration tracking
  6. **Tickets/Violations:** Ticket records with court dates, statuses, fines, driver association
  7. **Accident Registry:** Accident records with details, dates, involved parties

### Maintenance page
- Match production structure exactly with design system styling
- Truck filter dropdown, sort (newest/oldest), clear filters button
- Stat cards: Total Records, Filtered Records, Total Spent
- Maintenance records table: Truck, Date, Type (badge), Shop, Description, Cost, Actions

### Tasks page
- Match production structure: stat cards (Pending, Due Today, Overdue, Urgent) as clickable filters
- Filter tabs: All Pending, Today, Upcoming, Overdue, Completed
- Task cards with checkbox, title, priority badge, status badge, due date, assignee
- Overdue tasks with red left border, urgent tasks with amber left border

### Activity Log
- Full filter + table + detail modal
- Stats cards: Today, This Week, Unique Users, Total Records
- Filter dropdowns (by action, by user) + date range inputs
- Paginated table with color-coded action badges and detail column
- Include detail modal overlay showing full activity info

### Team Chat
- 8-12 mock messages from different users showing realistic conversation
- Include @ mentions, file attachment indicators, timestamps
- Message input area with @ mention hint and attachment button
- Chat header with online status indicator
- Refresh button

### Settings page
- 4 integration sections as stacked cards: Samsara GPS, Google Maps, Email/Resend, Claude AI
- Each card shows: API key input field, status indicator (configured/not configured), test button
- Setup instructions included at Claude's discretion (can condense or include full steps)

### Claude's Discretion
- Settings page instruction detail level (full numbered steps vs. condensed)
- Exact mock data values (truck numbers, dollar amounts, dates, driver names)
- Spacing and padding adjustments within design system constraints
- How to handle the drill-down view within fuel.html (separate section vs. toggle)

</decisions>

<specifics>
## Specific Ideas

- Fuel page is one of the most data-rich in the TMS (~250 lines of production rendering) — mockup should demonstrate the full analytics capability
- Compliance Dashboard hero card should use design system gradient tokens, not the hardcoded `linear-gradient(135deg, #1e40af, #3b82f6)` from production
- IFTA calculation table has specific columns: State, Miles, % of Miles, Taxable Gal, Fuel Purchased, Net Taxable, Tax Rate, Tax Due — preserve this exact structure
- Compliance Tasks has real-world items (BOC-3, MCS-150, UCR, IFTA, IRP, 2290 Heavy Vehicle Tax, Drug & Alcohol Consortium, etc.) — use these actual task names in mock data

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 10-operations-admin-pages*
*Context gathered: 2026-02-09*
