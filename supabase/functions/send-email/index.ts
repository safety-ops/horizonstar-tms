// Supabase Edge Function for sending emails via Resend
// Deploy: supabase functions deploy send-email
// Set secret: supabase secrets set RESEND_API_KEY=re_xxxxx

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? ""
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? ""
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? ""
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""

const ALLOWED_KINDS = new Set(["invoice", "tracking", "settlement", "inspection_customer", "system_test"])
const DRIVER_ALLOWED_KINDS = new Set(["inspection_customer"])

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

function json(status: number, payload: Record<string, unknown>) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed." })
  }

  try {
    if (!RESEND_API_KEY) {
      return json(500, { error: "RESEND_API_KEY is not configured." })
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

    const { data: tmsUser } = await service
      .from("users")
      .select("id, is_active")
      .eq("auth_id", caller.id)
      .eq("is_active", true)
      .limit(1)
      .maybeSingle()

    const { data: driver } = await service
      .from("drivers")
      .select("id, status")
      .eq("auth_user_id", caller.id)
      .limit(1)
      .maybeSingle()

    const isDriverActive = !!driver && String(driver.status ?? "ACTIVE").toUpperCase() !== "INACTIVE"
    if (!tmsUser && !isDriverActive) {
      return json(403, { error: "Caller is not authorized to send email." })
    }

    const {
      to,
      cc,
      bcc,
      subject,
      html,
      text,
      from_name,
      attachment,
      attachments,
      kind,
    } = await req.json()

    const requestedKind = String(kind ?? "").trim().toLowerCase()
    if (!ALLOWED_KINDS.has(requestedKind)) {
      return json(400, { error: "Invalid or missing email kind." })
    }
    if (!tmsUser && isDriverActive && !DRIVER_ALLOWED_KINDS.has(requestedKind)) {
      return json(403, { error: "Driver is not authorized for this email kind." })
    }

    if (!to || !subject || (!html && !text && !attachment && !attachments)) {
      return json(400, {
        error: "Missing required fields: to, subject, and one of html/text/attachment(s).",
      })
    }

    const emailPayload: Record<string, unknown> = {
      from: from_name ? `${from_name} <noreply@luckycabbagetms.com>` : "Horizon Star TMS <noreply@luckycabbagetms.com>",
      to: Array.isArray(to) ? to : [to],
      subject,
    }

    if (cc) {
      emailPayload.cc = Array.isArray(cc) ? cc : [cc]
    }
    if (bcc) {
      emailPayload.bcc = Array.isArray(bcc) ? bcc : [bcc]
    }
    if (html) {
      emailPayload.html = html
    }
    if (text) {
      emailPayload.text = text
    }

    if (attachments && Array.isArray(attachments) && attachments.length > 0) {
      emailPayload.attachments = attachments
        .filter((att: any) => att.filename && att.content)
        .map((att: any) => ({ filename: att.filename, content: att.content }))
    } else if (attachment && attachment.filename && attachment.content) {
      emailPayload.attachments = [{ filename: attachment.filename, content: attachment.content }]
    }

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify(emailPayload),
    })

    const data = await res.json()
    if (!res.ok) {
      console.error("Resend API error:", data)
      return json(res.status, { error: data?.message || "Failed to send email." })
    }

    return json(200, { success: true, id: data.id })
  } catch (error) {
    console.error("Edge function error:", error)
    return json(500, { error: error instanceof Error ? error.message : "Unknown error" })
  }
})
