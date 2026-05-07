// Supabase Edge Function for sending emails via Resend.
// Hardened (Workstream C, P0 reliability):
//   • CORS allowlist via ALLOWED_ORIGINS env (no wildcard).
//   • Hardcoded From address (no display-name spoofing / header injection).
//   • Strict recipient + size validation, regex-based HTML sanitization.
//   • Atomic kill-switch + 1h rate limit + idempotency replay via RPC.
//   • Single 5s fetch timeout w/ one retry on network error; outer 10s cap.
//   • Generic error responses; full detail to console.error for ops.
//
// Deploy: supabase functions deploy send-email
// Secrets: RESEND_API_KEY, ALLOWED_ORIGINS (comma-sep)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// ---------- Env / constants ----------
const RESEND_API_KEY            = Deno.env.get("RESEND_API_KEY") ?? ""
const SUPABASE_URL              = Deno.env.get("SUPABASE_URL") ?? ""
const SUPABASE_ANON_KEY         = Deno.env.get("SUPABASE_ANON_KEY") ?? ""
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
  .split(",").map(s => s.trim()).filter(Boolean)

const ALLOWED_KINDS        = new Set(["invoice", "billing_reminder", "tracking", "settlement", "inspection_customer", "system_test"])
const DRIVER_ALLOWED_KINDS = new Set(["inspection_customer"])

const FROM_ADDRESS         = "Horizon Star TMS <noreply@luckycabbagetms.com>"
const MAX_RECIPIENTS       = 50
const MAX_SUBJECT_LEN      = 200
const MAX_HTML_BYTES       = 51_200       // 50 KB
const MAX_TEXT_BYTES       = 51_200       // 50 KB
const MAX_ATTACHMENT_BYTES = 6_291_456    // 6 MB per attachment
const MAX_TOTAL_ATTACH_BYTES = 6_291_456  // 6 MB total (matches Edge body cap)
const MAX_EMAIL_LEN        = 320          // RFC 5321
const FETCH_TIMEOUT_MS     = 5_000
const OUTER_TIMEOUT_MS     = 10_000
const QUOTA_LIMIT_PER_HOUR = 20

// Email regex: pragmatic RFC 5321 superset. Not perfect but rejects obvious junk.
const EMAIL_REGEX = /^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$/
const IDEMPOTENCY_REGEX = /^[A-Za-z0-9_-]{8,128}$/

// ---------- Types ----------
interface AttachmentIn { filename?: unknown; content?: unknown }
interface EmailRequestBody {
  to?: unknown; cc?: unknown; bcc?: unknown
  subject?: unknown; html?: unknown; text?: unknown
  attachment?: AttachmentIn; attachments?: AttachmentIn[]
  kind?: unknown
  // from_name intentionally absent: silently ignored if sent (locked-down From).
}
interface NormalizedAttachment { filename: string; content: string; bytes: number }

// ---------- CORS ----------
function corsHeadersFor(origin: string | null): Record<string, string> {
  const base: Record<string, string> = {
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, idempotency-key",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  }
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    return { ...base, "Access-Control-Allow-Origin": origin, "Vary": "Origin" }
  }
  // Native client / no Origin — CORS headers are irrelevant; return base only
  return base
}
function json(status: number, payload: Record<string, unknown>, origin: string | null) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeadersFor(origin), "Content-Type": "application/json" },
  })
}

// ---------- Validation helpers ----------
function isEmail(s: unknown): s is string {
  return typeof s === "string" && s.length > 0 && s.length <= MAX_EMAIL_LEN && EMAIL_REGEX.test(s)
}
function normalizeRecipientList(v: unknown, fieldName: string): { ok: true; list: string[] } | { ok: false; reason: string } {
  if (v === undefined || v === null) return { ok: true, list: [] }
  // Accept a single string (`to: "user@example.com"`) by lifting it into a
  // one-element array. Web TMS callers historically pass strings; this is
  // safe because the per-element isEmail() guard below still validates.
  if (typeof v === "string") v = [v]
  if (!Array.isArray(v)) return { ok: false, reason: `invalid_${fieldName}_not_array` }
  if (v.length > MAX_RECIPIENTS) return { ok: false, reason: `${fieldName}_too_many` }
  const out: string[] = []
  for (const e of v) {
    if (!isEmail(e)) return { ok: false, reason: `invalid_${fieldName}_address` }
    out.push(e)
  }
  return { ok: true, list: out }
}
function utf8Bytes(s: string): number { return new TextEncoder().encode(s).length }

// ---------- HTML sanitization (defense-in-depth) ----------
// Belt-and-suspenders strip: <script>/<iframe>/<style> blocks, on*= handlers,
// and href/src URIs that aren't on our allowlist. We control upstream
// templates; do not treat this as the only layer. Proper email-HTML
// sanitization is hard and best done with a real parser.
//
// Two hardening choices:
//   1. Fixed-point loop on the strip passes — defeats split-tag bypass like
//      `<scr<script>ipt>`. After the inner `<script>` is removed, the outer
//      `<script>` is exposed and must be stripped on the next pass.
//   2. URL ALLOWLIST instead of a blacklist on `javascript:`/`vbscript:` —
//      enumerating bad schemes is a losing game (data:text/html, blob:, etc.).
//      Only allow https:, mailto:, cid:, and data:image/. Anything else
//      becomes "#".
const URL_ATTR_RE = /(href|src)\s*=\s*("([^"]*)"|'([^']*)'|([^\s>]+))/gi
// Allowlist anchors at start-of-value; case-insensitive; tolerates leading
// whitespace inside the quoted value.
const URL_ALLOW_RE = /^\s*(?:https:|mailto:|cid:|data:image\/)/i
const STRIP_TAG_PASSES: ReadonlyArray<RegExp> = [
  /<script\b[^>]*>[\s\S]*?<\/script\s*>/gi,
  /<iframe\b[^>]*>[\s\S]*?<\/iframe\s*>/gi,
  /<style\b[^>]*>[\s\S]*?<\/style\s*>/gi,
]
const SANITIZE_MAX_ITERATIONS = 10

function sanitizeHtml(input: string): string {
  // 1. Iteratively strip dangerous block tags until output is stable. Cap at
  //    SANITIZE_MAX_ITERATIONS so a pathological input can't pin CPU.
  let prev = ""
  let cur  = input
  let iter = 0
  while (prev !== cur && iter < SANITIZE_MAX_ITERATIONS) {
    prev = cur
    for (const re of STRIP_TAG_PASSES) cur = cur.replace(re, "")
    iter++
  }

  // 2. Strip on*= event handlers. These don't suffer the split-tag class of
  //    bypass the same way (no nested handler syntax), so a single pass is
  //    fine. Order: quoted forms first, unquoted last.
  cur = cur
    .replace(/\son[a-z]+\s*=\s*"[^"]*"/gi, "")
    .replace(/\son[a-z]+\s*=\s*'[^']*'/gi, "")
    .replace(/\son[a-z]+\s*=\s*[^\s>]+/gi, "")

  // 3. URL allowlist: replace any href/src whose value isn't on the allowlist
  //    with "#". Single regex over all three quoting styles; we inspect the
  //    captured value (not the whole match) and rewrite the whole attribute.
  cur = cur.replace(URL_ATTR_RE, (_match, attr: string, _whole: string, dq?: string, sq?: string, uq?: string) => {
    const value = dq ?? sq ?? uq ?? ""
    if (URL_ALLOW_RE.test(value)) {
      // Keep original quoting style so we don't subtly mangle valid markup.
      if (dq !== undefined) return `${attr}="${value}"`
      if (sq !== undefined) return `${attr}='${value}'`
      return `${attr}=${value}`
    }
    return `${attr}="#"`
  })

  return cur
}

// ---------- Attachments ----------
function approxBase64Bytes(b64: string): number {
  // base64 expands ~4/3; this is the decoded byte size.
  const len = b64.length
  const padding = b64.endsWith("==") ? 2 : b64.endsWith("=") ? 1 : 0
  return Math.max(0, Math.floor((len * 3) / 4) - padding)
}
function normalizeAttachments(body: EmailRequestBody): { ok: true; list: NormalizedAttachment[]; totalBytes: number } | { ok: false; reason: string } {
  const raw: AttachmentIn[] = []
  if (Array.isArray(body.attachments)) raw.push(...body.attachments)
  else if (body.attachment) raw.push(body.attachment)

  const out: NormalizedAttachment[] = []
  let total = 0
  for (const a of raw) {
    if (!a || typeof a !== "object") continue
    const filename = typeof a.filename === "string" ? a.filename : ""
    const content  = typeof a.content  === "string" ? a.content  : ""
    if (!filename || !content) continue
    // CRLF / NUL rejection on filename: same MIME header-injection guard as
    // subject. A filename like `foo.pdf\r\nBcc: attacker@evil` could split
    // headers in the Content-Disposition line.
    if (/[\r\n\0]/.test(filename)) return { ok: false, reason: "invalid_filename" }
    const bytes = approxBase64Bytes(content)
    if (bytes > MAX_ATTACHMENT_BYTES) return { ok: false, reason: "attachment_too_large" }
    total += bytes
    if (total > MAX_TOTAL_ATTACH_BYTES) return { ok: false, reason: "attachments_total_too_large" }
    out.push({ filename, content, bytes })
  }
  return { ok: true, list: out, totalBytes: total }
}

// ---------- Resend fetch with one retry ----------
async function postToResend(payload: Record<string, unknown>): Promise<Response> {
  const doFetch = () => fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${RESEND_API_KEY}` },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  })
  try {
    return await doFetch()
  } catch (err) {
    // Retry once on network/timeout — never on 4xx/5xx (those throw no error).
    console.error("Resend fetch failed, retrying once:", err)
    return await doFetch()
  }
}

// ---------- Main handler ----------
serve(async (req) => {
  const requestOrigin = req.headers.get("origin")
  const isBrowserRequest = requestOrigin !== null && requestOrigin !== ""

  // 1. CORS allowlist BEFORE any other logic. Preflight short-circuits.
  if (req.method === "OPTIONS") {
    // CORS preflight is browser-only. Native apps (iOS URLSession, etc.) don't preflight.
    if (isBrowserRequest && ALLOWED_ORIGINS.includes(requestOrigin)) {
      return new Response("ok", { headers: corsHeadersFor(requestOrigin) })
    }
    return new Response("forbidden", { status: 403 })
  }

  // For non-OPTIONS: reject only if a browser is calling from an unauthorized origin.
  // Native clients (no Origin header) pass CORS; JWT auth below is the real security gate.
  if (isBrowserRequest && !ALLOWED_ORIGINS.includes(requestOrigin)) {
    return new Response("forbidden", { status: 403 })
  }

  if (req.method !== "POST") return json(405, { error: "Method not allowed." }, requestOrigin)

  // 2. Outer 10s deadline. Enforced as a Promise.race wrapper around the
  //    full work() body — not just one checkpoint — so any async hop
  //    (Supabase RPC, Resend fetch, JSON parse) can be overrun without
  //    leaving a hung connection. On timeout we still attempt to finalize
  //    the audit row (best-effort) and return 504.
  const deadlineMs = Date.now() + OUTER_TIMEOUT_MS
  const startedAt  = Date.now()

  let logId: number | null = null
  let logFinalized = false
  const finalize = async (status: string, reason: string | null, resendId: string | null) => {
    if (logId == null || logFinalized) return
    logFinalized = true
    try {
      const svc = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
        auth: { persistSession: false, autoRefreshToken: false },
      })
      await svc.rpc("email_quota_finalize", {
        p_log_id:        logId,
        p_status:        status,
        p_reject_reason: reason,
        p_resend_id:     resendId,
        p_duration_ms:   Date.now() - startedAt,
      })
    } catch (e) {
      console.error("email_quota_finalize failed:", e)
    }
  }

  const work = async (): Promise<Response> => {
    // 3. Env checks.
    if (!RESEND_API_KEY) return json(500, { error: "RESEND_API_KEY is not configured." }, requestOrigin)
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return json(500, { error: "Supabase environment is not configured." }, requestOrigin)
    }

    // 4. Auth.
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) return json(401, { error: "Missing Authorization header." }, requestOrigin)

    const authClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
      auth:   { persistSession: false, autoRefreshToken: false },
    })
    const { data: { user: caller }, error: callerError } = await authClient.auth.getUser()
    if (callerError || !caller) return json(401, { error: "Invalid or expired session." }, requestOrigin)

    const service = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    })

    const { data: tmsUser } = await service
      .from("users").select("id, is_active, role")
      .eq("auth_id", caller.id).eq("is_active", true)
      .limit(1).maybeSingle()

    const STAFF_ROLES = new Set(["ADMIN", "MANAGER", "DISPATCHER"])
    const isStaff = !!tmsUser && STAFF_ROLES.has(String(tmsUser.role ?? "").toUpperCase())

    const { data: driver } = await service
      .from("drivers").select("id, status")
      .eq("auth_user_id", caller.id)
      .limit(1).maybeSingle()

    const isDriverActive = !!driver && String(driver.status ?? "ACTIVE").toUpperCase() !== "INACTIVE"
    if (!isStaff && !isDriverActive) return json(403, { error: "Caller is not authorized to send email." }, requestOrigin)

    // 5. Parse + validate body.
    const body = (await req.json()) as EmailRequestBody

    const requestedKind = String(body.kind ?? "").trim().toLowerCase()
    if (!ALLOWED_KINDS.has(requestedKind)) return json(400, { error: "Invalid or missing email kind." }, requestOrigin)
    if (!isStaff && isDriverActive && !DRIVER_ALLOWED_KINDS.has(requestedKind)) {
      return json(403, { error: "Driver is not authorized for this email kind." }, requestOrigin)
    }

    // Recipient validation.
    const toR = normalizeRecipientList(body.to, "to")
    const ccR = normalizeRecipientList(body.cc, "cc")
    const bcR = normalizeRecipientList(body.bcc, "bcc")
    if (!toR.ok || !ccR.ok || !bcR.ok) return json(400, { error: "Invalid recipients." }, requestOrigin)
    if (toR.list.length === 0) return json(400, { error: "Missing required field: to." }, requestOrigin)

    // Driver-allowed kinds: single to, no cc/bcc.
    if (!isStaff && isDriverActive && (toR.list.length !== 1 || ccR.list.length || bcR.list.length)) {
      return json(403, { error: "Driver may only send to a single recipient." }, requestOrigin)
    }

    // Subject + body validation.
    const subject = typeof body.subject === "string" ? body.subject : ""
    if (!subject || subject.length > MAX_SUBJECT_LEN) return json(400, { error: "Invalid subject." }, requestOrigin)
    // CRLF / NUL rejection: SMTP header injection guard. Resend builds headers
    // from `subject` and from attachment `filename`; raw \r or \n could let an
    // attacker inject Bcc/From or split a body. Also reject bare \0.
    if (/[\r\n\0]/.test(subject)) return json(400, { error: "Invalid characters in subject." }, requestOrigin)

    const html = typeof body.html === "string" ? body.html : ""
    const text = typeof body.text === "string" ? body.text : ""
    if (html && utf8Bytes(html) > MAX_HTML_BYTES) return json(400, { error: "html too large." }, requestOrigin)
    if (text && utf8Bytes(text) > MAX_TEXT_BYTES) return json(400, { error: "text too large." }, requestOrigin)

    // Attachments.
    const att = normalizeAttachments(body)
    if (!att.ok) return json(400, { error: "Attachment validation failed." }, requestOrigin)
    if (!html && !text && att.list.length === 0) {
      return json(400, { error: "Missing required content: one of html/text/attachment(s)." }, requestOrigin)
    }

    // 6. Idempotency key (optional).
    const idemHeader = req.headers.get("idempotency-key")
    const idempotencyKey = idemHeader && IDEMPOTENCY_REGEX.test(idemHeader) ? idemHeader : null
    if (idemHeader && !idempotencyKey) return json(400, { error: "Invalid Idempotency-Key." }, requestOrigin)

    // 7. IP from X-Forwarded-For (first hop).
    const xff = req.headers.get("x-forwarded-for") ?? ""
    const ip  = xff.split(",")[0]?.trim() || "unknown"

    // 8. Atomic preflight: kill-switch + replay + rate limit + insert pending.
    //    The RPC enforces three rate-limit tiers (per-uid, per-IP, global)
    //    and we map all three to a single 429 client response — clients
    //    don't need to know which ceiling tripped, only to back off.
    const recipientCount = toR.list.length + ccR.list.length + bcR.list.length
    const { data: preflight, error: preflightError } = await service.rpc("email_quota_check_and_log", {
      p_auth_uid:               caller.id,
      p_user_id:                tmsUser?.id ?? null,
      p_driver_id:              driver?.id ?? null,
      p_ip:                     ip,
      p_origin:                 requestOrigin,
      p_kind:                   requestedKind,
      p_recipient_count:        recipientCount,
      p_attachment_count:       att.list.length,
      p_attachment_total_bytes: att.totalBytes,
      p_idempotency_key:        idempotencyKey,
      p_limit:                  QUOTA_LIMIT_PER_HOUR,
      // p_ip_limit / p_global_limit use server-side defaults (100, 1000).
    })
    if (preflightError) {
      console.error("email_quota_check_and_log failed:", preflightError)
      return json(500, { error: "Quota service unavailable." }, requestOrigin)
    }
    const row = Array.isArray(preflight) ? preflight[0] : preflight
    const decision: string         = row?.decision ?? ""
    const priorResendId: string | null = row?.prior_resend_id ?? null
    logId = (row?.log_id ?? null) as number | null

    if (decision === "blocked_kill_switch") {
      return json(503, { error: "Service temporarily unavailable." }, requestOrigin)
    }
    // All three rate-limit tiers map to 429 with identical client behavior.
    // The specific tier is recorded server-side (decision field above) for ops.
    if (
      decision === "rate_limited" ||
      decision === "rate_limited_ip" ||
      decision === "rate_limited_global"
    ) {
      return json(429, { error: "Rate limit exceeded. Try again later." }, requestOrigin)
    }
    if (decision === "replay") {
      return json(200, { success: true, id: priorResendId, replay: true }, requestOrigin)
    }
    if (decision !== "proceed" || logId == null) {
      console.error("Unexpected preflight decision:", decision)
      return json(500, { error: "Quota service error." }, requestOrigin)
    }

    // 9. Build sanitized Resend payload.
    const emailPayload: Record<string, unknown> = { from: FROM_ADDRESS, to: toR.list, subject }
    if (ccR.list.length) emailPayload.cc  = ccR.list
    if (bcR.list.length) emailPayload.bcc = bcR.list
    if (html) emailPayload.html = sanitizeHtml(html)
    if (text) emailPayload.text = text
    if (att.list.length) emailPayload.attachments = att.list.map(a => ({ filename: a.filename, content: a.content }))

    // 10. Pre-fetch deadline check. Belt-and-suspenders alongside the outer
    //     Promise.race wrapper: if we're already past deadline, skip the
    //     Resend round-trip entirely and finalize cleanly. The wrapper would
    //     still catch us mid-fetch if we slip past this checkpoint.
    if (Date.now() > deadlineMs) {
      await finalize("rejected_outer_timeout", "outer_timeout_pre_fetch", null)
      return json(504, { error: "Request timed out." }, requestOrigin)
    }

    // 11. Send.
    let resendId: string | null = null
    try {
      const res = await postToResend(emailPayload)
      const data = await res.json().catch(() => ({}))
      if (!res.ok) {
        console.error("Resend API error:", { status: res.status, data })
        await finalize("rejected_resend_error", `resend_${res.status}`, null)
        return json(502, { error: "Failed to send email." }, requestOrigin)
      }
      resendId = typeof data?.id === "string" ? data.id : null
    } catch (err) {
      console.error("Resend fetch error after retry:", err)
      await finalize("rejected_network", "network_error", null)
      return json(502, { error: "Failed to send email." }, requestOrigin)
    }

    // 12. Finalize log row as sent.
    await finalize("sent", null, resendId)
    return json(200, { success: true, id: resendId }, requestOrigin)
  }

  // ---- Outer wrapper: race work() against an absolute timeout ----
  // Sentinel object (not an Error) lets us distinguish "timeout fired" from
  // "work() threw" without string-matching error messages. Promise.race
  // resolves/rejects with whichever settles first; the loser still completes
  // in the background but its result is discarded.
  const TIMEOUT_SENTINEL = Symbol("outer-timeout")
  let timeoutHandle: number | undefined
  const timeoutPromise = new Promise<typeof TIMEOUT_SENTINEL>((resolve) => {
    timeoutHandle = setTimeout(() => resolve(TIMEOUT_SENTINEL), OUTER_TIMEOUT_MS) as unknown as number
  })

  try {
    const result = await Promise.race([work(), timeoutPromise])
    if (result === TIMEOUT_SENTINEL) {
      console.error("Edge function exceeded outer timeout:", OUTER_TIMEOUT_MS, "ms")
      // Best-effort finalize — if work() already inserted a pending log row,
      // mark it rejected_outer_timeout so it doesn't pin the rate-limit
      // counter as a stale pending. If logId is still null we just return.
      await finalize("rejected_outer_timeout", "outer_timeout", null)
      return json(504, { error: "Request timed out." }, requestOrigin)
    }
    return result
  } catch (error) {
    console.error("Edge function error:", error)
    await finalize("rejected_unhandled", "unhandled_exception", null)
    return json(500, { error: "Internal error." }, requestOrigin)
  } finally {
    if (timeoutHandle !== undefined) clearTimeout(timeoutHandle)
  }
})
