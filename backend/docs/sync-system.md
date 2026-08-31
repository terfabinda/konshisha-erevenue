# Offline-First Sync System

This document describes the sync architecture that replaces the fragile Firebase
realtime-listener approach. The core idea: **the mobile app never requires a live
connection to function** (this directly addresses the "poor connectivity forced us to
turn features off" problem).

## Why this solves the connectivity pain

| Old (Firebase) | New (Supabase sync) |
|---|---|
| Always-on websocket listeners on every screen; drop/reconnect storms on flaky networks | Request/response REST reads; succeed-or-fail cleanly |
| Fragile encrypted pending-queue hack | First-class offline queue + automatic sync |
| Receipts written directly, risk of loss offline | Receipts saved locally instantly, pushed when reachable |
| Features disabled when network flaky | All collection features work fully offline |

---

## Architecture

```
┌─────────────┐  writes (offline-safe)   ┌──────────────────┐
│  Flutter App │ ───────────────────────▶ │  Local Queue     │
│  (agent)     │                          │  (SQLite/persist)│
└─────────────┘                           └────────┬─────────┘
                                                   │ auto-sync (background)
                                                   ▼
                                          ┌──────────────────┐     idempotent RPC
                                          │  Node.js API      │ ────────────────►┐
                                          │  (Vercel)         │                  ▼
                                          └──────────────────┘          ┌────────────────┐
                                                                        │  Supabase RPC   │
                                                                        │  (Postgres SQL) │
                                                                        └────────────────┘
```

---

## Data flow

1. **Capture (always works, even offline)**
   - Agent enters a receipt → saved to **local queue first** → immediately usable/printable.
   - Client generates an `id` (e.g. `RCP-<millis>`) → the server treats this id as the
     idempotency key.

2. **Auto-sync trigger (no user action needed)**
   - Network listener detects connectivity regained (or periodic background timer).
   - Queued receipts/print-logs are replayed to the API in a single batch.

3. **Server idempotent apply**
   - The API calls `sync_receipts` / `log_print` (Postgres RPC).
   - Because these are **idempotent** (keyed by the client `id`), replaying the queue
     multiple times never creates duplicates — even if the app sends the same receipt
     while a previous attempt partially succeeded.

4. **Queue management**
   - On success: items removed from queue.
   - On failure (still offline / timeout): items retained, retried later.

---

## Network listener (runs even when app is minimized)

The app should register a background network/connectivity listener that:

1. Listens for connectivity restoration (`connectivity_plus` or `connectivity_plus` /
   platform network callbacks on Android/iOS).
2. When connected → calls `syncNow()`.
3. Runs a periodic timer (e.g. every 5 min) as a fallback even when foregrounded.
4. On Android, a headless background service / WorkManager keeps the listener alive
   while the app is minimized.

---

## API endpoints used by sync

| Endpoint | Purpose |
|---|---|
| `POST /api/receipts/sync` | Batch uplink of pending receipts (idempotent) |
| `POST /api/receipts` | Single receipt upsert (idempotent) |
| `POST /api/prints` | Log a print (idempotent) |
| `POST /api/prints/:id` | Update print result after async print |
| `POST /api/security/verify-device` | Device binding check before sync |
| `GET /api/security/config` | Fetch offline-limit / force-sync config |

---

## Reference client queue (TS, mirrors the Dart logic the app will use)

See `packages/sync/syncEngine.ts` for a runnable, type-safe reference implementation
of the queue + auto-sync engine. The Flutter app should mirror this in Dart using the
`@erevenue/shared` types and `supabase-js` (or the Dart `supabase_flutter`).

---

## Receipt idempotency key

```ts
// The client owns the id to make sync safe to replay.
const receiptId = `RCP-${Date.now()}` // + optional random suffix
```

The server's `upsert_receipt` ignores any insert whose `id` already exists and returns
the existing row — so replaying is always safe.

---

## Config knobs (server-controlled)

`security_config` row (managed by super-admin) controls:
- `max_offline_days` — hard offline allowance before the app is force-blocked.
- `force_sync` — a server-issued command to push all local queues immediately.
- `login_expiry_days` — session freshness.

The app polls `GET /api/security/config` whenever it comes online and enforces these
server-side, giving the admin authority over offline windows.
