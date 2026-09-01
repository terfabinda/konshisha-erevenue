import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { RevenueCategory } from '@erevenue/shared'
import {
  AreaChart, Area, BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid,
} from 'recharts'

interface TrendPoint { day: string; revenue: number; count: number }
interface RevenueStats { total_receipts: number; total_revenue: number; avg_amount: number; top_categories: { category_id: string; revenue: number; count: number }[] }

export default function Reports() {
  const [from, setFrom] = useState('')
  const [to, setTo] = useState('')
  const [trend, setTrend] = useState<TrendPoint[]>([])
  const [stats, setStats] = useState<RevenueStats | null>(null)
  const [cats, setCats] = useState<RevenueCategory[]>([])
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    supabase.from('categories').select('id, name').order('name').then(({ data }) => setCats((data as any) ?? []))
  }, [])

  const load = async () => {
    setLoading(true)
    const pStart = from ? new Date(from).toISOString() : null
    const pEnd = to ? new Date(to + 'T23:59:59').toISOString() : null
    const [rev, tr] = await Promise.all([
      supabase.rpc('get_revenue_stats', { p_start: pStart, p_end: pEnd }),
      supabase.rpc('get_revenue_trend', { p_days: from && to ? Math.max(1, Math.round((new Date(to).getTime() - new Date(from).getTime()) / 86400000) + 1) : 30 }),
    ])
    if (!rev.error) setStats(rev.data as RevenueStats)
    if (!tr.error) setTrend((tr.data as TrendPoint[]) ?? [])
    setLoading(false)
  }

  useEffect(() => { load() }, [])

  const catName = (id: string | null) => cats.find((c) => c.id === id)?.name ?? id ?? '—'

  const exportCsv = () => {
    const rows = [
      ['Day', 'Revenue', 'Count'],
      ...trend.map((p) => [p.day, String(p.revenue), String(p.count)]),
    ]
    const csv = rows.map((r) => r.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(',')).join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `revenue-report-${from || 'start'}-${to || 'now'}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  const printReport = () => window.print()

  const fmt = (n: number) => '₦' + Number(n ?? 0).toLocaleString('en-NG', { maximumFractionDigits: 2 })

  const pieData = (stats?.top_categories ?? []).map((c) => ({
    name: catName(c.category_id),
    value: Number(c.revenue),
  }))

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12, flexWrap: 'wrap', gap: 8 }}>
        <h2 style={{ margin: 0 }}>Reports</h2>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn secondary" onClick={exportCsv} disabled={!trend.length}>Export CSV</button>
          <button className="btn secondary" onClick={printReport}>Print</button>
          <button className="btn" onClick={load} disabled={loading}>{loading ? 'Loading…' : 'Refresh'}</button>
        </div>
      </div>

      <div className="filter-bar">
        <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
        <span style={{ color: 'var(--muted)' }}>to</span>
        <input type="date" value={to} onChange={(e) => setTo(e.target.value)} />
        <button className="btn secondary" onClick={() => { setFrom(''); setTo('') }}>Clear</button>
      </div>

      <div className="grid">
        <div className="card">
          <div className="label">Total Revenue</div>
          <div className="value">{fmt(stats?.total_revenue ?? 0)}</div>
          <div className="sub">{stats?.total_receipts ?? 0} receipts</div>
        </div>
        <div className="card">
          <div className="label">Average Receipt</div>
          <div className="value">{fmt(stats?.avg_amount ?? 0)}</div>
          <div className="sub">per receipt</div>
        </div>
        <div className="card">
          <div className="label">Receipts in Range</div>
          <div className="value">{stats?.total_receipts ?? 0}</div>
          <div className="sub">{trend.length} days</div>
        </div>
        <div className="card">
          <div className="label">Top Category</div>
          <div className="value" style={{ fontSize: '1.2rem' }}>{pieData[0]?.name ?? '—'}</div>
          <div className="sub">{pieData[0] ? fmt(pieData[0].value) : '—'}</div>
        </div>
      </div>

      <div className="card" style={{ padding: 16, marginBottom: 16, height: 300 }}>
        <h4 style={{ margin: '0 0 8px' }}>Revenue Trend</h4>
        {trend.length ? (
          <ResponsiveContainer width="100%" height="90%">
            <AreaChart data={trend} margin={{ top: 5, right: 10, left: 0, bottom: 0 }}>
              <defs>
                <linearGradient id="repGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#1B8C3D" stopOpacity={0.5} />
                  <stop offset="95%" stopColor="#1B8C3D" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis dataKey="day" tick={{ fontSize: 11 }} tickFormatter={(d: string) => new Date(d).toLocaleDateString('en-NG', { day: 'numeric', month: 'short' })} />
              <YAxis tick={{ fontSize: 11 }} tickFormatter={(v: number) => '₦' + (v / 1000).toFixed(0) + 'k'} />
              <Tooltip formatter={(v: number) => [fmt(v as number), 'Revenue']} labelFormatter={(d: string) => new Date(d).toLocaleDateString('en-NG', { weekday: 'short', day: 'numeric', month: 'long' })} />
              <Area type="monotone" dataKey="revenue" stroke="#1B8C3D" fill="url(#repGrad)" strokeWidth={2} />
            </AreaChart>
          </ResponsiveContainer>
        ) : (
          <div style={{ textAlign: 'center', color: 'var(--muted)', paddingTop: 80 }}>No data in range</div>
        )}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 16 }}>
        <div className="card" style={{ padding: 16, height: 300 }}>
          <h4 style={{ margin: '0 0 8px' }}>Top Categories (Revenue)</h4>
          {pieData.length ? (
            <ResponsiveContainer width="100%" height="90%">
              <BarChart data={pieData} layout="vertical" margin={{ left: 20 }}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis type="number" tick={{ fontSize: 11 }} tickFormatter={(v) => `₦${(v/1000).toFixed(0)}k`} />
                <YAxis dataKey="name" type="category" width={110} tick={{ fontSize: 11 }} />
                <Tooltip formatter={(v: number) => [fmt(v), 'Revenue']} />
                <Bar dataKey="value" fill="#1B8C3D" radius={[0, 6, 6, 0]} />
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <div style={{ textAlign: 'center', color: 'var(--muted)', paddingTop: 80 }}>No category data</div>
          )}
        </div>

        <div className="card" style={{ padding: 16, height: 300 }}>
          <h4 style={{ margin: '0 0 8px' }}>Receipts per Day</h4>
          {trend.length ? (
            <ResponsiveContainer width="100%" height="90%">
              <BarChart data={trend}>
                <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                <XAxis dataKey="day" tick={{ fontSize: 11 }} tickFormatter={(d: string) => new Date(d).toLocaleDateString('en-NG', { day: 'numeric', month: 'short' })} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip />
                <Bar dataKey="count" fill="#3B82F6" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <div style={{ textAlign: 'center', color: 'var(--muted)', paddingTop: 80 }}>No data</div>
          )}
        </div>
      </div>

      {pieData.length > 0 && (
        <div className="card" style={{ padding: 16 }}>
          <h4 style={{ marginTop: 0 }}>Breakdown</h4>
          <table>
            <thead><tr><th>Category</th><th>Revenue</th><th>Receipts</th></tr></thead>
            <tbody>
              {(stats?.top_categories ?? []).map((c) => (
                <tr key={c.category_id}>
                  <td>{catName(c.category_id)}</td>
                  <td>{fmt(Number(c.revenue))}</td>
                  <td>{c.count}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <style>{`@media print { .sidebar, .filter-bar, button { display: none !important; } .content { padding: 0 !important; } .card { break-inside: avoid; } }`}</style>
    </div>
  )
}
