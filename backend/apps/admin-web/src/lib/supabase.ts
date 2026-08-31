import { createClient } from '@supabase/supabase-js'

// Admin console talks DIRECTLY to Supabase (PostgREST + Auth) for live log
// streaming and to the Node.js API for aggregate reports.
// Fill these in .env (Vite: VITE_ prefix)
const url = (import.meta.env.VITE_SUPABASE_URL as string) || ''
const key = (import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string) || ''

export const API_URL = (import.meta.env.VITE_API_URL as string) || '/api'

export const supabase = createClient(url, key, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
})

export const isConfigured = Boolean(url && key)
