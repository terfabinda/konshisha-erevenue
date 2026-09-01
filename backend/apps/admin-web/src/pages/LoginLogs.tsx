import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

interface LoginLog {
  id: string
  user_id: string | null
  email: string | null
  display_name: string | null
  agency_id: string | null
  agency_code: string | null
  agency_name: string | null
  login_at: string
  user_agent: string | null
  success: boolean
  failure_reason: string | null
}

export default function LoginLogs() {
  const [logs, setLogs] = useState<LoginLog[]>([])
  const [filter, setFilter] = useState<'all' | 'success' | 'failed'>('all')
  const [agency, setAgency] = useState('')
  const [from, setFrom] = useState('')
  const [to, setTo] = useState('')
  const [q, setQ] = useState('')
  const [error, setError] = useState('')

  const load = async () => {
    let query = supabase.from('login_logs').select('*').order('login_at', { ascending: false }).limit(200)
    if (filter === 'success') query = query.eq('success', true)
    if (filter === 'failed') query = query.eq('success', false)
    if (agency) query = query.eq('agency_id', agency as any)
    if (from) query = query.gte('login_at', from)
    if (to) query = query.lte('login_at', to + 'T23:59:59')
    if (q) query = query.ilike('email', `%${q}%`)
    const { data, error } = await query
    if (error) setError(error.message)
    else { setLogs(data ?? []); setError('') }
  }

  useEffect(() => { load() }, [filter, agency, from, to])

  const filtered = q
    ? logs.filter((l) => (l.email ?? '').toLowerCase().includes(q.toLowerCase()) || (l.display_name ?? '').toLowerCase().includes(q.toLowerCase()))
    : logs

  const successCount = logs.filter((l) => l.success).length
  const failedCount = logs.length - successCount

  return (
    <div>
      <h2>Agent Login Activity</h2>

      <div className="grid">
        <div className="card">
          <div className="label">Total Logins</div>
          <div className="value">{logs.length}</div>
          <div className="sub">last 200</div>
        </div>
        <div className="card">
          <div className="label">Successful</div>
          <div className="value" style={{ color: '#166534' }}>{successCount}</div>
          <div className="sub">{logs.length ? Math.round((successCount / logs.length) * 100) : 0}% success</div>
        </div>
        <div className="card">
          <div className="label">Failed</div>
          <div className="value" style={{ color: '#991b1b' }}>{failedCount}</div>
          <div className="sub">needs attention</div>
        </div>
        <div className="card">
          <div className="label">Unique Agents</div>
          <div className="value">{new Set(logs.map((l) => l.email).filter(Boolean)).size}</div>
          <div className="sub">in this view</div>
        </div>
      </div>

      <div className="filter-bar">
        <input placeholder="Search email/name" value={q} onChange={(e) => setQ(e.target.value)} style={{ minWidth: 180 }} />
        <select value={filter} onChange={(e) => setFilter(e.target.value as any)}>
          <option value="all">All</option>
          <option value="success">Successful only</option>
          <option value="failed">Failed only</option>
        </select>
        <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
        <input type="date" value={to} onChange={(e) => setTo(e.target.value)} />
        <button className="btn secondary" onClick={() => { setFilter('all'); setAgency(''); setFrom(''); setTo(''); setQ('') }}>Reset</button>
        <button className="btn secondary" onClick={load}>Refresh</button>
      </div>

      {error && <div className="error">{error}</div>}

      <table>
        <thead>
          <tr>
            <th>Agent</th>
            <th>Agency</th>
            <th>Status</th>
            <th>Device / UA</th>
            <th>Time</th>
          </tr>
        </thead>
        <tbody>
          {filtered.map((l) => (
            <tr key={l.id}>
              <td>
                <div><strong>{l.display_name ?? '—'}</strong></div>
                <div style={{ fontSize: '0.8rem', color: 'var(--muted)' }}>{l.email ?? l.user_id?.slice(0, 8) ?? '—'}</div>
              </td>
              <td>{l.agency_code ? `${l.agency_code} — ${l.agency_name}` : '—'}</td>
              <td>
                <span className={`badge ${l.success ? 'active' : 'voided'}`}>
                  {l.success ? 'Success' : 'Failed'}
                </span>
                {!l.success && l.failure_reason && (
                  <div style={{ fontSize: '0.75rem', color: '#991b1b', marginTop: 4 }}>{l.failure_reason}</div>
                )}
              </td>
              <td style={{ maxWidth: 280, fontSize: '0.8rem', color: 'var(--muted)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }} title={l.user_agent ?? ''}>
                {l.user_agent ? l.user_agent.slice(0, 80) : '—'}
              </td>
              <td>{new Date(l.login_at).toLocaleString()}</td>
            </tr>
          ))}
          {filtered.length === 0 && (
            <tr><td colSpan={5} style={{ textAlign: 'center', color: 'var(--muted)' }}>No login activity yet</td></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}
