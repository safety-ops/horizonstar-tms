# iOS Reliability Foundation + Restructure Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the 3,629-line `SupabaseService.swift` god-class with five domain services + a shared "envelope" reliability primitive + autosaving inspections + realtime live-sync, shipped to drivers via three weekly TestFlight checkpoints.

**Architecture:** Strangler-fig migration. Keep the existing `SupabaseService` alive throughout; build new services and primitives next to it; migrate call sites one by one; delete the old file in the final cleanup commit. All API calls route through one envelope that handles retry, token refresh, and error surfacing. Mid-flight inspection state autosaves to disk on every step and best-effort syncs to backend so dispatchers see live progress.

**Tech Stack:** Swift / SwiftUI, async/await, URLSession, Supabase REST + Realtime, JSONDecoder/Encoder, FileManager, XCTest. Backend: Supabase Postgres migrations.

**Reference:** See `docs/plans/2026-04-30-ios-reliability-restructure-design.md` for the full approved design and rationale.

**Repos:** This plan touches **two** repos:
- Web TMS / migrations / web changes: `/Users/reepsy/Desktop/OG TMS CLAUDE/`
- iOS app (separate git repo): `/Users/reepsy/Desktop/OG TMS CLAUDE/Horizon Star LLC Driver App/`

For all iOS tasks, work happens inside the iOS-app working directory. Commits land in that repo's history (origin: `github.com/reepsy/Horizon-Star-Driver-App.git`).

**Branch strategy:** Create `ios-reliability-foundation` branch in the iOS repo. All iOS tasks commit there. The web TMS repo gets its own branch `dispatcher-inspection-progress` for the dispatcher-view changes (week 3).

---

## Pre-flight: branch setup

### Task 0: Create branches in both repos

**Files:** none

**Step 1: Create iOS branch**

```bash
cd "/Users/reepsy/Desktop/OG TMS CLAUDE/Horizon Star LLC Driver App"
git checkout -b ios-reliability-foundation
git status
```

Expected: "On branch ios-reliability-foundation; nothing to commit" (or the existing 45 modified files we discussed earlier — those stay in working tree, that's user WIP).

**Step 2: Create web TMS branch**

```bash
cd "/Users/reepsy/Desktop/OG TMS CLAUDE"
git checkout -b dispatcher-inspection-progress main
git status
```

**Step 3: Verify branches**

```bash
cd "/Users/reepsy/Desktop/OG TMS CLAUDE"
git branch --show-current
cd "Horizon Star LLC Driver App"
git branch --show-current
```

Expected: `dispatcher-inspection-progress` and `ios-reliability-foundation` respectively.

---

# Week 1 — Foundation + Auth

## Task 1: Create the `Result<T>` type

**Files:**
- Create: `Horizon Star LLC Driver App/LuckyCabbage Driver App/Network/Result.swift`
- Test: `Horizon Star LLC Driver App/LuckyCabbageDriverAppTests/Network/ResultTests.swift`

**Step 1: Write the failing tests**

```swift
// ResultTests.swift
import XCTest
@testable import LuckyCabbage_Driver_App

final class ResultTests: XCTestCase {
    func test_success_carriesValue() {
        let r: ApiResult<Int> = .success(42)
        if case .success(let v) = r { XCTAssertEqual(v, 42) }
        else { XCTFail("expected success") }
    }
    func test_failed_carriesReason() {
        let r: ApiResult<Int> = .failed(.network("offline"))
        if case .failed(let reason) = r {
            if case .network(let msg) = reason { XCTAssertEqual(msg, "offline") }
            else { XCTFail("wrong reason") }
        } else { XCTFail("expected failed") }
    }
    func test_isSuccess_helper() {
        XCTAssertTrue(ApiResult.success(1).isSuccess)
        XCTAssertFalse(ApiResult<Int>.failed(.network("x")).isSuccess)
    }
}
```

**Step 2: Run test to verify it fails**

```bash
cd "Horizon Star LLC Driver App"
xcodebuild test -project "LuckyCabbage Driver App.xcodeproj" \
  -scheme "LuckyCabbage Driver App" \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:LuckyCabbageDriverAppTests/ResultTests
```
Expected: FAIL — `ApiResult` not defined.

**Step 3: Write minimal implementation**

```swift
// Result.swift
import Foundation

public enum ApiResult<T> {
    case success(T)
    case failed(EnvelopeError)
    public var isSuccess: Bool {
        if case .success = self { return true } else { return false }
    }
}

public enum EnvelopeError: Error, Equatable {
    case network(String)        // timeout, DNS, conn reset
    case http(Int, String)      // status, body
    case decoding(String)
    case unauthorized           // 401 even after refresh
    case quotaExceeded
    case unknown(String)
    public var userMessage: String {
        switch self {
        case .network: return "Couldn't reach the server. Tap to retry."
        case .http(let s, _): return "Server error \(s). Tap to retry."
        case .decoding: return "Couldn't read server response."
        case .unauthorized: return "Session expired. Please sign in again."
        case .quotaExceeded: return "Too many requests. Try again in a minute."
        case .unknown(let m): return "Something went wrong: \(m)"
        }
    }
}
```

**Step 4: Run test to verify it passes**

Same xcodebuild command. Expected: 3 tests pass.

**Step 5: Commit**

```bash
git add "LuckyCabbage Driver App/Network/Result.swift" "LuckyCabbageDriverAppTests/Network/ResultTests.swift"
git commit -m "feat(network): add ApiResult + EnvelopeError types"
```

---

## Task 2: Create the retry policy

**Files:**
- Create: `LuckyCabbage Driver App/Network/RetryPolicy.swift`
- Test: `LuckyCabbageDriverAppTests/Network/RetryPolicyTests.swift`

**Step 1: Write tests**

```swift
final class RetryPolicyTests: XCTestCase {
    func test_standard_retriesOnNetwork() {
        let p = RetryPolicy.standard
        XCTAssertTrue(p.shouldRetry(error: .network("x"), attempt: 1))
        XCTAssertTrue(p.shouldRetry(error: .network("x"), attempt: 2))
        XCTAssertFalse(p.shouldRetry(error: .network("x"), attempt: 3))
    }
    func test_standard_retriesOn5xx() {
        XCTAssertTrue(RetryPolicy.standard.shouldRetry(error: .http(503, ""), attempt: 1))
    }
    func test_standard_doesNotRetry4xx() {
        XCTAssertFalse(RetryPolicy.standard.shouldRetry(error: .http(400, ""), attempt: 1))
        XCTAssertFalse(RetryPolicy.standard.shouldRetry(error: .http(403, ""), attempt: 1))
    }
    func test_backoffGrows() {
        let p = RetryPolicy.standard
        XCTAssertLessThan(p.delay(attempt: 1), p.delay(attempt: 2))
        XCTAssertLessThan(p.delay(attempt: 2), p.delay(attempt: 3))
    }
    func test_none_neverRetries() {
        XCTAssertFalse(RetryPolicy.none.shouldRetry(error: .network("x"), attempt: 1))
    }
}
```

**Step 2: Run; expect FAIL.**

**Step 3: Implement**

```swift
// RetryPolicy.swift
import Foundation

public struct RetryPolicy {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval

    public static let standard = RetryPolicy(maxAttempts: 3, baseDelay: 0.5)
    public static let none = RetryPolicy(maxAttempts: 1, baseDelay: 0)

    public func shouldRetry(error: EnvelopeError, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
        switch error {
        case .network: return true
        case .http(let status, _): return status >= 500
        default: return false
        }
    }
    public func delay(attempt: Int) -> TimeInterval {
        baseDelay * pow(2.0, Double(attempt - 1))   // 0.5, 1.0, 2.0...
    }
}
```

**Step 4: Run; expect PASS.**

**Step 5: Commit**

```bash
git add LuckyCabbage*/Network/RetryPolicy.swift LuckyCabbageDriverAppTests/Network/RetryPolicyTests.swift
git commit -m "feat(network): add retry policy with exponential backoff"
```

---

## Task 3: Create the network Envelope

**Files:**
- Create: `LuckyCabbage Driver App/Network/Envelope.swift`
- Test: `LuckyCabbageDriverAppTests/Network/EnvelopeTests.swift`

This is the heart of the reliability work — every API call routes through `Envelope.send`.

**Step 1: Write tests** — covering: success path, network retry, 401 → token refresh → retry, 4xx no retry, 500 retry exhaustion.

(Tests use a mock `URLProtocol` to intercept requests and return canned responses. ~10 tests, ~150 LOC. Write them out in full when implementing — too verbose to inline here. Pattern: each test sets up the mock to return N responses, calls envelope.send, asserts result.)

**Step 2: Run; expect FAIL.**

**Step 3: Implement** the envelope (~200 LOC):

```swift
// Envelope.swift  — full file structure
public protocol TokenSource: AnyObject {
    var accessToken: String? { get }
    func refresh() async -> Bool
}

public final class Envelope {
    private let session: URLSession
    private let tokenSource: TokenSource
    private let baseURL: URL
    private let apiKey: String

    public init(baseURL: URL, apiKey: String, tokenSource: TokenSource, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.tokenSource = tokenSource
        self.session = session
    }

    public func get<T: Decodable>(_ path: String, retry: RetryPolicy = .standard) async -> ApiResult<T> {
        await send(path: path, method: "GET", body: nil, retry: retry)
    }
    public func post<T: Decodable>(_ path: String, body: Encodable, retry: RetryPolicy = .none) async -> ApiResult<T> {
        // ...
    }
    public func patch<T: Decodable>(_ path: String, body: Encodable, retry: RetryPolicy = .standard) async -> ApiResult<T> {
        // ...
    }

    private func send<T: Decodable>(path: String, method: String, body: Data?, retry: RetryPolicy) async -> ApiResult<T> {
        var attempt = 0
        var didRefresh = false
        while attempt < retry.maxAttempts {
            attempt += 1
            // Build request, set headers (apikey + Authorization), send
            // On 401: if !didRefresh, await tokenSource.refresh(), retry once
            // On network/5xx: sleep delay, retry
            // On success: decode and return .success
            // On 4xx: return .failed(.http(status, body))
        }
        return .failed(.network("retry exhausted"))
    }
}
```

**Step 4: Run; expect PASS.**

**Step 5: Commit**

```bash
git add LuckyCabbage*/Network/Envelope.swift LuckyCabbageDriverAppTests/Network/EnvelopeTests.swift
git commit -m "feat(network): add Envelope with retry, token refresh, error mapping"
```

---

## Task 4: Create the ErrorBus

**Files:**
- Create: `LuckyCabbage Driver App/Network/ErrorBus.swift`
- Test: `LuckyCabbageDriverAppTests/Network/ErrorBusTests.swift`

**Step 1: Write tests**

```swift
final class ErrorBusTests: XCTestCase {
    func test_publishedError_appearsToObservers() {
        let bus = ErrorBus()
        var received: EnvelopeError?
        let exp = expectation(description: "received")
        let cancel = bus.$current.dropFirst().sink { received = $0; exp.fulfill() }
        bus.publish(.network("x"))
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(received, .network("x"))
        cancel.cancel()
    }
    func test_dismiss_clearsCurrent() {
        let bus = ErrorBus()
        bus.publish(.network("x"))
        bus.dismiss()
        XCTAssertNil(bus.current)
    }
}
```

**Step 2: Run; expect FAIL.**

**Step 3: Implement**

```swift
// ErrorBus.swift
import Combine

public final class ErrorBus: ObservableObject {
    @Published public private(set) var current: EnvelopeError?
    public private(set) var lastRetryAction: (() -> Void)?

    public static let shared = ErrorBus()

    public func publish(_ error: EnvelopeError, retry: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            self.current = error
            self.lastRetryAction = retry
        }
    }
    public func dismiss() {
        DispatchQueue.main.async {
            self.current = nil
            self.lastRetryAction = nil
        }
    }
}
```

**Step 4: Run; expect PASS.**

**Step 5: Commit**

```bash
git commit -am "feat(network): add ErrorBus singleton for surfacing failures to UI"
```

---

## Task 5: Create the SwiftUI ErrorBanner

**Files:**
- Create: `LuckyCabbage Driver App/UI/ErrorBanner.swift`
- Modify: `LuckyCabbage Driver App/ContentView.swift` (mount the banner at root)

No tests for SwiftUI views in this plan — UI verified manually in TestFlight.

**Step 1: Implement the banner**

```swift
// ErrorBanner.swift
import SwiftUI

struct ErrorBanner: View {
    @ObservedObject var bus: ErrorBus = .shared
    var body: some View {
        if let err = bus.current {
            VStack {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(err.userMessage).font(.callout)
                    Spacer()
                    if bus.lastRetryAction != nil {
                        Button("Retry") {
                            let action = bus.lastRetryAction
                            bus.dismiss()
                            action?()
                        }
                    }
                    Button { bus.dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
                .padding(12)
                .background(Color.red.opacity(0.95))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .transition(.move(edge: .top))
                Spacer()
            }
        }
    }
}
```

**Step 2: Mount at app root in ContentView.swift** (overlay on the root ZStack).

**Step 3: Build to verify it compiles**

```bash
xcodebuild build -project "LuckyCabbage Driver App.xcodeproj" \
  -scheme "LuckyCabbage Driver App" \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Step 4: Commit**

```bash
git commit -am "feat(ui): add ErrorBanner mounted at app root, observes ErrorBus"
```

---

## Task 6: Build AuthService + tests

**Files:**
- Create: `LuckyCabbage Driver App/Services/AuthService.swift`
- Test: `LuckyCabbageDriverAppTests/Services/AuthServiceTests.swift`

`AuthService` owns: storing access/refresh tokens, refresh-on-demand, sign-in via OTP, sign-out. Implements `TokenSource` protocol from Task 3.

**Step 1: Write ~10 tests** covering: initial state nil, refresh success updates token, refresh failure clears tokens, signOut clears state, OTP precheck calls RPC, token persistence to Keychain.

**Step 2: Run; expect FAIL.**

**Step 3: Implement (~250 LOC).** API surface:

```swift
public final class AuthService: ObservableObject, TokenSource {
    @Published public private(set) var session: AuthSession?

    public init(envelope: Envelope, keychain: KeychainStore = .default)

    public func sendOTP(email: String) async -> ApiResult<Void>
    public func verifyOTP(email: String, code: String) async -> ApiResult<AuthSession>
    public func signOut() async
    public var accessToken: String? { session?.accessToken }
    public func refresh() async -> Bool   // TokenSource conformance
}
```

Internally migrates the existing OTP precheck path from `SupabaseService.swift:413-455` (already changed to use the `driver_can_login_by_email` RPC).

**Step 4: Run; expect PASS.**

**Step 5: Commit**

```bash
git commit -am "feat(auth): add AuthService — owns tokens, OTP flow, refresh"
```

---

## Task 7: Migrate OTP login views to AuthService

**Files:**
- Modify: `LuckyCabbage Driver App/LoginView.swift` (or wherever OTP screens are)
- Modify: `LuckyCabbage Driver App/SupabaseService.swift` (delete the migrated methods; keep stubs that delegate to AuthService for any missed call sites)

**Step 1: Identify all call sites.** Run:

```bash
grep -nE "SupabaseService\.shared\.(sendOTP|verifyOTP|signOut|currentSession)" -r "LuckyCabbage Driver App/"
```

Expected: ~6-8 sites.

**Step 2: Replace each call site** with `authService.<method>()`. Inject `AuthService` via `@EnvironmentObject` from app root.

**Step 3: Stub the old methods** so anything missed throws a clear error:

```swift
// SupabaseService.swift — temporarily during migration
@available(*, deprecated, message: "Use AuthService instead")
func sendOTP(email: String) async -> Bool {
    fatalError("Migrated to AuthService — should not be called")
}
```

**Step 4: Build + manual smoke test in simulator** — sign in with OTP works end-to-end.

**Step 5: Commit**

```bash
git commit -am "refactor(auth): migrate OTP login views to AuthService"
```

---

## Task 8: TestFlight Checkpoint #1

**Files:** none (build + ship)

**Step 1: Bump build number**

In `LuckyCabbage Driver App.xcodeproj/project.pbxproj`, change `CURRENT_PROJECT_VERSION = 33;` → `34;` (both occurrences).

**Step 2: Archive**

```bash
TIMESTAMP=$(date +%Y%m%d%H%M%S)
xcodebuild -project "LuckyCabbage Driver App.xcodeproj" \
  -scheme "LuckyCabbage Driver App" -configuration Release \
  -destination generic/platform=iOS \
  -archivePath "build/TestFlight-iOS-$TIMESTAMP.xcarchive" \
  -derivedDataPath "build/DerivedData-tf-ios-$TIMESTAMP" \
  -allowProvisioningUpdates archive
```

**Step 3: Export & upload**

```bash
xcodebuild -exportArchive \
  -archivePath "build/TestFlight-iOS-$TIMESTAMP.xcarchive" \
  -exportOptionsPlist build/ExportOptions.plist \
  -exportPath "build/export-$TIMESTAMP" \
  -allowProvisioningUpdates
```

Expected: `** EXPORT SUCCEEDED **`.

**Step 4: Have operator install + verify**

User installs build 34 from TestFlight, signs in via OTP, confirms:
- Sign-in works
- Driver sees their orders/trips like before
- No new errors visible
- Token-expiry behavior: leave the app open for 70 minutes, then make a request — should auto-refresh silently

**Step 5: Commit version bump**

```bash
git commit -am "chore: bump build to 34 (TestFlight checkpoint #1 — Auth foundation)"
```

If the operator reports any issue, revert at this point — the rest of the plan can pause indefinitely without affecting drivers.

---

# Week 2 — Orders, Trips, Live Sync

## Task 9: Build OrdersService

**Files:**
- Create: `LuckyCabbage Driver App/Services/OrdersService.swift`
- Test: `LuckyCabbageDriverAppTests/Services/OrdersServiceTests.swift`

OrdersService owns: fetchOrders, updateDeliveryStatus, updatePaymentStatus, updateOrderETA. Replaces `SupabaseService.swift:950-1250`.

**Step 1: Write tests** (~12 tests) — for each method: happy path, network failure surfaces to ErrorBus, 401 triggers refresh.

**Step 2: Run; expect FAIL.**

**Step 3: Implement** (~350 LOC). API surface:

```swift
public final class OrdersService: ObservableObject {
    @Published public private(set) var orders: [Order] = []

    public init(envelope: Envelope, auth: AuthService, cache: CacheManager)

    public func fetchOrders() async -> ApiResult<[Order]>
    public func updateDeliveryStatus(orderId: Int, status: String,
        actualDate: Date?, localFlow: LocalFlowState?) async -> ApiResult<Void>
    public func updatePaymentStatus(orderId: Int, status: String,
        amount: Double?, method: String?) async -> ApiResult<Void>
    public func updateOrderETA(orderId: Int, type: ETAType, date: Date) async -> ApiResult<Void>
}
```

Each method calls `envelope.get/patch`. Failure path automatically surfaces via ErrorBus (handled inside the envelope; no per-method code).

**Step 4: Run; expect PASS.**

**Step 5: Commit**

```bash
git commit -am "feat(orders): add OrdersService with fetch/update/payment/ETA"
```

---

## Task 10: Migrate orders call sites

**Files:**
- Modify: `LuckyCabbage Driver App/HomeView.swift`, `OrderDetailView.swift`, `InspectionView.swift`, etc.
- Modify: `LuckyCabbage Driver App/SupabaseService.swift` (delete migrated methods)

**Step 1: Find call sites**

```bash
grep -nE "SupabaseService\.shared\.(fetchAllDriverOrders|fetchOrders|updateOrderDeliveryStatus|updatePaymentStatus|updateOrderETA)" -r "LuckyCabbage Driver App/"
```

Expected: ~15 sites.

**Step 2: Replace** each with `ordersService.<method>()` and switch on `.success/.failed`.

**Step 3: Build + simulator smoke test** — open the app, see orders, tap one, mark delivered.

**Step 4: Commit**

```bash
git commit -am "refactor(orders): migrate views to OrdersService"
```

---

## Task 11: Build TripsService

Same pattern as Task 9. Files: `Services/TripsService.swift` + tests. ~300 LOC. Methods: `fetchTrips`, `fetchTripHistory`, `startTrip`, `endTrip`. Replaces `SupabaseService.swift:825-950, 2200-2480`.

**Step 1-5:** Tests → fail → impl → pass → commit. Same shape as Task 9.

```bash
git commit -am "feat(trips): add TripsService with fetch/start/end"
```

---

## Task 12: Migrate trips call sites

Same pattern as Task 10. ~10 call sites.

```bash
git commit -am "refactor(trips): migrate views to TripsService"
```

---

## Task 13: Build LiveSync service

**Files:**
- Create: `LuckyCabbage Driver App/Realtime/LiveSync.swift`
- Test: `LuckyCabbageDriverAppTests/Realtime/LiveSyncTests.swift`

**Step 1: Write tests** (~10) — covering: subscribe-on-login, event delivery to right service, reconnect-on-drop, foreground re-fetch.

**Step 2: Run; expect FAIL.**

**Step 3: Implement** using Supabase Swift Realtime SDK or direct websocket. ~150 LOC. Subscribes to:
- `trips?driver_id=eq.<id>`
- `orders?driver_id=eq.<id>` (and `local_driver_id=eq.<id>` for local-flow drivers)
- `driver_notifications?driver_id=eq.<id>`

On event arrival, calls `ordersService.refresh(orderId:)` etc. — domain services own their `@Published` state.

**Step 4: Run; expect PASS.**

**Step 5: Commit**

```bash
git commit -am "feat(realtime): add LiveSync — postgres realtime → domain services"
```

---

## Task 14: Upgrade CacheManager with TTL

**Files:**
- Modify: `LuckyCabbage Driver App/CacheManager.swift`
- Test: `LuckyCabbageDriverAppTests/CacheManagerTests.swift`

**Step 1: Write tests** — covering: cache returns fresh data, expired data triggers refresh, LiveSync invalidate clears cache instantly.

**Step 2: Modify CacheManager** — add `cachedAt` timestamp per entry; `getOrders()` returns cached only if <5 min old, otherwise returns nil to force refetch.

**Step 3: Add `LiveSync.invalidate(table:rowId:)` hook** that calls `cacheManager.invalidate(...)`.

**Step 4: Run; expect PASS.**

**Step 5: Commit**

```bash
git commit -am "feat(cache): 5-min TTL + LiveSync invalidation"
```

---

## Task 15: TestFlight Checkpoint #2

Same as Task 8. Bump build to 35. Archive + export + upload.

**Operator verification:**
- Open the app; orders + trips load like before
- On the web TMS, change an order's `delivery_status` — the driver's iOS app should reflect within ~2 seconds
- Reassign a driver — original driver's app should remove the order within seconds
- Network blip (toggle airplane mode briefly): error banner appears with Retry; tap Retry → success

```bash
git commit -am "chore: bump build to 35 (TestFlight checkpoint #2 — Orders/Trips/LiveSync)"
```

---

# Week 3 — Inspections + Dispatcher Visibility

## Task 16: Backend migration — inspection draft columns

**Files:**
- Create: `supabase/migrations/20260507000000_inspection_drafts.sql` (in **web TMS repo**, branch `dispatcher-inspection-progress`)

**Step 1: Write migration**

```sql
ALTER TABLE public.vehicle_inspections
  ADD COLUMN IF NOT EXISTS current_step INTEGER,
  ADD COLUMN IF NOT EXISTS draft_state JSONB,
  ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_vehicle_inspections_in_progress
  ON public.vehicle_inspections(last_activity_at DESC)
  WHERE current_step IS NOT NULL;

COMMENT ON COLUMN public.vehicle_inspections.current_step IS
  'When non-null, indicates an in-progress inspection. Cleared on completion.';
```

**Step 2: Push**

```bash
cd "/Users/reepsy/Desktop/OG TMS CLAUDE"
/Users/reepsy/.local/bin/supabase db push --linked
```

Expected: `Finished supabase db push.`

**Step 3: Verify columns added**

```bash
URL='https://yrrczhlzulwvdqjwvhtu.supabase.co'; KEY='<anon>'
curl -s "$URL/rest/v1/vehicle_inspections?select=current_step,draft_state,last_activity_at&limit=1" \
  -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
```

Expected: empty array (anon can't read; RLS works; no schema error).

**Step 4: Commit**

```bash
git add supabase/migrations/20260507000000_inspection_drafts.sql
git commit -m "feat(db): add inspection draft columns to vehicle_inspections"
```

---

## Task 17: Build InspectionDraftStore

**Files:**
- Create: `LuckyCabbage Driver App/Storage/InspectionDraftStore.swift`
- Test: `LuckyCabbageDriverAppTests/Storage/InspectionDraftStoreTests.swift`

**Step 1: Write tests** (~15) — covering: save → reload, partial save survives crash simulation, multiple drafts (different trip+order) don't interfere, 7-day cleanup, draft deletion on completion.

**Step 2: Run; expect FAIL.**

**Step 3: Implement** (~200 LOC). API:

```swift
public final class InspectionDraftStore {
    public init(documentsDir: URL = .documentsDirectory)

    public func saveDraft(_ draft: InspectionDraft) throws
    public func loadDraft(tripId: Int, orderId: Int, type: InspectionType) -> InspectionDraft?
    public func deleteDraft(tripId: Int, orderId: Int, type: InspectionType) throws
    public func cleanupOlderThan(days: Int) throws
}

public struct InspectionDraft: Codable {
    public let tripId: Int
    public let orderId: Int
    public let type: InspectionType
    public var currentStep: Int
    public var lastSavedAt: Date
    public var notes: String?
    public var vin: String?
    public var odometer: Int?
    public var exteriorConditions: [String]
    public var damageMarkers: [DamageMarker]
    public var photoFilePaths: [String]
    public var videoFilePath: String?
    public var customerSignatureBase64: String?
}
```

Files stored at `{documents}/inspection-drafts/draft-trip{id}-order{id}-{type}.json`.

**Step 4: Run; expect PASS.**

**Step 5: Commit**

```bash
git commit -am "feat(inspections): add InspectionDraftStore for autosave"
```

---

## Task 18: Build InspectionsService

**Files:**
- Create: `LuckyCabbage Driver App/Services/InspectionsService.swift`
- Test: `LuckyCabbageDriverAppTests/Services/InspectionsServiceTests.swift`

Owns: starting an inspection, advancing step (saves draft locally + best-effort backend sync), completing inspection. Replaces `SupabaseService.swift:2870-3200`.

**Step 1: Write tests** (~15).

**Step 2: Run; expect FAIL.**

**Step 3: Implement** (~450 LOC). Key methods:

```swift
public func advance(draft: InspectionDraft) async {
    // 1. saveDraft locally (synchronous, fast)
    try? draftStore.saveDraft(draft)
    // 2. fire-and-forget backend sync
    Task {
        let body = ["current_step": draft.currentStep,
                    "draft_state": draft.toBackendJSON(),
                    "last_activity_at": Date()]
        _ = await envelope.patch("vehicle_inspections?id=eq.\(draft.inspectionId)", body: body)
    }
}

public func complete(_ draft: InspectionDraft) async -> ApiResult<Void> {
    // 1. flush all queued media uploads (block until done or fail)
    // 2. PATCH the inspection: status='completed', current_step=null, draft_state=null
    // 3. on success: deleteDraft locally
    // 4. on failure: keep draft, surface to ErrorBus with retry
}
```

**Step 4: Run; expect PASS.**

**Step 5: Commit**

```bash
git commit -am "feat(inspections): add InspectionsService — autosave + completion"
```

---

## Task 19: Migrate InspectionView

**Files:**
- Modify: `LuckyCabbage Driver App/InspectionView.swift`
- Modify: `LuckyCabbage Driver App/SupabaseService.swift` (delete inspection methods)

**Step 1: Replace** all `@State` form vars with bindings into a single `@State var draft: InspectionDraft`. Each user input mutates the draft and triggers `inspectionsService.advance(draft:)`.

**Step 2: Add resume prompt on view appear**

```swift
.onAppear {
    if let existing = draftStore.loadDraft(tripId: tripId, orderId: orderId, type: .pickup) {
        showResumePrompt = true
        pendingDraft = existing
    }
}
.alert("Resume inspection?", isPresented: $showResumePrompt) {
    Button("Resume") { draft = pendingDraft! }
    Button("Start fresh", role: .destructive) {
        try? draftStore.deleteDraft(tripId: tripId, orderId: orderId, type: .pickup)
    }
} message: { Text("You started this inspection \(relativeAgo) and got to step \(pendingDraft?.currentStep ?? 1) of 6.") }
```

**Step 3: Wire completion flow** to `inspectionsService.complete(draft:)`. On `.success`, dismiss view; on `.failed`, banner already showed via ErrorBus.

**Step 4: Manual smoke test** in simulator — start inspection, force-quit app, reopen, verify resume.

**Step 5: Commit**

```bash
git commit -am "refactor(inspections): InspectionView uses draft store + service"
```

---

## Task 20: Build NotificationsService + delete old SupabaseService

**Files:**
- Create: `LuckyCabbage Driver App/Services/NotificationsService.swift`
- Test: `LuckyCabbageDriverAppTests/Services/NotificationsServiceTests.swift`
- Delete: `LuckyCabbage Driver App/SupabaseService.swift`
- Delete: `LuckyCabbage Driver App/InspectionUploadQueue.swift` (functionality moved into InspectionsService)

**Step 1-4:** Same pattern. ~150 LOC service. Tests cover fetchNotifications, markRead, markAllRead.

**Step 5: Verify no remaining SupabaseService.shared references**

```bash
grep -rn "SupabaseService\.shared" "Horizon Star LLC Driver App/" || echo "CLEAN"
```

Expected: `CLEAN`.

**Step 6: Commit**

```bash
git rm "LuckyCabbage Driver App/SupabaseService.swift"
git rm "LuckyCabbage Driver App/InspectionUploadQueue.swift"
git commit -am "refactor: delete SupabaseService god-class — fully migrated"
```

---

## Task 21: Web TMS dispatcher view for in-progress inspections

**Files:**
- Modify: `index.html` (find the Trips or Orders render function; add the in-progress badge)

This task is in the **web TMS repo** branch `dispatcher-inspection-progress`.

**Step 1: Read `appData.inspections` filter** for `current_step IS NOT NULL`.

**Step 2: Add a small badge component**

```js
function renderInProgressInspectionBadge(insp) {
  const minsAgo = Math.floor((Date.now() - new Date(insp.last_activity_at)) / 60000);
  return `<span class="badge badge-progress">
    ${escapeHtml(`step ${insp.current_step}/6`)} · ${minsAgo}m ago
  </span>`;
}
```

**Step 3: Wire into the orders list render** so each row showing an order with an in-progress inspection displays the badge.

**Step 4: Manual verification** — open web TMS in browser; do a partial inspection on a TestFlight iOS build; confirm badge appears within ~3 seconds (one realtime debounce + render).

**Step 5: Commit**

```bash
cd "/Users/reepsy/Desktop/OG TMS CLAUDE"
git commit -am "feat(web): show in-progress inspection badge on orders list"
```

---

## Task 22: Set up CI for iOS tests

**Files:**
- Create: `Horizon Star LLC Driver App/.github/workflows/test.yml`

**Step 1: Write workflow**

```yaml
name: iOS Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: |
          xcodebuild test \
            -project "LuckyCabbage Driver App.xcodeproj" \
            -scheme "LuckyCabbage Driver App" \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -only-testing:LuckyCabbageDriverAppTests \
            CODE_SIGNING_ALLOWED=NO
```

**Step 2: Commit + push** to trigger CI.

**Step 3: Verify** — green check on the GitHub PR/branch.

**Step 4: Commit**

```bash
git commit -am "ci: add GitHub Actions workflow for iOS tests"
```

---

## Task 23: TestFlight Checkpoint #3 + final cleanup

**Files:** none (build + ship)

**Step 1: Bump build to 36** (same as Task 8).

**Step 2: Archive + export + upload** (same as Task 8).

**Step 3: Operator verification** (full system):
- Sign in works (TestFlight prompt to update)
- Orders/trips load + live-update from web TMS changes
- Network blip → red banner with Retry
- Start an inspection on iOS, capture 2 photos, force-quit app, reopen → "Resume inspection?" prompt → tap Resume → form state intact + photos still in gallery
- Complete the inspection → web TMS shows it as completed within seconds
- During inspection (steps 2-5), refresh the web TMS Orders page → see the "step N/6 · M min ago" badge

**Step 4: Merge to main** (in iOS repo)

```bash
cd "Horizon Star LLC Driver App"
git checkout main
git merge --no-ff ios-reliability-foundation -m "Merge ios-reliability-foundation: full restructure + reliability foundation"
git push origin main
```

Same for web TMS repo branch:

```bash
cd "/Users/reepsy/Desktop/OG TMS CLAUDE"
git checkout main
git merge --no-ff dispatcher-inspection-progress -m "Merge dispatcher-inspection-progress: live in-progress inspection badges"
git push origin main
```

**Step 5: Tag**

```bash
cd "Horizon Star LLC Driver App"
git tag -a ios-reliability-foundation-shipped -m "iOS reliability foundation + restructure shipped 2026-05-21"
git push origin ios-reliability-foundation-shipped
```

---

# Skill references

- **For executing this plan:** `superpowers:executing-plans` (parallel session) OR `superpowers:subagent-driven-development` (this session, fresh subagent per task)
- **For each task's red/green/refactor cycle:** `superpowers:test-driven-development`
- **For TestFlight builds:** see memory `reference_testflight_deployment.md`
- **For commits:** never `--no-verify`, never bypass the migration pre-commit hook installed in `.githooks/`

---

## Plan complete. Two execution options:

**1. Subagent-Driven (this session)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Parallel Session (separate)** — Open a new session with `superpowers:executing-plans`, batch execution with checkpoints.

Which approach?
