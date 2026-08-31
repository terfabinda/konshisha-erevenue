import { FastifyInstance } from 'fastify'
import { getSupabase } from '../lib/supabase'
import { requireAuth } from '../lib/auth'

export async function registerPrintRoutes(app: FastifyInstance) {
  // Create print log (idempotent)
  app.post('/', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const b = request.body as Record<string, unknown>
    const sb = getSupabase()
    const { data, error } = await sb.rpc('log_print', {
      p_id: b.id,
      p_receipt_id: b.receipt_id,
      p_copies: b.copies ?? 1,
      p_print_mode: b.print_mode ?? 'text',
      p_printer_name: b.printer_name ?? null,
      p_printer_address: b.printer_address ?? null,
      p_printer_model: b.printer_model ?? null,
      p_success: b.success ?? true,
      p_error_message: b.error_message ?? null,
      p_is_reprint: b.is_reprint ?? false,
      p_receipt_ref: b.receipt_ref ?? null,
      p_agency_id: b.agency_id ?? null,
    })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.code(201).send(data)
  })

  // Update print result
  app.patch('/:id', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const { id } = request.params as { id: string }
    const b = request.body as Record<string, unknown>
    const sb = getSupabase()
    const { data, error } = await sb.rpc('update_print_log', {
      p_id: id,
      p_success: b.success,
      p_error_message: b.error_message ?? null,
      p_copies: b.copies ?? null,
    })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // List print logs
  app.get('/', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const q = request.query as Record<string, string>
    const sb = getSupabase()
    let query = sb.from('print_logs').select('*')
    if (q.from) query = query.gte('printed_at', q.from)
    if (q.to) query = query.lte('printed_at', q.to)
    if (q.printed_by) query = query.eq('printed_by', q.printed_by)
    if (q.agency_id) query = query.eq('agency_id', q.agency_id)
    if (q.success !== undefined) query = query.eq('success', q.success === 'true')
    query = query.order('printed_at', { ascending: false })
    const { data, error } = await query
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Prints for a receipt
  app.get('/by-receipt/:receiptId', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const { receiptId } = request.params as { receiptId: string }
    const sb = getSupabase()
    const { data, error } = await sb
      .from('print_logs')
      .select('*')
      .eq('receipt_id', receiptId)
      .order('printed_at', { ascending: false })
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send(data)
  })

  // Reprint count for a receipt
  app.get('/reprint-count/:receiptId', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const { receiptId } = request.params as { receiptId: string }
    const sb = getSupabase()
    const { data, error } = await sb
      .from('print_logs')
      .select('id')
      .eq('receipt_id', receiptId)
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send({ count: data ? data.length - 1 : 0 })
  })

}
