# Phase 24 Plan 02: Billing Invoices/Collections + Payroll Restyle Summary

**One-liner:** Billing invoices/collections tabs and payroll page restyled with segmented-control filters, stat-flat cards, data-table classes, and CSS variable colors throughout.

## What Was Done

### Task 1: Restyle renderBillingInvoicesTab and renderBillingCollectionsTab
- Replaced inline-styled filter buttons with `.segmented-control` + `.segmented-control-btn` pattern in both tabs
- Added `class="data-table"` and `card-flush` wrapper to invoice and collections tables
- Added `class="input"` to search fields (billing search, collections search)
- Replaced inline stat cards in collections with `.stat-flat` + `.stat-card--{color}` accent pattern
- Replaced hardcoded hex colors (#22c55e, #dc2626, #ef4444, #f97316, #3b82f6, #8b5cf6, #eab308, rgba() values) with CSS variables throughout
- Replaced inline-styled action buttons with `btn-primary`/`btn-secondary`/`btn-ghost` classes
- Fixed status badges in collections to use `.badge` component classes
- Fixed `getPaymentStatusInfo()` helper to use CSS variables instead of hex
- Fixed invoice detail modal: hex colors, font-weights, inline button styles
- Capped all font-weights at 600 (was 700/800 in batch modals, status badges)

### Task 2: Restyle renderPayroll
- Replaced tab toggle (Run Payroll / Paystub History) with `.segmented-control` component
- Replaced period type tabs (Weekly/Monthly/Year) with `.segmented-control` component
- Replaced driver filter pills (All/Company/Owner-OP) with `.segmented-control` component
- Replaced `.stat-card` + `.stat-icon` pattern with `.stat-flat` + `.stat-card--{color}` accents (removed all stat-icon divs)
- Replaced history summary cards with `.stat-flat` pattern
- Added `font-family:var(--font-mono)` to all monetary values in driver cards
- Replaced inline-styled driver stat boxes (border-radius:12px, surface-elevated) with flat bg-tertiary pattern
- Replaced hardcoded driver type badges (#f59e0b) with `.badge` classes
- Added `class="data-table"` to history tables
- Added `.input`/`.select` classes to search and filter controls
- Capped all font-weights at 600 throughout payroll
- Fixed record payment modal (badge classes, flat stat boxes, font-mono, input class)
- Fixed `buildPayrollStatusChip()` font-weight from 700 to 600
- Page heading set to 18px/600 (removed emoji icon)
- Paystub print template (line ~34300) NOT modified

## Commits

| # | Hash | Description |
|---|------|-------------|
| 1 | ec36d39 | feat(24-02): restyle billing invoices and collections tabs |
| 2 | 9ae4069 | feat(24-02): restyle payroll page to Stripe/Linear aesthetic |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Fixed getPaymentStatusInfo() helper**
- **Found during:** Task 1
- **Issue:** Shared helper function `getPaymentStatusInfo()` used hardcoded hex colors (#22c55e, #dc2626, #eab308) that would bleed into any caller
- **Fix:** Replaced with CSS variables (--success, --danger, --warning)
- **Files modified:** index.html (line ~29844)
- **Commit:** ec36d39

**2. [Rule 2 - Missing Critical] Fixed buildPayrollStatusChip() font-weight**
- **Found during:** Task 2
- **Issue:** Shared helper used font-weight:700, would affect all payroll status chips
- **Fix:** Changed to font-weight:600
- **Files modified:** index.html (line ~31898)
- **Commit:** 9ae4069

**3. [Rule 2 - Missing Critical] Fixed invoice detail modal styling**
- **Found during:** Task 1
- **Issue:** `openInvoiceDetailModal()` had hardcoded hex colors (#22c55e, #dc2626, #ef4444, #3b82f6, #8b5cf6) and font-weight:700/800
- **Fix:** Replaced with CSS variables and capped font-weights at 600
- **Files modified:** index.html
- **Commit:** ec36d39

## Key Files Modified

| File | Changes |
|------|---------|
| index.html | renderBillingInvoicesTab, renderBillingCollectionsTab, renderPayroll, getPaymentStatusInfo, openInvoiceDetailModal, buildPayrollStatusChip, batch modals, collection action modals |

## Metrics

- **Duration:** ~8 minutes
- **Completed:** 2026-03-13
- **Tasks:** 2/2
