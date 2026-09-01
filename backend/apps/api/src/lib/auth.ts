import { FastifyRequest, FastifyReply } from 'fastify'
import { getSupabase } from './supabase'

declare module 'fastify' {
  interface FastifyRequest {
    user?: {
      id: string
      email: string
      role: string
      app_metadata: Record<string, unknown>
    }
    supabaseToken?: string
  }
}

// Require a valid bearer JWT. On success attaches request.user and returns true.
// On failure sends a 401 and returns false (caller must `return`).
export async function requireAuth(request: FastifyRequest, reply: FastifyReply): Promise<boolean> {
  const auth = request.headers.authorization
  if (!auth || !auth.startsWith('Bearer ')) {
    reply.code(401).send({ error: 'missing bearer token' })
    return false
  }

  const token = auth.slice(7)
  const sb = getSupabase()
  const { data, error } = await sb.auth.getUser(token)

  if (error || !data.user) {
    reply.code(401).send({ error: 'invalid token' })
    return false
  }

  const appMeta = (data.user.app_metadata ?? {}) as Record<string, unknown>
  let role = (appMeta.role as string) ?? ''
  // Fallback to profiles.role (covers users created via Dashboard + manual profile insert)
  if (!role) {
    try {
      const svc = (await import('./supabase')).getServiceSupabase()
      const { data: prof } = await svc.from('profiles').select('role').eq('id', data.user.id).single()
      if (prof?.role) role = prof.role as string
    } catch {
      /* ignore */
    }
  }
  request.user = {
    id: data.user.id,
    email: data.user.email ?? '',
    role: role || 'agent',
    app_metadata: appMeta,
  }
  request.supabaseToken = token
  return true
}
