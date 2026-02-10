---
phase: 12-core-dispatch-pages
plan: 05
subsystem: dispatch-ui
tags: [css, design-system, orders-list, ui-consistency]

requires: [12-01]
provides: [orders-list-design-tokens]
affects: []

tech-stack:
  added: []
  patterns: [design-token-substitution, filter-bar-styling, table-styling]

decisions: []

key-files:
  created: []
  modified: [index.html]

metrics:
  duration: 6m
  completed: 2026-02-10
---

# Phase 12 Plan 05: Orders List Design Tokens Summary

**One-liner:** Orders list page restyled with design system tokens for year selector, filter bar, search input, dropdowns, and table elements while preserving all interactive functionality.

## What Was Implemented

### renderOrders() Function Restyling
Applied design system tokens to the Orders list page (lines 17695-17719 in index.html), replacing hardcoded pixel values with CSS custom properties:

**Year Selector (line 17695):**
- Wrapper: `padding:8px 12px` → `var(--spacing-2) var(--spacing-3)`, `border-radius:6px` → `var(--radius)`
- Label: `font-weight:600` → `var(--weight-semibold)`, `font-size:13px` → `var(--text-sm)`
- Select: `padding:6px 10px` → `var(--spacing-1-5) var(--spacing-2-5)`, `border-radius:6px` → `var(--radius)`, `font-size:14px` → `var(--text-sm)`

**Search and Filter Bar (lines 17698-17706):**
- Wrapper: `gap:16px` → `var(--spacing-4)`, `margin-bottom:20px` → `var(--spacing-5)`, `padding:16px` → `var(--spacing-4)`, `border-radius:8px` → `var(--radius)`
- Search input: `padding:10px 14px` → `var(--spacing-2-5) var(--spacing-3-5)`, `border-radius:6px` → `var(--radius)`, `font-size:14px` → `var(--text-sm)`
- Filter labels: `font-weight:600` → `var(--weight-semibold)` (all 4 labels: Status, Dispatcher, Driver, Broker)
- Filter selects: `padding:8px 12px` → `var(--spacing-2) var(--spacing-3)`, `border-radius:6px` → `var(--radius)`, `font-size:14px` → `var(--text-sm)` (all 4 dropdowns)
- Clear button: `padding:8px 16px` → `var(--spacing-2) var(--spacing-4)`
- Results count: `font-size:13px` → `var(--text-sm)`

**Table (lines 17708-17719):**
- Empty state: `padding:40px` → `var(--spacing-10)`
- Note rows: `padding:8px 16px` → `var(--spacing-2) var(--spacing-4)`, `font-size:13px` → `var(--text-sm)`

### Functionality Preservation
All existing interactive elements remain fully functional:
- Year selector onchange handler (ordersYear)
- Search input with debounced filtering (debouncedOrderSearch)
- Status/Dispatcher/Driver/Broker filter dropdowns with onchange handlers
- Clear filters button
- Bulk select/delete checkboxes (toggleSelectAllOrders, toggleOrderSelection, bulkDeleteOrders)
- Individual order actions (openOrderModal, openOrderDetailPage, deleteOrder, openAssignToTrip, unassignOrderFromTrip)
- Export/import buttons (exportOrders, openCreateNewLoad)
- Conditional note rows for dispatcher_notes

## Technical Decisions

### Decision 1: Layout constraints preserved
- Kept `min-width:200px` on search input wrapper (flex layout constraint)
- Kept `width:40px` on checkbox column (table structure constraint)
- These are structural values, not design tokens

### Decision 2: Consistent filter pattern
Applied identical styling across all 4 filter dropdowns (Status, Dispatcher, Driver, Broker) to ensure visual consistency in the filter bar

### Decision 3: Note row styling
Note rows (amber background for dispatcher_notes) now use design tokens for padding and font-size, maintaining visual hierarchy while aligning with design system

## Verification

```bash
# Verify design tokens applied
grep -n "var(--radius)" index.html | grep "1769[5-9]\|1770[0-5]"
# Expected: 8 instances in renderOrders section

grep -n "var(--text-sm)" index.html | grep "1769[5-9]\|1770[0-5]"
# Expected: 8 instances (year label/select, search, 4 filters, results count, note rows)

grep -n "var(--weight-semibold)" index.html | grep "1769[5-9]\|1770[0-5]"
# Expected: 5 instances (year label, 4 filter labels)

grep -n "var(--spacing-" index.html | grep "1769[5-9]\|1770[0-5]\|1771[0-5]"
# Expected: 15+ instances across all styled elements
```

All verifications passed. Orders list page now uses design system tokens exclusively for spacing, typography, and border-radius.

## Commits

| Commit | Message | Files |
|---|---|---|
| 3a28d6a | feat(12-05): restyle Orders list with design system tokens | index.html |

## Dependencies

**Required:**
- 12-01 complete (page component CSS foundation with design-system.css tokens)

**Enables:**
- Future phase 12 plans (Trip Board, other dispatch pages)
- Visual consistency across all dispatch pages

## Next Phase Readiness

**Blockers:** None

**Concerns:** None

**Recommendations:**
- Continue with 12-02 (Trip Board) or remaining phase 12 plans
- Orders list is now visually aligned with design system
- All dispatch page filter bars should follow this pattern

## Related

- Plan 12-01: Page component CSS foundation
- Plan 12-03: Trips list restyling (similar filter bar pattern)
- Plan 12-04: Trip Detail restyling
