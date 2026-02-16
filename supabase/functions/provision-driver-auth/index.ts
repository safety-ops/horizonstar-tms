import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

type JsonRecord = Record<string, unknown>

type DriverRecord = {
  id: number
  first_name: string | null
  last_name: string | null
  email: string | null
  auth_user_id: string | null
  status: string | null
}

type LocalDriverRecord = {
  id: number
  name: string | null
  phone: string | null
  email: string | null
  status: string | null
  auth_user_id: string | null
  linked_driver_id: number | null
  app_access_enabled: boolean | null
}

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

function parsePositiveInt(value: unknown) {
  const numberValue = Number(value)
  if (!Number.isFinite(numberValue) || numberValue <= 0) return null
  return Math.trunc(numberValue)
}

function normalizeStatus(value: string | null | undefined) {
  const status = String(value || "ACTIVE").toUpperCase()
  if (["ACTIVE", "INACTIVE", "ON_LEAVE", "TERMINATED"].includes(status)) {
    return status
  }
  return "ACTIVE"
}

function splitLocalDriverName(name: string | null | undefined) {
  const cleaned = String(name || "").trim()
  if (!cleaned) {
    return { first: "Local", last: "Driver" }
  }
  const parts = cleaned.split(/\s+/).filter(Boolean)
  const first = parts[0] || "Local"
  const last = parts.length > 1 ? parts.slice(1).join(" ") : "Driver"
  return { first, last }
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

function isAuthSignupDatabaseError(message: string) {
  const msg = message.toLowerCase()
  return (
    msg.includes("database error saving new user") ||
    msg.includes("database error creating new user") ||
    msg.includes("unexpected_failure")
  )
}

async function findAuthUserIdByEmail(service: any, email: string) {
  try {
    const target = normalizeEmail(email)
    let page = 1
    const perPage = 200
    const maxPages = 20

    while (page <= maxPages) {
      const { data, error } = await service.auth.admin.listUsers({ page, perPage })
      if (error) return null

      const users = data?.users ?? []
      const match = users.find((user: any) => normalizeEmail(user?.email ?? "") === target)
      if (match?.id) return match.id as string

      if (users.length < perPage) break
      page += 1
    }
  } catch (_) {
    return null
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
    const driverId = parsePositiveInt(body.driver_id)
    const localDriverId = parsePositiveInt(body.local_driver_id)
    const emailInput = typeof body.email === "string" ? body.email : ""
    const email = normalizeEmail(emailInput)

    if ((driverId ? 1 : 0) + (localDriverId ? 1 : 0) !== 1) {
      return json(400, { error: "Provide exactly one of driver_id or local_driver_id." })
    }

    if (!email || !email.includes("@")) {
      return json(400, { error: "A valid email is required." })
    }

    const target = localDriverId ? "local_driver" : "driver"
    let linkedDriverId = driverId as number
    let driverRecord: DriverRecord | null = null
    let localDriverRecord: LocalDriverRecord | null = null

    if (target === "driver") {
      const { data: driver, error: driverError } = await service
        .from("drivers")
        .select("id, first_name, last_name, email, auth_user_id, status")
        .eq("id", linkedDriverId)
        .maybeSingle()

      if (driverError) {
        const message = driverError.message ?? "Failed to load driver."
        if (message.toLowerCase().includes("auth_user_id") && message.toLowerCase().includes("column")) {
          return json(500, {
            error: "Database migration is missing. Please run 20260210_driver_auth_email_otp.sql.",
          })
        }
        return json(500, { error: message })
      }

      if (!driver) {
        return json(404, { error: "Driver not found." })
      }

      driverRecord = driver as DriverRecord
    } else {
      const { data: localDriver, error: localDriverError } = await service
        .from("local_drivers")
        .select("id, name, phone, email, status, auth_user_id, linked_driver_id, app_access_enabled")
        .eq("id", localDriverId)
        .maybeSingle()

      if (localDriverError) {
        const message = localDriverError.message ?? "Failed to load local driver."
        if (
          message.toLowerCase().includes("linked_driver_id") ||
          message.toLowerCase().includes("auth_user_id") ||
          message.toLowerCase().includes("app_access_enabled")
        ) {
          return json(500, {
            error: "Database migration is missing. Please run 20260216_local_driver_auth_and_local_flow_sync.sql.",
          })
        }
        return json(500, { error: message })
      }

      if (!localDriver) {
        return json(404, { error: "Local driver not found." })
      }

      localDriverRecord = localDriver as LocalDriverRecord
      linkedDriverId = parsePositiveInt(localDriverRecord.linked_driver_id) ?? 0

      if (linkedDriverId > 0) {
        const { data: linkedDriver, error: linkedDriverError } = await service
          .from("drivers")
          .select("id, first_name, last_name, email, auth_user_id, status")
          .eq("id", linkedDriverId)
          .maybeSingle()

        if (linkedDriverError) {
          return json(500, { error: linkedDriverError.message ?? "Failed to load linked driver." })
        }

        if (linkedDriver) {
          driverRecord = linkedDriver as DriverRecord
        }
      }

      if (!driverRecord) {
        const nameParts = splitLocalDriverName(localDriverRecord.name)
        const payload: JsonRecord = {
          first_name: nameParts.first,
          last_name: nameParts.last,
          phone: localDriverRecord.phone || null,
          email,
          status: normalizeStatus(localDriverRecord.status),
        }

        const { data: createdDriver, error: createDriverError } = await service
          .from("drivers")
          .insert(payload)
          .select("id, first_name, last_name, email, auth_user_id, status")
          .single()

        if (createDriverError || !createdDriver) {
          return json(500, { error: createDriverError?.message ?? "Failed to create linked driver profile." })
        }

        driverRecord = createdDriver as DriverRecord
        linkedDriverId = driverRecord.id
      }
    }

    if (!driverRecord || !linkedDriverId) {
      return json(500, { error: "Failed to resolve linked driver profile." })
    }

    const { data: duplicateDriver } = await service
      .from("drivers")
      .select("id, first_name, last_name")
      .neq("id", linkedDriverId)
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

    let authUserId: string | null =
      driverRecord.auth_user_id ??
      localDriverRecord?.auth_user_id ??
      null
    let created = false

    if (!authUserId) {
      authUserId = await findAuthUserIdByEmail(service, email)
      if (!authUserId) {
        const temporaryPassword = `${crypto.randomUUID()}Aa1!`
        const { data: createdUserData, error: createUserError } = await service.auth.admin.createUser({
          email,
          password: temporaryPassword,
          email_confirm: true,
          user_metadata: {
            role: "DRIVER",
            driver_id: linkedDriverId,
            local_driver_id: localDriverId ?? null,
            first_name: driverRecord.first_name ?? "",
            last_name: driverRecord.last_name ?? "",
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
          } else if (isAuthSignupDatabaseError(createMessage)) {
            return json(500, {
              error:
                "Supabase Auth signup is failing at the database level. Please run migration 20260211_fix_auth_signup_trigger.sql in SQL Editor, then retry.",
            })
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
      .eq("id", linkedDriverId)

    if (updateDriverError) {
      const updateMessage = updateDriverError.message ?? "Failed to update driver record."
      if (updateMessage.toLowerCase().includes("auth_user_id") && updateMessage.toLowerCase().includes("column")) {
        return json(500, {
          error: "Database migration is missing. Please run 20260210_driver_auth_email_otp.sql.",
        })
      }
      if (updateMessage.toLowerCase().includes("duplicate") || updateMessage.toLowerCase().includes("unique")) {
        return json(409, { error: "Another driver already uses this email." })
      }
      return json(500, { error: updateMessage })
    }

    if (target === "local_driver" && localDriverId) {
      const { error: updateLocalDriverError } = await service
        .from("local_drivers")
        .update({
          email,
          auth_user_id: authUserId,
          linked_driver_id: linkedDriverId,
          app_access_enabled: true,
        })
        .eq("id", localDriverId)

      if (updateLocalDriverError) {
        const message = updateLocalDriverError.message ?? "Failed to update local driver record."
        if (
          message.toLowerCase().includes("linked_driver_id") ||
          message.toLowerCase().includes("auth_user_id") ||
          message.toLowerCase().includes("app_access_enabled")
        ) {
          return json(500, {
            error: "Database migration is missing. Please run 20260216_local_driver_auth_and_local_flow_sync.sql.",
          })
        }
        if (message.toLowerCase().includes("duplicate") || message.toLowerCase().includes("unique")) {
          return json(409, { error: "Another local driver already uses this email." })
        }
        return json(500, { error: message })
      }
    }

    const { error: updateAuthUserError } = await service.auth.admin.updateUserById(authUserId, {
      user_metadata: {
        role: "DRIVER",
        driver_id: linkedDriverId,
        local_driver_id: localDriverId ?? null,
        first_name: driverRecord.first_name ?? "",
        last_name: driverRecord.last_name ?? "",
      },
    })

    const warning = updateAuthUserError?.message ?? null

    return json(200, {
      success: true,
      driver_id: linkedDriverId,
      local_driver_id: localDriverId ?? null,
      linked_driver_id: linkedDriverId,
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
