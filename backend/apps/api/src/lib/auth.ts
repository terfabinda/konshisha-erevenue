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

// Require a valid bearer JWT (Supabase or Firebase). On success attaches request.user and returns true.
export async function requireAuth(request: FastifyRequest, reply: FastifyReply): Promise<boolean> {
  const auth = request.headers.authorization
  if (!auth || !auth.startsWith('Bearer ')) {
    reply.code(401).send({ error: 'missing bearer token' })
    return false
  }

  const token = auth.slice(7)

  // Try Supabase first
  try {
    const sb = getSupabase()
    const { data, error } = await sb.auth.getUser(token)
    if (!error && data.user) {
      const appMeta = (data.user.app_metadata ?? {}) as Record<string, unknown>
      let role = (appMeta.role as string) ?? ''
      if (!role) {
        try {
          const svc = (await import('./supabase')).getServiceSupabase()
          const { data: prof } = await svc.from('profiles').select('role').eq('id', data.user.id).single()
          if (prof?.role) role = prof.role as string
        } catch {}
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
  } catch {}

  // Fallback: try Firebase Admin verification
  try {
    const adminNs = await import('firebase-admin') as any
    const admin = adminNs.default ?? adminNs
    if (!admin.apps.length) {
      try {
        admin.initializeApp()
      } catch {}
    }
    if (admin.apps.length) {
      const decoded = await admin.auth().verifyIdToken(token)
      const uid = decoded.uid
      const email = decoded.email ?? ''
      // Try to get role from Supabase profiles (if mirrored) or from Firebase custom claims
      let role = (decoded['role'] as string) ?? ''
      if (!role) {
        try {
          const svc = (await import('./supabase')).getServiceSupabase()
          const { data: prof } = await svc.from('profiles').select('role').eq('id', uid).single()
          if (prof?.role) role = prof.role as string
        } catch {}
      }
      // Also try Firestore for legacy Firebase users
      if (!role) {
        try {
          const svc = (await import('./supabase')).getServiceSupabase()
          const { data: prof } = await svc.from('profiles').select('role').eq('id', uid).single()
          if (prof?.role) role = prof.role as string
        } catch {}
      }
      request.user = {
        id: uid,
        email,
        role: role || 'agent',
        app_metadata: decoded as Record<string, unknown>,
      }
      request.supabaseToken = token
      return true
    }
  } catch {}

  reply.code(401).send({ error: 'invalid token' })
  return false
}
