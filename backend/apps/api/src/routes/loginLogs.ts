import { FastifyInstance } from 'fastify'
import { getServiceSupabase, getSupabaseForUser } from '../lib/supabase'
import { requireAuth } from '../lib/auth'

export async function registerLoginLogRoutes(app: FastifyInstance) {
  // Public: Flutter app (Firebase auth) can log without Supabase JWT.
  // Uses service_role to bypass RLS.
  app.post('/', async (request, reply) => {
    try {
      const b = (request.body as Record<string, unknown>) ?? {}
      const email = typeof b.email === 'string' ? b.email.trim() : null
      if (!email) return reply.code(400).send({ error: 'email is required' })

      const svc = getServiceSupabase()
      const payload: Record<string, unknown> = {
        user_id: typeof b.user_id === 'string' ? b.user_id : null,
        email,
        display_name: typeof b.display_name === 'string' ? b.display_name : null,
        agency_id: typeof b.agency_id === 'string' ? b.agency_id : null,
        agency_code: typeof b.agency_code === 'string' ? b.agency_code : null,
        agency_name: typeof b.agency_name === 'string' ? b.agency_name : null,
        ip_address: (request.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() ?? request.ip ?? null,
        user_agent: typeof b.user_agent === 'string' ? b.user_agent.slice(0, 500) : (request.headers['user-agent'] as string)?.slice(0, 500) ?? null,
        device_fingerprint: typeof b.device_fingerprint === 'string' ? b.device_fingerprint : null,
        platform: typeof b.platform === 'string' ? b.platform.slice(0, 50) : null,
        device_name: typeof b.device_name === 'string' ? b.device_name.slice(0, 200) : null,
        os_version: typeof b.os_version === 'string' ? b.os_version.slice(0, 100) : null,
        success: b.success !== false,
        failure_reason: typeof b.failure_reason === 'string' ? b.failure_reason.slice(0, 500) : null,
      }

      // Enrich agency code/name if agency_id provided but code/name missing
      if (payload.agency_id && (!payload.agency_code || !payload.agency_name)) {
        const { data: ag } = await svc.from('agencies').select('code, name').eq('id', payload.agency_id as string).single()
        if (ag) {
          payload.agency_code = payload.agency_code ?? (ag as any).code ?? null
          payload.agency_name = payload.agency_name ?? (ag as any).name ?? null
        }
      }

      const { data, error } = await svc.from('login_logs').insert(payload).select().single()
      if (error) {
        request.log.error({ err: error }, 'login_logs insert failed')
        return reply.code(400).send({ error: error.message })
      }
      return reply.code(201).send(data)
    } catch (err) {
      request.log.error(err, 'unhandled login_logs POST')
      return reply.code(500).send({ error: (err as Error).message })
    }
  })

  // Authenticated read: respects RLS via user JWT
  app.get('/', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const sb = getSupabaseForUser(request.supabaseToken!)
    const { data, error } = await sb
      .from('login_logs')
      .select('*')
      .order('login_at', { ascending: false })
      .limit(200)
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })
}
