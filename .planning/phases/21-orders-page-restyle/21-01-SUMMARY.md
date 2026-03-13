---
phase: 21-orders-page-restyle
plan: 01
subsystem: web-tms-ui
tags: [css, badges, pagination, order-cards, shared-helpers]
dependency_graph:
  requires: [19-design-foundation]
  provides: [badge-css-for-getBadge, flat-order-cards, flat-pagination]
  affects: [21-02, orders, trips, loadboard, brokers, dealer-portal]
tech_stack:
  added: []
  patterns: [css-token-based-styling, shared-helper-propagation]
key_files:
  created: []
  modified:
    - assets/css/base.css
    - index.html
decisions:
  - id: remove-accent-border
    description: "Removed accentColor border-left:4px logic from order cards -- flat cards use uniform hairline borders"
    rationale: "Stripe/Linear aesthetic requires flat, uniform borders without colored left accents"
metrics:
  duration: "~2 min"
  completed: "2026-03-13"
---

# Phase 21 Plan 01: Shared Helpers Restyle Summary

**Restyled renderOrderPreviewCard and renderPaginationControls plus added getBadge() CSS rules -- propagates flat Stripe/Linear aesthetic to all 8+ order card usage sites automatically.**

## What Was Done

### Task 1: Badge CSS Rules and Pagination Class (base.css)
- Added `.badge-green`, `.badge-amber`, `.badge-blue`, `.badge-red`, `.badge-gray` rules mapping to same color tokens as semantic badge names (green-dim/green, amber-dim/amber, etc.)
- Added `.pagination-flat` utility class: flex layout, hairline top border, 13px font, centered alignment
- Commit: `1427a70`

### Task 2: Restyle Shared Helpers (index.html)
- **renderOrderPreviewCard**: Replaced inline card styles with CSS tokens (`--border-primary`, `--bg-primary`, `--radius-md`, `--space-3`/`--space-4`). Removed `accentColor` border-left:4px logic. Added `font-family: var(--font-mono)` to revenue amount.
- **renderPaginationControls**: Replaced card-style container (bg-card, border-radius:12px, padding:16px) with `pagination-flat` class. Buttons use `btn-sm` size. Text uses `--text-secondary` color.
- Commit: `d2b3424`

## Propagation Impact

These two shared helpers are called from 8+ locations:
1. Orders page (renderOrders)
2. Loadboard
3. Trip detail order list
4. Local drivers order assignments
5. Broker detail orders
6. Dealer portal orders (3 call sites)
7. Activity log pagination

All inherit the flat aesthetic without per-page changes.

## Deviations from Plan

None -- plan executed exactly as written.

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Removed accentColor border-left logic entirely | Flat cards use uniform hairline borders per Stripe/Linear aesthetic. Call sites that pass accentColor option are unaffected (option is silently ignored). |
| Kept badge inline padding/font-size overrides | The `style="padding:2px 6px;font-size:10px"` on badge spans makes badges compact within cards -- works well with new CSS class backgrounds. |

## Next Phase Readiness

Plan 21-02 can proceed. The shared helpers are now flat and token-based. Page-specific order rendering (orders page layout, filters, etc.) is the next target.
