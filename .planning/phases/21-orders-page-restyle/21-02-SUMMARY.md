# Phase 21 Plan 02: Orders Page Chrome Restyle Summary

**One-liner:** Restyled orders page header, filter bar, view toggle, table view, and card wrapper to Stripe/Linear aesthetic with proper button hierarchy and CSS component classes.

## Completed Tasks

| # | Task | Commit | Key Changes |
|---|------|--------|-------------|
| 1 | Restyle orders page header, filter bar, and view toggle | 2b21bc2 | 18px/600 heading, .select/.input classes, badge-xs chips, btn-secondary AI Import, segmented view toggle |
| 2 | Restyle orders table view and clean up card view wrapper | 8c0f3b2 | .data-table class, card-flush wrapper, badge-green/amber/blue, CSS token spacing, modal hardcoded colors fixed |

## What Changed

### Page Header
- Heading: 18px font-size, 600 weight (matching Phase 20 pattern)
- Year selector: Uses `.select` component class, removed inline border/padding/background
- Year/undated chips: badge-xs pattern (4px radius, 10px font, 2px 6px padding, bg-tertiary background)
- Button hierarchy: Only "+ New Order" is btn-primary (dark slate); AI Import changed from purple (#8b5cf6) to btn-secondary; Export is btn-secondary; Bulk delete uses btn-danger

### Filter Bar
- Search input: Uses `.input` component class, removed all inline padding/border/radius styles
- Filter selects (Status, Dispatcher, Driver, Broker): All use `.select` component class
- Filter labels: font-weight 500, color var(--text-secondary), font-size 13px
- Container: flex-wrap with gap var(--space-3) and padding var(--space-3) 0
- Clear button: `btn btn-ghost btn-sm`
- Result count: color var(--text-secondary), font-size 13px

### View Toggle
- Segmented control: border 1px solid var(--border-primary), border-radius var(--radius-md), overflow hidden
- Active state: background var(--btn-primary-bg), color white (dark slate)
- Inactive state: transparent background, color var(--text-secondary)
- Button sizing: padding var(--space-1-5) var(--space-3), font-size 13px

### Table View
- Table element: Added `class="data-table"` for base.css styling (hairline borders, bg-tertiary headers, alternating row tint)
- Table wrapper: `card card-flush` with overflow-x auto
- Status badges: Changed from badge-success/warning/info to badge-green/amber/blue (Plan 01 CSS classes)
- Action buttons: Consistent 2px 8px padding, 12px font (Assign/Edit/Del)
- Select-all bar: CSS token spacing, font-weight 500

### Card View
- Wrapper: padding var(--space-4), CSS token gap/margin
- Card list gap: var(--space-3)
- Action buttons: Consistent 2px 8px padding, 12px font

### Bulk Action Bar
- Background: var(--bg-primary) instead of var(--bg-card)
- Border: var(--border-primary) instead of var(--border)
- Shadow: var(--shadow-md) instead of hardcoded rgba
- Removed animation (fadeInUp)

### Order Detail Modal
- New broker section: bg-tertiary + border-primary instead of hardcoded #f0fdf4/#bbf7d0
- Split payment border: var(--border-primary) instead of hardcoded #f59e0b
- Readonly split bill input: var(--bg-tertiary) instead of var(--surface-elevated)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Fixed order wizard new broker section colors**
- **Found during:** Task 2
- **Issue:** The newBrokerSection hardcoded colors (#f0fdf4, #bbf7d0) also appeared in the order wizard function (line 20708), not just the order modal
- **Fix:** Applied replace_all to fix both instances
- **Files modified:** index.html

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| AI Import button changed to btn-secondary | User decision: only New Order gets primary treatment |
| Status badges use badge-green/amber/blue | Consistent with Plan 01 getBadge() CSS classes |
| Filter labels font-weight 500 (not 600) | Lighter weight for secondary labels, matching Stripe pattern |
| Bulk delete button uses btn-danger | More semantic than inline red background styles |

## Metrics

- Duration: ~3 minutes
- Files modified: 1 (index.html)
- Lines changed: ~48 (24 insertions, 24 deletions per commit)
- Completed: 2026-03-13
