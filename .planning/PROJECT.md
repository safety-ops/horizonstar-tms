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

### Active

<!-- Current scope. Building toward these. -->

- Web TMS UI redesign mockups — all major pages
- Unified design system matching iOS v3 (dark/light theme)
- Standalone HTML mockups with theme toggle (no production code changes)

## Current Milestone: v1.1 Web TMS UI Redesign Mockups

**Goal:** Create standalone HTML mockups for every major Web TMS page, applying the iOS v3 design system. Same layout and functionality, modern professional look. Both light and dark mode with toggle. One HTML file per page in `mockups/web-tms-redesign/`.

**Target deliverables:**
- Shared design system (CSS tokens, sidebar, header, common components)
- Core dispatch pages (Dashboard, Load Board, Trips, Orders)
- People & fleet pages (Drivers, Local Drivers, Trucks, Brokers, Dispatchers)
- Financial pages (Payroll, Billing, Financials)
- Operations pages (Fuel, IFTA, Compliance, Maintenance)
- Admin pages (Tasks, Settings, Activity Log, Team Chat)

### Out of Scope

- SaaS multi-tenant transformation (documented but deferred)
- Android driver app
- Customer-facing portal (mockup only)

## Context

- Web TMS is a single ~38,000-line `index.html` with inline JS + 6 external modules
- iOS app at `Horizon Star LLC Driver App/LuckyCabbage Driver App/`
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
| Mockups before code changes | Review and approve designs before touching production index.html | — Pending |
| Match iOS v3 design system | Unified brand across web and mobile products | — Pending |

---
*Last updated: 2026-02-09 after v1.1 milestone definition*
