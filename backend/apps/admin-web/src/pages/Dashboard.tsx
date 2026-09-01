import { useEffect, useState } from 'react'
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid,
} from 'recharts'
import { supabase } from '../lib/supabase'
import { RevenueStats, PrintStats } from '@erevenue/shared'

interface DashboardData {
  today_revenue: number
  today_receipt_count: number
  recent_receipts: any[]
  total_agencies?: number
  total_agents?: number
  total_revenue?: number
  total_receipts?: number
}

interface TrendPoint {
  day: string
  revenue: number
  count: number
}

export default function Dashboard() {
  const [data, setData] = useState<DashboardData | null>(null)
  const [stats, setStats] = useState<RevenueStats | null>(null)
  const [prints, setPrints] = useState<PrintStats | null>(null)
  const [trend, setTrend] = useState<TrendPoint[]>([])

  useEffect(() => {
    supabase.rpc('get_dashboard_stats').then(({ data, error }) => {
      if (!error) setData(data)
    })
    supabase.rpc('get_revenue_stats', { p_start: null, p_end: null }).then(({ data, error }) => {
      if (!error) setStats(data)
    })
    supabase.rpc('get_print_stats', { p_start: null, p_end: null }).then(({ data, error }) => {
      if (!error) setPrints(data)
    })
    supabase.rpc('get_revenue_trend', { p_days: 30 }).then(({ data, error }) => {
      if (!error) setTrend((data as TrendPoint[]) ?? [])
    })
  }, [])

  const fmt = (n?: number) =>
    '₦' + (n ?? 0).toLocaleString('en-NG', { maximumFractionDigits: 2 })

  return (
    <div>
      <h2>Revenue Dashboard</h2>
      <div className="grid">
        <div className="card">
          <div className="label">Today's Revenue</div>
          <div className="value">{fmt(data?.today_revenue)}</div>
        </div>
        <div className="card">
          <div className="label">Receipts Today</div>
          <div className="value">{data?.today_receipt_count ?? 0}</div>
        </div>
        <div className="card">
          <div className="label">Total Revenue (30d)</div>
          <div className="value">{fmt(stats?.total_revenue)}</div>
          <div className="sub">{stats?.total_receipts} receipts</div>
        </div>
        <div className="card">
          <div className="label">Print Success</div>
          <div className="value">{prints?.success_rate ?? 0}%</div>
          <div className="sub">{prints?.total_prints ?? 0} jobs</div>
        </div>
      </div>

      {data?.total_agencies !== undefined && (
        <div className="grid">
          <div className="card"><div className="label">Agencies</div><div className="value">{data.total_agencies}</div></div>
          <div className="card"><div className="label">Agents</div><div className="value">{data.total_agents}</div></div>
          <div className="card"><div className="label">All-time Revenue</div><div className="value">{fmt(data.total_revenue)}</div></div>
          <div className="card"><div className="label">All-time Receipts</div><div className="value">{data.total_receipts}</div></div>
        </div>
      )}

      <h3>Revenue Trend (30 days)</h3>
      <div className="card" style={{ padding: '16px', height: 300 }}>
        {trend.length > 0 ? (
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={trend} margin={{ top: 5, right: 10, left: 0, bottom: 0 }}>
              <defs>
                <linearGradient id="revGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#1B8C3D" stopOpacity={0.5} />
                  <stop offset="95%" stopColor="#1B8C3D" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis
                dataKey="day"
                tick={{ fontSize: 11 }}
                tickFormatter={(d: string) => new Date(d).toLocaleDateString('en-NG', { day: 'numeric', month: 'short' })}
              />
              <YAxis tick={{ fontSize: 11 }} tickFormatter={(v: number) => '₦' + (v / 1000).toFixed(0) + 'k'} />
              <Tooltip
                formatter={(value: number) => ['₦' + value.toLocaleString('en-NG', { maximumFractionDigits: 2 }), 'Revenue']}
                labelFormatter={(d: string) => new Date(d).toLocaleDateString('en-NG', { weekday: 'short', day: 'numeric', month: 'long' })}
              />
              <Area type="monotone" dataKey="revenue" stroke="#1B8C3D" fill="url(#revGrad)" strokeWidth={2} />
            </AreaChart>
          </ResponsiveContainer>
        ) : (
          <div style={{ textAlign: 'center', color: 'var(--muted)', paddingTop: 100 }}>
            No revenue data in range yet
          </div>
        )}
      </div>

      <h3>Recent Receipts</h3>
      <table>
        <thead>
          <tr>
            <th>Ref</th>
            <th>Payer</th>
            <th>Category</th>
            <th>Amount</th>
            <th>Status</th>
            <th>Date</th>
          </tr>
        </thead>
        <tbody>
          {(data?.recent_receipts ?? []).map((r) => (
            <tr key={r.id}>
              <td>{r.receipt_ref ?? r.id}</td>
              <td>{r.payer_name}</td>
              <td>{r.description || r.category_id}</td>
              <td>{fmt(r.total_amount)}</td>
              <td>
                <span className={`badge ${r.status}`}>{r.status}</span>
              </td>
              <td>{new Date(r.created_at).toLocaleString()}</td>
            </tr>
          ))}
          {(data?.recent_receipts ?? []).length === 0 && (
            <tr>
              <td colSpan={6} style={{ textAlign: 'center', color: 'var(--muted)' }}>
                No receipts yet
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  )
}
