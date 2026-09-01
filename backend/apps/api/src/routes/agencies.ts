import { FastifyInstance } from 'fastify'
import { getSupabase, getSupabaseForUser } from '../lib/supabase'
import { requireAuth } from '../lib/auth'

export async function registerAgencyRoutes(app: FastifyInstance) {
  // List agencies (scoped by role via RLS)
  app.get('/', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const sb = getSupabaseForUser(request.supabaseToken!)
    const { data, error } = await sb.from('agencies').select('*').order('name')
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Get agency by id
  app.get('/:id', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const { id } = request.params as { id: string }
    const sb = getSupabaseForUser(request.supabaseToken!)
    const { data, error } = await sb.from('agencies').select('*').eq('id', id).single()
    if (error) return reply.code(404).send({ error: error.message })
    return reply.send(data)
  })

  // Get agency by code
  app.get('/by-code/:code', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const { code } = request.params as { code: string }
    const sb = getSupabaseForUser(request.supabaseToken!)
    const { data, error } = await sb.from('agencies').select('*').eq('code', code).single()
    if (error) return reply.code(404).send({ error: error.message })
    return reply.send(data)
  })

  // Create agency (admin)
  app.post('/', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    if (request.user!.role !== 'admin') return reply.code(403).send({ error: 'admin only' })
    const { name, code, address, phone, email, tin, admin_name, admin_phone } =
      request.body as Record<string, unknown>
    const sb = getSupabaseForUser(request.supabaseToken!)
    const { data, error } = await sb.from('agencies').insert({
      name,
      code: String(code).toUpperCase(),
      address,
      phone,
      email,
      tin,
      admin_name,
      admin_phone,
      onboarded_by: request.user!.id,
    }).select().single()
    if (error) return reply.code(400).send({ error: error.message })
    return reply.code(201).send(data)
  })

  // Update agency
  app.patch('/:id', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    if (request.user!.role !== 'admin') return reply.code(403).send({ error: 'admin only' })
    const { id } = request.params as { id: string }
    const body = request.body as Record<string, unknown>
    const sb = getSupabaseForUser(request.supabaseToken!)
    const { data, error } = await sb.from('agencies').update(body).eq('id', id).select().single()
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Deactivate / reactivate
  app.patch('/:id/active', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    if (request.user!.role !== 'admin') return reply.code(403).send({ error: 'admin only' })
    const { id } = request.params as { id: string }
    const { is_active } = request.body as { is_active: boolean }
    const sb = getSupabaseForUser(request.supabaseToken!)
    const { data, error } = await sb
      .from('agencies')
      .update({ is_active })
      .eq('id', id)
      .select()
      .single()
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Delete agency (super admin)
  app.delete('/:id', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const sb = getSupabase()
    const { data: me } = await sb.from('profiles').select('agency_id').eq('id', request.user!.id).single()
    if (me?.agency_id !== null) return reply.code(403).send({ error: 'super admin only' })
    const { id } = request.params as { id: string }
    const { error } = await sb.from('agencies').delete().eq('id', id)
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send({ ok: true })
  })

  // Agency agent count
  app.get('/:id/agent-count', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const { id } = request.params as { id: string }
    const sb = getSupabase()
    const { data, error } = await sb.rpc('get_agency_agent_count', { p_agency_id: id })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send({ count: data })
  })

  // Agency receipt count
  app.get('/:id/receipt-count', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const { id } = request.params as { id: string }
    const sb = getSupabase()
    const { data, error } = await sb.rpc('get_agency_receipt_count', { p_agency_id: id })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send({ count: data })
  })

}
