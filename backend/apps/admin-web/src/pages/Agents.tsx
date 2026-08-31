import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { Profile } from '@erevenue/shared'

export default function Agents() {
  const [agents, setAgents] = useState<(Profile & { counts?: any })[]>([])

  useEffect(() => {
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
          })
        )
        setAgents(withCounts)
      })
  }, [])

  const toggleActive = async (a: Profile) => {
    const { error } = await supabase.from('profiles').update({ is_active: !a.is_active }).eq('id', a.id)
    if (!error) setAgents((prev) => prev.map((x) => (x.id === a.id ? { ...x, is_active: !x.is_active } : x)))
  }

  return (
    <div>
      <h2>Agents</h2>
      <table>
        <thead>
          <tr>
            <th>Name</th>
            <th>Email</th>
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
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
