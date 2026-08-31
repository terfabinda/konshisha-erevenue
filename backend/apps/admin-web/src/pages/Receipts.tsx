import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { Receipt } from '@erevenue/shared'

export default function Receipts() {
  const [receipts, setReceipts] = useState<Receipt[]>([])
  const [from, setFrom] = useState('')
  const [to, setTo] = useState('')
  const [status, setStatus] = useState('')
  const [agency, setAgency] = useState('')

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
        <button className="btn secondary" onClick={() => { setFrom(''); setTo(''); setStatus(''); setAgency('') }}>
          Reset
        </button>
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
            </tr>
          ))}
          {receipts.length === 0 && (
            <tr><td colSpan={9} style={{ textAlign: 'center', color: 'var(--muted)' }}>No receipts</td></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}
