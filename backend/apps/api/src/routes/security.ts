import { FastifyInstance } from 'fastify'
import { getSupabase } from '../lib/supabase'
import { requireAuth } from '../lib/auth'

export async function registerSecurityRoutes(app: FastifyInstance) {
  // Get security config (public-ish; single row id=1)
  app.get('/config', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const sb = getSupabase()
    const { data, error } = await sb.from('security_config').select('*').eq('id', 1).single()
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Update security config (super admin)
  app.patch('/config', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const { data: me } = await getSupabase()
      .from('profiles')
      .select('agency_id')
      .eq('id', request.user!.id)
      .single()
    if (me?.agency_id !== null) return reply.code(403).send({ error: 'super admin only' })
    const body = request.body as Record<string, unknown>
    const sb = getSupabase()
    const { data, error } = await sb.from('security_config').update(body).eq('id', 1).select().single()
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Publish global force-sync command (super admin)
  app.post('/force-sync', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const sb = getSupabase()
    const { error } = await sb.from('security_commands').insert({
      type: 'force_sync',
      target: 'global',
      issued_by: request.user!.id,
    })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send({ ok: true })
  })

  // Bind device fingerprint to current user
  app.post('/bind-device', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const { fingerprint } = request.body as { fingerprint: string }
    const sb = getSupabase()
    const { error } = await sb.rpc('bind_device', { p_fingerprint: fingerprint })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send({ ok: true })
  })

  // Verify device fingerprint
  app.post('/verify-device', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const { fingerprint } = request.body as { fingerprint: string }
    const sb = getSupabase()
    const { data, error } = await sb.rpc('verify_device', { p_fingerprint: fingerprint })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send({ matches: data })
  })

}
