import { buildApp } from '../src/server'

// Vercel serverless entrypoint: export the Fastify instance
// so @vercel/node can serve it as a single request handler.
const app = buildApp()

export default async function handler(req: any, res: any) {
  await app.ready()
  app.server.emit('request', req, res)
}
