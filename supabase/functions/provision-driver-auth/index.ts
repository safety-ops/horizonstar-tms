import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

type JsonRecord = Record<string, unknown>

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? ""
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? ""
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""

function json(status: number, payload: JsonRecord) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

function normalizeEmail(email: string) {
  return email.trim().toLowerCase()
}

function isDuplicateAuthEmailError(message: string) {
  const msg = message.toLowerCase()
  return (
    msg.includes("already been registered") ||
    msg.includes("already exists") ||
    msg.includes("already registered") ||
    msg.includes("email_exists") ||
    msg.includes("duplicate")
  )
}

async function findAuthUserIdByEmail(service: any, email: string) {
  const target = normalizeEmail(email)
  let page = 1
  const perPage = 200
  const maxPages = 20

  while (page <= maxPages) {
    const { data, error } = await service.auth.admin.listUsers({ page, perPage })
    if (error) {
      throw new Error(error.message || "Failed to query auth users.")
    }

    const users = data?.users ?? []
    const match = users.find((user: any) => normalizeEmail(user?.email ?? "") === target)
    if (match?.id) return match.id as string

    if (users.length < perPage) break
    page += 1
  }

  return null
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
    return json(500, {
      error: "Supabase environment is not configured for this function.",
    })
  }

  try {
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

    // Only allow known TMS users to provision driver auth.
    const { data: tmsUser, error: tmsUserError } = await service
      .from("users")
      .select("id, role, is_active")
      .eq("auth_id", caller.id)
      .limit(1)
      .maybeSingle()

    if (tmsUserError || !tmsUser) {
      return json(403, { error: "Caller is not an authorized TMS user." })
    }
    if (tmsUser.is_active === false) {
      return json(403, { error: "Caller account is inactive." })
    }

    const body = (await req.json()) as JsonRecord
    const driverId = Number(body.driver_id)
    const emailInput = typeof body.email === "string" ? body.email : ""
    const email = normalizeEmail(emailInput)

    if (!Number.isFinite(driverId) || driverId <= 0) {
      return json(400, { error: "driver_id must be a positive integer." })
    }
    if (!email || !email.includes("@")) {
      return json(400, { error: "A valid email is required." })
    }

    const { data: driver, error: driverError } = await service
      .from("drivers")
      .select("id, first_name, last_name, email, auth_user_id")
      .eq("id", driverId)
      .maybeSingle()

    if (driverError || !driver) {
      return json(404, { error: "Driver not found." })
    }

    const { data: duplicateDriver } = await service
      .from("drivers")
      .select("id, first_name, last_name")
      .neq("id", driverId)
      .ilike("email", email)
      .limit(1)

    if (duplicateDriver && duplicateDriver.length > 0) {
      const conflict = duplicateDriver[0]
      const name = `${conflict.first_name ?? ""} ${conflict.last_name ?? ""}`.trim()
      return json(409, {
        error: name
          ? `This email is already assigned to driver ${name}.`
          : "Another driver already uses this email.",
        conflict_driver_id: conflict.id ?? null,
      })
    }

    let authUserId: string | null = driver.auth_user_id ?? null
    let created = false

    if (!authUserId) {
      // Reuse any existing auth user with this email.
      authUserId = await findAuthUserIdByEmail(service, email)
      if (!authUserId) {
        const temporaryPassword = `${crypto.randomUUID()}Aa1!`
        const { data: createdUserData, error: createUserError } = await service.auth.admin.createUser({
          email,
          password: temporaryPassword,
          email_confirm: true,
          user_metadata: {
            role: "DRIVER",
            driver_id: driverId,
            first_name: driver.first_name ?? "",
            last_name: driver.last_name ?? "",
          },
        })

        if (createUserError || !createdUserData.user) {
          const createMessage = createUserError?.message ?? "Failed to create auth user."
          let existingAuthUserId: string | null = null

          try {
            existingAuthUserId = await findAuthUserIdByEmail(service, email)
          } catch (_) {
            existingAuthUserId = null
          }

          if (existingAuthUserId) {
            authUserId = existingAuthUserId
          } else if (isDuplicateAuthEmailError(createMessage)) {
            return json(409, { error: "Email already exists in auth and could not be linked automatically." })
          } else {
            return json(500, { error: createMessage })
          }
        } else {
          authUserId = createdUserData.user.id
          created = true
        }
      }
    }

    if (!authUserId) {
      return json(500, { error: "Failed to resolve auth user for this email." })
    }

    const { error: updateDriverError } = await service
      .from("drivers")
      .update({
        email,
        auth_user_id: authUserId,
      })
      .eq("id", driverId)

    if (updateDriverError) {
      const updateMessage = updateDriverError.message ?? "Failed to update driver record."
      if (updateMessage.toLowerCase().includes("duplicate") || updateMessage.toLowerCase().includes("unique")) {
        return json(409, { error: "Another driver already uses this email." })
      }
      return json(500, { error: updateMessage })
    }

    // Keep metadata in sync for the linked auth user.
    const { error: updateAuthUserError } = await service.auth.admin.updateUserById(authUserId, {
      user_metadata: {
        role: "DRIVER",
        driver_id: driverId,
        first_name: driver.first_name ?? "",
        last_name: driver.last_name ?? "",
      },
    })

    const warning = updateAuthUserError?.message ?? null

    return json(200, {
      success: true,
      driver_id: driverId,
      auth_user_id: authUserId,
      email,
      created,
      warning,
    })
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error"
    return json(500, { error: message })
  }
})
