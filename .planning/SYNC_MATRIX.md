# TMS + Driver App Sync Matrix (Go-Live)

## Scope
Canonical runtime and contract sync for:
- Web TMS: `index.html`
- Driver iOS: `Horizon Star LLC Driver App/LuckyCabbage Driver App`
- Supabase tables/functions/migrations

## Runtime Source of Truth
- Web runtime: `index.html`
- Auth policy: Supabase session token required for protected operations
- Split payment storage: normalized cash subtype (`COD|COP|LOCAL_COD`) + `cod_amount` + `bill_amount`

## Critical Field Mapping

| Domain | TMS/DB Field | Driver Model Field | Notes |
|---|---|---|---|
| Order identity | `orders.id`, `order_number` | `Order.id`, `order_number` | Canonical key pair |
| Trip linkage | `orders.trip_id` | `Order.trip_id` | Required for trip-level payroll |
| Core payment type | `orders.payment_type` | `Order.payment_type` | Supports legacy `SPLIT` read + normalized write |
| Split cash | `orders.cod_amount` | `Order.cod_amount` | Cash-side amount |
| Split billed | `orders.bill_amount` | `Order.bill_amount` | AR-side amount |
| Payment terms | `orders.payment_terms` | `Order.payment_terms` | `QUICK_PAY`, `NET*` codes |
| Revenue | `orders.revenue` | `Order.revenue` | Gross order revenue |
| Fees | `orders.broker_fee`, `local_fee` | `Order.broker_fee`, `local_fee` | Clean gross basis |
| Driver notes | `orders.notes` | `Order.notes` | Driver-facing notes |
| Scheduled dates | `pickup_date`, `dropoff_date` | `Order.pickup_date`, `dropoff_date` | Route timeline |
| Actual dates | `actual_pickup_date`, `actual_delivery_date` | `Order.actual_pickup_date`, `actual_delivery_date` | Inspection/event-driven updates |
| Delivery state | `delivery_status` | `Order.delivery_status` | pending/picked_up/delivered |
| Addresses | `origin`, `destination`, `pickup_full_address`, `delivery_full_address` | `Order.origin`, `destination`, `pickup_full_address`, `delivery_full_address` | Split address fields remain DB-compatible |

## Canonical Payment Helpers (Driver)
- `Order.paymentBreakdown`
  - Mirrors TMS split/cash/billed logic.
- `Order.tripDriverCashCollectedAmount`
  - Excludes `LOCAL_COD` from trip-driver payroll.
- `Order.invoiceAmount`
  - Billed-side amount for AR displays.

## Auth/Security Contracts
- Web and iOS protected API calls require bearer session token.
- No anon-key bearer fallback for protected operations.
- Signed URL reads for hardened buckets:
  - `inspection-media`
  - `order-attachments`
  - `chatfiles`

## Migration/Schema Parity Checklist
- `20260212000100_auth_storage_hardening.sql`
- `20260212071000_orders_notes_compat.sql`
- Prior orders/payment/address migrations already in release chain

## Baseline Metrics (capture per rollout stage)
- Auth failures (`401/403`) by route/action
- `send-email` failure rate by `kind`
- `media-sign` failure rate by bucket
- Split payroll variance check:
  - `driver net pay delta (TMS vs Driver app)`

## Hard-Gate Acceptance
1. Session-token-only auth behavior passes expiry tests.
2. `orders.notes` exists and loads without schema-cache errors.
3. Split math parity:
   - revenue, cash side, billed side match in TMS + Driver app.
4. Driver payroll deductions match TMS for COD/COP/split cash-side.
5. Signed media open succeeds only for authorized users.
