import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { RevenueCategory } from '@erevenue/shared'

const emptyForm = { name: '', default_amount: '', sort_order: '' }

export default function Categories() {
  const [cats, setCats] = useState<RevenueCategory[]>([])
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState({ ...emptyForm })
  const [editing, setEditing] = useState<Record<string, string>>({})
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const load = () => {
    supabase
      .from('categories')
      .select('*')
      .order('sort_order')
      .order('name')
      .then(({ data, error }) => {
        if (!error) setCats(data ?? [])
      })
  }

  useEffect(load, [])

  const flash = (msg: string) => {
    setNotice(msg)
    window.setTimeout(() => setNotice(''), 4000)
  }

  const create = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setSaving(true)
    const payload: Record<string, unknown> = {
      name: form.name.trim(),
      default_amount: form.default_amount ? Number(form.default_amount) : null,
      sort_order: form.sort_order ? Number(form.sort_order) : cats.length,
    }
    const { error } = await supabase.from('categories').insert(payload)
    setSaving(false)
    if (error) {
      setError(error.message)
      return
    }
    setForm({ ...emptyForm })
    setShowForm(false)
    load()
    flash('Category created')
  }

  const toggle = async (c: RevenueCategory) => {
    const { error } = await supabase.from('categories').update({ is_enabled: !c.is_enabled }).eq('id', c.id)
    if (error) return setError(error.message)
    setCats((prev) => prev.map((x) => (x.id === c.id ? { ...x, is_enabled: !x.is_enabled } : x)))
  }

  const saveAmount = async (c: RevenueCategory) => {
    const raw = editing[c.id]
    if (raw === undefined) return
    const val = raw === '' ? null : Number(raw)
    if (raw !== '' && Number.isNaN(val)) return setError('Invalid amount')
    const { error } = await supabase.from('categories').update({ default_amount: val }).eq('id', c.id)
    if (error) return setError(error.message)
    setCats((prev) => prev.map((x) => (x.id === c.id ? { ...x, default_amount: val } : x)))
    setEditing((prev) => {
      const n = { ...prev }
      delete n[c.id]
      return n
    })
  }

  const remove = async (c: RevenueCategory) => {
    if (!window.confirm(`Delete category "${c.name}"?`)) return
    const { error } = await supabase.from('categories').delete().eq('id', c.id)
    if (error) return setError(error.message)
    setCats((prev) => prev.filter((x) => x.id !== c.id))
  }

  const setF = (k: keyof typeof emptyForm) => (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm((f) => ({ ...f, [k]: e.target.value }))

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
        <h2 style={{ margin: 0 }}>Revenue Categories</h2>
        <button className="btn" onClick={() => { setShowForm((s) => !s); setError('') }}>
          {showForm ? 'Cancel' : '+ New Category'}
        </button>
      </div>

      {showForm && (
        <form onSubmit={create} className="card" style={{ padding: 16, marginBottom: 16 }}>
          <h4 style={{ marginTop: 0 }}>Create category</h4>
          <div className="form-grid">
            <div className="form-row">
              <label>Name *</label>
              <input value={form.name} onChange={setF('name')} required placeholder="e.g. Market Fees" />
            </div>
            <div className="form-row">
              <label>Default amount (₦)</label>
              <input type="number" step="0.01" value={form.default_amount} onChange={setF('default_amount')} placeholder="5000" />
            </div>
            <div className="form-row">
              <label>Sort order</label>
              <input type="number" value={form.sort_order} onChange={setF('sort_order')} placeholder={`${cats.length}`} />
            </div>
          </div>
          {error && <div className="error">{error}</div>}
          <button type="submit" className="btn" disabled={saving} style={{ marginTop: 12 }}>
            {saving ? 'Creating…' : 'Create Category'}
          </button>
        </form>
      )}

      {notice && <div className="notice">{notice}</div>}
      {error && !showForm && <div className="error">{error}</div>}

      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>Name</th>
            <th>Default Amount</th>
            <th>Enabled</th>
            <th>Created</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          {cats.map((c) => (
            <tr key={c.id}>
              <td>{c.sort_order}</td>
              <td><strong>{c.name}</strong></td>
              <td>
                {editing[c.id] !== undefined ? (
                  <span style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                    <input
                      type="number"
                      step="0.01"
                      value={editing[c.id]}
                      onChange={(e) => setEditing((p) => ({ ...p, [c.id]: e.target.value }))}
                      style={{ width: 110 }}
                      placeholder="—"
                    />
                    <button className="btn small" onClick={() => saveAmount(c)}>Save</button>
                    <button className="btn small secondary" onClick={() => setEditing((p) => { const n = { ...p }; delete n[c.id]; return n })}>
                      Cancel
                    </button>
                  </span>
                ) : (
                  <span style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                    {c.default_amount != null ? `₦${Number(c.default_amount).toLocaleString('en-NG')}` : '—'}
                    <button className="btn small secondary" onClick={() => setEditing((p) => ({ ...p, [c.id]: String(c.default_amount ?? '') }))}>
                      Edit
                    </button>
                  </span>
                )}
              </td>
              <td>
                <span className={`badge ${c.is_enabled ? 'active' : 'voided'}`}>
                  {c.is_enabled ? 'Enabled' : 'Disabled'}
                </span>
              </td>
              <td>{new Date(c.created_at).toLocaleDateString()}</td>
              <td>
                <button className="btn small secondary" onClick={() => toggle(c)}>
                  {c.is_enabled ? 'Disable' : 'Enable'}
                </button>{' '}
                <button className="btn small danger" onClick={() => remove(c)}>Delete</button>
              </td>
            </tr>
          ))}
          {cats.length === 0 && (
            <tr><td colSpan={6} style={{ textAlign: 'center', color: 'var(--muted)' }}>No categories yet</td></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}
