import { FastifyInstance } from 'fastify'
import { getSupabase } from '../lib/supabase'
import { requireAuth } from '../lib/auth'

export async function registerAuthRoutes(app: FastifyInstance) {
  app.post('/signup', async (request, reply) => {
    const { email, password, display_name } = request.body as {
      email: string
      password: string
      display_name: string
    }
    const sb = getSupabase()
    const { data, error } = await sb.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { display_name },
      app_metadata: { role: 'admin' },
    })
    if (error) return reply.code(400).send({ error: error.message })
    if (data.user) {
      await sb.from('profiles').insert({
        id: data.user.id,
        username: email,
        display_name,
        role: 'admin',
        agency_id: null,
        is_active: true,
      })
    }
    return reply.send(data)
  })

  app.post('/login', async (request, reply) => {
    const { email, password } = request.body as { email: string; password: string }
    const sb = getSupabase()
    const { data, error } = await sb.auth.signInWithPassword({ email, password })
    if (error) return reply.code(401).send({ error: error.message })
    return reply.send(data)
  })

  app.post('/refresh', async (request, reply) => {
    const { refresh_token } = request.body as { refresh_token: string }
    const sb = getSupabase()
    const { data, error } = await sb.auth.refreshSession({ refresh_token })
    if (error) return reply.code(401).send({ error: error.message })
    return reply.send(data)
  })

  app.post('/change-password', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const { new_password } = request.body as { new_password: string }
    const sb = getSupabase()
    const { error } = await sb.auth.admin.updateUserById(request.user!.id, {
      password: new_password,
    })
    if (error) return reply.code(400).send({ error: error.message })
    await sb.from('profiles').update({ must_change_password: false }).eq('id', request.user!.id)
    return reply.send({ ok: true })
  })

  app.get('/session', async (request, reply) => {
    if (!(await requireAuth(request, reply))) return
    const sb = getSupabase()
    const { data, error } = await sb.from('profiles').select('*').eq('id', request.user!.id).single()
    if (error) return reply.code(400).send({ error: error.message })
    return reply.send({ ...data, role_from_jwt: request.user!.role })
  })

  app.get('/logout', async (request, reply) => {
    const sb = getSupabase()
    await sb.auth.signOut()
    return reply.send({ ok: true })
  })

}
