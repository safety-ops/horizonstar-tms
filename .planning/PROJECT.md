# Horizon Star TMS

## What This Is

A Transportation Management System for Horizon Star LLC (VroomX Transport). Two products: a Web TMS (single-page PWA for fleet management, dispatching, payroll, billing) and an iOS Driver App (SwiftUI for drivers — inspections, trips, earnings, BOL generation). Both share a Supabase backend.

## Core Value

Dispatchers can efficiently manage the full lifecycle of vehicle transport orders — from broker intake through driver assignment, pickup, transit, delivery, and payment — in a single system.

## Requirements

### Validated

<!-- Shipped and confirmed valuable. -->

- Web TMS: Full dispatch workflow (orders, trips, drivers, trucks)
- Web TMS: Load Board with categories (Home to NY, NY to Home, NY to FL, FL to NY)
- Web TMS: Local driver management with fee tracking
- Web TMS: Trip financials (revenue, broker fees, local fees, expenses, driver cut)
- Web TMS: Owner-Operator support with dispatch fee model
- Web TMS: Billing/invoicing with broker payment terms
- Web TMS: Payroll with settlement PDFs
- Web TMS: Executive dashboard and analytics
- Web TMS: Real-time sync across dispatchers
- Web TMS: Central Dispatch Chrome Extension importer
- Web TMS: Fleet mileage (Samsara integration)
- Web TMS: Compliance module (driver files, company files)
- Web TMS: Terminal flow (Mark At Terminal, pending local deliveries)
- iOS App: PIN + email authentication
- iOS App: Trip list and trip detail views
- iOS App: 6-step vehicle inspection flow
- iOS App: BOL generation and email
- iOS App: Expense tracking
- iOS App: Earnings/payroll view
- iOS App: Offline caching
- iOS App: Push notifications
- Web TMS UI redesign mockups — all major pages — v1.1
- Unified design system matching iOS v3 (dark/light theme) — v1.1
- Standalone HTML mockups with theme toggle (no production code changes) — v1.1

### Active

<!-- Current scope. Building toward these. -->

- [ ] Strip all gradients from production CSS — solid colors only
- [ ] Remove all glow/glass effects — clean shadows, solid overlays
- [ ] Simplify shadow system to minimal depth levels
- [ ] Remove decorative animations — keep only functional (spinner, toast, transitions)
- [ ] Clean, professional light and dark themes
- [ ] Status color coding preserved across all pages

## Current Milestone: v1.3 — CSS Polish (Flat & Professional)

**Goal:** Strip gradients, glow effects, heavy shadows, and decorative animations from production. Deliver clean, flat, Stripe-dashboard-tier styling across all pages.

**Target features:**
- Solid color replacements for all gradients (buttons, cards, sidebar, login, chat)
- Simplified shadow system (3 levels max, no color tint)
- Removal of glass/backdrop-filter effects
- Removal of decorative animations (particle rain, shimmer, float, bounce)
- Clean hover states (no scale transforms, no glow)
- Professional light and dark themes with solid backgrounds

## Shipped Milestones

- **v1.0** — Core TMS (phases 1-5, pre-GSD)
- **v1.1** — Web TMS UI Redesign Mockups (phases 6-10, 21 plans, 31 requirements, shipped 2026-02-10)
- **v1.2** — Apply UI Redesign to Production (phases 11-15, abandoned — reverted, direction changed)

## Current State

- Web TMS: ~38,000-line `index.html` with inline JS + 6 external modules
- iOS app: SwiftUI at `Horizon Star LLC Driver App/LuckyCabbage Driver App/`
- Production CSS: `variables.css` (139 lines), `base.css` (301 lines), `print.css` (491 lines)
- Production has gradients, glow shadows, glass effects, 47 animation keyframes, heavy shadows throughout

### Out of Scope

- SaaS multi-tenant transformation (documented but deferred)
- Android driver app
- Customer-facing portal (mockup only)
- Applying v1.1 mockup designs (abandoned in v1.2)

## Context

- Supabase project ref: `yrrczhlzulwvdqjwvhtu`
- Supabase CLI is NOT installed — migrations must be applied via Dashboard SQL Editor
- v1.2 work was reverted (commit `ae70551`) — production is at original styling
- Protected files (DO NOT modify): Config.swift, CacheManager.swift, LocalizationManager.swift

## Constraints

- **Platform**: iOS (SwiftUI) for driver app, vanilla HTML/JS for web TMS
- **Backend**: Supabase (PostgreSQL + REST + Storage) — no server-side code except Edge Functions
- **No build tools**: Web TMS has no bundler, linter, or test suite
- **DB migrations**: Must be applied manually via Supabase Dashboard SQL Editor
- **UI-ONLY**: No layout changes, no behavior changes — CSS polish only
- **Offline**: iOS app must work offline with CacheManager

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Single index.html for Web TMS | No build step, instant deploy | ✓ Good — works well at 38K lines |
| Supabase for backend | Free tier, built-in auth/storage/realtime | ✓ Good |
| SwiftUI for iOS | Modern Apple framework, declarative | ✓ Good |
| Local driver fee preservation | Fees must persist through reassignment | ✓ Good — fixed 2026-02-09 |
| Mockups before code changes | Review and approve designs before touching production index.html | ✓ Good — v1.1 complete |
| v1.2 revert | Mockup-matching approach was too heavy; pivot to flat/professional polish | ✓ Good — simpler direction |
| Flat over gradients | User wants Stripe-tier professional, not shiny/glossy | — Pending |
| Solid shadows only | No color-tinted glow, no glass effects | — Pending |
| Keep functional animations only | Spinners, toasts, transitions stay; decorative effects go | — Pending |

---
*Last updated: 2026-02-11 after v1.3 milestone started*
