import { createClient, SupabaseClient } from '@supabase/supabase-js'

let anonClient: SupabaseClient
let serviceClient: SupabaseClient | null = null

function getEnv(): { url: string; anonKey: string; serviceKey: string | undefined } {
  const url = process.env.SUPABASE_URL
  const anonKey = process.env.SUPABASE_ANON_KEY ?? process.env.SUPABASE_PUBLISHABLE_KEY ?? ''
  const serviceKey = process.env.SUPABASE_SERVICE_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!url || !anonKey) throw new Error('SUPABASE_URL and SUPABASE_ANON_KEY must be set')
  return { url, anonKey, serviceKey }
}

export function getSupabase(): SupabaseClient {
  if (!anonClient) {
    const { url, anonKey } = getEnv()
    anonClient = createClient(url, anonKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })
  }
  return anonClient
}

export function getServiceSupabase(): SupabaseClient {
  if (serviceClient) return serviceClient
  const { url, serviceKey } = getEnv()
  if (!serviceKey) throw new Error('SUPABASE_SERVICE_KEY (service_role) must be set for admin operations')
  serviceClient = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  return serviceClient
}

export function getSupabaseForUser(token: string): SupabaseClient {
  const { url, anonKey } = getEnv()
  return createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  })
}
