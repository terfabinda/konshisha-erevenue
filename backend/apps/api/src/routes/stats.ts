import { FastifyInstance } from 'fastify'
import { getSupabase } from '../lib/supabase'
import { requireAuth } from '../lib/auth'

export async function registerStatsRoutes(app: FastifyInstance) {
  // Dashboard stats (server-computed)
  app.get('/dashboard', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const sb = getSupabase()
    const { data, error } = await sb.rpc('get_dashboard_stats')
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Revenue stats over a date range
  app.get('/revenue', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const q = request.query as Record<string, string>
    const sb = getSupabase()
    const { data, error } = await sb.rpc('get_revenue_stats', {
      p_start: q.from || null,
      p_end: q.to || null,
    })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Print stats over a date range
  app.get('/prints', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const q = request.query as Record<string, string>
    const sb = getSupabase()
    const { data, error } = await sb.rpc('get_print_stats', {
      p_start: q.from || null,
      p_end: q.to || null,
    })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Revenue trend for charts
  app.get('/trend', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const q = request.query as Record<string, string>
    const sb = getSupabase()
    const { data, error } = await sb.rpc('get_revenue_trend', {
      p_days: q.days ? Number(q.days) : 30,
    })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Agency summary (admin)
  app.get('/agencies', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const sb = getSupabase()
    const { data, error } = await sb.rpc('get_agency_summary')
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Agent summary (admin)
  app.get('/agents', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const sb = getSupabase()
    const { data, error } = await sb.rpc('get_agent_summary')
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

}
