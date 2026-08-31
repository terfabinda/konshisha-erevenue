import { FastifyInstance } from 'fastify'
import { getSupabase } from '../lib/supabase'
import { requireAuth } from '../lib/auth'

export async function registerAgentRoutes(app: FastifyInstance) {
  const requireAdmin = async (request: Parameters<typeof requireAuth>[0], reply: Parameters<typeof requireAuth>[1]) => {
    if (!(await requireAuth(request, reply))) return false
    if (request.user!.role !== 'admin') {
      reply.code(403).send({ error: 'admin only' })
      return false
    }
    return true
  }

  // List users (agents)
  app.get('/', async (request, reply) => {
    if (!(await requireAdmin(request, reply))) return
    const sb = getSupabase()
    const { data, error } = await sb
      .from('profiles')
      .select('*')
      .eq('role', 'agent')
      .order('created_at', { ascending: false })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Create agent
  app.post('/', async (request, reply) => {
    if (!(await requireAdmin(request, reply))) return
    const b = request.body as Record<string, unknown>
    const sb = getSupabase()
    const { data: userData, error: userError } = await sb.auth.admin.createUser({
      email: b.email as string,
      password: b.password as string,
      email_confirm: true,
      user_metadata: { display_name: b.display_name, agency_id: b.agency_id },
      app_metadata: { role: 'agent' },
    })
    if (userError) return reply.code(400).send({ error: userError.message })
    if (userData.user) {
      const { error } = await sb.from('profiles').insert({
        id: userData.user.id,
        username: b.email,
        display_name: b.display_name,
        role: 'agent',
        agency_id: b.agency_id,
        max_offline_days: b.max_offline_days ?? 7,
        expiry_days: b.expiry_days ?? null,
        must_change_password: true,
        is_active: true,
      })
      if (error) return reply.code(400).send({ error: error.message })
    }
    return reply.code(201).send(userData)
  })

  // Update agent
  app.patch('/:id', async (request, reply) => {
    if (!(await requireAdmin(request, reply))) return
    const { id } = request.params as { id: string }
    const body = request.body as Record<string, unknown>
    const sb = getSupabase()
    const { data, error } = await sb.from('profiles').update(body).eq('id', id).select().single()
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Toggle active
  app.patch('/:id/active', async (request, reply) => {
    if (!(await requireAdmin(request, reply))) return
    const { id } = request.params as { id: string }
    const { is_active } = request.body as { is_active: boolean }
    const sb = getSupabase()
    const { data, error } = await sb.from('profiles').update({ is_active }).eq('id', id).select().single()
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Reset device binding
  app.patch('/:id/reset-device', async (request, reply) => {
    if (!(await requireAdmin(request, reply))) return
    const { id } = request.params as { id: string }
    const sb = getSupabase()
    const { data, error } = await sb
      .from('profiles')
      .update({ bound_device_fingerprint: null, device_fingerprint_fixed: false })
      .eq('id', id)
      .select()
      .single()
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Agent receipt count
  app.get('/:id/receipt-count', async (request, reply) => {
    if (!(await requireAdmin(request, reply))) return
    const { id } = request.params as { id: string }
    const sb = getSupabase()
    const { data, error } = await sb.rpc('get_agent_receipt_count', { p_user_id: id })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send({ count: data })
  })

}
