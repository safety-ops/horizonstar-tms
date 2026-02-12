import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? ""
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? ""
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""

const ALLOWED_BUCKETS = new Set(["inspection-media", "order-attachments", "chatfiles"])
const MAX_PATHS_PER_REQUEST = 150

function json(status: number, payload: Record<string, unknown>) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

function normalizePath(path: string) {
  const trimmed = path.trim()
  if (!trimmed || trimmed.startsWith("/") || trimmed.includes("..")) {
    return null
  }
  return trimmed
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed" })
  }

  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
    return json(500, { error: "Supabase environment is not configured." })
  }

  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return json(401, { error: "Missing Authorization header." })
  }

  const authClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const {
    data: { user: caller },
    error: callerError,
  } = await authClient.auth.getUser()

  if (callerError || !caller) {
    return json(401, { error: "Invalid or expired session." })
  }

  const service = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  try {
    const body = (await req.json()) as {
      bucket?: string
      paths?: string[]
      ttl_seconds?: number
    }

    const bucket = String(body.bucket ?? "").trim()
    if (!ALLOWED_BUCKETS.has(bucket)) {
      return json(400, { error: "Unsupported bucket." })
    }

    const ttlSeconds = Math.max(60, Math.min(Number(body.ttl_seconds ?? 3600), 86_400))
    const inputPaths = Array.isArray(body.paths) ? body.paths : []
    const normalizedPaths = [...new Set(inputPaths.map((p) => normalizePath(String(p))).filter(Boolean) as string[])]

    if (normalizedPaths.length === 0) {
      return json(200, { urls: [] })
    }
    if (normalizedPaths.length > MAX_PATHS_PER_REQUEST) {
      return json(400, { error: `Too many paths. Max ${MAX_PATHS_PER_REQUEST}.` })
    }

    const { data: tmsUser } = await service
      .from("users")
      .select("id")
      .eq("auth_id", caller.id)
      .eq("is_active", true)
      .limit(1)
      .maybeSingle()

    const { data: driver } = await service
      .from("drivers")
      .select("id")
      .eq("auth_user_id", caller.id)
      .limit(1)
      .maybeSingle()

    if (!tmsUser && !driver) {
      return json(403, { error: "Caller is not authorized for media signing." })
    }

    if (driver && !tmsUser) {
      const expectedPrefix = `${driver.id}/`
      let candidatePaths = normalizedPaths

      if (bucket === "chatfiles") {
        const invalidChatPath = normalizedPaths.find((p) => !p.startsWith(expectedPrefix))
        if (invalidChatPath) {
          return json(403, { error: "Driver cannot sign chatfiles outside own namespace." })
        }
      } else if (bucket === "order-attachments") {
        const prefixedPaths = new Set(normalizedPaths.filter((p) => p.startsWith(expectedPrefix)))
        const unresolvedPaths = normalizedPaths.filter((p) => !prefixedPaths.has(p))

        if (unresolvedPaths.length > 0) {
          const { data: attachmentRows, error: attachmentError } = await service
            .from("order_attachments")
            .select("storage_path, order_id")
            .in("storage_path", unresolvedPaths)

          if (attachmentError) {
            return json(500, { error: attachmentError.message ?? "Failed to validate attachment scope." })
          }

          const attachmentByPath = new Map<string, number>()
          const orderIds = new Set<number>()
          ;(attachmentRows || []).forEach((row: any) => {
            const storagePath = String(row?.storage_path ?? "").trim()
            const orderId = Number(row?.order_id)
            if (!storagePath || !Number.isFinite(orderId)) return
            attachmentByPath.set(storagePath, orderId)
            orderIds.add(orderId)
          })

          const allowedOrderIds = new Set<number>()
          if (orderIds.size > 0) {
            const orderIdList = Array.from(orderIds)
            const { data: orders, error: ordersError } = await service
              .from("orders")
              .select("id, driver_id, trip_id")
              .in("id", orderIdList)

            if (ordersError) {
              return json(500, { error: ordersError.message ?? "Failed to validate order ownership." })
            }

            const tripIds = Array.from(
              new Set(
                (orders || [])
                  .map((o: any) => Number(o?.trip_id))
                  .filter((tripId: number) => Number.isFinite(tripId))
              )
            )

            const tripDriverMap = new Map<number, number>()
            if (tripIds.length > 0) {
              const { data: trips, error: tripsError } = await service
                .from("trips")
                .select("id, driver_id")
                .in("id", tripIds)

              if (tripsError) {
                return json(500, { error: tripsError.message ?? "Failed to validate trip ownership." })
              }

              ;(trips || []).forEach((trip: any) => {
                const tripId = Number(trip?.id)
                const tripDriverId = Number(trip?.driver_id)
                if (Number.isFinite(tripId) && Number.isFinite(tripDriverId)) {
                  tripDriverMap.set(tripId, tripDriverId)
                }
              })
            }

            ;(orders || []).forEach((order: any) => {
              const orderId = Number(order?.id)
              const directDriverId = Number(order?.driver_id)
              const tripId = Number(order?.trip_id)
              const tripDriverId = Number.isFinite(tripId) ? tripDriverMap.get(tripId) : undefined
              if (
                Number.isFinite(orderId) &&
                (directDriverId === Number(driver.id) || tripDriverId === Number(driver.id))
              ) {
                allowedOrderIds.add(orderId)
              }
            })
          }

          const disallowedPath = unresolvedPaths.find((path) => {
            const orderId = attachmentByPath.get(path)
            return !orderId || !allowedOrderIds.has(orderId)
          })

          if (disallowedPath) {
            return json(403, { error: "Driver cannot sign attachment outside assigned orders." })
          }
        }

        candidatePaths = normalizedPaths
      } else {
        const invalidDriverPath = normalizedPaths.find((p) => !p.startsWith(expectedPrefix))
        if (invalidDriverPath) {
          return json(403, { error: "Driver cannot sign media outside own namespace." })
        }
      }

      normalizedPaths.splice(0, normalizedPaths.length, ...candidatePaths)
    }

    const expiresAt = new Date(Date.now() + ttlSeconds * 1000).toISOString()
    const urls: Array<{ path: string; signed_url: string; expires_at: string }> = []
    const errors: Array<{ path: string; error: string }> = []

    for (const path of normalizedPaths) {
      const { data, error } = await service.storage.from(bucket).createSignedUrl(path, ttlSeconds)
      if (error || !data?.signedUrl) {
        errors.push({ path, error: error?.message ?? "Unable to sign path." })
        continue
      }

      const signedUrl = data.signedUrl.startsWith("http")
        ? data.signedUrl
        : `${SUPABASE_URL}/storage/v1${data.signedUrl}`

      urls.push({
        path,
        signed_url: signedUrl,
        expires_at: expiresAt,
      })
    }

    return json(200, {
      urls,
      ...(errors.length > 0 ? { errors } : {}),
    })
  } catch (error) {
    return json(500, { error: error instanceof Error ? error.message : "Unknown error" })
  }
})
