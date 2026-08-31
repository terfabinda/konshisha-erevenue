import Fastify from 'fastify'
import cors from '@fastify/cors'
import fastifyStatic from '@fastify/static'
import path from 'node:path'
import dotenv from 'dotenv'
import { registerAuthRoutes } from './routes/auth'
import { registerAgencyRoutes } from './routes/agencies'
import { registerReceiptRoutes } from './routes/receipts'
import { registerPrintRoutes } from './routes/prints'
import { registerStatsRoutes } from './routes/stats'
import { registerCategoryRoutes } from './routes/categories'
import { registerSecurityRoutes } from './routes/security'
import { registerAgentRoutes } from './routes/agents'

dotenv.config()

export function buildApp() {
  const app = Fastify({ logger: true })

  app.register(cors, {
    origin: true,
    credentials: true,
  })

  app.get('/health', async () => ({ status: 'ok', service: 'erevenue-api' }))

  app.register(registerAuthRoutes, { prefix: '/api/auth' })
  app.register(registerAgencyRoutes, { prefix: '/api/agencies' })
  app.register(registerReceiptRoutes, { prefix: '/api/receipts' })
  app.register(registerPrintRoutes, { prefix: '/api/prints' })
  app.register(registerStatsRoutes, { prefix: '/api/stats' })
  app.register(registerCategoryRoutes, { prefix: '/api/categories' })
  app.register(registerSecurityRoutes, { prefix: '/api/security' })
  app.register(registerAgentRoutes, { prefix: '/api/agents' })

  // Serve the admin-web SPA (built into apps/api/public before deploy).
  // Resolve the directory robustly across dev (source), compiled (dist), and
  // Vercel function bundle (includeFiles preserves apps/api/public/...).
  const publicDirCandidates = [
    path.join(process.cwd(), 'apps', 'api', 'public'),
    path.join(__dirname, '..', '..', 'public'),
    path.join(__dirname, '..', '..', 'dist', 'public'),
    path.join(__dirname, '..', 'public'),
  ]
  const publicDir =
    publicDirCandidates.find((p) => {
      try {
        return require('node:fs').existsSync(p)
      } catch {
        return false
      }
    }) ?? null

  if (publicDir) {
    app.register(fastifyStatic, {
      root: publicDir,
      wildcard: false,
      prefix: '/',
    })
  }

  // SPA fallback: any non-API GET returns index.html for client-side routing.
  app.setNotFoundHandler((req, reply) => {
    if (
      publicDir &&
      req.method === 'GET' &&
      !req.url.startsWith('/api') &&
      req.url !== '/health'
    ) {
      return reply.sendFile('index.html')
    }
    return reply.code(404).send({ error: 'Not found', path: req.url })
  })

  return app
}

// Only listen when run directly (not when imported by Vercel)
if (require.main === module) {
  const app = buildApp()
  const port = Number(process.env.PORT) || 8080
  app.listen({ port, host: '0.0.0.0' }, (err) => {
    if (err) {
      app.log.error(err)
      process.exit(1)
    }
  })
}
