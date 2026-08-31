import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { createRequire } from 'node:module'
import { execSync } from 'node:child_process'

// Produce a Vercel v3 Build Output (`.vercel/output`) that serves the admin-web
// SPA as static files and the Node API as a single bundled serverless function.
// This is deterministic (no reliance on Vercel monorepo heuristics): whatever
// we place in `.vercel/output` is exactly what gets deployed.

const require = createRequire(import.meta.url)
const __dirname = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(__dirname, '..')
const esbuild = require('esbuild')

const adminDist = path.join(root, 'apps', 'admin-web', 'dist')
const apiEntry = path.join(root, 'apps', 'api', 'api', 'index.ts')

const outputDir = path.join(root, '.vercel', 'output')
const staticDir = path.join(outputDir, 'static')
const functionsRoot = path.join(outputDir, 'functions')
const apiFuncDir = path.join(functionsRoot, 'api.func')

function rmrf(p) {
  fs.rmSync(p, { recursive: true, force: true })
}

function copyDir(src, dest) {
  if (!fs.existsSync(src)) {
    throw new Error(`[vercel-build] source not found: ${src}`)
  }
  rmrf(dest)
  fs.cpSync(src, dest, { recursive: true })
  console.log(`[vercel-build] copied ${src} -> ${dest}`)
}

// 1) Build the workspaces (compiles api/shared/sync, builds admin-web dist).
console.log('[vercel-build] building workspaces...')
execSync('npm run build --workspaces', { cwd: root, stdio: 'inherit' })

// 2) Assemble the v3 output.
rmrf(outputDir)
fs.mkdirSync(staticDir, { recursive: true })
fs.mkdirSync(apiFuncDir, { recursive: true })

// 2a) Static SPA (served directly by Vercel).
copyDir(adminDist, staticDir)

// 2b) Single bundled API function (all deps inlined via esbuild).
console.log('[vercel-build] bundling API function...')
await esbuild.build({
  entryPoints: [apiEntry],
  bundle: true,
  platform: 'node',
  target: 'node20',
  format: 'cjs',
  outfile: path.join(apiFuncDir, 'index.cjs'),
  sourcemap: false,
  logLevel: 'info',
})

// 2c) Co-locate the SPA inside the function too, so the Fastify fallback works
//     even if a static request reaches the function (matches tested layout).
copyDir(adminDist, path.join(apiFuncDir, 'public'))

fs.writeFileSync(
  path.join(apiFuncDir, '.vc-config.json'),
  JSON.stringify(
    {
      runtime: 'nodejs20.x',
      handler: 'index.cjs',
      launcherType: 'Nodejs',
      maxDuration: 10,
    },
    null,
    2,
  ),
)

fs.writeFileSync(
  path.join(outputDir, 'config.json'),
  JSON.stringify(
    {
      version: 3,
      routes: [
        { src: '/api/(.*)', dest: '/api.func' },
        { src: '/health', dest: '/api.func' },
        { src: '/(.*)', dest: '/index.html' },
      ],
    },
    null,
    2,
  ),
)

console.log('[vercel-build] done. Output at', outputDir)
