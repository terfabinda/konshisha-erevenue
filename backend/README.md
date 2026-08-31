# erevenue-backend

Konshisha IGR backend: **Node.js API + Supabase (Postgres) + Admin Web Dashboard**.

Backs the offline-first Flutter collection app. Designed so that poor connectivity
never forces features to be disabled — receipts are captured and printed fully offline,
then auto-synced when a network is available.

## Stack

| Layer | Tech | Host |
|---|---|---|
| Database / Auth / Storage | Supabase (Postgres, GoTrue, PostgREST) | Supabase Cloud |
| REST API | Node.js + Fastify (TypeScript) | Vercel |
| Admin Web Console | React + Vite + recharts | Vercel |
| Shared types | `@erevenue/shared` | Workspace package |

## Monorepo layout

```
backend/
  apps/
    api/            Node.js + Fastify REST API (Vercel)
    admin-web/      React admin dashboard (Vite)
  packages/
    shared/         Shared TS types/contracts
    sync/           Offline sync engine reference (queued, idempotent)
  supabase/
    migrations/     Schema + RLS + functions (apply with supabase db push)
    seed.sql        Default 56 revenue categories
  docs/
    sync-system.md  Offline-first sync architecture guide
```

## Getting started

```bash
cd backend
npm install

# 1. Apply database schema (requires Supabase CLI + supabase link)
supabase link --project-ref <your-project-ref>
supabase db push
# seed categories
psql "$SUPABASE_DB_URL" -f supabase/seed.sql

# 2. Configure API env
cp apps/api/.env.example apps/api/.env   # add SUPABASE_URL + SUPABASE_ANON_KEY

# 3. Run API locally
npm run dev            # -> http://localhost:8080

# 4. Run admin web (in a second terminal)
cp apps/admin-web/.env.example apps/admin-web/.env
npm run dev:admin      # -> http://localhost:3000
```

## Deploy

- **API → Vercel**: `cd backend/apps/api && vercel` (set env: `SUPABASE_URL`, `SUPABASE_ANON_KEY`)
- **Admin Web → Vercel**: `cd backend/apps/admin-web && vercel` (set env: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_API_URL`)
- **Supabase**: keep migrations in this repo; the DB is the single source of truth.

## Offline-first sync

See `docs/sync-system.md`. The mobile app keeps an on-device queue and let it sync
idempotently (receipts use client-owned IDs) against:
- `POST /api/receipts/sync` — batch uplink
- `POST /api/receipts` — single idempotent upsert
- `POST /api/prints` — print log

A reference engine is in `packages/sync`.

## Security model

RLS policies enforce scoping (see `0002_rls_policies.sql`):
- `agent` -> own data only
- `scoped_admin` -> own agency
- `super_admin` -> everything

Write-heavy operations go through **security-definer Postgres functions**
(`upsert_receipt`, `sync_receipts`, `void_receipt`, ...) so data always lands server-side
even when the caller's row-level visibility is limited.
