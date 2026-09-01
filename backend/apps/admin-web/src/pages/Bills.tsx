import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { RevenueCategory } from '@erevenue/shared'

interface Payer {
  id: string
  name: string
  phone: string | null
  tin: string | null
  address: string | null
}

interface Bill {
  id: string
  payer_id: string | null
  agency_id: string | null
  category_id: string | null
  amount: number
  status: string
  receipt_id: string | null
  due_at: string | null
  created_at: string
}

export default function Bills() {
  const [bills, setBills] = useState<Bill[]>([])
  const [payers, setPayers] = useState<Payer[]>([])
  const [cats, setCats] = useState<RevenueCategory[]>([])
  const [status, setStatus] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState({ payer_name: '', payer_phone: '', payer_tin: '', category_id: '', amount: '', due_at: '' })
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const load = () => {
    let q = supabase.from('bills').select('*').order('created_at', { ascending: false }).limit(200)
    if (status) q = q.eq('status', status)
    q.then(({ data, error }) => { if (!error) setBills(data ?? []) })
  }

  useEffect(() => {
    load()
    supabase.from('payers').select('id, name, tin').order('name').then(({ data }) => setPayers((data as Payer[]) ?? []))
    supabase.from('categories').select('id, name').order('name').then(({ data }) => setCats((data as RevenueCategory[]) ?? []))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status])

  const flash = (m: string) => { setNotice(m); window.setTimeout(() => setNotice(''), 4000) }

  const create = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setSaving(true)

    // Create or reuse payer by TIN if provided, otherwise by name
    let payerId: string | null = null
    if (form.payer_tin) {
      const { data } = await supabase.from('payers').select('id').eq('tin', form.payer_tin).single()
      if (data) payerId = data.id
    }
    if (!payerId) {
      const { data, error } = await supabase
        .from('payers')
        .insert({ name: form.payer_name, phone: form.payer_phone || null, tin: form.payer_tin || null })
        .select('id')
        .single()
      if (error) { setSaving(false); return setError(error.message) }
      payerId = data.id
    }

    const { error } = await supabase.from('bills').insert({
      payer_id: payerId,
      category_id: form.category_id || null,
      amount: Number(form.amount),
      status: 'outstanding',
      due_at: form.due_at ? new Date(form.due_at).toISOString() : null,
    })
    setSaving(false)
    if (error) return setError(error.message)
    setForm({ payer_name: '', payer_phone: '', payer_tin: '', category_id: '', amount: '', due_at: '' })
    setShowForm(false)
    flash('Bill created')
    load()
  }

  const markPaid = async (b: Bill) => {
    const { error } = await supabase.from('bills').update({ status: 'paid' }).eq('id', b.id)
    if (error) return setError(error.message)
    setBills((prev) => prev.map((x) => (x.id === b.id ? { ...x, status: 'paid' } : x)))
  }

  const voidBill = async (b: Bill) => {
    if (!window.confirm('Void this bill?')) return
    const { error } = await supabase.from('bills').update({ status: 'voided' }).eq('id', b.id)
    if (error) return setError(error.message)
    setBills((prev) => prev.map((x) => (x.id === b.id ? { ...x, status: 'voided' } : x)))
  }

  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm((f) => ({ ...f, [k]: e.target.value }))

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
        <h2 style={{ margin: 0 }}>Bills</h2>
        <button className="btn" onClick={() => setShowForm((s) => !s)}>{showForm ? 'Cancel' : '+ New Bill'}</button>
      </div>

      <div className="filter-bar">
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="">All statuses</option>
          <option value="outstanding">Outstanding</option>
          <option value="paid">Paid</option>
          <option value="voided">Voided</option>
        </select>
      </div>

      {showForm && (
        <form onSubmit={create} className="card" style={{ padding: 16, marginBottom: 16 }}>
          <h4 style={{ marginTop: 0 }}>Create bill</h4>
          <div className="form-grid">
            <div className="form-row">
              <label>Payer name *</label>
              <input value={form.payer_name} onChange={set('payer_name')} required list="payers" />
              <datalist id="payers">
                {payers.map((p) => <option key={p.id} value={p.name} />)}
              </datalist>
            </div>
            <div className="form-row">
              <label>Payer phone</label>
              <input value={form.payer_phone} onChange={set('payer_phone')} />
            </div>
            <div className="form-row">
              <label>Payer TIN</label>
              <input value={form.payer_tin} onChange={set('payer_tin')} />
            </div>
            <div className="form-row">
              <label>Category</label>
              <select value={form.category_id} onChange={set('category_id')}>
                <option value="">— none —</option>
                {cats.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
            </div>
            <div className="form-row">
              <label>Amount (₦) *</label>
              <input type="number" step="0.01" value={form.amount} onChange={set('amount')} required />
            </div>
            <div className="form-row">
              <label>Due date</label>
              <input type="date" value={form.due_at} onChange={set('due_at')} />
            </div>
          </div>
          {error && <div className="error">{error}</div>}
          <button type="submit" className="btn" disabled={saving} style={{ marginTop: 12 }}>{saving ? 'Creating…' : 'Create Bill'}</button>
        </form>
      )}

      {notice && <div className="notice">{notice}</div>}
      {error && !showForm && <div className="error">{error}</div>}

      <table>
        <thead>
          <tr>
            <th>Payer</th>
            <th>Category</th>
            <th>Amount</th>
            <th>Status</th>
            <th>Due</th>
            <th>Created</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          {bills.map((b) => (
            <tr key={b.id}>
              <td>{b.payer_id?.slice(0, 8) ?? '—'}</td>
              <td>{b.category_id?.slice(0, 8) ?? '—'}</td>
              <td>₦{Number(b.amount).toLocaleString('en-NG')}</td>
              <td><span className={`badge ${b.status === 'paid' ? 'active' : b.status === 'voided' ? 'voided' : 'admin'}`}>{b.status}</span></td>
              <td>{b.due_at ? new Date(b.due_at).toLocaleDateString() : '—'}</td>
              <td>{new Date(b.created_at).toLocaleString()}</td>
              <td>
                {b.status === 'outstanding' && (
                  <>
                    <button className="btn small" onClick={() => markPaid(b)}>Mark paid</button>{' '}
                    <button className="btn small danger" onClick={() => voidBill(b)}>Void</button>
                  </>
                )}
                {b.status !== 'outstanding' && <span style={{ color: 'var(--muted)' }}>—</span>}
              </td>
            </tr>
          ))}
          {bills.length === 0 && (
            <tr><td colSpan={7} style={{ textAlign: 'center', color: 'var(--muted)' }}>No bills</td></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}
