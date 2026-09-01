import { supabase } from './supabase'

export async function logLogin(opts: {
  email: string
  success: boolean
  failure_reason?: string | null
  user_id?: string | null
  display_name?: string | null
  agency_id?: string | null
}) {
  try {
    const { data: { user } } = await supabase.auth.getUser().catch(() => ({ data: { user: null } } as any))
    // Try to enrich with profile if we have a user_id
    let agencyId = opts.agency_id ?? null
    let displayName = opts.display_name ?? null
    let agencyCode: string | null = null
    let agencyName: string | null = null
    const uid = opts.user_id ?? user?.id ?? null
    if (uid && (!agencyId || !displayName)) {
      const { data: prof } = await supabase.from('profiles').select('display_name, agency_id').eq('id', uid).single()
      if (prof) {
        displayName = displayName ?? (prof as any).display_name ?? null
        agencyId = agencyId ?? (prof as any).agency_id ?? null
      }
    }
    if (agencyId) {
      const { data: ag } = await supabase.from('agencies').select('code, name').eq('id', agencyId).single()
      if (ag) {
        agencyCode = (ag as any).code ?? null
        agencyName = (ag as any).name ?? null
      }
    }

    const ua = typeof navigator !== 'undefined' ? navigator.userAgent.slice(0, 400) : null
    const platform =
      typeof navigator !== 'undefined'
        ? ((navigator as any).userAgentData?.platform as string) ??
          (navigator.platform as string) ??
          null
        : null
    // crude OS version from UA
    let osVersion: string | null = null
    try {
      const m = ua?.match(/(Windows NT [^;)]+|Mac OS X [^;)]+|Android [^;)]+|iPhone OS [^;)]+)/)
      if (m) osVersion = m[1].slice(0, 100)
    } catch {}

    await supabase.from('login_logs').insert({
      user_id: uid,
      email: opts.email,
      display_name: displayName,
      agency_id: agencyId,
      agency_code: agencyCode,
      agency_name: agencyName,
      user_agent: ua,
      platform: platform?.slice(0, 50) ?? null,
      device_name: null,
      os_version: osVersion,
      success: opts.success,
      failure_reason: opts.failure_reason ?? null,
    })
  } catch {
    // never block login on logging failure
  }
}
