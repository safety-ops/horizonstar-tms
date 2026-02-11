import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? ""
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? ""
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""

const ALLOWED_BUCKETS = new Set(["inspection-media", "order-attachments"])
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
      const invalidDriverPath = normalizedPaths.find((p) => !p.startsWith(expectedPrefix))
      if (invalidDriverPath) {
        return json(403, { error: "Driver cannot sign media outside own namespace." })
      }
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
