import { FastifyInstance } from 'fastify'
import { getSupabase } from '../lib/supabase'
import { requireAuth } from '../lib/auth'

export async function registerCategoryRoutes(app: FastifyInstance) {
  // List all revenue categories
  app.get('/', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const sb = getSupabase()
    const { data, error } = await sb
      .from('categories')
      .select('*')
      .order('sort_order')
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Categories enabled for an agency
  app.get('/agency/:agencyId', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const { agencyId } = request.params as { agencyId: string }
    const sb = getSupabase()
    const { data, error } = await sb
      .from('agency_categories')
      .select('*, categories(*)')
      .eq('agency_id', agencyId)
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Reference to the 56 default categories. Seeding is done via migration/seed script.
  app.get('/defaults', async () => ({ count: 56, note: 'seed via default_categories.dart' }))

  // Add category (admin)
  app.post('/', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    if (request.user!.role !== 'admin') return reply.code(403).send({ error: 'admin only' })
    const b = request.body as Record<string, unknown>
    const sb = getSupabase()
    const { data, error } = await sb.from('categories').insert({
      name: b.name,
      default_amount: b.default_amount ?? null,
      sort_order: b.sort_order ?? 0,
    }).select().single()
    if (error) return reply.code(400).send({ error: error.message })
    return reply.code(201).send(data)
  })

}
