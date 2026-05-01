// Phase B of the per-trip Samsara mileage tracking feature.
// Reference plan: .claude/plans/hey-i-notcied-cozy-waterfall.md
// Phase A migration: supabase/migrations/20260501190000_trip_mileage_tracking.sql
//
// All DB reads and writes use the service role client (SUPABASE_SERVICE_ROLE_KEY)
// to bypass RLS and the block_trips_field_escalation trigger. That trigger
// already contains an explicit `IF current_user = 'service_role' THEN RETURN NEW`
// early-exit (rls_tier3.sql:314), so no trigger manipulation is needed.
// The odometer columns (trip_started_at, start_odometer, end_odometer, etc.) are
// NOT in the trigger's "allowed" list, meaning a driver-role JWT would be blocked
// even for legitimate writes — the service role bypass is the correct path.
//
// Authorization is enforced in application code: caller must be either the driver
// assigned to the trip (drivers.auth_user_id = auth.uid() from their JWT) or TMS
// staff (is_tms_staff() evaluated by querying the users table via service role).
//
// Deploy: supabase functions deploy record-trip-odometer
// Secrets: SUPABASE_SERVICE_ROLE_KEY (injected automatically by Supabase),
//          ALLOWED_ORIGINS (comma-sep, same as send-email)
// No SAMSARA_API_TOKEN secret — the Samsara key is read from app_settings table
// (key='samsara', value->>'api_key'), consistent with the Web TMS pattern.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// ---------- Env ----------
const SUPABASE_URL              = Deno.env.get("SUPABASE_URL") ?? ""
const SUPABASE_ANON_KEY         = Deno.env.get("SUPABASE_ANON_KEY") ?? ""
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
  .split(",").map(s => s.trim()).filter(Boolean)

// Samsara API endpoint for live vehicle stats (OBD odometer).
const SAMSARA_STATS_URL = "https://api.samsara.com/fleet/vehicles/stats"

// AbortController timeout for the Samsara HTTP call — 12 seconds matches
// the Web TMS samsaraFetch() timeout (index.html:42525-42572).
const SAMSARA_TIMEOUT_MS = 12_000

// A reading older than this is considered stale (Samsara gateway may be
// caching a disconnected ELD). Reject it and fall through to the warning path.
const SAMSARA_MAX_READING_AGE_MS = 15 * 60 * 1_000  // 15 minutes

// ---------- CORS ----------
// If ALLOWED_ORIGINS is not configured, allow * as a fallback so the iOS app
// and Web TMS can reach the function during development.
// TODO: set ALLOWED_ORIGINS before production hardening of this function.
function corsHeadersFor(origin: string | null): Record<string, string> {
  let allowOrigin: string
  if (ALLOWED_ORIGINS.length === 0) {
    // No allowlist configured — permissive fallback (see TODO above).
    allowOrigin = "*"
  } else {
    allowOrigin = origin && ALLOWED_ORIGINS.includes(origin) ? origin : ""
  }
  return {
    "Access-Control-Allow-Origin":  allowOrigin,
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  }
}

function json(
  status: number,
  payload: Record<string, unknown>,
  origin: string | null,
): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeadersFor(origin), "Content-Type": "application/json" },
  })
}

// ---------- Types ----------
interface TripRow {
  id:              number
  driver_id:       number | null
  truck_id:        number | null
  status:          string | null
  trip_started_at: string | null
  trip_ended_at:   string | null
  start_odometer:  number | null
  end_odometer:    number | null
  miles_driven:    number | null
  samsara_vehicle_id: string | null
}

interface DriverRow {
  id:           number
  auth_user_id: string | null
}

// ---------- Samsara fetch ----------
// Calls the Samsara OBD odometer stats endpoint for a single vehicle.
// Returns { odometer_miles, reading_time } on success or throws with a
// short human-readable message on any failure.
//
// NOTE: Phase B implements the direct Bearer-token path only. The proxy_url
// stored alongside the Samsara key in app_settings is NOT used here. The
// Edge Function runs server-side and can reach api.samsara.com directly,
// so the proxy (a Cloudflare Workers relay for browser CORS) is unnecessary.
// If a network egress restriction requires it in future, wire proxy_url support
// the same way samsaraFetch() in index.html does.
async function fetchSamsaraOdometer(
  vehicleId: string,
  apiKey: string,
): Promise<{ odometer_miles: number; reading_time: Date }> {
  const url = `${SAMSARA_STATS_URL}?types=obdOdometerMeters&vehicleIds=${encodeURIComponent(vehicleId)}`
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), SAMSARA_TIMEOUT_MS)

  let res: Response
  try {
    // The Samsara API key is NOT logged — only its presence is noted below.
    console.log("Fetching Samsara odometer — token present:", apiKey.length > 0, "vehicleId:", vehicleId)
    res = await fetch(url, {
      headers: { Authorization: `Bearer ${apiKey}` },
      signal: controller.signal,
    })
  } catch (err) {
    if ((err as { name?: string }).name === "AbortError") {
      throw new Error("samsara_timeout")
    }
    throw new Error(`samsara_network_error: ${(err as Error).message}`)
  } finally {
    clearTimeout(timer)
  }

  if (!res.ok) {
    throw new Error(`samsara_http_${res.status}`)
  }

  // Expected response shape (Samsara Fleet API v1):
  //   { data: [{ id: "<vehicleId>", obdOdometerMeters: { value: <int>, time: "<ISO8601>" } }] }
  //
  // ASSUMPTION A: `obdOdometerMeters` is always a flat object with `value` and `time`
  // at the top level of the per-vehicle entry. The Samsara docs show two sub-shapes
  // depending on the stat type — point stats use { value, time } directly on the
  // type key, while history stats wrap them in an array. The `stats` endpoint (used
  // here, not `stats/history`) returns the point shape. If Samsara changes this
  // in a future API version this parse will return undefined and fall through to
  // the samsara_parse_error warning path rather than crashing.
  //
  // ASSUMPTION B: when `vehicleIds` has exactly one ID, `data` is a single-element
  // array. We take data[0] and verify its `id` matches to guard against Samsara
  // ever returning a wrong-vehicle entry.
  let body: unknown
  try {
    body = await res.json()
  } catch {
    throw new Error("samsara_invalid_json")
  }

  const data = (body as Record<string, unknown>)?.data
  if (!Array.isArray(data) || data.length === 0) {
    throw new Error("samsara_parse_error: data array missing or empty")
  }

  const entry = data[0] as Record<string, unknown>
  if (entry?.id !== vehicleId) {
    // Belt-and-suspenders: vehicle ID mismatch — refuse the reading.
    throw new Error(`samsara_parse_error: returned vehicle ${entry?.id}, expected ${vehicleId}`)
  }

  const obd = entry?.obdOdometerMeters as Record<string, unknown> | undefined
  const meters = typeof obd?.value === "number" ? obd.value : undefined
  const timeStr = typeof obd?.time === "string" ? obd.time : undefined

  if (meters === undefined || timeStr === undefined) {
    throw new Error("samsara_parse_error: obdOdometerMeters value/time missing")
  }

  const readingTime = new Date(timeStr)
  if (isNaN(readingTime.getTime())) {
    throw new Error(`samsara_parse_error: unparseable time string "${timeStr}"`)
  }

  // Staleness check — the ELD may be offline and the gateway returns the last
  // cached reading. If it is older than SAMSARA_MAX_READING_AGE_MS we reject it.
  const ageMs = Date.now() - readingTime.getTime()
  if (ageMs > SAMSARA_MAX_READING_AGE_MS) {
    const ageMin = Math.round(ageMs / 60_000)
    throw new Error(`samsara_stale_reading: reading is ${ageMin} minutes old (max 15)`)
  }

  // Meters → miles. Round to 1 decimal place.
  const miles = Math.round(meters * 0.000621371 * 10) / 10
  return { odometer_miles: miles, reading_time: readingTime }
}

// ---------- Error sanitization ----------
// Maps internal Samsara error messages to safe public codes so that Samsara
// internals (vehicle IDs, parse details, network stack traces) are never
// surfaced in API responses. The full internal message is still logged for ops.
function publicErrorCode(internalMsg: string): string {
  if (!internalMsg) return "samsara_unknown_error"
  const m = internalMsg.toLowerCase()
  if (m.includes("timeout"))       return "samsara_timeout"
  if (m.startsWith("samsara_http_")) return internalMsg.split(":")[0]  // e.g. "samsara_http_401"
  if (m.includes("parse_error"))   return "samsara_parse_error"
  if (m.includes("stale"))         return "samsara_stale_reading"
  if (m.includes("network"))       return "samsara_network_error"
  return "samsara_fetch_failed"
}

// ---------- Main handler ----------
serve(async (req) => {
  const requestOrigin = req.headers.get("origin")

  // CORS preflight.
  if (req.method === "OPTIONS") {
    if (ALLOWED_ORIGINS.length === 0 || (requestOrigin && ALLOWED_ORIGINS.includes(requestOrigin))) {
      return new Response("ok", { headers: corsHeadersFor(requestOrigin) })
    }
    return new Response("forbidden", { status: 403 })
  }

  // Only POST is accepted.
  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed." }, requestOrigin)
  }

  try {
    return await handleRequest(req, requestOrigin)
  } catch (err) {
    console.error("Unhandled exception in record-trip-odometer:", err)
    return json(500, { error: "Internal error." }, requestOrigin)
  }
})

async function handleRequest(req: Request, requestOrigin: string | null): Promise<Response> {
  // 1. Env sanity check.
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error("Supabase env vars missing")
    return json(500, { error: "Server configuration error." }, requestOrigin)
  }

  // 2. Parse and validate request body.
  let body: unknown
  try {
    body = await req.json()
  } catch {
    return json(400, { error: "Invalid JSON body." }, requestOrigin)
  }

  const raw = body as Record<string, unknown>

  // trip_id: must be a positive integer (accept number or numeric string).
  const rawTripId = raw?.trip_id
  const trip_id = typeof rawTripId === "number"
    ? rawTripId
    : typeof rawTripId === "string"
      ? Number(rawTripId)
      : NaN
  if (!Number.isInteger(trip_id) || trip_id <= 0) {
    return json(400, { error: "trip_id must be a positive integer." }, requestOrigin)
  }

  // event: must be 'start' or 'end'.
  const event = raw?.event
  if (event !== "start" && event !== "end") {
    return json(400, { error: "event must be 'start' or 'end'." }, requestOrigin)
  }

  // 3. Authenticate the caller via their JWT (Authorization: Bearer <jwt>).
  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return json(401, { error: "Missing Authorization header." }, requestOrigin)
  }

  // Use the anon-key client with the caller's JWT to validate the session and
  // extract auth.uid(). We do NOT use this client for any DB writes — all DB
  // operations go through the service role client below.
  const anonClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth:   { persistSession: false, autoRefreshToken: false },
  })
  const { data: { user: caller }, error: callerError } = await anonClient.auth.getUser()
  if (callerError || !caller) {
    return json(401, { error: "Invalid or expired session." }, requestOrigin)
  }
  const callerUid = caller.id

  // 4. Service role client — used for all DB reads and writes.
  //    This bypasses RLS and the block_trips_field_escalation trigger's
  //    driver-restriction path (the trigger checks `current_user = 'service_role'`
  //    and returns NEW immediately, so the new odometer columns are writable).
  const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  // 5. Load the trip + joined samsara_vehicle_id from the truck.
  const { data: tripData, error: tripError } = await svc
    .from("trips")
    .select(`
      id,
      driver_id,
      truck_id,
      status,
      trip_started_at,
      trip_ended_at,
      start_odometer,
      end_odometer,
      miles_driven,
      trucks!left ( samsara_vehicle_id )
    `)
    .eq("id", trip_id)
    .limit(1)
    .maybeSingle()

  if (tripError) {
    console.error("Trip lookup error:", tripError)
    return json(500, { error: "Failed to load trip." }, requestOrigin)
  }
  if (!tripData) {
    return json(404, { error: "Trip not found." }, requestOrigin)
  }

  // Flatten the joined truck column. Supabase returns the joined table as a
  // nested object; the left join means it may be null if truck_id is null.
  const trip: TripRow = {
    id:              tripData.id,
    driver_id:       tripData.driver_id,
    truck_id:        tripData.truck_id,
    status:          tripData.status,
    trip_started_at: tripData.trip_started_at,
    trip_ended_at:   tripData.trip_ended_at,
    start_odometer:  tripData.start_odometer,
    end_odometer:    tripData.end_odometer,
    miles_driven:    tripData.miles_driven,
    samsara_vehicle_id: (tripData as Record<string, unknown> & {
      trucks?: { samsara_vehicle_id?: string | null } | null
    }).trucks?.samsara_vehicle_id ?? null,
  }

  // 6. Authorization: staff OR the assigned driver.
  //    is_tms_staff() is a SECURITY DEFINER SQL function that reads users.role.
  //    We replicate the check here rather than calling the RPC, because the
  //    service role client does not run under the caller's auth.uid() context —
  //    we must pass callerUid explicitly.
  const { data: staffCheck } = await svc
    .from("users")
    .select("id")
    .eq("auth_id", callerUid)
    .eq("is_active", true)
    .in("role", ["ADMIN", "MANAGER", "DISPATCHER"])
    .limit(1)
    .maybeSingle()

  const isStaff = !!staffCheck

  if (!isStaff) {
    // Check whether the caller is the driver assigned to this trip.
    if (!trip.driver_id) {
      return json(403, { error: "No driver assigned to this trip." }, requestOrigin)
    }
    const { data: driverRow }: { data: DriverRow | null } = await svc
      .from("drivers")
      .select("id, auth_user_id")
      .eq("id", trip.driver_id)
      .limit(1)
      .maybeSingle()

    if (!driverRow || driverRow.auth_user_id !== callerUid) {
      return json(403, { error: "Not authorized for this trip." }, requestOrigin)
    }
  }

  // 7. samsara_vehicle_id check.
  if (!trip.samsara_vehicle_id) {
    return json(422, { error: "truck_not_linked_to_samsara" }, requestOrigin)
  }
  const vehicleId = trip.samsara_vehicle_id

  // 8. Idempotency guards.
  if (event === "start") {
    // Idempotency: if start was already recorded with a real odometer, return existing.
    if (trip.trip_started_at && trip.start_odometer !== null) {
      console.log(`Trip ${trip_id} start replay (caller ${callerUid}); returning existing values`)
      return json(200, {
        ok:           true,
        odometer:     Number(trip.start_odometer),
        miles_driven: null,
        status:       trip.status,
      }, requestOrigin)
    }
    // If start_odometer is NULL but trip_started_at is set, the prior attempt hit
    // the warning path. Allow this retry to attempt Samsara again.
  } else {
    // event === 'end'
    if (trip.trip_started_at === null) {
      return json(422, { error: "trip_not_started" }, requestOrigin)
    }
    // Idempotency: if end was already recorded with a real odometer, return existing.
    if (trip.trip_ended_at && trip.end_odometer !== null) {
      console.log(`Trip ${trip_id} end replay (caller ${callerUid}); returning existing values`)
      return json(200, {
        ok:           true,
        odometer:     Number(trip.end_odometer),
        miles_driven: trip.miles_driven,
        status:       trip.status,
      }, requestOrigin)
    }
    // If end_odometer is NULL but trip_ended_at is set, the prior attempt hit
    // the warning path. Allow this retry to attempt Samsara again.
  }

  // 9. Read Samsara credentials from app_settings.
  //    The Web TMS stores { api_key, proxy_url } in app_settings.value (jsonb)
  //    under key = 'samsara'. This is a staff-restricted row (RLS: is_tms_staff()
  //    only) so the service role client is required to read it.
  const { data: settingsRow, error: settingsError } = await svc
    .from("app_settings")
    .select("value")
    .eq("key", "samsara")
    .limit(1)
    .maybeSingle()

  if (settingsError) {
    console.error("app_settings lookup error:", settingsError)
    return json(500, { error: "samsara_not_configured" }, requestOrigin)
  }

  const settingsValue = settingsRow?.value as Record<string, unknown> | null | undefined
  const samsaraApiKey = typeof settingsValue?.api_key === "string" ? settingsValue.api_key : ""

  if (!samsaraApiKey) {
    return json(500, { error: "samsara_not_configured" }, requestOrigin)
  }
  // NOTE: samsara_api_key value is NOT logged here (only presence is checked above in fetchSamsaraOdometer).

  // 10. Fetch odometer from Samsara. Failure is non-blocking — the trip state
  //     transitions regardless, and mileage_error is set so the dispatcher can
  //     reconcile manually.
  const targetStatus = event === "start" ? "IN_TRANSIT" : "COMPLETED"

  let odometer_miles: number | null = null
  let fetchErrorMsg:  string | null = null

  try {
    const result = await fetchSamsaraOdometer(vehicleId, samsaraApiKey)
    odometer_miles = result.odometer_miles
    console.log(`Samsara odometer fetched for trip ${trip_id}: ${odometer_miles} miles (event=${event})`)
  } catch (err) {
    fetchErrorMsg = (err as Error).message
    console.error(`Samsara fetch failed for trip ${trip_id} (event=${event}):`, fetchErrorMsg)
  }

  // 11. Update the trip row.
  //     Service role bypasses both RLS and block_trips_field_escalation.
  const now = new Date().toISOString()
  let updatePayload: Record<string, unknown>

  if (event === "start") {
    updatePayload = {
      trip_started_at: now,
      start_odometer:  odometer_miles,           // null if Samsara failed
      mileage_source:  odometer_miles !== null ? "samsara" : null,
      mileage_error:   fetchErrorMsg,             // null on success
      status:          targetStatus,
    }
  } else {
    updatePayload = {
      trip_ended_at: now,
      end_odometer:  odometer_miles,             // null if Samsara failed
      mileage_error: fetchErrorMsg,              // null on success
      status:        targetStatus,
    }
  }

  const { error: updateError } = await svc
    .from("trips")
    .update(updatePayload)
    .eq("id", trip_id)

  if (updateError) {
    console.error(`Failed to update trip ${trip_id}:`, updateError)
    return json(500, { error: "Failed to update trip." }, requestOrigin)
  }

  // 12. Re-fetch the updated row to get the generated miles_driven column.
  //     miles_driven is a GENERATED ALWAYS AS (end_odometer - start_odometer) STORED
  //     column — Postgres computes it; we read it back rather than computing here.
  const { data: updatedRow, error: refetchError } = await svc
    .from("trips")
    .select("start_odometer, end_odometer, miles_driven, status, trip_started_at, trip_ended_at")
    .eq("id", trip_id)
    .limit(1)
    .maybeSingle()

  if (refetchError || !updatedRow) {
    console.error(`Failed to re-fetch trip ${trip_id} after update:`, refetchError)
    // The update succeeded — return a best-effort response from what we know.
    if (fetchErrorMsg) {
      return json(200, {
        ok:           true,
        odometer:     null,
        status:       targetStatus,
        warning:      "mileage_capture_failed",
        error_detail: publicErrorCode(fetchErrorMsg),
      }, requestOrigin)
    }
    return json(200, {
      ok:           true,
      odometer:     odometer_miles,
      miles_driven: null,
      status:       targetStatus,
    }, requestOrigin)
  }

  // 13. Return result.
  if (fetchErrorMsg) {
    // Samsara failed, but trip state transitioned successfully.
    // error_detail is sanitized to a public code; full internal message is in console.error above.
    return json(200, {
      ok:           true,
      odometer:     null,
      status:       updatedRow.status ?? targetStatus,
      warning:      "mileage_capture_failed",
      error_detail: publicErrorCode(fetchErrorMsg),
    }, requestOrigin)
  }

  // Fix C2: end succeeded but start_odometer was never captured — surface a warning
  // so callers understand why miles_driven is null rather than silently returning it.
  if (event === "end" && updatedRow.miles_driven === null) {
    return json(200, {
      ok:           true,
      odometer:     Number(updatedRow.end_odometer),
      miles_driven: null,
      status:       updatedRow.status ?? targetStatus,
      warning:      "miles_driven_unavailable_no_start_odometer",
    }, requestOrigin)
  }

  return json(200, {
    ok:           true,
    odometer:     event === "start" ? updatedRow.start_odometer : updatedRow.end_odometer,
    miles_driven: event === "start" ? null : updatedRow.miles_driven,
    status:       updatedRow.status ?? targetStatus,
  }, requestOrigin)
}
