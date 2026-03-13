# Phase 25 Plan 02: Tasks + Settings Restyle Summary

**One-liner:** Tasks page gets flat stat cards, segmented-control filter, CSS variable borders; Settings gets .input classes, section-header pattern, and zero hardcoded hex

## What Was Done

### Task 1: Restyle renderTasks and openTaskModal
- Converted 4 stat cards from colored-background stat-card to stat-flat + stat-card--{color} accent border pattern
- Replaced btn-primary/btn-secondary filter toggle row with segmented-control component (5 buttons)
- Task item borders: replaced `#e5e7eb` hardcoded border and colored background tints with CSS variable borders (--border, --red, --amber)
- Task list card uses card-flush + section-header pattern instead of card-header + h3
- Page header set to 18px/600
- Replaced `<strong>` on task titles with `<span>` + font-weight:600
- Replaced `var(--danger)` references with `var(--red)` for consistency
- openTaskModal: added .input class to text/date inputs, .textarea to description, .select to 3 dropdowns

### Task 2: Restyle renderSettings
- Applied .input class to all 11 form inputs across Company Profile, Samsara, Google Maps, and Claude API sections
- Replaced all 11 card-header + h3 patterns with section-header + section-header-title
- Added card-flush class to all 11 card containers
- Replaced hardcoded hex colors: #059669 and #047857 -> var(--green), #dc2626 -> btn-danger class
- Fixed wrong CSS variable naming: --dim-green/red/amber/blue -> --green-dim/red-dim/amber-dim/blue-dim
- Replaced --surface-elevated (not in variables.css) with --bg-tertiary for code snippet backgrounds
- Remove/delete buttons changed from inline red styling to btn-danger component class
- Page header set to 18px/600

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| 483a916 | feat | Restyle tasks page - stat-flat, segmented-control, CSS variable borders |
| ddc2767 | feat | Restyle settings page - .input classes, section-headers, CSS variable colors |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Fixed wrong CSS variable naming in Settings**
- **Found during:** Task 2
- **Issue:** Settings used `--dim-green`, `--dim-red`, `--dim-amber`, `--dim-blue` which don't exist in variables.css
- **Fix:** Replaced with correct `--green-dim`, `--red-dim`, `--amber-dim`, `--blue-dim`
- **Files modified:** index.html (renderSettings)
- **Commit:** ddc2767

**2. [Rule 2 - Missing Critical] Replaced undefined --surface-elevated variable**
- **Found during:** Task 2
- **Issue:** `var(--surface-elevated)` used for code snippet backgrounds but not defined in variables.css
- **Fix:** Replaced with `var(--bg-tertiary)` which is the equivalent defined variable
- **Files modified:** index.html (renderSettings)
- **Commit:** ddc2767

**3. [Rule 1 - Bug] Remove buttons used inline styled red instead of btn-danger**
- **Found during:** Task 2
- **Issue:** Remove/delete buttons had `style="background:var(--dim-red);color:#dc2626"` inline -- mixed hardcoded hex with wrong variable
- **Fix:** Changed to `class="btn btn-danger"` component class
- **Files modified:** index.html (renderSettings)
- **Commit:** ddc2767

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Tasks stat cards reduced from 4 clickable filter cards to 4 display-only stat-flat | Stat cards should show metrics, segmented-control handles filtering |
| Settings remove buttons use btn-danger class | Consistent destructive action styling across app |
| --surface-elevated replaced with --bg-tertiary | surface-elevated not in main variables.css; bg-tertiary is the defined equivalent |

## Metrics

- **Duration:** ~4 minutes
- **Completed:** 2026-03-13
- **Files modified:** 1 (index.html)
- **Tasks:** 2/2
