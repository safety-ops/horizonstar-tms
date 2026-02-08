# PROJECT.md — Horizon Star LLC Driver App UI/UX Redesign

> **Company:** Horizon Star LLC (VroomX Transport)
> **App Name:** LuckyCabbage Driver App (internal), VroomX Driver (user-facing)
> **Platform:** iOS (SwiftUI)
> **Backend:** Supabase (PostgreSQL + REST + Storage)
> **Version Target:** v3.0.0
> **Prototype Reference:** `mockups/ui_concept_4_driver_app_v3.html`

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Current Architecture](#2-current-architecture)
3. [Design System — Light & Dark Theme](#3-design-system--light--dark-theme)
4. [Screen-by-Screen Implementation Guide](#4-screen-by-screen-implementation-guide)
5. [New Data Models & Schema Changes](#5-new-data-models--schema-changes)
6. [Navigation Architecture](#6-navigation-architecture)
7. [Feature Implementation Details](#7-feature-implementation-details)
8. [Supabase Integration Points](#8-supabase-integration-points)
9. [File-by-File Migration Plan](#9-file-by-file-migration-plan)
10. [Testing Checklist](#10-testing-checklist)
11. [Appendix — Existing Code Reference](#11-appendix--existing-code-reference)

---

## 1. Project Overview

### Objective

Replace the current driver app UI/UX with a modern, professional design based on the interactive HTML prototype (`ui_concept_4_driver_app_v3.html`). The redesign preserves **all existing functionality** (inspections, BOL generation, payments, expenses, signatures, offline sync) while introducing:

1. **Light/Dark Mode** with proper theming across all screens
2. **Redesigned Home Screen** with 4 order modules (Pickup, Delivery, Completed, Archived)
3. **Unified Order Detail View** with map links, ETA buttons, file management, and inspection access
4. **Pay Period Settlement Detail** with PDF/Excel download
5. **Professional Lucide-style SF Symbol** icon system
6. **Map integration** — tap address to open Google/Apple Maps
7. **ETA submission** — drivers provide pickup and delivery ETAs

### What Does NOT Change

- Supabase backend (tables, columns, RLS, storage buckets)
- Authentication flow (PIN + email/password)
- Inspection workflow (6-step: photos → video → exterior → notes → driver review → customer sign-off)
- BOL generation and email sending
- Offline caching (CacheManager)
- Notification system (NotificationManager)
- Localization system (LocalizationManager)

---

## 2. Current Architecture

### Source Location

```
Horizon Star LLC Driver App/
└── LuckyCabbage Driver App/
    ├── LuckyCabbage_Driver_AppApp.swift   # App entry
    ├── Config.swift                        # Supabase config
    ├── Models.swift                        # All data models
    ├── ContentView.swift                   # Root nav (Login vs Main)
    ├── LoginView.swift                     # PIN/Email auth
    ├── SupabaseService.swift               # API client (1,260 lines)
    ├── CacheManager.swift                  # Offline storage
    ├── NotificationManager.swift           # Push notifications
    ├── LocalizationManager.swift           # i18n (EN/GE)
    │
    ├── TripsListView.swift                 # Main dashboard (REPLACE)
    ├── TripDetailView.swift                # Trip detail (UPDATE)
    ├── AllTripsView.swift                  # Trip history
    │
    ├── InspectionView.swift                # Inspection controller
    ├── InspectionPhotoView.swift           # Photo capture
    ├── InspectionVideoCaptureView.swift    # Video capture
    ├── ExteriorInspectionView.swift        # Damage mapping
    ├── InspectionDamageView.swift          # Damage detail
    ├── InspectionNotesView.swift           # Notes/conditions
    ├── InspectionComparisonView.swift      # Before/after
    ├── DriverReviewView.swift              # Driver sign-off
    ├── CustomerReviewView.swift            # Customer flow
    ├── CustomerSignOffView.swift           # Customer signature
    ├── CustomerInspectionDetailView.swift  # Customer-facing
    ├── VehicleDiagrams.swift               # SVG diagrams
    ├── VehicleDiagramView.swift            # Diagram component
    │
    ├── PaymentSheetView.swift              # Payment recording
    ├── PayrollView.swift                   # Trip payroll (UPDATE)
    ├── EarningsHistoryView.swift           # Earnings (UPDATE)
    ├── ExpensesView.swift                  # Expenses
    │
    ├── OrderAttachmentsView.swift          # Files (MOVE TO ORDER DETAIL)
    ├── BOLPreviewView.swift                # BOL display
    ├── BOLGenerator.swift                  # BOL PDF gen
    ├── PDFGenerator.swift                  # PDF utils
    ├── SignaturePadView.swift              # Signature drawing
    ├── OptimizedRouteView.swift            # Route UI
    ├── RouteOptimizer.swift                # Route calculation
    └── SettingsView.swift                  # Settings (UPDATE)
```

### Current Navigation Flow

```
ContentView
├── LoginView (when not authenticated)
└── TripsListView (when authenticated)
    ├── TripDetailView → OrderCards → InspectionView (6-step flow)
    ├── AllTripsView
    ├── PayrollView → EarningsHistoryView
    ├── ExpensesView
    └── SettingsView
```

---

## 3. Design System — Light & Dark Theme

### Color Tokens

Create a new file: **`ThemeManager.swift`**

```swift
import SwiftUI

class ThemeManager: ObservableObject {
    @AppStorage("appTheme") var isDarkMode: Bool = true

    var colorScheme: ColorScheme { isDarkMode ? .dark : .light }
}

// MARK: - Color Extension
extension Color {
    // ─── Semantic Colors (adapt to theme automatically) ───
    static let appBackground = Color("AppBackground")
    static let cardBackground = Color("CardBackground")
    static let cardBackgroundHover = Color("CardBackgroundHover")
    static let elevatedBackground = Color("ElevatedBackground")
    static let borderColor = Color("BorderColor")

    // ─── Brand Colors (same in both themes) ───
    static let brandGreen = Color(hex: "22c55e")        // dark
    static let brandGreenLight = Color(hex: "16a34a")    // light
    static let brandBlue = Color(hex: "3b82f6")
    static let brandAmber = Color(hex: "f59e0b")
    static let brandRed = Color(hex: "ef4444")
    static let brandPurple = Color(hex: "a855f7")
}
```

### Color Asset Catalog Values

Create color sets in `Assets.xcassets`:

| Color Name | Dark Mode | Light Mode |
|---|---|---|
| `AppBackground` | `#09090b` | `#f8f9fa` |
| `CardBackground` | `#18181b` | `#ffffff` |
| `CardBackgroundHover` | `#1f1f23` | `#f3f4f6` |
| `ElevatedBackground` | `#27272a` | `#e5e7eb` |
| `BorderColor` | `rgba(255,255,255,0.06)` | `rgba(0,0,0,0.08)` |
| `TextPrimary` | `#fafafa` | `#111827` |
| `TextSecondary` | `#a1a1aa` | `#4b5563` |
| `TextMuted` | `#52525b` | `#9ca3af` |
| `GreenDim` | `rgba(34,197,94,0.12)` | `rgba(22,163,74,0.10)` |
| `BlueDim` | `rgba(59,130,246,0.12)` | `rgba(37,99,235,0.10)` |
| `AmberDim` | `rgba(245,158,11,0.12)` | `rgba(217,119,6,0.10)` |
| `RedDim` | `rgba(239,68,68,0.12)` | `rgba(220,38,38,0.10)` |

### Typography

```swift
// Primary font: Inter (or system -apple-system as fallback)
// If Inter is not bundled, use .system(design: .default)

static let titleLarge = Font.system(size: 28, weight: .heavy)
static let titleMedium = Font.system(size: 20, weight: .heavy)
static let body = Font.system(size: 14, weight: .regular)
static let bodyBold = Font.system(size: 14, weight: .semibold)
static let caption = Font.system(size: 12, weight: .medium)
static let captionSmall = Font.system(size: 10, weight: .semibold)
static let mono = Font.system(size: 14, weight: .bold).monospacedDigit()
```

### SF Symbols Mapping (Replacing Lucide Icons)

| Lucide Icon | SF Symbol | Usage |
|---|---|---|
| `home` | `house.fill` | Home tab |
| `package` | `shippingbox.fill` | Trips tab |
| `message-circle` | `message.fill` | Messages tab |
| `wallet` | `wallet.pass.fill` | Earnings tab |
| `user` | `person.fill` | Profile tab |
| `car` | `car.fill` | Vehicle icon |
| `truck` | `truck.box.fill` | Truck icon |
| `map-pin` | `mappin.circle.fill` | Location |
| `map` | `map.fill` | Open Maps button |
| `clock` | `clock.fill` | ETA/time |
| `calendar` | `calendar` | Date |
| `route` | `arrow.triangle.swap` | Distance |
| `check-circle` | `checkmark.circle.fill` | Completed |
| `circle` | `circle.fill` | Status dot |
| `arrow-left` | `chevron.left` | Back navigation |
| `search` | `magnifyingglass` | Search |
| `clipboard-list` | `clipboard.fill` | Inspection |
| `camera` | `camera.fill` | Photo capture |
| `file-text` | `doc.text.fill` | Documents/BOL |
| `alert-triangle` | `exclamationmark.triangle.fill` | Issues |
| `phone` | `phone.fill` | Call |
| `credit-card` | `creditcard.fill` | Payment |
| `receipt` | `receipt` | Receipt/expense |
| `fuel` | `fuelpump.fill` | Fuel expense |
| `star` | `star.fill` | Rating |
| `bell` | `bell.fill` | Notifications |
| `moon` | `moon.fill` | Dark mode |
| `sun` | `sun.max.fill` | Light mode |
| `globe` | `globe` | Language |
| `shield` | `shield.fill` | Privacy |
| `dollar-sign` | `dollarsign.circle.fill` | Earnings |
| `bar-chart-3` | `chart.bar.fill` | Charts |
| `banknote` | `banknote.fill` | Payment history |
| `download` | `arrow.down.doc.fill` | Download |
| `table` | `tablecells.fill` | Excel export |
| `archive` | `archivebox.fill` | Archived |
| `key` | `key.fill` | Key photo |
| `plus` | `plus` | Add/extra |
| `edit-3` | `square.and.pencil` | Compose |
| `trash-2` | `trash.fill` | Delete |
| `check` | `checkmark` | Check |
| `image` | `photo.fill` | Photos |
| `wrench` | `wrench.fill` | Tolls/maintenance |
| `coffee` | `cup.and.saucer.fill` | Meals |
| `pen-tool` | `signature` | Signature/BOL |
| `flag` | `flag.fill` | Delivered |

---

## 4. Screen-by-Screen Implementation Guide

### 4.1 Home Screen (MAJOR REDESIGN)

**File:** `TripsListView.swift` → rename to `HomeView.swift`

**Current:** Shows greeting, status ribbon ("Currently On Route — I-10 East / EN ROUTE"), quick stats, current trip hero card, quick actions grid, today's schedule timeline.

**New Design:**

```
┌─────────────────────────────┐
│ Good morning                │ [☀/🌙] [MR]
│ Mike Rodriguez              │
├─────────────────────────────┤
│ ┌──────┬──────┬──────┐      │
│ │ 🚗 5 │ ✅12 │ $6.8k│      │  ← Quick Stats
│ │Active│ Done │Earns │      │
│ └──────┴──────┴──────┘      │
├─────────────────────────────┤
│ [Pickup 2][Deliv 2][Done 3][Arch 2] │  ← Module Tabs
├─────────────────────────────┤
│ ┌───────────────────────┐   │
│ │ 🚗 2024 Tesla Model 3 │   │  ← Order Cards
│ │ 📍 Dallas → Miami     │   │     (filtered by tab)
│ │ VIN: 5YJ3E... · $1,450│   │
│ └───────────────────────┘   │
│ ┌───────────────────────┐   │
│ │ 🚗 2024 Porsche Cayen │   │
│ │ ...                    │   │
│ └───────────────────────┘   │
├─────────────────────────────┤
│ QUICK ACTIONS               │
│ [Inspect][Photos][BOL][Issue]│
└─────────────────────────────┘
```

**REMOVED:** Status ribbon "Currently On Route — I-10 East" and EN ROUTE pill. The today's schedule timeline is also removed. Hero load card is replaced by the tabbed modules.

**Implementation Steps:**

1. **Remove** `status-ribbon` section entirely
2. **Add** `ThemeToggle` button next to avatar in greeting row
3. **Keep** quick stats row (update counts to reflect real order counts by status)
4. **Add** `ModuleTabsView` — a segmented control with 4 tabs:
   - `Pickup` — orders where `delivery_status` is `nil` or `pending_pickup` or `awaiting_pickup`
   - `Delivery` — orders where `delivery_status == "picked_up"` (in transit)
   - `Completed` — orders where `delivery_status == "delivered"`
   - `Archived` — orders from trips with `status == "COMPLETED"` older than 30 days
5. **Each tab** renders a scrollable list of `OrderCardView` components
6. **Each order card** is tappable → navigates to new `OrderDetailView`
7. **Keep** Quick Actions grid at bottom

**SwiftUI Structure:**

```swift
struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var supabase: SupabaseService
    @State private var selectedModule: OrderModule = .pickup

    enum OrderModule: String, CaseIterable {
        case pickup = "Pickup"
        case delivery = "Delivery"
        case completed = "Done"
        case archived = "Archived"
    }

    var filteredOrders: [Order] { /* filter by selectedModule */ }

    var body: some View {
        ScrollView {
            GreetingRow()
            QuickStatsRow()
            ModuleTabsView(selected: $selectedModule)
            ForEach(filteredOrders) { order in
                OrderCardView(order: order)
                    .onTapGesture { navigateToOrderDetail(order) }
            }
            QuickActionsGrid()
        }
    }
}
```

### 4.2 Order Detail Screen (NEW)

**File:** Create new `OrderDetailView.swift`

This is the **core new screen** — accessed by tapping any order card from Home, Trip Detail, or any module.

```
┌─────────────────────────────┐
│ ← Back                      │
├─────────────────────────────┤
│ ┌───────────────────────┐   │
│ │    🚗 (hero image)     │   │  ← Vehicle Hero
│ │ 2024 Tesla Model 3    │   │
│ │ White · Sedan · ORD-9847│  │
│ │ VIN: 5YJ3E1EA8RF214837│   │
│ └───────────────────────┘   │
├─────────────────────────────┤
│ PAYMENT INFO                │
│ ┌──────────┬──────────┐     │
│ │Revenue   │Payment   │     │
│ │$1,450    │COP · Paid│     │
│ ├──────────┼──────────┤     │
│ │Broker Fee│Your Cut  │     │
│ │-$145     │$848      │     │
│ └──────────┴──────────┘     │
├─────────────────────────────┤
│ PICKUP LOCATION             │
│ ┌───────────────────────┐   │
│ │ PICKUP · Stop 1 of 2  │   │
│ │ Dallas, TX         [🗺] │  ← Map icon opens Google/Apple Maps
│ │ 4521 Commerce St...    │   │
│ │ 📞 John M. · (214)... [Call] │
│ │ [⏰ Provide Pickup ETA]│   │  ← ETA Button
│ └───────────────────────┘   │
├─────────────────────────────┤
│ DELIVERY LOCATION           │
│ (same structure as pickup)  │
│ [⏰ Provide Delivery ETA]   │  ← ETA Button
├─────────────────────────────┤
│ DELIVERY PROGRESS           │
│ ✅ Order Created            │
│ ✅ Pickup Inspection        │
│ ✅ Photos Captured          │
│ ✅ Customer Signed BOL      │
│ 🟢 In Transit (pulsing)    │
│ ⬜ Delivery Inspection      │
│ ⬜ Delivered                │
├─────────────────────────────┤
│ NOTES                       │
│ Customer requested...       │
├─────────────────────────────┤
│ FILES & DOCUMENTS           │
│ ┌──────────┬──────────┐     │
│ │📄 BOL    │📋 Inspect │     │
│ │PDF 245KB │PDF 1.2MB │     │
│ ├──────────┼──────────┤     │
│ │📸 Photos │🧾 Receipt │     │
│ │JPG 8.4MB │PDF 89KB  │     │
│ └──────────┴──────────┘     │
├─────────────────────────────┤
│ [Inspect] [BOL] [Contact]   │  ← Action Bar
└─────────────────────────────┘
```

**Data Sources:**

| UI Element | Source Table | Field(s) |
|---|---|---|
| Vehicle title | `orders` | `vehicle_year`, `vehicle_make`, `vehicle_model` |
| Subtitle | `orders` | color (from VIN decode or notes), body type |
| VIN | `orders` | `vehicle_vin` |
| Revenue | `orders` | `revenue` |
| Payment | `orders` | `payment_type`, `payment_status` |
| Broker Fee | `orders` | `broker_fee` |
| Your Cut | Calculated | `(revenue - broker_fee - local_fee) * driver_cut_percent` |
| Pickup City | `orders` | `origin` |
| Pickup Address | `orders` | `origin` (full address) |
| Pickup Contact | NEW | See schema changes below |
| Delivery City | `orders` | `destination` |
| Delivery Address | `orders` | `destination` (full address) |
| Delivery Contact | NEW | See schema changes below |
| Pickup Sequence | `orders` | `pickup_sequence` |
| Delivery Sequence | `orders` | `delivery_sequence` |
| Notes | `orders` | `notes` |
| Files | `order_attachments` | All attachments for this order |
| Timeline | Derived | From `delivery_status` + inspection records |

**Key Interactions:**

1. **Map Icon** — SF Symbol `map.fill` button next to each address. On tap:
   ```swift
   func openInMaps(address: String) {
       let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
       #if targetEnvironment(simulator)
       if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encoded)") {
           UIApplication.shared.open(url)
       }
       #else
       // Try Apple Maps first, fallback to Google
       if let url = URL(string: "maps://?q=\(encoded)") {
           UIApplication.shared.open(url)
       }
       #endif
   }
   ```

2. **ETA Buttons** — Dashed border button with clock icon. On tap, show a time picker or text input. Once set, display "ETA: 2:30 PM" with green checkmark. Save to new `pickup_eta` / `delivery_eta` fields on the order.

3. **Inspect Button** → Navigate to existing `InspectionView` with this order pre-selected

4. **BOL Button** → Navigate to existing `BOLPreviewView`

5. **Contact Button** → Show contact action sheet:
   ```swift
   struct ContactActionSheet {
       static func show(name: String, phone: String) {
           // Action sheet options:
           // 1. "Call {name}" → tel://{phone}
           // 2. "Send SMS" → sms://{phone}
           // 3. "Copy Number" → UIPasteboard.general.string = phone
           // 4. "Cancel"
       }
   }

   // Usage in OrderDetailView:
   Button("Contact") {
       guard let phone = order.pickup_contact_phone else { return }
       let name = order.pickup_contact_name ?? "Contact"
       showContactSheet(name: name, phone: phone)
   }

   // Present as .confirmationDialog:
   .confirmationDialog("Contact \(contactName)", isPresented: $showContactDialog) {
       Button("Call \(contactName)") {
           if let url = URL(string: "tel://\(contactPhone)") {
               UIApplication.shared.open(url)
           }
       }
       Button("Send SMS") {
           if let url = URL(string: "sms://\(contactPhone)") {
               UIApplication.shared.open(url)
           }
       }
       Button("Copy Number") {
           UIPasteboard.general.string = contactPhone
       }
       Button("Cancel", role: .cancel) {}
   }
   ```

6. **Files Grid** → Reuse existing `OrderAttachmentsView` logic in a 2-column grid layout.
   **File tap behavior:**
   ```swift
   // On file tap → determine action by file type:
   func openAttachment(_ attachment: OrderAttachment) {
       guard let urlString = attachment.file_url,
             let url = URL(string: urlString) else { return }

       switch attachment.file_type?.lowercased() {
       case "pdf":
           // Open in-app PDF viewer using QuickLook
           selectedFileURL = url
           showQuickLook = true
       case "image", "jpg", "jpeg", "png":
           // Open full-screen image viewer
           selectedImageURL = url
           showImageViewer = true
       default:
           // Open via system share sheet
           shareFile(url: url)
       }
   }
   ```
   - Files are downloaded from Supabase Storage (`inspection-media` or `receipts` bucket)
   - Use `URLSession` to download to temp directory before presenting
   - Show loading indicator during download
   - Handle download failure with alert: "Unable to load file. Check your connection."

### 4.3 Trip Detail Screens (UPDATE)

**Files:** `TripDetailView.swift`

The prototype contains two trip detail screen variants that represent **different display states** of the same `TripDetailView`:

**Trip Detail (Standard)** — `screen-trip-detail` in prototype:
- Shows trip overview: route, status badge, trip number, miles, dates
- Financial summary grid: Gross Revenue, Broker Fees, Expenses, Driver Cut
- Loads/Vehicles list with `OrderCardView` components (tappable → `OrderDetailView`)
- Expense breakdown by category
- Back navigation to Trips list

**Trip Detail (Expanded/Active)** — `screen-trip-detail-2` in prototype:
- Same layout as standard, but for **active/in-transit trips**
- Includes real-time status indicators (pulsing green dot for "In Transit")
- Shows progress tracker (e.g., "3 of 5 vehicles delivered")
- May include optimized route button linking to `OptimizedRouteView`

**Implementation:** Use a **single `TripDetailView`** with conditional rendering based on `trip.status`:
```swift
// In TripDetailView.swift:
if trip.status == "IN_TRANSIT" || trip.status == "LOADING" {
    ActiveTripHeaderView(trip: trip)  // pulsing status, progress tracker
} else {
    CompletedTripHeaderView(trip: trip)  // static status badge
}
```

**Changes:**
- Keep financial summary grid
- Keep expense section
- Update order/load cards to use new `OrderCardView` component
- Each order card now taps to `OrderDetailView` (not load detail)
- Add back navigation arrow using `chevron.left` SF Symbol
- Add conditional active/completed header rendering

### 4.4 Earnings Screen (UPDATE)

**File:** `EarningsHistoryView.swift` or create `EarningsView.swift`

**Changes:**
- Keep earnings hero card (green gradient)
- Keep breakdown grid (gross, expenses, vehicles, miles)
- Keep bar chart
- **NEW:** Make payment history items tappable → navigate to `SettlementDetailView`
- Add chevron `›` to each payment history row

### 4.5 Settlement Detail Screen (NEW)

**File:** Create new `SettlementDetailView.swift`

```
┌─────────────────────────────┐
│ ← Back to Earnings          │
├─────────────────────────────┤
│ Pay Period: Jan 13 – Jan 26 │
│ $5,920                      │
│ ✅ Paid · Jan 31, 2026      │
├─────────────────────────────┤
│ ┌──────────┬──────────┐     │
│ │Gross Rev │Broker Fee│     │
│ │$9,108    │-$911     │     │
│ ├──────────┼──────────┤     │
│ │Expenses  │Your Cut  │     │
│ │-$624     │$5,920    │     │
│ └──────────┴──────────┘     │
├─────────────────────────────┤
│ TRIPS INCLUDED              │
│ Trip #TRP-2835              │
│ Phoenix → LA · 3 vehicles   │  → $1,950
│ ─────────────────────       │
│ Trip #TRP-2838              │
│ LA → San Diego · 2 vehicles │  → $1,200
├─────────────────────────────┤
│ EXPENSE DETAIL              │
│ ⛽ Fuel (3 stops)    -$487  │
│ 🔧 Tolls             -$87  │
│ ☕ Meals              -$50  │
├─────────────────────────────┤
│ DOWNLOAD SETTLEMENT         │
│ [📄 PDF]  [📊 Excel]        │  ← Download buttons
└─────────────────────────────┘
```

**Data Sources:**
- Settlement data is **calculated** from trips within the pay period date range
- Filter trips by `period_start_date` and `period_end_date`
- Sum orders, expenses, broker fees per trip
- Apply driver cut percentage

**Download Implementation:**

```swift
// PDF Download — extend existing PDFGenerator.swift
func generateSettlementPDF(period: String, trips: [Trip], orders: [Order], expenses: [Expense], driverCut: Double) -> Data {
    // Use existing PDFGenerator patterns
    // Layout: Header with Horizon Star logo, period dates, financial summary table, trip breakdown, expense list
}

// Excel Download — use CSV export (simpler) or TabularData
func generateSettlementCSV(trips: [Trip], orders: [Order], expenses: [Expense]) -> Data {
    var csv = "Trip Number,Route,Vehicles,Gross Revenue,Broker Fees,Net Revenue\n"
    for trip in trips {
        csv += "\(trip.trip_number),\(trip.origin ?? "") → \(trip.destination ?? ""),..."
    }
    return csv.data(using: .utf8)!
}

// Share sheet
func shareFile(data: Data, filename: String) {
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    try? data.write(to: tempURL)
    let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
    // Present
}
```

### 4.6 Inspection Screen (THEME UPDATE ONLY)

**Files:** All `Inspection*.swift` files

**Changes:**
- Apply theme colors to backgrounds, borders, text
- Update vehicle diagram SVG to use theme-adaptive colors (see `VehicleDiagrams.swift`)
- Ensure damage marker colors remain consistent in both themes (they're brand colors, not theme-dependent)
- Update photo slot borders and backgrounds

**Vehicle Diagram Theme Adaptation:**

```swift
// In VehicleDiagrams.swift, update color references:
// Dark: fill="#1a1d25" stroke="rgba(255,255,255,0.15)"
// Light: fill="#e5e7eb" stroke="rgba(0,0,0,0.15)"

// Use Color assets instead of hardcoded:
static let diagramFill = Color("DiagramFill")      // Dark: #1a1d25, Light: #e5e7eb
static let diagramStroke = Color("DiagramStroke")   // Dark: rgba(255,255,255,0.15), Light: rgba(0,0,0,0.15)
```

### 4.7 Messages Screen (KEEP AS-IS WITH THEME)

No structural changes. Apply theme colors only.

### 4.8 Profile/Settings Screen (UPDATE)

**File:** `SettingsView.swift`

**Changes:**
- Add driver stats row at top (Total Trips, Rating, On Time %)
- Add `ThemeToggle` in Preferences section (syncs with `ThemeManager.isDarkMode`)
- Replace `scroll` icon for Privacy Policy with `shield.fill`
- Keep language, notifications, location toggles
- Keep cache/sync info
- Style sign-out button with red dim background

---

## 5. New Data Models & Schema Changes

### New Fields on `orders` Table (Supabase)

```sql
-- Add contact info and ETA fields to orders table
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_contact_name TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_contact_phone TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_contact_name TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_contact_phone TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_eta TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_eta TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS vehicle_color TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS vehicle_body_type TEXT;
```

### Updated `Order` Struct in `Models.swift`

```swift
struct Order: Codable, Identifiable {
    // ... existing fields ...

    // NEW fields
    var pickup_contact_name: String?
    var pickup_contact_phone: String?
    var delivery_contact_name: String?
    var delivery_contact_phone: String?
    var pickup_eta: String?         // ISO8601
    var delivery_eta: String?       // ISO8601
    var vehicle_color: String?
    var vehicle_body_type: String?   // sedan, suv, truck, van, coupe, etc.
}
```

### New Enum: `OrderModule`

```swift
enum OrderModule: String, CaseIterable, Identifiable {
    case pickup = "Pickup"
    case delivery = "Delivery"
    case completed = "Done"
    case archived = "Archived"

    var id: String { rawValue }

    func matches(order: Order, tripStatus: String?) -> Bool {
        switch self {
        case .pickup:
            return order.delivery_status == nil ||
                   order.delivery_status == "pending_pickup" ||
                   order.delivery_status == "awaiting_pickup"
        case .delivery:
            return order.delivery_status == "picked_up"
        case .completed:
            return order.delivery_status == "delivered"
        case .archived:
            return tripStatus == "COMPLETED"
        }
    }
}
```

### Timeline Step Model

```swift
struct TimelineStep: Identifiable {
    let id = UUID()
    let icon: String          // SF Symbol name
    let label: String
    let time: String
    let status: StepStatus    // .done, .active, .pending

    enum StepStatus {
        case done, active, pending
    }
}

// Build timeline from order data:
func buildTimeline(for order: Order, inspection: VehicleInspection?) -> [TimelineStep] {
    var steps: [TimelineStep] = []
    steps.append(.init(icon: "clipboard.fill", label: "Order Created", time: order.created_at ?? "", status: .done))

    if let insp = inspection, insp.inspection_type == "pickup" {
        steps.append(.init(icon: "magnifyingglass", label: "Pickup Inspection",
                          time: insp.completed_at ?? "Pending", status: insp.status == "completed" ? .done : .pending))
        // ... etc
    }

    if order.delivery_status == "picked_up" {
        steps.append(.init(icon: "truck.box.fill", label: "In Transit", time: "In progress", status: .active))
    }
    // ... delivery inspection, delivered
    return steps
}
```

---

## 6. Navigation Architecture

### New Navigation Flow

```
ContentView
├── LoginView (unauthenticated)
└── MainTabView (authenticated)
    ├── Tab 1: HomeView
    │   ├── OrderDetailView (from any order card)
    │   │   ├── InspectionView (6-step flow, existing)
    │   │   ├── BOLPreviewView (existing)
    │   │   └── Maps (external, Apple/Google)
    │   └── Quick Actions → InspectionView, etc.
    │
    ├── Tab 2: TripsView
    │   ├── TripDetailView
    │   │   ├── OrderDetailView (from load card)
    │   │   └── ExpensesView
    │   └── AllTripsView
    │
    ├── Tab 3: MessagesView
    │
    ├── Tab 4: EarningsView
    │   └── SettlementDetailView (from payment history)
    │       └── Share (PDF/Excel)
    │
    └── Tab 5: ProfileView
        └── SettingsView (inline)
```

### Tab Bar Implementation

```swift
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }.tag(0)

            NavigationStack { TripsView() }
                .tabItem { Label("Trips", systemImage: "shippingbox.fill") }.tag(1)

            NavigationStack { MessagesView() }
                .tabItem { Label("Messages", systemImage: "message.fill") }.tag(2)
                .badge(2)

            NavigationStack { EarningsView() }
                .tabItem { Label("Earnings", systemImage: "wallet.pass.fill") }.tag(3)

            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person.fill") }.tag(4)
        }
        .tint(Color.brandGreen)
    }
}
```

---

## 7. Feature Implementation Details

### 7.1 Light/Dark Mode Toggle

**Storage:** `@AppStorage("appTheme")` in `ThemeManager`

**Toggle Points:**
1. Home screen header — sun/moon icon button
2. Profile > Preferences — toggle switch

**Implementation:**

```swift
// In App entry point:
@main
struct LuckyCabbageApp: App {
    @StateObject var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        }
    }
}
```

### 7.2 Map Integration

**Trigger:** Map icon button (SF Symbol `map.fill`) next to pickup and delivery addresses.

```swift
struct MapLinkButton: View {
    let address: String

    var body: some View {
        Button {
            openInMaps(address: address)
        } label: {
            Image(systemName: "map.fill")
                .font(.system(size: 14))
                .foregroundColor(.brandBlue)
                .frame(width: 28, height: 28)
                .background(Color.blueDim)
                .cornerRadius(6)
        }
    }

    func openInMaps(address: String) {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        // iOS: use Apple Maps URL scheme
        if let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}
```

### 7.3 ETA Submission

**UI:** Dashed-border button that shows a DatePicker on tap.

```swift
struct ETAButton: View {
    let label: String  // "Pickup ETA" or "Delivery ETA"
    @Binding var eta: Date?
    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack {
                Image(systemName: eta == nil ? "clock" : "checkmark.circle.fill")
                    .foregroundColor(.brandGreen)
                Text(eta == nil ? "Provide \(label)" : "ETA: \(eta!.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color.greenDim)
            .foregroundColor(.brandGreen)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: eta == nil ? StrokeStyle(lineWidth: 1.5, dash: [6]) : StrokeStyle(lineWidth: 1.5))
                    .foregroundColor(.brandGreen.opacity(0.4))
            )
        }
        .sheet(isPresented: $showPicker) {
            ETAPickerSheet(label: label, eta: $eta)
        }
    }
}
```

**Saving ETA to Supabase:**

```swift
// In SupabaseService.swift, add:
func updateOrderETA(orderId: Int, type: String, eta: Date) async -> Bool {
    let field = type == "pickup" ? "pickup_eta" : "delivery_eta"
    let isoDate = ISO8601DateFormatter().string(from: eta)
    let body: [String: Any] = [field: isoDate]
    // PATCH /rest/v1/orders?id=eq.\(orderId)
    return await patchRecord(table: "orders", id: orderId, body: body)
}
```

### 7.4 File Management Module

Reuse existing `OrderAttachmentsView` logic, but render as a 2-column grid.

```swift
struct FileManagementGrid: View {
    let attachments: [OrderAttachment]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(attachments) { file in
                FileItemView(attachment: file)
            }
        }
    }
}

struct FileItemView: View {
    let attachment: OrderAttachment

    var iconConfig: (String, Color) {
        switch attachment.file_type ?? "" {
        case "pdf": return ("doc.text.fill", .brandBlue)
        case "image": return ("photo.fill", .brandAmber)
        case "doc", "word": return ("doc.fill", .brandPurple)
        default: return ("paperclip", .gray)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconConfig.0)
                .foregroundColor(iconConfig.1)
                .frame(width: 36, height: 36)
                .background(iconConfig.1.opacity(0.12))
                .cornerRadius(8)
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.file_name).font(.system(size: 12, weight: .semibold))
                Text(formatFileSize(attachment.file_size ?? 0))
                    .font(.system(size: 10)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.elevatedBackground)
        .cornerRadius(8)
    }
}
```

### 7.5 Settlement PDF Generation

Extend `PDFGenerator.swift`:

```swift
func generateSettlementPDF(
    driverName: String,
    period: String,
    paidDate: String,
    grossRevenue: Double,
    brokerFees: Double,
    expenses: Double,
    driverCut: Double,
    cutPercent: Double,
    trips: [(tripNumber: String, route: String, vehicles: Int, amount: Double)],
    expenseDetails: [(category: String, amount: Double)]
) -> Data {
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
    return renderer.pdfData { context in
        context.beginPage()
        // Header: "HORIZON STAR LLC — Settlement Statement"
        // Period, paid date, status
        // Financial summary table
        // Trip breakdown table
        // Expense breakdown
        // Footer: Generated date, app version
    }
}
```

### 7.6 Settlement PDF Detailed Layout

The settlement PDF should follow this exact layout structure:

```
┌─────────────────────────────────────────────────┐
│  HORIZON STAR LLC                               │
│  Settlement Statement                           │
│─────────────────────────────────────────────────│
│  Driver: Mike Rodriguez                         │
│  Pay Period: Jan 13, 2026 – Jan 26, 2026        │
│  Status: Paid · Jan 31, 2026                    │
│  Driver Cut: 65%                                │
│─────────────────────────────────────────────────│
│  FINANCIAL SUMMARY                              │
│  ┌─────────────────┬──────────────┐             │
│  │ Gross Revenue    │    $9,108.00 │             │
│  │ Broker Fees      │     -$911.00 │             │
│  │ Net Revenue      │    $8,197.00 │             │
│  │ Total Expenses   │     -$624.00 │             │
│  │ Driver Share(65%)│    $5,920.00 │ ← BOLD     │
│  └─────────────────┴──────────────┘             │
│─────────────────────────────────────────────────│
│  TRIP BREAKDOWN                                 │
│  ┌─────────┬──────────────┬────┬───────────┐    │
│  │ Trip #   │ Route        │ Veh│ Revenue   │    │
│  ├─────────┼──────────────┼────┼───────────┤    │
│  │ TRP-2835│ PHX → LA     │  3 │ $3,200.00 │    │
│  │ TRP-2838│ LA → SD      │  2 │ $2,100.00 │    │
│  │ TRP-2841│ SD → PHX     │  4 │ $3,808.00 │    │
│  └─────────┴──────────────┴────┴───────────┘    │
│─────────────────────────────────────────────────│
│  EXPENSE DETAIL                                 │
│  ┌──────────────┬──────────┬────────────┐       │
│  │ Category      │ Count    │ Amount     │       │
│  ├──────────────┼──────────┼────────────┤       │
│  │ Fuel          │ 3 stops  │   -$487.00 │       │
│  │ Tolls         │ 2 tolls  │    -$87.00 │       │
│  │ Meals         │ 1 meal   │    -$50.00 │       │
│  └──────────────┴──────────┴────────────┘       │
│─────────────────────────────────────────────────│
│  Generated: Feb 6, 2026 · VroomX Driver v3.0   │
└─────────────────────────────────────────────────┘
```

**Settlement calculation logic:**
```swift
func calculateSettlement(trips: [Trip], orders: [Order], expenses: [Expense], driverCutPercent: Double) -> SettlementData {
    let grossRevenue = orders.reduce(0.0) { $0 + ($1.revenue ?? 0) }
    let brokerFees = orders.reduce(0.0) { $0 + ($1.broker_fee ?? 0) }
    let localFees = orders.reduce(0.0) { $0 + ($1.local_fee ?? 0) }
    let totalExpenses = expenses.reduce(0.0) { $0 + ($1.amount ?? 0) }
    let netRevenue = grossRevenue - brokerFees - localFees
    let driverCut = (netRevenue - totalExpenses) * driverCutPercent

    return SettlementData(
        grossRevenue: grossRevenue,
        brokerFees: brokerFees,
        localFees: localFees,
        expenses: totalExpenses,
        netRevenue: netRevenue,
        driverCut: driverCut,
        cutPercent: driverCutPercent
    )
}
```

**Excel/CSV export** generates a `.csv` file (not `.xlsx`) for simplicity. The CSV includes:
- Row 1: Headers — Trip #, Route, Vehicles, Gross Revenue, Broker Fees, Expenses, Net
- Rows 2–N: One row per trip
- Final row: Totals
- Temp storage: `FileManager.default.temporaryDirectory`
- Share via `UIActivityViewController`

### 7.7 Error Handling & Edge Cases

All new screens and components must handle these scenarios gracefully:

**Network Errors:**
```swift
// Standard error handling pattern for all new views:
@State private var errorMessage: String?
@State private var showError = false

func loadData() async {
    do {
        // ... API call
    } catch {
        errorMessage = "Unable to load data. Pull down to retry."
        showError = true
    }
}

// Display as banner or inline message, NOT alert (to match app style)
if let error = errorMessage {
    ErrorBannerView(message: error, onRetry: { Task { await loadData() } })
}
```

**Missing Data Edge Cases:**

| Scenario | Behavior |
|---|---|
| Order has no contact info | Hide contact row entirely; hide Call button in action bar |
| Order has no notes | Show muted text: "No notes for this order" |
| Order has no attachments | Show muted text: "No files uploaded" with dashed border placeholder |
| Order has no VIN | Show "VIN: Not provided" in muted text |
| Order has no pickup/delivery address | Show "Address not available"; hide map icon |
| Trip has 0 expenses | Show "No expenses recorded" in expense section |
| Settlement period has no trips | Show empty state: "No trips in this pay period" |
| ETA already submitted | Show green checkmark + time; button text changes to "Update ETA" |
| Map app not installed | `canOpenURL` check; fallback to Google Maps web URL |
| File download fails | Show alert: "Unable to download file. Check your connection." |
| PDF generation fails | Show alert: "Unable to generate PDF. Please try again." |
| Settlement calculation has $0 | Display $0.00 values normally (don't hide sections) |

**Timeline Edge Cases:**
```swift
func buildTimeline(for order: Order, inspection: VehicleInspection?) -> [TimelineStep] {
    var steps: [TimelineStep] = []

    // Step 1: Always present
    steps.append(.init(icon: "clipboard.fill", label: "Order Created",
                       time: formatDate(order.created_at), status: .done))

    // Step 2: Pickup inspection — only if inspection exists
    if let insp = inspection, insp.inspection_type == "pickup" {
        let status: StepStatus = insp.status == "completed" ? .done : .pending
        steps.append(.init(icon: "magnifyingglass", label: "Pickup Inspection",
                          time: formatDate(insp.completed_at) ?? "Pending", status: status))
    } else if order.delivery_status != nil && order.delivery_status != "pending_pickup" {
        // Inspection happened but data not loaded — show as done
        steps.append(.init(icon: "magnifyingglass", label: "Pickup Inspection",
                          time: "Completed", status: .done))
    }

    // Step 3: Photos — check if inspection_photos exist
    if let insp = inspection, insp.status == "completed" {
        steps.append(.init(icon: "camera.fill", label: "Photos Captured",
                          time: formatDate(insp.completed_at), status: .done))
    }

    // Step 4: BOL signed — check customer_signature
    if let insp = inspection, insp.customer_signature != nil {
        steps.append(.init(icon: "signature", label: "Customer Signed BOL",
                          time: formatDate(insp.completed_at), status: .done))
    }

    // Step 5: In Transit
    if order.delivery_status == "picked_up" || order.delivery_status == "in_transit" {
        steps.append(.init(icon: "truck.box.fill", label: "In Transit",
                          time: "In progress", status: .active))  // Pulsing green dot
    }

    // Step 6: Delivery Inspection
    let deliveryInspDone = order.delivery_status == "delivered"
    steps.append(.init(icon: "clipboard.fill", label: "Delivery Inspection",
                      time: deliveryInspDone ? "Completed" : "Pending",
                      status: deliveryInspDone ? .done : .pending))

    // Step 7: Delivered
    steps.append(.init(icon: "flag.fill", label: "Delivered",
                      time: deliveryInspDone ? "Completed" : "Pending",
                      status: deliveryInspDone ? .done : .pending))

    return steps
}
```

### 7.8 Offline Behavior for New Features

The existing `CacheManager` handles offline storage. New features must integrate:

**ETA Submission (Offline):**
```swift
// When offline, queue the ETA update:
func submitETA(orderId: Int, type: String, eta: Date) async {
    if NetworkMonitor.shared.isConnected {
        await supabase.updateOrderETA(orderId: orderId, type: type, eta: eta)
    } else {
        // Save to CacheManager pending actions queue
        let action = PendingAction(
            table: "orders",
            id: orderId,
            field: type == "pickup" ? "pickup_eta" : "delivery_eta",
            value: ISO8601DateFormatter().string(from: eta),
            timestamp: Date()
        )
        CacheManager.shared.addPendingAction(action)
        // Still update local UI immediately
    }
}
```

**Settlement Detail (Offline):**
- Settlement data is calculated from cached trips/orders/expenses
- PDF/CSV generation works fully offline (no network needed)
- Show "Last synced: {date}" indicator when offline

**Home Module Filtering (Offline):**
- Use cached orders for filtering by `delivery_status`
- Module tab counts reflect cached data
- Show "Offline — showing cached data" banner when no network

**Cache Invalidation Strategy:**
- On app foreground: refresh all trips + orders for current driver
- After ETA submission: refresh the specific order
- After inspection completion: refresh order + trip
- Settlement data: refresh when Earnings tab is selected (debounce 30s)

---

## 8. Supabase Integration Points

### New API Calls Required

| Endpoint | Method | Purpose |
|---|---|---|
| `PATCH /orders?id=eq.{id}` | Update `pickup_eta` | Save pickup ETA |
| `PATCH /orders?id=eq.{id}` | Update `delivery_eta` | Save delivery ETA |
| `GET /orders?trip_id=in.(...)&delivery_status=eq.{status}` | Filter orders by status | Home module filtering |
| `GET /trips?driver_id=eq.{id}&period_start_date=gte.{date}&period_end_date=lte.{date}` | Trips in pay period | Settlement detail |

### Existing API Calls (No Changes)

- `GET drivers?pin_code=eq.{pin}` — Login
- `GET trips?driver_id=eq.{id}` — Fetch trips
- `GET orders?trip_id=eq.{id}` — Fetch orders per trip
- `GET expenses?trip_id=eq.{id}` — Fetch expenses
- `GET order_attachments?order_id=eq.{id}` — Fetch files
- `POST vehicle_inspections` — Create inspection
- `POST inspection_photos` — Upload photo
- All inspection CRUD operations

---

## 9. File-by-File Migration Plan

### Phase 0: Database Schema (MUST RUN FIRST)

Before any Swift code changes, run this migration on Supabase:

```sql
-- Migration: v3_order_fields
-- Run via Supabase SQL Editor or migration CLI
-- Date: 2026-02-06

-- New contact info fields
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_contact_name TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_contact_phone TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_contact_name TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_contact_phone TEXT;

-- New ETA fields
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_eta TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_eta TIMESTAMPTZ;

-- New vehicle detail fields
ALTER TABLE orders ADD COLUMN IF NOT EXISTS vehicle_color TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS vehicle_body_type TEXT;

-- Verify migration:
-- SELECT column_name, data_type FROM information_schema.columns
-- WHERE table_name = 'orders' AND column_name IN
-- ('pickup_contact_name','pickup_eta','vehicle_color');
```

> **IMPORTANT:** The app will still work before this migration runs — new fields are all optional (`String?` in Swift). But ETA submission and contact display will not function until the migration is applied.

### Phase 1: Foundation (Theme + Navigation)

| Priority | Action | File |
|---|---|---|
| 1 | CREATE | `ThemeManager.swift` — theme state management |
| 2 | CREATE | Color assets in `Assets.xcassets` (all color sets from Section 3) |
| 3 | UPDATE | `LuckyCabbage_Driver_AppApp.swift` — inject ThemeManager, set colorScheme |
| 4 | UPDATE | `ContentView.swift` — replace TripsListView with MainTabView |
| 5 | CREATE | `MainTabView.swift` — 5-tab navigation |
| 6 | UPDATE | `Models.swift` — add new Order fields (8 new optional properties) |

### Phase 2: Home Screen + Order Detail

| Priority | Action | File |
|---|---|---|
| 7 | CREATE | `HomeView.swift` — new home screen with modules |
| 8 | CREATE | `OrderCardView.swift` — reusable order card component |
| 9 | CREATE | `ModuleTabsView.swift` — segmented control for home |
| 10 | CREATE | `OrderDetailView.swift` — full order detail screen |
| 11 | CREATE | `MapLinkButton.swift` — map icon component |
| 12 | CREATE | `ETAButton.swift` — ETA submission component |
| 13 | CREATE | `FileManagementGrid.swift` — files 2-col grid |
| 14 | CREATE | `TimelineView.swift` — delivery progress timeline |

### Phase 3: Earnings + Settlement

| Priority | Action | File |
|---|---|---|
| 15 | UPDATE | `EarningsHistoryView.swift` → `EarningsView.swift` — add tappable history |
| 16 | CREATE | `SettlementDetailView.swift` — pay period detail |
| 17 | UPDATE | `PDFGenerator.swift` — add settlement PDF generation |
| 18 | UPDATE | `SupabaseService.swift` — add ETA update method |

### Phase 4: Theme Application

| Priority | Action | File |
|---|---|---|
| 19 | UPDATE | `TripDetailView.swift` — theme colors + new order cards |
| 20 | UPDATE | `SettingsView.swift` → merge into `ProfileView.swift` |
| 21 | UPDATE | `InspectionView.swift` — theme-adaptive colors |
| 22 | UPDATE | `VehicleDiagrams.swift` — theme-adaptive SVG fills |
| 23 | UPDATE | `ExteriorInspectionView.swift` — theme colors |
| 24 | UPDATE | `InspectionPhotoView.swift` — theme colors |
| 25 | UPDATE | All remaining views — consistent theme tokens |

### Phase 5: Cleanup

| Priority | Action | File |
|---|---|---|
| 26 | DEPRECATE | Old TripsListView (replaced by HomeView) |
| 27 | VERIFY | All navigation paths work |
| 28 | VERIFY | Offline caching still functions |
| 29 | VERIFY | Inspection flow end-to-end |
| 30 | VERIFY | Light and dark mode on all screens |

---

## 10. Testing Checklist

### Functional Tests

- [ ] Login with PIN → HomeView displays with correct orders
- [ ] Login with email → HomeView displays with correct orders
- [ ] Home: Pickup tab shows orders awaiting pickup
- [ ] Home: Delivery tab shows orders in transit
- [ ] Home: Completed tab shows delivered orders
- [ ] Home: Archived tab shows old completed orders
- [ ] Home: Tap order card → OrderDetailView opens with correct data
- [ ] OrderDetail: Vehicle info, VIN, payment info display correctly
- [ ] OrderDetail: Pickup address + map icon → opens Apple Maps
- [ ] OrderDetail: Delivery address + map icon → opens Apple Maps
- [ ] OrderDetail: Pickup ETA button → picker → saves to Supabase
- [ ] OrderDetail: Delivery ETA button → picker → saves to Supabase
- [ ] OrderDetail: Inspect button → opens InspectionView for this order
- [ ] OrderDetail: BOL button → opens BOLPreviewView
- [ ] OrderDetail: Contact button → opens phone dialer
- [ ] OrderDetail: Files grid shows correct attachments
- [ ] OrderDetail: Timeline reflects actual order status
- [ ] Trips: Filter tabs work (Active, Completed, Archived)
- [ ] Trips: Trip cards navigate to TripDetailView
- [ ] TripDetail: Load cards navigate to OrderDetailView
- [ ] Earnings: Hero card shows current period totals
- [ ] Earnings: Payment history items tap → SettlementDetailView
- [ ] Settlement: Shows correct trips, expenses, financial breakdown
- [ ] Settlement: PDF download generates and shares correctly
- [ ] Settlement: Excel/CSV download generates and shares correctly
- [ ] Inspection: Full 6-step flow works (photos → video → exterior → notes → driver → customer)
- [ ] Inspection: Damage markers visible in both themes
- [ ] Profile: Theme toggle switches between light/dark
- [ ] Profile: Stats (trips, rating, on-time) display correctly

### Theme Tests

- [ ] Dark mode: All backgrounds use dark tokens
- [ ] Dark mode: All text readable against dark backgrounds
- [ ] Dark mode: Icons visible (use `--icon-default: #a1a1aa`)
- [ ] Dark mode: Green buttons use `color: #000` for contrast
- [ ] Light mode: All backgrounds use light tokens
- [ ] Light mode: All text readable against light backgrounds
- [ ] Light mode: Icons visible (use `--icon-default: #4b5563`)
- [ ] Light mode: Vehicle diagram SVG fills adapt
- [ ] Light mode: Status bar text adapts to light background
- [ ] Theme persists across app restart (@AppStorage)
- [ ] Theme toggle in header syncs with Profile toggle

### Edge Cases

- [ ] Order with no contact info → hide contact row, hide Call button
- [ ] Order with no notes → show "No notes" muted placeholder
- [ ] Order with no attachments → show "No files" dashed placeholder
- [ ] Order with no VIN → show "VIN: Not provided" muted text
- [ ] Order with no address → hide map icon, show "Address not available"
- [ ] Trip with 0 expenses → show "No expenses recorded" placeholder
- [ ] Settlement with no trips → show "No trips in this pay period" empty state
- [ ] Settlement with $0 values → display $0.00 normally (don't hide sections)
- [ ] ETA already submitted → show green checkmark + time, button says "Update ETA"
- [ ] Map app not available → fallback to Google Maps web URL
- [ ] File download failure → show alert with retry option
- [ ] PDF generation failure → show alert "Unable to generate PDF"
- [ ] Offline mode → cached orders display correctly with "Offline" banner
- [ ] Offline ETA submission → queued in CacheManager, synced on reconnect
- [ ] Network reconnect → orders refresh, pending actions sync
- [ ] Large settlement (20+ trips) → PDF pagination works correctly
- [ ] Order with no delivery_status (nil) → shows in Pickup tab correctly

---

## 11. Appendix — Existing Code Reference

### Supabase Configuration (`Config.swift`)

```
Base URL: https://yrrczhlzulwvdqjwvhtu.supabase.co
API Key: [stored in Config.swift]
Storage Buckets: receipts, inspection-media
```

### Existing Table Schema

```
drivers: id, first_name, last_name, email, phone, pin_code, cut_percent
trips: id, trip_number, driver_id, truck_id, status, trip_date, origin, destination, miles, notes, driver_cut_percent, period_start_date, period_end_date
orders: id, trip_id, order_number, vehicle_year, vehicle_make, vehicle_model, vehicle_vin, origin, destination, revenue, payment_type, payment_status, driver_paid_status, driver_paid_amount, driver_paid_method, notes, broker_fee, local_fee, pickup_sequence, delivery_sequence, delivery_status
expenses: id, trip_id, category, amount, description, expense_date, receipt_url, created_at
order_attachments: id, order_id, file_name, file_url, file_type, file_size, uploaded_by, uploaded_at, notes
vehicle_inspections: id, order_id, trip_id, driver_id, inspection_type, vehicle_year/make/model/vin/color, odometer, started_at, completed_at, customer_signature/name/email, driver_signature, condition_*, notes, status, lat/lng/address
inspection_photos: id, inspection_id, photo_type, photo_url, captured_at
inspection_videos: id, inspection_id, video_url, duration_seconds, captured_at
inspection_damages: id, inspection_id, damage_type, view, x_position, y_position, description, photo_url
```

### Payment Types

```
Cash, Zelle, Check, CashApp, Venmo, Card
```

### Delivery Status Values

```
nil (not started), pending_pickup, awaiting_pickup, picked_up, in_transit, delivered
```

### Trip Status Values

```
PLANNED, LOADING, IN_TRANSIT, COMPLETED, CANCELLED
```

### Inspection Types

```
pickup, delivery
```

### Damage Types with Colors

```
scratch: #f59e0b (orange), initial: S
dent:    #ef4444 (red), initial: D
chip:    #3b82f6 (blue), initial: C
broken:  #a855f7 (purple), initial: B
missing: #ec4899 (pink), initial: M
```

### Photo Types (Required + Optional)

```
Required: odometer, left, front, right, rear, top, key (VIN photo)
Optional: extra_1, extra_2, extra_3, extra_4, extra_5
```

### Damage Views

```
side_left, side_right, front, rear, top
```

---

## 12. Development Changelog

All commits to the repository, organized by feature area.

### Infrastructure & Setup
- `a5abf16` Initial commit — Horizon Star TMS
- `1e35a45` Rename app.html to index.html for Netlify deployment
- `733405b` Fix PWA and console errors
- `0720cb7` Fix Netlify build: remove orphaned submodule reference
- `a80c26b` Fix critical bugs: CSS link typo and viewport zoom
- `271a673` Update index.html
- `6a16c57` Expand CLAUDE.md with API signatures, iOS patterns, and architectural details

### Dashboard & Navigation
- `9715adf` Add dashboard period filter & fix navigation jump
- `b73f53b` Add 2027 to all year filters + monthly dashboard filter
- `5ae9ee0` Add All Time health score to Executive Dashboard
- `4ce22f1` Add year filters to all remaining pages (Payroll, Trips, Orders, Local Drivers)
- `1d1f269` Fix year-based date filtering for all financial reports
- `9fa7460` Add Active/Completed/All status filter tabs to Trips page

### Real-time Sync & Data Integrity
- `a7fb60f` Fix real-time sync preserving detail views
- `a851b56` Add null checks to all detail view functions
- `86c847e` Fix real-time sync race condition kicking users from detail views
- `666939f` Fix local_drivers data missing after real-time sync
- `82e6162` Fix data persistence issues across TMS
- `06987d6` Fix 25+ bugs across TMS — comprehensive data accuracy and integrity fixes
- `0e68418` Fix TMS data audit issues
- `455f592` Fix dbFetch to support in.() operator for inspection photos

### PDF & Earnings Statements
- `1d0e9bc` Send earnings statements as PDF attachments via email
- `67442a4` Fix blank PDF in earnings statement email
- `6a4b0ab` Fix blank PDF: use iframe for html2canvas rendering
- `5643c88` Fix PDF content cut off on left side
- `9c4327c` Fix PDF layout: hide print button, proper margins and width
- `e39cf41` Fix PDF: hide print button, adjust widths to 800px
- `1af1b39` Replace html2canvas with jsPDF for pixel-perfect PDF generation
- `ddbeadf` Add company logo to login page, sidebar, and PDF
- `d314342` Fix settlement PDF: table width and email auth variable
- `c4e6fa1` Fix text overlap in settlement PDF summary box
- `d64a09b` Add Owner-Operator company name to settlement PDF
- `28cae8b` Remove top OWNER SETTLEMENT banner from settlement PDF
- `72f721c` Add deductions to Owner-Operator settlement statements
- `08e3ac9` Add Order/Vehicle and Payment Type columns to PDF statements
- `660592d` Enhanced earnings/settlement UI with detailed trip/order view
- `aed5d3d` Add cash collected deduction to Owner-Op settlement statements

### Fleet & Mileage
- `30224d6` Add Fleet Mileage upload feature (Samsara Vehicle Activity Report)
- `82810ae` Add Supabase persistence for fleet mileage data
- `a8b3d3a` Add automatic Samsara API mileage fetch
- `7582a95` Fix Supabase client reference in fleet mileage functions
- `7c92b67` Fix IFTA MPG calculation to use uploaded IFTA miles
- `fe2d3ea` Fix financial reporting data sources for fleet vs trip metrics
- `ffea08f` Fix fleet fuel cost field name (amount not total_cost)

### Financial Features
- `0cc24e3` Add Fuel Card Expenses display and Trip Profitability page
- `56c0f83` Add Owner-Operator driver type with dispatch fee model
- `234efad` Fix financial calculations: Owner-Op, standalone orders, filters
- `031718f` Fix settlement statement TypeError for Owner-Operators
- `44358f1` Fix getTripFin to use string comparison for trip IDs
- `5076c60` Fix: Remove trip expenses from overall business financials
- `9a7cd87` Add Truck P&L Dashboard to Financials (Phase 2A)
- `3bb7009` Add Payment Status Tracker (Phase 2B)
- `123ed60` Phase 2C: PrePass toll integration infrastructure
- `a8e136e` Phase 3: Historical comparison and trends dashboard
- `8963a57` Fix payroll cash collected calculation — exclude LOCAL_COD
- `c33e4cf` Add Driver Cut % display to trip detail header
- `d4a5e48` Add Driver Cut stat card to Trip Detail view

### Trip Map & Route Optimization
- `1e6d65a` Add Trip Map feature with auto-sequence algorithms
- `3673731` Skip pickup stops for terminal pickups (broker_fee or local_fee)
- `94c15db` Fix: Only local_fee determines terminal pickup, not broker_fee
- `6fb2925` Fix Trip Map: Use straight lines instead of Directions API
- `12c2484` Improve geographic auto-sequence algorithm
- `9a16381` Fix geographic auto-sequence to properly interleave stops
- `97f5a31` Improve geographic sort to approximate driving routes
- `06b42da` Simplify Trip Map: keep only Geographic auto-sequence
- `7bd0c5c` Fix latitude sorting to only apply in Oklahoma region

### Driver Management
- `99a0a2d` Add payment info fields to driver form (Pay To, Address, Company)
- `0148296` Add Company EIN field to driver payment info section
- `3b4567f` Split address into separate fields (Street, City, State, Zip)
- `5e65fc1` Add delete button to driver cards
- `4ae6a4d` Add auto-detect vehicle direction + Owner-Op settlement statements
- `2134112` Add driver assignment dropdown to Edit Order modal
- `6b6de99` Sync orders.driver_id when assigning orders to trips
- `de874b3` Fix driver display and add assignment notifications

### Login & Applications
- `4c52523` Fix login page header and footer design
- `bfc7c39` Fix login card covering footer on mobile
- `10f6876` Increase gap between login card and footer on mobile
- `5fe8fc1` Add Privacy Policy to login page footer
- `a9cc470` Add FMCSA-compliant CDL driver employment application
- `e362dce` Add admin Applications review page
- `8c0f59f` Fix supabase client reference in Applications page
- `285d8da` Fix employment history field mapping in driver application
- `804d8b0` Fix file input fields causing submission error

### Billing & Invoicing
- `dbc703f` Add Billing Dashboard, AI Import, and Order Filters
- `043a186` Add database migrations for billing and attachments
- `f56567d` Enhance Billing module with broker-level receivables tracking
- `08ceb24` Redesign invoice/billing UI: theme-aware styling, segmented controls, improved PDF
- `d9f014f` Add broker payment terms, payment terms detection in CD importer, and actual date tracking

### Compliance & Company Files
- `d1f5e97` Add Company Files feature to Compliance module
- `8a724e6` Fix company_files initialization in loadAllData
- `fcb6f9f` Add debug logging for company files
- `8386741` Add error logging for company_files fetch
- `b042b82` Fix company files loading — fetch directly if not cached
- `e46df94` Fix async timing bugs in compliance module render functions

### Dealer Portal
- `8110cd0` Implement Dealer Portal feature
- `b68d61f` Fix dealer portal and image reference issues
- `a9fe65f` Add dealer portal login link and info modal
- `0a9f2ba` Add login form to dealer portal modal

### Terminal & Local Delivery Flow
- `575649d` Add "Mark At Terminal" button to split trip completion and local delivery flow
- `b62efd7` Fix Mark At Terminal not sending orders to pending local deliveries
- `aa3cda0` Add AT_TERMINAL trip status so Mark At Terminal does not complete the trip
- `dfb328f` Fix pending local deliveries year filter excluding AT_TERMINAL trips

### Trucks & Trailers
- `165199d` Add trailer assignment to trucks with exclusive assignment
- `e476469` Fix migration: use INTEGER instead of UUID for assigned_trailer_id

### Inspection & Photos
- `34a4e6e` Fix photo capture button disappearing when switching photo types
- `3428bb7` Fix inspection data flow and BOL signatures
- `9d6b689` Add debug logging for inspection data fetch
- `6c710f1` Fix tracking page and inspection photos data loading

### Orders & AI Import
- `2f1b94e` Add assign/unassign buttons to Orders page
- `7174431` Sort Future Cars by recently added first
- `5d05ef9` Sort vehicles by earliest date in Local Drivers and Future Cars
- `90564b4` Add order contact/ETA fields and clean up duplicate CSS variables
- `aff8bc5` Fix AI Import: use getApiKey() instead of undefined variable
- `a2aa81a` Fix AI Import: handle duplicate order numbers

### Activity Logs & UI Fixes
- `0011cf5` Add dispatcher name to activity logs
- `e770887` Fix activity log dispatcher names and inspection photo filtering
- `a20a4fc` Fix Actions column: ensure buttons are fully visible
- `5ac0169` Fix Actions column clipping — add padding for buttons

### SaaS Planning (Documentation Only)
- `93e159b` Add comprehensive multi-tenant SaaS transformation SOP
- `029ab3e` Update SOP with VroomX TMS branding
- `d350058` Add VroomX TMS landing page with modern black/white design
- `9b4e030` Add VroomX TMS landing page
- `9dd9b60` Add comprehensive SaaS TMS development plan
- `df8c0ed` Add detailed VroomX TMS SaaS development plan

---

*Generated from V3 Prototype Analysis — Feb 6, 2026*
*Updated with error handling, offline behavior, and SQL migration details — Feb 6, 2026*
*Changelog added — Feb 8, 2026*
*Prototype: `mockups/ui_concept_4_driver_app_v3.html`*
*Company: Horizon Star LLC / VroomX Transport*
