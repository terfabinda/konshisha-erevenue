import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { apiFetch } from '../lib/api'
import { Agency } from '@erevenue/shared'

const emptyForm = {
  name: '',
  code: '',
  address: '',
  phone: '',
  email: '',
  tin: '',
  admin_name: '',
  admin_phone: '',
}

export default function Agencies() {
  const [agencies, setAgencies] = useState<Agency[]>([])
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState({ ...emptyForm })
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  const load = () => {
    supabase
      .from('agencies')
      .select('*')
      .order('name')
      .then(({ data, error }) => {
        if (!error) setAgencies(data ?? [])
      })
  }

  useEffect(load, [])

  const toggle = async (a: Agency) => {
    const { error } = await supabase
      .from('agencies')
      .update({ is_active: !a.is_active })
      .eq('id', a.id)
    if (!error) setAgencies((prev) => prev.map((x) => (x.id === a.id ? { ...x, is_active: !x.is_active } : x)))
  }

  const set = (k: keyof typeof emptyForm) => (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm((f) => ({ ...f, [k]: e.target.value }))

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setSaving(true)
    const { error } = await apiFetch<Agency>('/agencies', { method: 'POST', body: form })
    setSaving(false)
    if (error) {
      setError(error)
      return
    }
    setShowForm(false)
    setForm({ ...emptyForm })
    load()
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
        <h2 style={{ margin: 0 }}>Agencies</h2>
        <button className="btn" onClick={() => { setShowForm((s) => !s); setError('') }}>
          {showForm ? 'Cancel' : '+ New Agency'}
        </button>
      </div>

      {showForm && (
        <form onSubmit={submit} className="card" style={{ padding: 16, marginBottom: 16 }}>
          <h4 style={{ marginTop: 0 }}>Onboard new agency</h4>
          <div className="form-grid">
            <div className="form-row">
              <label>Agency name *</label>
              <input value={form.name} onChange={set('name')} required />
            </div>
            <div className="form-row">
              <label>Code *</label>
              <input value={form.code} onChange={set('code')} required placeholder="KNS" />
            </div>
            <div className="form-row">
              <label>Address</label>
              <input value={form.address} onChange={set('address')} />
            </div>
            <div className="form-row">
              <label>Phone</label>
              <input value={form.phone} onChange={set('phone')} />
            </div>
            <div className="form-row">
              <label>Email</label>
              <input type="email" value={form.email} onChange={set('email')} />
            </div>
            <div className="form-row">
              <label>TIN</label>
              <input value={form.tin} onChange={set('tin')} />
            </div>
            <div className="form-row">
              <label>Admin name</label>
              <input value={form.admin_name} onChange={set('admin_name')} />
            </div>
            <div className="form-row">
              <label>Admin phone</label>
              <input value={form.admin_phone} onChange={set('admin_phone')} />
            </div>
          </div>
          {error && <div className="error">{error}</div>}
          <button type="submit" className="btn" disabled={saving} style={{ marginTop: 12 }}>
            {saving ? 'Creating…' : 'Create Agency'}
          </button>
        </form>
      )}

      <table>
        <thead>
          <tr>
            <th>Code</th>
            <th>Name</th>
            <th>Contact</th>
            <th>Next Receipt #</th>
            <th>Status</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          {agencies.map((a) => (
            <tr key={a.id}>
              <td><strong>{a.code}</strong></td>
              <td>{a.name}</td>
              <td>{a.admin_name} · {a.phone}</td>
              <td>{a.receipt_prefix}-{String(a.next_receipt_number).padStart(6, '0')}</td>
              <td>
                <span className={`badge ${a.is_active ? 'active' : 'voided'}`}>
                  {a.is_active ? 'Active' : 'Inactive'}
                </span>
              </td>
              <td>
                <button className="btn small secondary" onClick={() => toggle(a)}>
                  {a.is_active ? 'Deactivate' : 'Reactivate'}
                </button>
              </td>
            </tr>
          ))}
          {agencies.length === 0 && (
            <tr><td colSpan={6} style={{ textAlign: 'center', color: 'var(--muted)' }}>No agencies yet</td></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}
