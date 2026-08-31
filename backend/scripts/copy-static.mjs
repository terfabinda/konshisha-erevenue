import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(__dirname, '..')
const adminDist = path.join(root, 'apps', 'admin-web', 'dist')
const publicDir = path.join(root, 'apps', 'api', 'public')

function copyDir(src, dest) {
  if (!fs.existsSync(src)) {
    console.warn(`[copy-static] source not found, skipping: ${src}`)
    return
  }
  fs.rmSync(dest, { recursive: true, force: true })
  fs.mkdirSync(dest, { recursive: true })
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const from = path.join(src, entry.name)
    const to = path.join(dest, entry.name)
    if (entry.isDirectory()) {
      copyDir(from, to)
    } else {
      fs.copyFileSync(from, to)
    }
  }
  console.log(`[copy-static] copied ${adminDist} -> ${publicDir}`)
}

copyDir(adminDist, publicDir)
