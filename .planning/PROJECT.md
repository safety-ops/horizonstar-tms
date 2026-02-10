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

- [ ] Apply v1.1 design system (CSS variables, tokens, component styles) to production index.html
- [ ] Dark/light theme toggle working in production
- [ ] Every page visually matches approved mockups (colors, typography, spacing, shadows, borders)
- [ ] No layout changes — same page structure, sections, element positions
- [ ] No behavior changes — all JS logic, functionality, and features identical
- [ ] Production sidebar nav order preserved exactly

## Current Milestone: v1.2 — Apply UI Redesign to Production

**Goal:** Apply the approved v1.1 mockup designs to the live production index.html — purely visual changes, no layout or behavior modifications.

**Target features:**
- Production design system (CSS variables from shared.css → variables.css/base.css)
- Dark/light theme toggle in production
- All pages restyled: dashboard, dispatch, people & fleet, financials, operations & admin
- Component styles: cards, tables, buttons, modals, forms, badges, nav

## Shipped Milestones

- **v1.0** — Core TMS (phases 1-5, pre-GSD)
- **v1.1** — Web TMS UI Redesign Mockups (phases 6-10, 21 plans, 31 requirements, shipped 2026-02-10)

## Current State

- Web TMS: ~38,000-line `index.html` with inline JS + 6 external modules
- iOS app: SwiftUI at `Horizon Star LLC Driver App/LuckyCabbage Driver App/`
- UI Redesign: 26 mockup files (24,516 lines) in `mockups/web-tms-redesign/` — approved, ready to apply to production
- Design system: `mockups/web-tms-redesign/shared.css` (1,308 lines) with iOS v3 color tokens, dark/light theming

### Out of Scope

- SaaS multi-tenant transformation (documented but deferred)
- Android driver app
- Customer-facing portal (mockup only)

## Context

- Supabase project ref: `yrrczhlzulwvdqjwvhtu`
- Supabase CLI is NOT installed — migrations must be applied via Dashboard SQL Editor
- Existing PROJECT.md in root has detailed iOS v3 redesign spec (1,650 lines)
- Prototype reference: `mockups/ui_concept_4_driver_app_v3.html`
- Protected files (DO NOT modify): Config.swift, CacheManager.swift, LocalizationManager.swift

## Constraints

- **Platform**: iOS (SwiftUI) for driver app, vanilla HTML/JS for web TMS
- **Backend**: Supabase (PostgreSQL + REST + Storage) — no server-side code except Edge Functions
- **No build tools**: Web TMS has no bundler, linter, or test suite
- **DB migrations**: Must be applied manually via Supabase Dashboard SQL Editor
- **Offline**: iOS app must work offline with CacheManager

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Single index.html for Web TMS | No build step, instant deploy | ✓ Good — works well at 38K lines |
| Supabase for backend | Free tier, built-in auth/storage/realtime | ✓ Good |
| SwiftUI for iOS | Modern Apple framework, declarative | ✓ Good |
| Local driver fee preservation | Fees must persist through reassignment | ✓ Good — fixed 2026-02-09 |
| Mockups before code changes | Review and approve designs before touching production index.html | ✓ Good — v1.1 complete |
| Match iOS v3 design system | Unified brand across web and mobile products | ✓ Good — design system created |
| Dark theme default | Consistency with iOS, reduces eye strain | ✓ Good |
| Pure CSS variables, no preprocessor | Simple mockups, no build step | ✓ Good |
| UI-ONLY constraint for redesign | No functionality changes during visual redesign | ✓ Good — clean separation |
| Sidebar nav from production | Mockup sidebar differs; use production order when applying | ✓ Good — confirmed for v1.2 |
| No layout changes in v1.2 | Apply visual design only, keep DOM structure identical | — Pending |

---
*Last updated: 2026-02-10 after v1.2 milestone started*
