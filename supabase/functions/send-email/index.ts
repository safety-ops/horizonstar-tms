// Supabase Edge Function for sending emails via Resend
// Deploy: supabase functions deploy send-email
// Set secret: supabase secrets set RESEND_API_KEY=re_xxxxx

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Check if API key is configured
    if (!RESEND_API_KEY) {
      return new Response(
        JSON.stringify({ error: 'RESEND_API_KEY not configured. Run: supabase secrets set RESEND_API_KEY=your_key' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { to, cc, bcc, subject, html, text, from_name, attachment, attachments } = await req.json()

    // Validate required fields - need either html or text body, OR an attachment
    if (!to || !subject || (!html && !text && !attachment && !attachments)) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: to, subject, and either html, text, attachment, or attachments' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Build the email payload
    const emailPayload: any = {
      from: from_name ? `${from_name} <noreply@luckycabbagetms.com>` : 'Horizon Star TMS <noreply@luckycabbagetms.com>',
      to: Array.isArray(to) ? to : [to],
      subject: subject,
    }

    // Add CC if provided
    if (cc) {
      emailPayload.cc = Array.isArray(cc) ? cc : [cc]
    }

    // Add BCC if provided
    if (bcc) {
      emailPayload.bcc = Array.isArray(bcc) ? bcc : [bcc]
    }

    // Add html body if provided
    if (html) {
      emailPayload.html = html
    }

    // Add text body if provided
    if (text) {
      emailPayload.text = text
    }

    // Add attachments - support both single attachment and array
    if (attachments && Array.isArray(attachments) && attachments.length > 0) {
      // Multiple attachments array - strip out any extra fields, keep only filename and content
      emailPayload.attachments = attachments
        .filter(att => att.filename && att.content)
        .map(att => ({ filename: att.filename, content: att.content }))
    } else if (attachment && attachment.filename && attachment.content) {
      // Single attachment object (legacy support)
      emailPayload.attachments = [{
        filename: attachment.filename,
        content: attachment.content  // base64 encoded content
      }]
    }

    // Send email via Resend API
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify(emailPayload),
    })

    const data = await res.json()

    if (!res.ok) {
      console.error('Resend API error:', data)
      return new Response(
        JSON.stringify({ error: data.message || 'Failed to send email' }),
        { status: res.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ success: true, id: data.id }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Edge function error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
