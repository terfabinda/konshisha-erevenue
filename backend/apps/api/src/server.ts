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
  const app = Fastify({ logger: true, ignoreTrailingSlash: true, ignoreDuplicateSlashes: true })

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
  // the Vercel function bundle. Fall back to a filesystem search so the SPA
  // is found regardless of where the runtime lands the included files.
  const fs = require('node:fs')
  const publicDir = resolvePublicDir(fs, __dirname)

  if (publicDir) {
    app.log.info({ publicDir }, 'Serving admin-web SPA from')
    app.register(fastifyStatic, {
      root: publicDir,
      wildcard: false,
      prefix: '/',
    })
  } else {
    app.log.warn('Unable to locate admin-web SPA static directory')
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

function resolvePublicDir(fs: typeof import('node:fs'), dirname: string): string | null {
  const candidates: string[] = [
    path.join(process.cwd(), 'apps', 'api', 'public'),
    path.join(dirname, '..', '..', 'public'),
    path.join(dirname, '..', '..', 'dist', 'public'),
    path.join(dirname, '..', 'public'),
    // Vercel lambda: files may be hoisted relative to the function root.
    path.join(process.cwd(), 'public'),
    path.join(process.cwd(), 'apps'),
  ]

  for (const candidate of candidates) {
    try {
      if (fs.existsSync(path.join(candidate, 'index.html'))) return candidate
    } catch {
      /* ignore */
    }
  }

  // Last resort: walk upward from the module and from cwd looking for a
  // directory that contains index.html (i.e. the admin-web build output).
  const dirs = [process.cwd(), dirname]
  for (const start of dirs) {
    let current = start
    for (let i = 0; i < 8; i++) {
      try {
        const root = path.join(current, 'apps', 'api', 'public')
        if (fs.existsSync(path.join(root, 'index.html'))) return root
      } catch {
        /* ignore */
      }
      const parent = path.dirname(current)
      if (parent === current) break
      current = parent
    }
  }

  return null
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
