# iOS Driver App — Reliability Foundation + Restructure

**Status**: Design approved 2026-04-30 — ready to convert to implementation plan
**Owner**: Levani (operator) + Claude (implementation)
**Estimated calendar time**: 3 weeks (15 working days)
**TestFlight checkpoints**: 3 (one per week)

## Context

After today's P0 reliability work (RLS hardening on 40 tables, XSS sweep, edge-function lockdown, importer fixes), the web TMS is in good shape. An audit confirmed the web app shows **no fake or hardcoded data** — every dashboard widget pulls from real Supabase queries.

The same audit found **~10 concrete reliability issues in the iOS driver app** plus structural problems that make those issues hard to fix one-at-a-time:

- Silent failures: drivers complete deliveries that never sync to dispatch
- Lost work: 6-step inspections wipe on app crash (no autosave)
- Empty screens with no retry signal on network blips
- Photos shown as ✓ uploaded while still on-device
- Token expiry → silent disconnection mid-shift
- Web ↔ iOS sync: 30s polling instead of realtime; cache holds forever

Operator wants:
- *"reliable TMS web app, without hardcoded data"* — already true; not in scope
- *"fully reliable end-to-end working mobile app"* — this design
- *"perfectly synced with the TMS"* — covered by the live-sync layer

## Goals

1. **Drivers always know whether something saved.** When they tap "Delivered" or "Submit Inspection", they see either a confirmation or a loud red retry banner — never silent fake-success.
2. **Inspection work survives an app crash.** Mid-flow state persists to disk per-step.
3. **Drivers see dispatcher changes within ~1 second.** Realtime subscriptions replace 30-second polling.
4. **Dispatchers see in-progress inspections.** Live "step 4/6 · 2 min ago" badge in web TMS.
5. **Future iOS work takes hours not days.** The 3,629-line `SupabaseService.swift` becomes 5 focused services with shared reliability primitives.
6. **Future regressions get caught before TestFlight.** ~150-test suite running in CI on every push.

## Non-goals (explicitly out of scope)

- **Offline write queue** — drivers operating with NO signal. Future phase if/when needed.
- **iOS UI/screen tests** — too brittle for the time investment. Manual TestFlight checkpoints fill this gap.
- **Web TMS modularization** — the 51K-line `index.html` split is a separate multi-month project (P2 from earlier).
- **Big UI redesign** — purely visual changes. Could happen in parallel.
- **Backend schema changes** beyond two columns on `vehicle_inspections`.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Views (HomeView, TripDetailView, InspectionView, …)        │
│  Unchanged — they keep working through dependency injection │
└───────────────┬─────────────────────────────────────────────┘
                │ async calls
                ▼
┌─────────────────────────────────────────────────────────────┐
│  Domain services — each owns ONE thing                      │
│  ┌──────────┬──────────┬──────────┬──────────┬───────────┐  │
│  │  Auth    │  Orders  │  Trips   │ Inspect. │ Notif.    │  │
│  │ Service  │ Service  │ Service  │ Service  │ Service   │  │
│  └──────────┴──────────┴──────────┴──────────┴───────────┘  │
└───────────────┬─────────────────────────────────────────────┘
                │ all calls go through
                ▼
┌─────────────────────────────────────────────────────────────┐
│  Reliability foundation (the "envelope")                    │
│   • Result<T> wrapper (.success | .failed)                  │
│   • Auto-retry on network errors (3x, exponential backoff)  │
│   • Auto-refresh JWT on 401                                 │
│   • Surfaces errors to a global ErrorBus                    │
└───────────────┬─────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────┐
│  Supporting services (cross-cutting)                        │
│  ┌──────────────┬──────────────┬───────────────────────┐    │
│  │ CacheManager │ LiveSync     │ InspectionDraftStore  │    │
│  │ (5-min TTL)  │ (realtime    │ (autosaves the 6-step │    │
│  │              │  postgres    │  flow to disk +       │    │
│  │              │  changes)    │  syncs to backend)    │    │
│  └──────────────┴──────────────┴───────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                │
                ▼
        Supabase (the source of truth)
```

### Domain services (replacing the 3,629-line `SupabaseService.swift`)

| Service | Owns | Approx LOC | Source today |
|---|---|---|---|
| **AuthService** | OTP login, token refresh, sign-out, current-user state | ~250 | `SupabaseService.swift:124-450` |
| **OrdersService** | Order list fetch, delivery status, payment, ETA | ~350 | `SupabaseService.swift:950-1250` |
| **TripsService** | Trip list, start/end trip, history | ~300 | `SupabaseService.swift:825-950, 2200-2480` |
| **InspectionsService** | 6-step flow, photo/video upload, completion | ~450 | `SupabaseService.swift:2870-3200` + `InspectionUploadQueue.swift` |
| **NotificationsService** | Driver in-app notifications | ~150 | `SupabaseService.swift:1300-1400` |

Plus three supporting services (composed, not domain-scoped):

| Supporting service | Status | What it does |
|---|---|---|
| **CacheManager** | Existing — gets a 5-min TTL refactor | On-device cache; LiveSync invalidates instantly |
| **LiveSync** | New, ~150 LOC | Subscribes to Supabase realtime postgres_changes for the driver's rows |
| **InspectionDraftStore** | New, ~200 LOC | Autosaves inspection draft to disk + best-effort sync to backend |

## The envelope (reliability foundation)

Every API call routes through one shared function:

```swift
// In OrdersService
func fetchOrders() async -> Result<[Order]> {
    return await api.get(
        "orders?driver_id=eq.\(currentDriverId)&select=*",
        retry: .standard
    )
}

// In a view:
let result = await ordersService.fetchOrders()
switch result {
case .success(let orders): self.orders = orders
case .failed(let reason): /* ErrorBus auto-shows red banner */ break
}
```

What the envelope does:
1. **Retries** transient failures (timeouts, 5xx) — 3 tries with exponential backoff (total wait < 7s)
2. **Refreshes the auth token** on 401, then retries once
3. **Doesn't retry** real failures (4xx other than 401)
4. **Always returns** `.success(data)` or `.failed(reason)` — calling code is forced to handle errors
5. **Pushes failures** to a global `ErrorBus` that shows a red retry banner in the SwiftUI hierarchy

Result for drivers:
- Network blip → red "Couldn't load orders. Tap to retry." banner; retry runs the same call
- Token expires → silent auto-refresh; driver never notices
- Photo upload fails → red badge on that photo; tap to retry just that one
- Mark order delivered → button stays "Saving…" until success or red error; never shows fake success

## Inspection autosave (most user-visible improvement)

### When state gets saved

- After each step transition
- After each photo/video capture (path noted within ~1 sec)
- After text-field commits (notes, VIN, odometer)
- After damage marker added to vehicle diagram
- After signature on driver/customer review steps

Local writes are <10ms — drivers don't see anything different.

### What gets saved

JSON file on device, keyed by `{trip_id, order_id, type}`:

```json
{
  "currentStep": 4,
  "lastSavedAt": "2026-04-30T11:42:13Z",
  "notes": "Mirror crack, see photos",
  "vin": "1HGBH41JXMN109186",
  "odometer": 87543,
  "exteriorConditions": ["clean", "minor_scratches"],
  "damageMarkers": [{"x":0.42,"y":0.18,"side":"front","note":"dent"}],
  "photoFiles": ["...uuid1.jpg", "...uuid2.jpg"],
  "videoFile": "...uuid.mp4",
  "customerSignature": "data:image/png;base64,..."
}
```

Photo/video files stay where iOS already puts them (the upload queue's local cache). The draft just remembers paths.

### Backend sync (operator-approved during brainstorming)

Two columns added to `vehicle_inspections`:
- `current_step INTEGER` (1-6, NULL once completed)
- `draft_state JSONB` (same shape as on-device draft, minus binary data)
- `last_activity_at TIMESTAMPTZ`

Each step transition upserts to backend (best-effort; local save is the source of truth). Web TMS dispatcher view reads `vehicle_inspections WHERE current_step IS NOT NULL` to show in-progress badge:

```
[●● step 4/6 · 2 min ago]   Order #1268124   Levani Grigolia
```

### Recovery flow

On InspectionView load, check for matching draft:
> **Resume inspection?**
> You started this 5 minutes ago and got to **Step 4 of 6**.
> [Resume] [Start fresh]

After successful sync to backend on completion, draft file deleted.

### Edge cases

| Scenario | Behavior |
|---|---|
| App backgrounded | Already saved. Pick up where left off. |
| Phone dies | Draft on disk. Plug in, reopen, resume. |
| Driver discards | Confirmation dialog → draft deleted on confirm. |
| Order reassigned mid-inspection | Show: "This load was reassigned. Photos kept; share via Notes." Draft preserved. |
| Multiple inspections in flight | Each gets its own draft file keyed by trip+order. |
| Drafts older than 7 days | Auto-cleaned on app launch. |

## Live-sync layer

`LiveSync` service:
- One persistent realtime connection on login
- Subscribes to driver's assigned trips, orders, notifications
- Updates the relevant domain service's `@Published` state on changes
- Reconnects automatically on disconnect; re-fetches affected rows

`CacheManager` upgrade:
- 5-minute TTL on each cached entry
- LiveSync events invalidate cache instantly
- Pull-to-refresh wipes cache manually
- Stale reads trigger background refresh

Result: dispatcher changes propagate to driver in ~1 second instead of 30.

## Testing strategy

~150 unit + integration tests, ~30 second runtime:

| Area | Coverage |
|---|---|
| Envelope | retry policy, token refresh, error mapping (~30 tests) |
| Each domain service | happy path, failure path, expired-token path (~40 total) |
| InspectionDraftStore | save/load, crash recovery, multi-inspection isolation, 7-day cleanup (~10) |
| LiveSync | event delivery, reconnect, foreground re-fetch (~10) |
| Integration | login → fetch → mark-delivered round-trip; inspection happy path (~20) |

Excluded: UI tests (XCUITest), real Supabase calls (mocked client used). Manual TestFlight checkpoints cover golden-path UI verification.

CI: GitHub Actions on every push to a branch.

## Rollout plan

3 weeks, 3 TestFlight checkpoints:

### Week 1 — Foundation + Auth
- Days 1-2: envelope (Result, retry, token refresh) + ErrorBus + SwiftUI banner
- Days 3-4: AuthService + tests; migrate OTP login
- Day 5: **TestFlight #1** — login + token refresh verified

### Week 2 — Orders, Trips, Live Sync
- Day 6: OrdersService + tests; migrate orders flows
- Day 7: TripsService + tests; migrate trip flows
- Day 8: LiveSync + 5-min cache TTL
- Day 9: **TestFlight #2** — all non-inspection flows reliable + live
- Day 10: Buffer / fix anything from feedback

### Week 3 — Inspections + Dispatcher Visibility
- Day 11: Backend migration: `current_step`, `draft_state`, `last_activity_at` on `vehicle_inspections`
- Day 12: InspectionDraftStore + InspectionsService + tests; migrate InspectionView
- Day 13: NotificationsService + delete old SupabaseService god-class
- Day 14: Web TMS dispatcher view: in-progress inspection badges
- Day 15: **TestFlight #3** — full reliability foundation + tests in CI

### Rollback strategy per checkpoint

| Failed checkpoint | Rollback action | Recovery time |
|---|---|---|
| #1 (Auth) | Revert auth migration; rest of app unchanged | ~15 min |
| #2 (Orders/Trips/Sync) | Keep auth, revert week 2 work | ~30 min |
| #3 (Inspections) | Keep auth + orders/trips/sync, revert inspection changes | ~30 min |

Strangler-fig pattern keeps the old `SupabaseService` alive until day 13 — selective re-enable possible if anything breaks.

### Operator commitment

| Week | Action |
|---|---|
| 1 | Install TestFlight build, log in once, confirm OTP works |
| 2 | Install build, watch the order list refresh when web TMS changes something |
| 3 | Install build, do a real inspection (or have driver do one). Confirm dispatcher view shows in-progress. |

~45 min total of operator time across the project.

## Open questions / risks

- **Apple TestFlight processing time** — typically 5-15 min, but Apple can occasionally take 1-2 hours. Builds happen near end-of-day so processing happens overnight.
- **Driver behavior during the transition** — drivers will see TestFlight prompts at days 5, 9, 15. We need to alert your team that updates are coming and the new builds carry the same operational behavior plus reliability improvements.
- **Existing in-progress iOS work** — the iOS repo had ~45 modified files at the start of this work (see `Horizon Star LLC Driver App/`). We'll branch off `main` of the iOS repo and merge back at the end. If your team commits to that repo during these 3 weeks, we coordinate a rebase.
- **Tests in CI require GitHub Actions setup** — small one-time setup (~1 hour), included in the timeline.

## What gets delivered

After 3 weeks:
- New `Auth/Orders/Trips/Inspections/Notifications/Service` files in `Horizon Star LLC Driver App/LuckyCabbage Driver App/`
- New `Network/Envelope.swift`, `Network/ErrorBus.swift`, `UI/ErrorBanner.swift`
- New `Realtime/LiveSync.swift`, `Storage/InspectionDraftStore.swift`
- Old `SupabaseService.swift` deleted in final commit
- 1 Supabase migration (vehicle_inspections columns)
- Web TMS update: dispatcher view for in-progress inspections
- ~150 unit/integration tests + GitHub Actions CI workflow
- TestFlight build 36+ shipped to drivers
