import { FastifyInstance } from 'fastify'
import { getSupabase } from '../lib/supabase'
import { requireAuth } from '../lib/auth'

export async function registerReceiptRoutes(app: FastifyInstance) {
  // Create-or-ignore a receipt (idempotent by client id)
  app.post('/', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const b = request.body as Record<string, unknown>
    const sb = getSupabase()
    const { data, error } = await sb.rpc('upsert_receipt', {
      p_id: b.id,
      p_agency_id: b.agency_id,
      p_payer_name: b.payer_name ?? '',
      p_payer_phone: b.payer_phone ?? null,
      p_payer_tin: b.payer_tin ?? null,
      p_payer_address: b.payer_address ?? null,
      p_category_id: b.category_id ?? null,
      p_category_name: b.category_name ?? null,
      p_description: b.description ?? null,
      p_amount: b.amount ?? 0,
      p_discount: b.discount ?? 0,
      p_penalty: b.penalty ?? 0,
      p_quantity: b.quantity ?? 1,
      p_notes: b.notes ?? null,
      p_device_fingerprint: b.device_fingerprint ?? null,
      p_status: b.status ?? 'active',
    })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.code(201).send(data)
  })

  // Sync: bulk idempotent uplink from offline queue
  app.post('/sync', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const { rows } = request.body as { rows: unknown[] }
    if (!Array.isArray(rows)) return reply.code(400).send({ error: 'rows must be an array' })
    const sb = getSupabase()
    const { data, error } = await sb.rpc('sync_receipts', { p_rows: rows })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send({ results: data, total: rows.length })
  })

  // List receipts (filters via query params)
  app.get('/', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const q = request.query as Record<string, string>
    const sb = getSupabase()
    let query = sb.from('receipts').select('*')

    if (q.from) query = query.gte('created_at', q.from)
    if (q.to) query = query.lte('created_at', q.to)
    if (q.agency_id) query = query.eq('agency_id', q.agency_id)
    if (q.created_by) query = query.eq('created_by', q.created_by)
    if (q.category_id) query = query.eq('category_id', q.category_id)
    if (q.status) query = query.eq('status', q.status)
    query = query.order('created_at', { ascending: false })

    const { data, error } = await query
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Single receipt
  app.get('/:id', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const { id } = request.params as { id: string }
    const sb = getSupabase()
    const { data, error } = await sb.from('receipts').select('*').eq('id', id).single()
    if (error) return reply.code(404).send({ error: error.message })
    return reply.send(data)
  })

  // Void receipt
  app.post('/:id/void', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const { id } = request.params as { id: string }
    const sb = getSupabase()
    const { data, error } = await sb.rpc('void_receipt', { p_receipt_id: id })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Issue next sequential receipt ref (server-side numbering)
  app.post('/issue-ref', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const { agency_id } = request.body as { agency_id: string }
    const sb = getSupabase()
    const { data, error } = await sb.rpc('issue_receipt_ref', { p_agency_id: agency_id })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send({ receipt_ref: data })
  })

}
