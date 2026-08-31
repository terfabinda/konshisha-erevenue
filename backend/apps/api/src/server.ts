import Fastify from 'fastify'
import cors from '@fastify/cors'
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
