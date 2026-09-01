import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { apiFetch } from '../lib/api'
import { Agency, Profile } from '@erevenue/shared'

const emptyForm = {
  email: '',
  password: '',
  display_name: '',
  agency_id: '',
  max_offline_days: '7',
  expiry_days: '',
}

function generateMemorablePassword(): string {
  const adjs = ['Bold','Calm','Swift','Bright','Brave','Kind','Wise','Fierce','Noble','Quick','Sunny','Merry','Clever','Grand','Fresh','Lucky','Rapid','Solid']
  const nouns = ['Tiger','Eagle','River','Stone','Hawk','Lion','Wolf','Peak','Flame','Storm','Bliss','Grove','Cedar','Maple','Brook','Ember','Harbor','Summit']
  const syms = ['!','@','#','$','%','&','*']
  for (let attempt = 0; attempt < 30; attempt++) {
    const adj = adjs[Math.floor(Math.random() * adjs.length)]
    const noun = nouns[Math.floor(Math.random() * nouns.length)]
    const num = String(10 + Math.floor(Math.random() * 90))
    const sym = syms[Math.floor(Math.random() * syms.length)]
    // build candidate and enforce 8-10 chars
    let candidate = `${adj}${noun}${num}${sym}`
    if (candidate.length > 10) {
      // shorten by trimming the longer word
      const excess = candidate.length - 10
      if (adj.length > noun.length) candidate = `${adj.slice(0, adj.length - excess)}${noun}${num}${sym}`
      else candidate = `${adj}${noun.slice(0, noun.length - excess)}${num}${sym}`
    } else if (candidate.length < 8) {
      candidate = `${candidate}${syms[Math.floor(Math.random() * syms.length)]}`
    }
    if (candidate.length >= 8 && candidate.length <= 10) return candidate
  }
  // fallback
  return `SunFox${10 + Math.floor(Math.random()*90)}!`
}

export default function Agents() {
  const [agents, setAgents] = useState<(Profile & { counts?: any })[]>([])
  const [agencies, setAgencies] = useState<Agency[]>([])
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState({ ...emptyForm })
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [copied, setCopied] = useState(false)

  const load = () => {
    supabase
      .from('profiles')
      .select('*')
      .eq('role', 'agent')
      .order('created_at', { ascending: false })
      .then(async ({ data, error }) => {
        if (error || !data) return
        const withCounts = await Promise.all(
          data.map(async (a: Profile) => {
            const r = await supabase
              .from('receipts')
              .select('total_amount', { count: 'exact', head: true })
              .eq('created_by', a.id)
              .eq('status', 'active')
            const p = await supabase
              .from('print_logs')
              .select('id', { count: 'exact', head: true })
              .eq('printed_by', a.id)
            return { ...a, counts: { receipts: r.count, prints: p.count } }
          }),
        )
        setAgents(withCounts)
      })
  }

  useEffect(() => {
    load()
    supabase.from('agencies').select('id, name, code').order('name').then(({ data, error }) => {
      if (!error) setAgencies((data as Agency[]) ?? [])
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const set = (k: keyof typeof emptyForm) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm((f) => ({ ...f, [k]: e.target.value }))

  const generate = () => {
    const pwd = generateMemorablePassword()
    setForm((f) => ({ ...f, password: pwd }))
    setShowPassword(true)
    setCopied(false)
  }

  const copyPassword = async () => {
    try {
      await navigator.clipboard.writeText(form.password)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 2000)
    } catch {
      /* ignore */
    }
  }

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setNotice('')
    setSaving(true)
    const body: Record<string, unknown> = {
      email: form.email,
      password: form.password,
      display_name: form.display_name,
      agency_id: form.agency_id || null,
      max_offline_days: Number(form.max_offline_days) || 7,
      expiry_days: form.expiry_days ? Number(form.expiry_days) : null,
    }
    const { error } = await apiFetch<{ user?: { id?: string } }>('/agents', {
      method: 'POST',
      body,
    })
    setSaving(false)
    if (error) {
      setError(error)
      return
    }
    setShowForm(false)
    const email = form.email
    setForm({ ...emptyForm })
    setNotice(`Agent created: ${email}`)
    window.setTimeout(() => setNotice(''), 6000)
    load()
  }

  const toggleActive = async (a: Profile) => {
    const { error } = await supabase.from('profiles').update({ is_active: !a.is_active }).eq('id', a.id)
    if (!error) setAgents((prev) => prev.map((x) => (x.id === a.id ? { ...x, is_active: !x.is_active } : x)))
  }

  const resetDevice = async (a: Profile) => {
    if (!window.confirm(`Reset device binding for ${a.display_name || a.username}?`)) return
    const { error } = await apiFetch(`/agents/${a.id}/reset-device`, { method: 'PATCH', body: {} })
    if (error) return setError(error)
    setError('')
    load()
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
        <h2 style={{ margin: 0 }}>Agents</h2>
        <button className="btn" onClick={() => { setShowForm((s) => !s); setError(''); setNotice('') }}>
          {showForm ? 'Cancel' : '+ New Agent'}
        </button>
      </div>

      {showForm && (
        <form onSubmit={submit} className="card" style={{ padding: 16, marginBottom: 16 }}>
          <h4 style={{ marginTop: 0 }}>Create agent account</h4>
          <div className="form-grid">
            <div className="form-row">
              <label>Display name *</label>
              <input value={form.display_name} onChange={set('display_name')} required />
            </div>
            <div className="form-row">
              <label>Email (login) *</label>
              <input type="email" value={form.email} onChange={set('email')} required />
            </div>
            <div className="form-row">
              <label>Password * <span style={{ fontWeight: 400, color: 'var(--muted)', fontSize: '0.8rem' }}>(8–10 chars, memorable)</span></label>
              <div style={{ display: 'flex', gap: 6 }}>
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={form.password}
                  onChange={set('password')}
                  required
                  minLength={8}
                  placeholder="e.g. BoldTiger42!"
                  style={{ flex: 1 }}
                />
                <button type="button" className="btn secondary small" onClick={() => setShowPassword((s) => !s)} title={showPassword ? 'Hide' : 'Show'}>
                  {showPassword ? 'Hide' : 'Show'}
                </button>
              </div>
              <div style={{ display: 'flex', gap: 6, marginTop: 6, flexWrap: 'wrap', alignItems: 'center' }}>
                <button type="button" className="btn small" onClick={generate}>Generate</button>
                {form.password && (
                  <button type="button" className="btn small secondary" onClick={copyPassword}>
                    {copied ? 'Copied!' : 'Copy'}
                  </button>
                )}
                <span style={{ fontSize: '0.8rem', color: 'var(--muted)' }}>{form.password.length >= 8 ? '✓ 8–10 chars, upper/lower/number/symbol' : 'Generate a strong memorable password'}</span>
              </div>
            </div>
            <div className="form-row">
              <label>Agency</label>
              <select value={form.agency_id} onChange={set('agency_id')}>
                <option value="">— none —</option>
                {agencies.map((a) => (
                  <option key={a.id} value={a.id}>{a.code} — {a.name}</option>
                ))}
              </select>
            </div>
            <div className="form-row">
              <label>Max offline days</label>
              <input type="number" value={form.max_offline_days} onChange={set('max_offline_days')} min={1} max={30} />
            </div>
            <div className="form-row">
              <label>Expiry days (blank = none)</label>
              <input type="number" value={form.expiry_days} onChange={set('expiry_days')} min={1} placeholder="e.g. 30" />
            </div>
          </div>
          {error && <div className="error">{error}</div>}
          <button type="submit" className="btn" disabled={saving} style={{ marginTop: 12 }}>
            {saving ? 'Creating…' : 'Create Agent'}
          </button>
        </form>
      )}

      {notice && <div className="notice">{notice}</div>}
      {!!error && !showForm && <div className="error">{error}</div>}

      <table>
        <thead>
          <tr>
            <th>Name</th>
            <th>Email</th>
            <th>Agency</th>
            <th>Receipts</th>
            <th>Prints</th>
            <th>Device Bound</th>
            <th>Status</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          {agents.map((a) => (
            <tr key={a.id}>
              <td>{a.display_name}</td>
              <td>{a.username}</td>
              <td>{a.agency_id?.slice(0, 8) ?? '—'}</td>
              <td>{a.counts?.receipts ?? 0}</td>
              <td>{a.counts?.prints ?? 0}</td>
              <td>{a.bound_device_fingerprint ? 'Yes' : 'No'}</td>
              <td>
                <span className={`badge ${a.is_active ? 'active' : 'voided'}`}>
                  {a.is_active ? 'Active' : 'Blocked'}
                </span>
              </td>
              <td>
                <button className="btn small secondary" onClick={() => toggleActive(a)}>
                  {a.is_active ? 'Block' : 'Activate'}
                </button>{' '}
                {a.bound_device_fingerprint && (
                  <button className="btn small secondary" onClick={() => resetDevice(a)}>
                    Reset device
                  </button>
                )}
              </td>
            </tr>
          ))}
          {agents.length === 0 && (
            <tr><td colSpan={8} style={{ textAlign: 'center', color: 'var(--muted)' }}>No agents yet</td></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}
