const { Client } = require('pg')
const fs = require('fs')
const path = require('path')

const CONN = process.env.DATABASE_URL
const MIGRATIONS_DIR = path.join(__dirname, '..', 'supabase', 'migrations')

if (!CONN) {
  console.error('DATABASE_URL env var required')
  process.exit(1)
}

async function runMigrations() {
  const client = new Client({ connectionString: CONN })
  await client.connect()
  console.log('Connected to Supabase Postgres')

  // Ensure a migrations bookkeeping table exists
  await client.query(`
    create table if not exists _migrations (
      name text primary key,
      applied_at timestamptz not null default now()
    )
  `)

  const files = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort()

  for (const file of files) {
    const existing = await client.query('select 1 from _migrations where name = $1', [file])
    if (existing.rowCount > 0) {
      console.log(`SKIP ${file} (already applied)`)
      continue
    }

    const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, file), 'utf8')
    console.log(`APPLY ${file} ...`)
    try {
      await client.query('BEGIN')
      await client.query(sql)
      await client.query('insert into _migrations (name) values ($1)', [file])
      await client.query('COMMIT')
      console.log(`  -> OK`)
    } catch (err) {
      await client.query('ROLLBACK')
      console.error(`  -> FAILED: ${err.message}`)
      // abort on first failure — do not partially migrate
      process.exitCode = 1
      break
    }
  }

  await client.end()
  console.log('Migration run complete')
}

runMigrations().catch((e) => {
  console.error('Fatal:', e.message)
  process.exit(1)
})
