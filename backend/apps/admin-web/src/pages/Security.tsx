import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { SecurityConfig } from '@erevenue/shared'

interface Cmd {
  id: string
  type: string
  target: string | null
  issued_by: string | null
  issued_at: string
}

export default function Security() {
  const [cfg, setCfg] = useState<SecurityConfig | null>(null)
  const [cmds, setCmds] = useState<Cmd[]>([])
  const [form, setForm] = useState({ max_offline_days: '7', login_expiry_days: '30', min_version_code: '1', force_sync: false })
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const load = () => {
    supabase.from('security_config').select('*').eq('id', 1).single().then(({ data, error }) => {
      if (!error && data) {
        setCfg(data)
        setForm({
          max_offline_days: String(data.max_offline_days),
          login_expiry_days: String(data.login_expiry_days),
          min_version_code: String(data.min_version_code),
          force_sync: Boolean(data.force_sync),
        })
      }
    })
    supabase.from('security_commands').select('*').order('issued_at', { ascending: false }).limit(50).then(({ data, error }) => {
      if (!error) setCmds(data ?? [])
    })
  }

  useEffect(load, [])

  const flash = (m: string) => { setNotice(m); window.setTimeout(() => setNotice(''), 4000) }

  const save = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setSaving(true)
    const payload = {
      max_offline_days: Number(form.max_offline_days),
      login_expiry_days: Number(form.login_expiry_days),
      min_version_code: Number(form.min_version_code),
      force_sync: form.force_sync,
      updated_at: new Date().toISOString(),
    }
    const { error } = await supabase.from('security_config').update(payload).eq('id', 1)
    setSaving(false)
    if (error) return setError(error.message)
    flash('Security config updated')
    load()
  }

  const issueSync = async () => {
    setError('')
    const { error } = await supabase.from('security_commands').insert({ type: 'force_sync', target: 'global' })
    if (error) return setError(error.message)
    flash('Force-sync command issued')
    load()
  }

  const set = (k: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement>) => {
    const v = e.target.type === 'checkbox' ? (e.target as HTMLInputElement).checked : e.target.value
    setForm((f) => ({ ...f, [k]: v as any }))
  }

  return (
    <div>
      <h2>Security</h2>

      {notice && <div className="notice">{notice}</div>}
      {error && <div className="error">{error}</div>}

      <form onSubmit={save} className="card" style={{ padding: 16, marginBottom: 16 }}>
        <h4 style={{ marginTop: 0 }}>Security config (id=1)</h4>
        <div className="form-grid">
          <div className="form-row">
            <label>Max offline days</label>
            <input type="number" min={1} value={form.max_offline_days} onChange={set('max_offline_days')} />
          </div>
          <div className="form-row">
            <label>Login expiry days</label>
            <input type="number" min={1} value={form.login_expiry_days} onChange={set('login_expiry_days')} />
          </div>
          <div className="form-row">
            <label>Min version code</label>
            <input type="number" min={1} value={form.min_version_code} onChange={set('min_version_code')} />
          </div>
          <div className="form-row" style={{ display: 'flex', alignItems: 'center', gap: 8, paddingTop: 22 }}>
            <input type="checkbox" checked={form.force_sync} onChange={set('force_sync')} style={{ width: 'auto' }} />
            <label style={{ margin: 0 }}>Force sync</label>
          </div>
        </div>
        {cfg?.security_alerts && cfg.security_alerts.length > 0 && (
          <div style={{ marginBottom: 12 }}>
            <strong>Alerts:</strong> {cfg.security_alerts.join(', ')}
          </div>
        )}
        <button type="submit" className="btn" disabled={saving}>{saving ? 'Saving…' : 'Save config'}</button>
        <button type="button" className="btn secondary" onClick={issueSync} style={{ marginLeft: 8 }}>Issue force-sync</button>
      </form>

      <h3>Recent commands</h3>
      <table>
        <thead>
          <tr>
            <th>Type</th>
            <th>Target</th>
            <th>Issued by</th>
            <th>Date</th>
          </tr>
        </thead>
        <tbody>
          {cmds.map((c) => (
            <tr key={c.id}>
              <td><span className="badge admin">{c.type}</span></td>
              <td>{c.target ?? '—'}</td>
              <td>{c.issued_by?.slice(0, 8) ?? '—'}</td>
              <td>{new Date(c.issued_at).toLocaleString()}</td>
            </tr>
          ))}
          {cmds.length === 0 && (
            <tr><td colSpan={4} style={{ textAlign: 'center', color: 'var(--muted)' }}>No commands yet</td></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}
