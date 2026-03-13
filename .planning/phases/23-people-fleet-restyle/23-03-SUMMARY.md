---
phase: 23
plan: 03
subsystem: people-fleet
tags: [brokers, dispatchers, restyle, css-variables, stat-flat]
depends_on: ["23-02"]
provides: ["brokers-restyled", "dispatchers-restyled", "dispatcher-ranking-restyled"]
affects: ["24-finance-restyle"]
tech_stack:
  patterns: [stat-flat, data-table, select-class, neutral-period-badge, left-border-accent]
key_files:
  modified: [index.html]
decisions:
  - Broker helper functions (getScoreColor, getActivityStatus) use CSS variables instead of hardcoded hex
  - Dispatcher spotlight cards use left border accents (green/amber) instead of colored backgrounds
  - Dispatcher ranking progress bars use var(--bg-tertiary) track with CSS variable fills
  - Leaderboard card headers neutral (14px/600, text-primary) instead of colored
metrics:
  duration: ~6 minutes
  completed: 2026-03-13
---

# Phase 23 Plan 03: Brokers + Dispatchers Restyle Summary

Restyled all broker and dispatcher pages to match the Stripe/Linear flat aesthetic established in prior phases.

## One-liner

Brokers + Dispatchers pages flattened: stat-flat cards, CSS variable colors, neutral badges, data-table classes, font-weight capped at 600.

## Tasks Completed

### Task 1: Restyle renderBrokers and viewBrokerDetails (176bb79)
- Replaced 4 gradient stat cards (blue/green/amber/purple) with stat-flat class pattern
- Replaced hardcoded hex colors in getScoreColor (#16a34a, #2563eb, #f59e0b, #dc2626) with CSS variables
- Replaced hardcoded hex/bg colors in getActivityStatus with CSS variables (--dim-green, --dim-blue, etc.)
- Replaced inline-styled selects with class="select"
- Replaced colored period badge (dim-blue/info-border) with neutral bg-tertiary style
- Capped all font-weights from 700/800 to 600 (avatar, name, revenue, profit values)
- viewBrokerDetails: replaced stat-card divs with stat-flat, replaced hardcoded colors (#10b981, #f59e0b, #059669, #7c3aed, #92400e, #64748b) with CSS variables
- Removed emoji icon from page heading, set to 18px/600

### Task 2: Restyle renderDispatchers and renderDispatcherRanking (ae94d14)
- Set dispatchers heading to 18px/600
- Replaced inline-styled selects with class="select"
- Added data-table class to dispatchers table
- Replaced colored period badges with neutral bg-tertiary style
- Replaced responsive-stat-strip stat-cards with stat-flat class pattern + font-mono values
- Replaced colored stat-card (rgba blue background) with stat-flat
- Flattened spotlight cards: removed 32px trophy/trend_up emojis, removed colored rgba backgrounds, added left border accents (3px solid green/amber)
- Replaced spotlight inner stat divs (rgba backgrounds) with stat-flat class
- Replaced colored names (#4ade80, #fbbf24) with var(--text-primary)
- Replaced colored labels (#9ca3af) with var(--text-muted)
- Added data-table class to ranking table
- Removed rgba() row highlighting on top/bottom rows, top row uses var(--bg-secondary) only
- Replaced progress bar colors (#3b82f6, #10b981) with CSS variables
- Replaced totals row colors (#f87171, #60a5fa) with CSS variables
- Replaced clean revenue color (#1d4ed8) with var(--blue)
- Replaced totals row font-weight 700 with 600
- Capped getMedal font-weight at 600
- Replaced getProgressBar track from rgba(255,255,255,0.1) to var(--bg-tertiary)
- Fixed leaderboard card headers: neutral 14px/600 instead of colored (#3b82f6, #10b981)
- Replaced leaderboard color props from hex to CSS variables
- Fixed rankedByCards progress bar track from rgba to var(--bg-tertiary)
- Fixed mobile ranking cards: replaced hardcoded hex colors with CSS variables

## Deviations from Plan

None -- plan executed exactly as written.

## Verification

- Searched renderBrokers/viewBrokerDetails (lines 24399-24705) for linear-gradient, font-weight:700, font-weight:800, hardcoded hex colors -- zero matches
- Searched renderDispatchers/renderDispatcherRanking (lines 24707-25020) for font-weight:700, font-weight:800, linear-gradient, rgba(, hardcoded hex colors, trophy emoji -- zero matches

## Next Phase Readiness

Phase 23 is now complete (3/3 plans). Ready for Phase 24 (Finance Pages Restyle).
