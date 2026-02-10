# Phase 10: Operations & Admin Pages - Research

**Researched:** 2026-02-10
**Domain:** HTML/CSS mockup development with design system constraints
**Confidence:** HIGH

## Summary

Phase 10 requires creating 8 standalone HTML mockups for operations and admin pages using the established Phase 6 design system. These pages fall into three categories: (1) **fuel operations** (Fuel, IFTA), (2) **compliance hub** (single page with 7 sub-tabs), and (3) **admin utilities** (Maintenance, Tasks, Settings, Activity Log, Team Chat).

The constraint is **UI-only redesign** — mockups must match production structure and data relationships exactly while applying the Phase 6 design system. No new features, no layout changes, only visual modernization.

**Primary recommendation:** Create 4 sequential plans batching related pages, fully populate with realistic mock data, and preserve exact production page structure while applying design system styling.

## Standard Stack

The established libraries/tools for this phase:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| None (vanilla HTML) | - | Static mockups | Phase 6 decision: no bundlers, no preprocessors |
| shared.css | 1.0 | Design system | 1,308 lines of design tokens, components, utilities |
| Inter font | - | Sans-serif typography | Primary typeface across all mockups |
| Google Fonts CDN | - | Font delivery | Standard web font loading |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| Browser DevTools | - | Preview/debug | Real-time mockup validation |
| VS Code | - | HTML editing | Standard editor for mockups |
| base-template.html | - | Boilerplate | Starting point for each new page |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Vanilla HTML | React components | Would violate UI-only constraint, add build complexity |
| Design system CSS | Tailwind | Already decided in Phase 6, would break consistency |
| Static data | API integration | Mockups are static by design, no backend needed |

**Installation:**
```bash
# No installation needed — all mockups use existing shared.css
# Simply copy base-template.html and edit
```

## Architecture Patterns

### Recommended Project Structure
```
mockups/web-tms-redesign/
├── shared.css              # Design system (1,308 lines)
├── base-template.html      # Boilerplate for new pages
├── fuel.html               # Plan 1
├── ifta.html               # Plan 1
├── compliance.html         # Plan 2 (7 tabs in one file)
├── maintenance.html        # Plan 3
├── tasks.html              # Plan 3
├── settings.html           # Plan 4
├── activity-log.html       # Plan 4
└── team-chat.html          # Plan 4
```

### Pattern 1: Standalone Page Template
**What:** Each page is a complete HTML document with sidebar + main content
**When to use:** All 8 pages in this phase
**Example:**
```html
<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
  <meta charset="UTF-8">
  <title>Horizon Star TMS — Page Name</title>

  <!-- FART prevention: set theme before CSS loads -->
  <script>
    (function() {
      const theme = localStorage.getItem('tms-theme') || 'dark';
      document.documentElement.setAttribute('data-theme', theme);
    })();
  </script>

  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="./shared.css">

  <style>
    /* Page-specific styles here */
  </style>
</head>
<body>
  <!-- Sidebar from shared.css -->
  <!-- Main content area -->
  <script>/* Page-specific JS */</script>
</body>
</html>
```

### Pattern 2: Multi-Tab Page with JS Tab Switching
**What:** Single HTML file with multiple content sections toggled via JS
**When to use:** Compliance page (7 sub-tabs)
**Example:**
```html
<!-- Tab bar (from financials.html) -->
<div class="tab-bar">
  <button class="tab-button active" onclick="switchTab('dashboard')">📊 Dashboard</button>
  <button class="tab-button" onclick="switchTab('tasks')">📋 Compliance Tasks</button>
  <!-- ... 5 more tabs -->
</div>

<!-- Tab content sections -->
<div id="dashboard-tab" class="tab-content active">
  <!-- Dashboard content -->
</div>
<div id="tasks-tab" class="tab-content">
  <!-- Tasks content -->
</div>

<script>
function switchTab(tabId) {
  // Hide all tabs
  document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.tab-button').forEach(b => b.classList.remove('active'));
  // Show selected tab
  document.getElementById(tabId + '-tab').classList.add('active');
  event.target.classList.add('active');
}
</script>
```

### Pattern 3: Gradient Hero Cards (NOT Hardcoded Colors)
**What:** Hero cards use design system gradient tokens, not production's hardcoded `linear-gradient(135deg, #1e40af, #3b82f6)`
**When to use:** Compliance Dashboard hero card
**Example:**
```css
.hero-card {
  background: linear-gradient(135deg, rgba(34,197,94,0.12) 0%, rgba(34,197,94,0.04) 100%);
  border: 2px solid var(--green);
}
/* NOT: background: linear-gradient(135deg, #1e40af, #3b82f6); */
```

### Pattern 4: Filter Row + Stat Cards + Table
**What:** Standard TMS page layout — filters → stats → data table
**When to use:** Fuel, Maintenance, Tasks, Activity Log
**Example:**
```html
<!-- Filter row -->
<div class="filter-row">
  <select><!-- Truck filter --></select>
  <select><!-- State filter --></select>
  <button>Clear Filters</button>
</div>

<!-- Stat cards -->
<div class="stat-row">
  <div class="stat-card">
    <div class="stat-label">Total Records</div>
    <div class="stat-value">1,234</div>
  </div>
</div>

<!-- Data table -->
<div class="card">
  <table><!-- Data rows --></table>
</div>
```

### Pattern 5: Drill-Down View (Fuel Page)
**What:** Single page can show "all trucks" or "filtered to one truck" state
**When to use:** Fuel page per-truck drill-down
**Example:**
```html
<!-- All trucks view -->
<div id="all-trucks-view">
  <h1>⛽ Fuel Tracking</h1>
  <!-- Stat cards for all trucks -->
</div>

<!-- Drill-down view (shown when truck selected) -->
<div id="drill-down-view" style="display:none">
  <button onclick="backToAll()">← Back to All Trucks</button>
  <h1>⛽ Fuel Tracking - Truck #1234</h1>
  <!-- Stat cards for single truck -->
</div>
```

### Anti-Patterns to Avoid
- **Hardcoded gradient colors:** Production uses `linear-gradient(135deg, #1e40af, #3b82f6)` for Compliance Dashboard hero — mockup must use design system tokens like `rgba(34,197,94,0.12)`
- **Inventing new layouts:** UI-only constraint means structure must match production exactly
- **Empty tables:** All tables must show realistic mock data (10-15 rows minimum)
- **Missing filters:** If production has filter dropdowns, mockup must show them
- **Inconsistent component usage:** Use shared.css components (.stat-card, .badge, .btn) not custom variants

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tab switching UI | Custom tab bar component | `.tab-bar` + `.tab-button` from financials.html | Already proven pattern, consistent with existing mockups |
| Stat cards | New stat card HTML | `.stat-card` from shared.css (lines 548-599) | Design system provides this, 6 built-in variants |
| Filter dropdowns | Custom styled selects | `<select>` with shared.css base styles | Native elements styled by design system |
| Badges | Custom colored spans | `.badge`, `.badge-green`, `.badge-red`, etc. from shared.css (lines 601-678) | 8 color variants pre-styled |
| Hero gradient cards | Hardcoded background colors | Design system gradient tokens (`--green-dim`, `rgba()` syntax) | Maintains theme consistency |
| Modal overlays | Custom modal HTML | `.modal-overlay` + `.modal` from shared.css if needed | Already in design system |
| Data tables | Custom table styling | `<table>` in `.card > .table-wrapper` (shared.css lines 428-508) | Responsive, scrollable, pre-styled |

**Key insight:** Phase 6 created a comprehensive 1,308-line design system. Every common UI pattern already exists — use it, don't recreate it.

## Common Pitfalls

### Pitfall 1: Production Structure Mismatch
**What goes wrong:** Mockup invents new page structure that looks good but doesn't match production
**Why it happens:** Designer creativity or not reading production code carefully
**How to avoid:** For each page, read `renderXxx()` function in index.html line-by-line, note exact sections, filters, stat cards, table columns
**Warning signs:**
- Mockup has stat cards production doesn't have
- Mockup table columns differ from production
- Filters exist in mockup but not production (or vice versa)

### Pitfall 2: Empty or Sparse Mock Data
**What goes wrong:** Tables show 2-3 rows, not enough to validate design at realistic scale
**Why it happens:** Laziness or underestimating importance of data volume
**How to avoid:**
- Fuel page: 20+ transaction rows
- IFTA page: ~10 state rows
- Compliance Tasks: 10-15 default tasks with varied statuses
- Activity Log: 30+ log entries
**Warning signs:** User scrolls and sees "No data" or only 3 rows

### Pitfall 3: Hardcoded Production Colors
**What goes wrong:** Copying production's `background: linear-gradient(135deg, #1e40af, #3b82f6)` instead of using design system
**Why it happens:** Copy-paste from production without translating to design system
**How to avoid:**
- Compliance Dashboard hero card: Use `rgba(34,197,94,0.12)` gradient, NOT `#1e40af` blue
- All hero cards: Use design system color tokens
- Check: Search mockup HTML for hex colors like `#1e40af` — if found, replace with tokens
**Warning signs:** Blue gradient in Compliance Dashboard when design system uses green

### Pitfall 4: Forgetting IFTA Calculation Table Structure
**What goes wrong:** IFTA page table has wrong columns or missing key data
**Why it happens:** Not reading production IFTA rendering function carefully
**How to avoid:** IFTA table has EXACT columns: State, Miles, % of Miles, Taxable Gal, Fuel Purchased, Net Taxable, Tax Rate, Tax Due
**Warning signs:** IFTA table looks generic or has different column names

### Pitfall 5: Incomplete Compliance Hub
**What goes wrong:** Compliance page only implements 3-4 of the 7 sub-tabs
**Why it happens:** Underestimating scope or not reading CONTEXT.md decision
**How to avoid:** CONTEXT.md states "all 7 sub-tabs fully detailed with realistic mock data" — Dashboard, Compliance Tasks, Driver Files, Truck Files, Company Files, Tickets/Violations, Accident Registry
**Warning signs:** Only 4 tabs in compliance.html when 7 are required

### Pitfall 6: Missing Samsara Mileage Status Card
**What goes wrong:** Fuel page doesn't show the blue "Samsara mileage loaded" banner
**Why it happens:** Not reading fuel page production code carefully
**How to avoid:** Fuel page has Samsara status card in "data uploaded" state showing truck count + total miles (production lines 20066-20075)
**Warning signs:** No blue banner in fuel.html mockup

### Pitfall 7: Tasks Page Missing Visual Indicators
**What goes wrong:** Overdue tasks don't have red left border, urgent tasks don't have amber border
**Why it happens:** Not implementing production visual design patterns
**How to avoid:** Production lines 21615-21616 show `border-left:4px solid #dc2626` for overdue, `border-left:4px solid #f59e0b` for urgent
**Warning signs:** All task cards look identical regardless of status

## Code Examples

Verified patterns from production source:

### Stat Card with Left Border
```html
<!-- Production pattern: line 31671 (Maintenance), 20079-20085 (Fuel) -->
<div class="stat-card" style="padding:16px; border-left:4px solid #10b981">
  <div class="label">Total Spent</div>
  <div class="value" style="color:#10b981">$45,678</div>
</div>
```

### Filter Row with Dropdowns
```html
<!-- Production pattern: lines 31662-31666 (Maintenance), 20041-20052 (Fuel) -->
<div style="display:flex; gap:16px; align-items:center; background:#f8fafc; padding:16px; border-radius:8px">
  <label style="font-weight:600; color:#475569">🚛 Truck:</label>
  <select style="padding:8px 12px; border:1px solid #e2e8f0; border-radius:6px">
    <option value="all">All Trucks</option>
    <option value="1234">#1234</option>
  </select>
  <button class="btn btn-secondary">Clear Filters</button>
</div>
```

### Badge Color Variants
```html
<!-- Production pattern: lines 21575-21578 (Tasks), 21962 (Compliance) -->
<span class="badge badge-green">✓ Done</span>
<span class="badge badge-red">OVERDUE</span>
<span class="badge badge-amber">Due Soon</span>
<span class="badge badge-blue">NORMAL</span>
```

### Task Card with Conditional Border
```html
<!-- Production pattern: lines 21615-21638 (Tasks) -->
<div style="padding:16px; border:1px solid #e5e7eb; border-radius:8px;
            border-left:4px solid #dc2626; background:#fef2f2"> <!-- Overdue -->
  <div style="display:flex; align-items:center; gap:12px">
    <input type="checkbox" style="width:20px; height:20px">
    <strong>Renew insurance policy</strong>
    <span class="badge badge-red">🔥 URGENT</span>
  </div>
  <p style="color:#64748b; margin:8px 0 0 32px">Policy expires next week</p>
  <div style="margin-left:32px; font-size:13px; color:#64748b">
    <span>📅 OVERDUE: Feb 5, 2026</span>
  </div>
</div>
```

### IFTA Calculation Table Row
```html
<!-- Production pattern: lines 21223-21224 (IFTA) -->
<table>
  <thead>
    <tr>
      <th>State</th>
      <th>Miles</th>
      <th>% of Miles</th>
      <th>Taxable Gal</th>
      <th>Fuel Purchased</th>
      <th>Net Taxable</th>
      <th>Tax Rate</th>
      <th>Tax Due</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><strong>TX</strong></td>
      <td>12,450</td>
      <td>35.20%</td>
      <td>2,075.00</td>
      <td>1,800.50</td>
      <td style="color:#dc2626">274.50</td>
      <td>$0.2000</td>
      <td class="money" style="color:#dc2626">$54.90</td>
    </tr>
  </tbody>
</table>
```

### Compliance Dashboard Hero Card (Design System Version)
```html
<!-- Production has hardcoded blue gradient (line 21846)
     Mockup must use design system tokens -->
<div class="card" style="margin-bottom:24px;
  background: linear-gradient(135deg, rgba(34,197,94,0.12) 0%, rgba(34,197,94,0.04) 100%);
  border: 2px solid var(--green); padding:24px">
  <h3 style="margin:0 0 16px; color:var(--text-primary)">📊 Compliance Report</h3>
  <div style="display:grid; grid-template-columns:repeat(3,1fr); gap:16px">
    <div style="background:rgba(255,255,255,0.1); padding:20px; border-radius:12px; text-align:center">
      <div style="font-size:14px; opacity:0.9">Open Tickets</div>
      <div style="font-size:36px; font-weight:700">5</div>
    </div>
    <!-- More stats -->
  </div>
</div>
```

### Activity Log with Color-Coded Actions
```html
<!-- Production pattern: lines 36020-36026 (Activity Log) -->
<tr>
  <td style="font-size:20px">🚛</td>
  <td>Feb 10, 2026 10:30 AM</td>
  <td>admin@horizonstar.com</td>
  <td>
    <span style="background:#22c55e22; color:#22c55e; padding:4px 10px;
                 border-radius:6px; font-size:12px; font-weight:600">
      TRIP CREATED
    </span>
  </td>
  <td>
    <span style="background:var(--bg-tertiary); padding:2px 6px; border-radius:4px">
      <strong>trip_id:</strong> 1234
    </span>
  </td>
</tr>
```

### Settings Integration Card
```html
<!-- Production pattern: lines 31829-31847 (Settings) -->
<div class="card" style="max-width:700px">
  <div class="card-header">
    <h3>📍 Samsara GPS Integration</h3>
  </div>
  <div style="padding:20px">
    <p style="color:#64748b; margin-bottom:20px">
      Connect to Samsara for real-time truck GPS tracking.
    </p>

    <div class="form-group">
      <label>Samsara API Token</label>
      <div style="display:flex; gap:12px">
        <input type="password" value="samsara_api_xxxxx..." style="flex:1">
        <button class="btn btn-secondary">👁️</button>
      </div>
    </div>

    <div style="background:#d1fae5; padding:12px; border-radius:8px">
      <span style="color:#059669">✓ API key configured</span>
    </div>

    <button class="btn btn-primary">💾 Save Settings</button>
    <button class="btn btn-secondary">🧪 Test Connection</button>
  </div>
</div>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Production blue gradients | Design system green gradients | Phase 6 (2026-02-09) | All hero cards now use `--green`, `--green-dim` tokens |
| Inline styles everywhere | Design system CSS classes | Phase 6 (2026-02-09) | Mockups use `.stat-card`, `.badge`, `.btn` instead of custom HTML |
| Light theme default | Dark theme default | Phase 6 (2026-02-09) | Matches iOS v3 driver app |
| No design consistency | 1,308-line design system | Phase 6 (2026-02-09) | All mockups share tokens, components, utilities |

**Deprecated/outdated:**
- **Hardcoded hex colors in gradients:** Production uses `#1e40af`, `#3b82f6` — design system uses `rgba(34,197,94,0.12)` with tokens
- **Custom stat card HTML per page:** Now standardized in shared.css with 6 variants
- **Inconsistent badge colors:** Now 8 standardized badge variants (green, red, amber, blue, purple, gray, dark, light)

## Open Questions

Things that couldn't be fully resolved:

1. **Fuel page drill-down implementation**
   - What we know: Production has per-truck drill-down view (lines 19869-19871, 20016-20022)
   - What's unclear: Best way to show both "all trucks" and "drill-down" states in static mockup
   - Recommendation: Show drill-down state as default with "Back to All Trucks" button visible, add comment noting this is one of two possible states

2. **Compliance Tasks default data**
   - What we know: Production has 15 default task names (BOC-3, UCR, IFTA, IRP, etc.) (lines 21921-21936)
   - What's unclear: Exact due dates to show for each task (annual, quarterly, biennial cycles)
   - Recommendation: Use realistic dates based on frequency — IFTA shows next quarter due date, UCR shows Jan 31 deadline, etc.

3. **Team Chat message count**
   - What we know: CONTEXT.md says "8-12 mock messages"
   - What's unclear: Ideal distribution of message types (@ mentions, file attachments, plain messages)
   - Recommendation: 10 messages total — 2 with @ mentions, 1 with file attachment indicator, 7 plain messages

4. **Settings setup instructions detail level**
   - What we know: CONTEXT.md says Claude's discretion on instruction detail (condense or full steps)
   - What's unclear: User preference for verbose vs. concise
   - Recommendation: Use production's numbered list format (lines 31851-31862, 31866-31873) but condense — 5-7 steps max per integration instead of verbose explanations

## Sources

### Primary (HIGH confidence)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/index.html` (lines 19848-20097: Fuel page, 21098-21292: IFTA, 21721-22120: Compliance, 21541-21713: Tasks, 31632-31735: Maintenance, 31817-31962: Settings, 35891-36081: Activity Log, 33307-33456: Team Chat)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/mockups/web-tms-redesign/shared.css` (1,308 lines: design system)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/mockups/web-tms-redesign/financials.html` (tab pattern reference)
- `/Users/reepsy/Desktop/OG TMS CLAUDE/.planning/phases/10-operations-admin-pages/10-CONTEXT.md` (user decisions)

### Secondary (MEDIUM confidence)
- None — all findings verified against production code

### Tertiary (LOW confidence)
- None — no web search required for this phase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Phase 6 established vanilla HTML + shared.css, no alternatives
- Architecture: HIGH - All 8 page structures verified in production index.html
- Pitfalls: HIGH - Derived from comparing production code to design system requirements

**Research date:** 2026-02-10
**Valid until:** 2026-03-12 (30 days — stable domain, no fast-moving dependencies)

---

## Phase-Specific Findings

### Fuel Page Structure (Production: lines 19848-20097)
**4 Analytics Tabs:** Overview, Analytics, Efficiency, Price Analysis
**Stat Cards (Overview):** Total Diesel, Diesel Cost, Avg $/Gallon, Total Savings, Total DEF, Total Cost
**Efficiency Metrics:** Miles Traveled (with Samsara source indicator), MPG, Cost Per Mile, Fill-Ups, Avg Gal/Fill-Up, Avg Discount/Gal
**Samsara Status Card:** Blue banner with truck count + total miles (lines 20066-20075)
**Filters:** Truck, State, Product, Driver dropdowns (lines 20043-20050)
**Drill-Down:** Per-truck filtered view with "Back to All Trucks" button (lines 20016-20022)

### IFTA Page Structure (Production: lines 21098-21292)
**Exact Columns:** State, Miles, % of Miles, Taxable Gal, Fuel Purchased, Net Taxable, Tax Rate, Tax Due (line 21223)
**Summary Stats:** Total Miles, Fleet MPG, Taxable Gallons, Fuel Purchased, Tax Owed, Tax Credit, Net Tax Due (lines 21197-21204)
**Auto-Calculated MPG Info Box:** Blue banner showing calculation (lines 21187-21193)
**Quarter/Year Selector:** Q1-Q4 dropdown + year dropdown (lines 21178-21180)
**Fleet MPG Input:** Editable input with "Use calculated MPG" button if data available (lines 21181-21182)

### Compliance Hub Structure (Production: lines 21721-22120)
**7 Sub-Tabs:** Dashboard, Compliance Tasks, Driver Files, Truck Files, Company Files, Tickets/Violations, Accident Registry
**Dashboard Hero Card:** 3 big stats (Open Tickets, Open Claims, Days Without Accidents), 6 upcoming-item cards (lines 21846-21904)
**Compliance Tasks:** IFTA due date banner, ~10-15 default tasks with statuses, reference table with "Add" buttons (lines 21908-21977)
**Driver Files:** List view + detail view with 10 file types (CDL, Medical Card, MVR, PSP Report, etc.)
**Truck Files:** List view + detail view with 8 file types
**Company Files:** Categories with expiration tracking
**Tickets/Violations:** Ticket records with court dates, fines, driver association
**Accident Registry:** Accident records with dates, involved parties, details

### Maintenance Page Structure (Production: lines 31632-31735)
**Filters:** Truck dropdown, Sort (newest/oldest), Clear filters button (lines 31662-31666)
**Stat Cards:** Total Records, Filtered Records, Total Spent (lines 31668-31671)
**Table Columns:** Truck, Date, Type (badge), Shop, Description, Cost, Actions (lines 31672-31687)

### Tasks Page Structure (Production: lines 21541-21713)
**Stat Cards (Clickable Filters):** Pending Tasks, Due Today, Overdue, Urgent (lines 21592-21596)
**Filter Tabs:** All Pending, Today, Upcoming, Overdue, Completed (lines 21600-21605)
**Task Card Elements:** Checkbox, title, priority badge, status badge, due date, assignee (lines 21612-21638)
**Visual Indicators:** Overdue = red left border + red background, Urgent = amber left border + amber background (lines 21615-21616)

### Settings Page Structure (Production: lines 31817-31962)
**4 Integration Sections:** Samsara GPS, Google Maps, Email/Resend, Claude AI (stacked cards)
**Card Elements:** API key input field (password type), status indicator (green success / yellow warning), test button, save button, remove button
**Setup Instructions:** Numbered lists (7-8 steps) with links to official documentation (lines 31851-31905)

### Activity Log Structure (Production: lines 35891-36081)
**Stats Cards:** Today, This Week, Unique Users, Total Records (lines 35980-35984)
**Filters:** Action dropdown, User dropdown, Date range (From/To) (lines 35988-36001)
**Table Columns:** Icon, Date/Time, User, Action (colored badge), Details (lines 36005)
**Color-Coded Actions:** Each action type has hex color (LOGIN_SUCCESS=#22c55e, ORDER_DELETED=#ef4444, etc.) (lines 35922-35956)
**Detail Modal:** Clicking row shows full activity info in modal (lines 36033-36059)

### Team Chat Structure (Production: lines 33307-33456)
**Header:** Title with online status, refresh button (lines 33309-33314)
**Messages Area:** Flex column with gap, scrollable, dark background (lines 33316-33318)
**Message Elements:** Avatar, sender name, timestamp, message text, @ mention highlighting, file attachment indicators
**Input Area:** @ mention hint, attachment button (📎), textarea with auto-resize, send button (lines 33320-33334)
**@ Mention Dropdown:** Shows users as you type @ (lines 33372-33404)
