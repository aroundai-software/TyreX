// supabase/functions/send-overdue-notifications/index.ts
// Cron-scheduled Edge Function: fires every 5 mins to check for overdue jobs
// and send FCM push notifications to the executive + all admins.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const FIREBASE_SA = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!)
const FCM_PROJECT_ID: string = FIREBASE_SA.project_id

// ─── JWT / OAuth2 helpers ───────────────────────────────────────────────────

function base64UrlEncode(input: string): string {
  return btoa(input).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
}

async function getGoogleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)

  const header = base64UrlEncode(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const payload = base64UrlEncode(JSON.stringify({
    iss: FIREBASE_SA.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }))

  const signingInput = `${header}.${payload}`

  // Import the RSA private key
  const pemBody = FIREBASE_SA.private_key
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\n/g, '')
  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0))

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBytes.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const signatureBytes = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(signingInput),
  )

  const signature = btoa(String.fromCharCode(...new Uint8Array(signatureBytes)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')

  const jwt = `${signingInput}.${signature}`

  // Exchange JWT for access token
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  const data = await res.json()
  if (!data.access_token) throw new Error(`Token error: ${JSON.stringify(data)}`)
  return data.access_token
}

// ─── FCM send helper ─────────────────────────────────────────────────────────

async function sendFcm(
  fcmToken: string,
  accessToken: string,
  title: string,
  body: string,
  jobCardId: string,
): Promise<boolean> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: fcmToken,
          notification: { title, body },
          data: { job_card_id: jobCardId, type: 'overdue_reminder' },
          android: {
            priority: 'high',
            notification: { sound: 'default', channel_id: 'overdue_reminders' },
          },
        },
      }),
    },
  )
  if (!res.ok) {
    const err = await res.text()
    console.warn(`FCM send failed for token ...${fcmToken.slice(-6)}: ${err}`)
  }
  return res.ok
}

// ─── Main handler ────────────────────────────────────────────────────────────

Deno.serve(async (_req) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    // 1. Read admin-configured interval (default 60 min)
    const { data: settingRow } = await supabase
      .from('app_settings')
      .select('setting_value')
      .eq('setting_key', 'overdue_minutes_threshold')
      .single()

    const intervalMin = parseInt(String(settingRow?.setting_value ?? 60))
    const repeatMin = 30 // fixed repeat interval after first reminder

    const utcNow = new Date()
    // Convert UTC 'now' to IST 'now' to match the database's assumption of time
    const now = new Date(utcNow.getTime() + 5.5 * 60 * 60 * 1000)
    const firstCutoff = new Date(now.getTime() - intervalMin * 60_000)
    const repeatCutoff = new Date(now.getTime() - repeatMin * 60_000)

    // 2. Fetch overdue jobs (started > intervalMin ago, not finished)
    const { data: jobs, error: jobErr } = await supabase
      .from('reports')
      .select('id, job_card_id, executive_id, last_reminder_sent_at, started_at')
      .not('status', 'in', '("Completed","Delivered","Cancelled")')
      .lt('started_at', firstCutoff.toISOString())
      .not('executive_id', 'is', null)
      .not('started_at', 'is', null)

    if (jobErr) throw jobErr

    if (!jobs || jobs.length === 0) {
      return new Response(JSON.stringify({ message: 'No overdue jobs' }), { status: 200 })
    }

    // 3. Filter: only jobs that haven't had a reminder yet, or it's been 30+ min
    const toNotify = jobs.filter((j) => {
      if (!j.last_reminder_sent_at) return true
      return new Date(j.last_reminder_sent_at) < repeatCutoff
    })

    if (toNotify.length === 0) {
      return new Response(JSON.stringify({ message: 'All jobs already notified recently' }), { status: 200 })
    }

    // 4. Get all admin FCM tokens
    const { data: admins } = await supabase
      .from('users')
      .select('fcm_token')
      .eq('role', 'admin')
      .not('fcm_token', 'is', null)

    const adminTokens: string[] = (admins ?? [])
      .map((a: { fcm_token: string }) => a.fcm_token)
      .filter(Boolean)

    // 5. Get Google access token once
    const accessToken = await getGoogleAccessToken()

    let sent = 0

    for (const job of toNotify) {
      const label = job.job_card_id ?? `#${job.id}`
      const title = '⚠️ Overdue Job Alert'
      const body = `Job ${label} is overdue and still in progress!`

      // Collect unique tokens: executive + all admins
      const tokens = new Set<string>(adminTokens)

      const { data: exec } = await supabase
        .from('users')
        .select('fcm_token')
        .eq('id', job.executive_id)
        .single()

      if (exec?.fcm_token) tokens.add(exec.fcm_token)

      for (const token of tokens) {
        const ok = await sendFcm(token, accessToken, title, body, label)
        if (ok) sent++
      }

      // Update last_reminder_sent_at
      await supabase
        .from('reports')
        .update({ last_reminder_sent_at: now.toISOString() })
        .eq('id', job.id)
    }

    return new Response(
      JSON.stringify({
        message: `Sent ${sent} notifications for ${toNotify.length} overdue jobs`,
        interval_minutes: intervalMin,
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    console.error('Edge function error:', err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
