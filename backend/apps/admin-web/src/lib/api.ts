import { supabase, API_URL } from './supabase'

// Thin wrapper around the Node.js API. Adds the logged-in Supabase session
// JWT as a Bearer token, matching what the backend's requireAuth() expects.
export async function apiFetch<T = unknown>(
  path: string,
  options: { method?: string; body?: unknown; headers?: Record<string, string> } = {},
): Promise<{ data: T | null; error: string | null; status: number }> {
  const {
    data: { session },
  } = await supabase.auth.getSession()
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    Accept: 'application/json',
    ...(options.headers ?? {}),
  }
  if (session?.access_token) headers['Authorization'] = `Bearer ${session.access_token}`

  try {
    const res = await fetch(`${API_URL}${path}`, {
      method: options.method ?? 'GET',
      headers,
      body: options.body !== undefined ? JSON.stringify(options.body) : undefined,
    })
    const text = await res.text()
    let data: unknown = null
    try {
      data = text ? JSON.parse(text) : null
    } catch {
      data = text
    }
    if (!res.ok) {
      const message: string =
        ((data as Record<string, unknown> | null)?.['error'] as string) ||
        `Request failed (${res.status})`
      return { data: null, error: message, status: res.status }
    }
    return { data: data as T, error: null, status: res.status }
  } catch (e) {
    return { data: null, error: (e as Error).message, status: 0 }
  }
}
