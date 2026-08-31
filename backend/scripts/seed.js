const { Client } = require('pg')
const fs = require('fs')
const path = require('path')

const CONN = process.env.DATABASE_URL
const SEED_FILE = path.join(__dirname, '..', 'supabase', 'seed.sql')

if (!CONN) {
  console.error('DATABASE_URL env var required')
  process.exit(1)
}

async function seed() {
  const client = new Client({ connectionString: CONN })
  await client.connect()
  console.log('Connected, applying seed...')
  const sql = fs.readFileSync(SEED_FILE, 'utf8')
  try {
    await client.query(sql)
    const r = await client.query('select count(*)::int as n from categories')
    console.log('Seed OK — categories:', r.rows[0].n)
  } catch (e) {
    console.error('Seed failed:', e.message)
    process.exitCode = 1
  }
  await client.end()
}

seed().catch((e) => {
  console.error('Fatal:', e.message)
  process.exit(1)
})
