# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Horizon Star TMS** — A Transportation Management System for Horizon Star LLC (VroomX Transport). The repo contains two main products:

1. **Web TMS** (`index.html`) — A single-page PWA for fleet management, dispatching, payroll, and operations
2. **iOS Driver App** (`Horizon Star LLC Driver App/LuckyCabbage Driver App/`) — A SwiftUI app for drivers (inspections, trips, earnings, BOL generation)

Both products share the same **Supabase** backend (PostgreSQL + REST + Storage).

## Running / Development

- **Web TMS**: Open `index.html` directly in a browser (no build step, no bundler). All JS/CSS is loaded via `<script>` and `<link>` tags.
- **iOS App**: Open the Xcode project in `Horizon Star LLC Driver App/`. Build target is `LuckyCabbage Driver App`.
- **Supabase Edge Functions**: Deploy with `supabase functions deploy send-email`. Set secrets with `supabase secrets set RESEND_API_KEY=re_xxxxx`.
- **Chrome Extension** (`cd-load-importer/`): Load unpacked in `chrome://extensions/` with Developer mode enabled.

There are no test suites, linters, or build commands.

## Web TMS Architecture

The web app is a **single ~38,000-line `index.html`** file with all page rendering functions inline, plus 6 external JS modules:

| File | Purpose |
|---|---|
| `assets/js/config.js` | Supabase client init, global state (`appData`, `currentUser`), pagination, data cache |
| `assets/js/app.js` | `initApp()` bootstrap, DOM ready handler |
| `assets/js/api.js` | `dbFetch()`, `dbInsert()`, `dbUpdate()`, `dbDelete()`, realtime sync, `loadAllData()` |
| `assets/js/auth.js` | Login/logout, session timeout, PIN lockout, password reset |
| `assets/js/ui.js` | Theme toggle, toasts (`showToast()`), sidebar, modals (`showModal()`), loading states |
| `assets/js/utils.js` | `formatMoney()`, `formatDate()`, `escapeHtml()`, validators |
| `assets/css/variables.css` | CSS custom properties for light/dark theming |
| `assets/css/base.css` | Global layout and component styles |

**Rendering pattern**: Each page has a `renderXxx(c)` function (e.g., `renderTrips(c)`, `renderOrders(c)`) that takes a container element and builds DOM via template literals with `innerHTML`. Navigation uses `navigate(page)` which calls `renderPage()` → dispatches to the correct render function. All state lives in the global `appData` object populated by `loadAllData()`.

**Key conventions**:
- Theme: CSS variables (`--bg-primary`, `--text-primary`, etc.) with `.dark-theme` class toggle
- Data: All tables cached in `appData.trips`, `appData.orders`, etc.
- XSS prevention: Use `escapeHtml()` for user-provided text in templates
- Supabase client: Global `sb` variable initialized in `config.js`
- Auth: `currentUser` object stored in localStorage (`horizonstar_user`)

## iOS Driver App Architecture

Swift/SwiftUI app at `Horizon Star LLC Driver App/LuckyCabbage Driver App/`. Key files:

- `Config.swift` — Supabase URL/key (DO NOT modify)
- `Models.swift` — All data models (`Order`, `Trip`, `Inspection`, etc.)
- `SupabaseService.swift` — API client (~1,260 lines)
- `CacheManager.swift` — Offline storage (DO NOT modify)
- `ContentView.swift` → `MainTabView.swift` — 5-tab navigation (Home, Trips, Messages, Earnings, Profile)
- `HomeView.swift` — Main dashboard with order modules (Pickup/Delivery/Completed/Archived)
- `OrderDetailView.swift` — Vehicle detail, payments, map links, ETA, files, timeline
- `InspectionView.swift` — 6-step inspection flow (photos → video → exterior → notes → driver review → customer sign-off)
- `ThemeManager.swift` — Light/dark mode via `@AppStorage`
- Color assets in `Assets.xcassets/Colors/` — always use asset colors, never hardcode hex

**Protected files** (do not modify): `Config.swift`, `CacheManager.swift`, `LocalizationManager.swift`, inspection workflow logic.

## Supabase

- Project ref in `supabase/.temp/project-ref`
- Migrations in `supabase/migrations/` (chronological SQL files)
- Edge function: `supabase/functions/send-email/index.ts` (Resend email API)
- Tables: `orders`, `trips`, `drivers`, `trucks`, `expenses`, `inspections`, `brokers`, `fuel_transactions`, `maintenance_records`, `claims`, `tickets`, `violations`, `company_files`, `dealers`, `tasks`, etc.

## Chrome Extension (cd-load-importer)

Manifest V3 extension that scrapes load data from Central Dispatch and imports it into the TMS via Supabase. See `CLAUDE_CODE_SOP_LOAD_IMPORTER.md` for the full implementation spec.

## Important Notes

- The Supabase anon key in `config.js` is a public/anon key (safe to be in client code, protected by RLS)
- `index.html` contains both HTML structure and ~30,000 lines of JavaScript — when editing, search for the relevant `renderXxx()` function rather than scrolling
- `mockups/` and `prototypes/` contain standalone HTML design mockups, not production code
- `AGENT_PROMPT.md` contains the phased implementation guide for the iOS driver app UI overhaul
- `PROJECT.md` contains the detailed iOS app redesign specification
