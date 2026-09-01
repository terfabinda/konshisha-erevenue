import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { Agency, Receipt } from '@erevenue/shared'

export default function Receipts() {
  const [receipts, setReceipts] = useState<Receipt[]>([])
  const [from, setFrom] = useState('')
  const [to, setTo] = useState('')
  const [status, setStatus] = useState('')
  const [agency, setAgency] = useState('')
  const [agencies, setAgencies] = useState<Agency[]>([])
  const [voidingId, setVoidingId] = useState('')
  const [error, setError] = useState('')

  useEffect(() => {
    supabase
      .from('agencies')
      .select('id, name, code')
      .order('name')
      .then(({ data, error }) => {
        if (!error) setAgencies((data as Agency[]) ?? [])
      })
  }, [])

  useEffect(() => {
    const load = async () => {
      let q = supabase.from('receipts').select('*')
      if (from) q = q.gte('created_at', from)
      if (to) q = q.lte('created_at', to + 'T23:59:59')
      if (status) q = q.eq('status', status as any)
      if (agency) q = q.eq('agency_id', agency as any)
      q = q.order('created_at', { ascending: false }).limit(200)
      const { data, error } = await q
      if (!error) setReceipts(data ?? [])
    }
    load()
  }, [from, to, status, agency])

  const fmt = (n?: number | string | null) =>
    '₦' + Number(n ?? 0).toLocaleString('en-NG', { maximumFractionDigits: 2 })

  const stats = (() => {
    const total = receipts.length
    const revenue = receipts.reduce((s, r) => s + Number(r.total_amount ?? 0), 0)
    const active = receipts.filter((r) => r.status === 'active').length
    const voided = total - active
    const avg = total ? revenue / total : 0
    return { total, revenue, active, voided, avg }
  })()

  const onVoid = async (r: Receipt) => {
    if (!window.confirm(`Void receipt ${r.receipt_ref ?? r.id}? This cannot be undone.`)) return
    setVoidingId(r.id)
    setError('')
    const { error } = await supabase.rpc('void_receipt', { p_receipt_id: r.id })
    setVoidingId('')
    if (error) {
      setError(error.message)
      return
    }
    setReceipts((prev) => prev.map((x) => (x.id === r.id ? { ...x, status: 'voided' as const } : x)))
  }

  const printReceipt = (r: Receipt) => {
    const w = window.open('', '_blank', 'width=380,height=600')
    if (!w) return
    const html = `
      <html><head><title>Receipt ${r.receipt_ref ?? r.id}</title>
      <style>
        body { font-family: monospace; padding: 16px; max-width: 380px; margin: 0 auto; font-size: 13px; }
        h2 { text-align: center; margin: 0 0 4px; font-size: 16px; }
        .sub { text-align: center; color: #555; font-size: 11px; margin-bottom: 12px; }
        .row { display: flex; justify-content: space-between; margin: 6px 0; border-bottom: 1px dashed #ccc; padding-bottom: 4px; }
        .label { color: #555; }
        .value { font-weight: 600; }
        .total { font-size: 15px; font-weight: 800; border-top: 2px solid #000; margin-top: 8px; padding-top: 8px; }
        .footer { text-align: center; margin-top: 16px; font-size: 10px; color: #777; }
        @media print { body { padding: 0; } }
      </style></head><body>
        <h2>KONSHISHA IGR</h2>
        <div class="sub">Official Government Collection Receipt<br/>${new Date(r.created_at).toLocaleString()}</div>
        <div class="row"><span class="label">Ref</span><span class="value">${r.receipt_ref ?? r.id}</span></div>
        <div class="row"><span class="label">Payer</span><span class="value">${r.payer_name}</span></div>
        ${r.payer_phone ? `<div class="row"><span class="label">Phone</span><span class="value">${r.payer_phone}</span></div>` : ''}
        ${r.payer_tin ? `<div class="row"><span class="label">TIN</span><span class="value">${r.payer_tin}</span></div>` : ''}
        <div class="row"><span class="label">Category</span><span class="value">${r.description || r.category_id || '—'}</span></div>
        <div class="row"><span class="label">Amount</span><span class="value">${fmt(r.amount)}</span></div>
        ${Number(r.discount) ? `<div class="row"><span class="label">Discount</span><span class="value">-${fmt(r.discount)}</span></div>` : ''}
        <div class="row total"><span>Total</span><span>${fmt(r.total_amount)}</span></div>
        <div class="row"><span class="label">Status</span><span class="value">${r.status}</span></div>
        <div class="row"><span class="label">Agent</span><span class="value">${r.created_by?.slice(0, 8) ?? '—'}</span></div>
        <div class="footer">Thank you for your payment.<br/>Powered by Konshisha IGR</div>
        <script>window.onload=()=>{window.print(); setTimeout(()=>window.close(), 500)}</script>
      </body></html>`
    w.document.write(html)
    w.document.close()
  }

  return (
    <div>
      <h2>Receipts</h2>
      <div className="filter-bar">
        <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
        <input type="date" value={to} onChange={(e) => setTo(e.target.value)} />
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">All statuses</option>
          <option value="active">Active</option>
          <option value="voided">Voided</option>
        </select>
        <select value={agency} onChange={(e) => setAgency(e.target.value)}>
          <option value="">All agencies</option>
          {agencies.map((a) => (
            <option key={a.id} value={a.id}>
              {a.code} — {a.name}
            </option>
          ))}
        </select>
        {from || to || status || agency ? (
          <button className="btn secondary" onClick={() => { setFrom(''); setTo(''); setStatus(''); setAgency('') }}>
            Reset
          </button>
        ) : null}
      </div>

      {error && <div className="error">{error}</div>}

      <div className="grid">
        <div className="card">
          <div className="label">Receipts (filtered)</div>
          <div className="value">{stats.total}</div>
          <div className="sub">{stats.total === 200 ? 'Showing latest 200' : `${stats.total} found`}</div>
        </div>
        <div className="card">
          <div className="label">Total Revenue</div>
          <div className="value">{fmt(stats.revenue)}</div>
          <div className="sub">Avg {fmt(stats.avg)}</div>
        </div>
        <div className="card">
          <div className="label">Active</div>
          <div className="value">{stats.active}</div>
          <div className="sub">{stats.voided} voided</div>
        </div>
        <div className="card">
          <div className="label">Voided Value</div>
          <div className="value">{fmt(receipts.filter((r) => r.status === 'voided').reduce((s, r) => s + Number(r.total_amount ?? 0), 0))}</div>
          <div className="sub">of filtered</div>
        </div>
      </div>

      <table>
        <thead>
          <tr>
            <th>Ref</th>
            <th>Payer</th>
            <th>Category</th>
            <th>Amount</th>
            <th>Discount</th>
            <th>Total</th>
            <th>Agent</th>
            <th>Status</th>
            <th>Date</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          {receipts.map((r) => (
            <tr key={r.id}>
              <td>{r.receipt_ref ?? r.id}</td>
              <td>{r.payer_name}</td>
              <td>{r.description || r.category_id}</td>
              <td>{fmt(r.amount)}</td>
              <td>{fmt(r.discount)}</td>
              <td>{fmt(r.total_amount)}</td>
              <td>{r.created_by?.slice(0, 8)}</td>
              <td><span className={`badge ${r.status}`}>{r.status}</span></td>
              <td>{new Date(r.created_at).toLocaleString()}</td>
              <td>
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                  <button className="btn small secondary" onClick={() => printReceipt(r)}>Print</button>
                  {r.status === 'active' ? (
                    <button
                      className="btn small danger"
                      disabled={voidingId === r.id}
                      onClick={() => onVoid(r)}
                    >
                      {voidingId === r.id ? 'Voiding…' : 'Void'}
                    </button>
                  ) : (
                    <span style={{ color: 'var(--muted)', alignSelf: 'center' }}>—</span>
                  )}
                </div>
              </td>
            </tr>
          ))}
          {receipts.length === 0 && (
            <tr><td colSpan={10} style={{ textAlign: 'center', color: 'var(--muted)' }}>No receipts</td></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}
