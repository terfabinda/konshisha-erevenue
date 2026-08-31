import { createClient, SupabaseClient } from '@supabase/supabase-js'
import { Receipt, PrintLog } from '@erevenue/shared'

// ============================================================
// Offline-first sync engine (reference implementation)
//
// Mirrors what the Flutter app must do in Dart. The server treats
// every receipt/print with a client-owned `id` as an idempotency key,
// so replaying the queue is always safe (no duplicates).
//
// Port to Dart for the mobile app using sqflite (queue) + supabase_flutter.
// ============================================================

export interface QueuedReceipt extends Receipt {
  _pending: true
  _queuedAt: number
}

export interface QueuedPrint extends PrintLog {
  _pending: true
  _queuedAt: number
}

export interface SyncEngine {
  enqueueReceipt(r: Receipt): Promise<void>
  enqueuePrint(p: PrintLog): Promise<void>
  syncNow(): Promise<SyncResult>
  pendingCount(): Promise<number>
  startAutoSync(opts?: AutoSyncOptions): void
  stop(): void
}

export interface SyncResult {
  receiptsSynced: number
  receiptsFailed: number
  printsSynced: number
  printsFailed: number
}

export interface AutoSyncOptions {
  /** milliseconds between periodic retries while online */
  intervalMs?: number
  /** called after each completed auto-sync */
  onSync?: (res: SyncResult, status: 'success' | 'partial' | 'offline') => void
  /** async function that resolves once network is restored (e.g. connectivity_plus listener) */
  waitForNetwork?: () => Promise<void>
}

interface SyncRepo {
  getPendingReceipts(): Promise<QueuedReceipt[]>
  removeReceipts(ids: string[]): Promise<void>
  getPendingPrints(): Promise<QueuedPrint[]>
  removePrints(ids: string[]): Promise<void>
}

/**
 * Builds a SyncEngine backed by a Supabase client (for network calls) and
 * a pluggable local repo (the durable offline queue).
 */
export function createSyncEngine(
  sb: SupabaseClient,
  repo: SyncRepo,
  opts: AutoSyncOptions = {}
): SyncEngine {
  const intervalMs = opts.intervalMs ?? 5 * 60 * 1000
  let timer: ReturnType<typeof setInterval> | null = null
  let syncing = false

  async function uploadReceipts(rows: QueuedReceipt[]): Promise<{ done: string[] }> {
    if (rows.length === 0) return { done: [] }
    const payload = rows.map(({ _pending, _queuedAt, ...receipt }) => receipt)
    // try: prod RPC push; fallback: per-item upsert
    const { error } = await sb.rpc('sync_receipts', { p_rows: payload })
    if (!error) return { done: rows.map((r) => r.id) }
    // fallback path: attempt one-by-one so a single bad row can't block the batch
    const done: string[] = []
    for (const row of rows) {
      const { error: e } = await sb.rpc('upsert_receipt', {
        p_id: row.id,
        p_agency_id: row.agency_id,
        p_payer_name: row.payer_name ?? '',
        p_payer_phone: row.payer_phone ?? null,
        p_payer_tin: row.payer_tin ?? null,
        p_payer_address: row.payer_address ?? null,
        p_category_id: row.category_id ?? null,
        p_category_name: row.description ?? null,
        p_description: row.description ?? null,
        p_amount: row.amount ?? 0,
        p_discount: row.discount ?? 0,
        p_penalty: row.penalty ?? 0,
        p_quantity: row.quantity ?? 1,
        p_notes: row.notes ?? null,
        p_device_fingerprint: row.device_fingerprint ?? null,
        p_status: row.status ?? 'active',
      })
      if (!e) done.push(row.id)
    }
    return { done }
  }

  async function uploadPrints(rows: QueuedPrint[]): Promise<{ done: string[] }> {
    const done: string[] = []
    for (const row of rows) {
      const { error } = await sb.rpc('log_print', {
        p_id: row.id,
        p_receipt_id: row.receipt_id,
        p_copies: row.copies ?? 1,
        p_print_mode: row.print_mode ?? 'text',
        p_printer_name: row.printer_name ?? null,
        p_printer_address: row.printer_address ?? null,
        p_printer_model: row.printer_model ?? null,
        p_success: row.success ?? true,
        p_error_message: row.error_message ?? null,
        p_is_reprint: row.is_reprint ?? false,
        p_receipt_ref: row.receipt_ref ?? null,
        p_agency_id: row.agency_id ?? null,
      })
      if (!error) done.push(row.id)
    }
    return { done }
  }

  async function syncNow(): Promise<SyncResult> {
    if (syncing) return { receiptsSynced: 0, receiptsFailed: 0, printsSynced: 0, printsFailed: 0 }
    syncing = true
    const result: SyncResult = {
      receiptsSynced: 0,
      receiptsFailed: 0,
      printsSynced: 0,
      printsFailed: 0,
    }
    try {
      const receipts = await repo.getPendingReceipts()
      const prints = await repo.getPendingPrints()
      if (receipts.length === 0 && prints.length === 0) return result

      const [rRes, pRes] = await Promise.all([uploadReceipts(receipts), uploadPrints(prints)])
      result.receiptsSynced = rRes.done.length
      result.receiptsFailed = receipts.length - rRes.done.length
      result.printsSynced = pRes.done.length
      result.printsFailed = prints.length - pRes.done.length

      if (rRes.done.length) await repo.removeReceipts(rRes.done)
      if (pRes.done.length) await repo.removePrints(pRes.done)

      const status: SyncResultStatus =
        result.receiptsSynced + result.printsSynced > 0 && result.receiptsFailed + result.printsFailed === 0
          ? 'success'
          : 'partial'
      opts.onSync?.(result, status)
      return result
    } finally {
      syncing = false
    }
  }

  return {
    async enqueueReceipt(r) {
      await repo.getPendingReceipts()
      // In real impl: insert into local queue with _pending/_queuedAt.
    },
    async enqueuePrint(p) {
      // In real impl: insert into local queue.
      void p
    },
    async pendingCount() {
      const [p, q] = await Promise.all([repo.getPendingReceipts(), repo.getPendingPrints()])
      return p.length + q.length
    },
    async syncNow() {
      return syncNow()
    },
    startAutoSync() {
      if (timer) clearInterval(timer)
      // Immediate opportunistic sync when possible, then repeat on an interval.
      void (async () => {
        if (opts.waitForNetwork) await opts.waitForNetwork()
        await syncNow()
      })()
      timer = setInterval(() => void syncNow(), intervalMs)
      timer.unref?.()
    },
    stop() {
      if (timer) clearInterval(timer)
      timer = null
    },
  }
}

type SyncResultStatus = 'success' | 'partial' | 'offline'

export function createSupabaseSyncEngine(
  url: string,
  key: string,
  repo: SyncRepo,
  opts: AutoSyncOptions = {}
): SyncEngine {
  const sb = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  return createSyncEngine(sb, repo, opts)
}
