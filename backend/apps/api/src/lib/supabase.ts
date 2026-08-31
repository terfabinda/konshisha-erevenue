import { createClient, SupabaseClient } from '@supabase/supabase-js'

let client: SupabaseClient

export function getSupabase(): SupabaseClient {
  if (!client) {
    const url = process.env.SUPABASE_URL
    const key =
      process.env.SUPABASE_ANON_KEY ??
      process.env.SUPABASE_PUBLISHABLE_KEY ??
      process.env.SUPABASE_SERVICE_KEY
    if (!url || !key) {
      throw new Error('SUPABASE_URL and SUPABASE_*_KEY must be set')
    }
    client = createClient(url, key, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    })
  }
  return client
}
