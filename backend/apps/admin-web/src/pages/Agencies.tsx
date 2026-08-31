import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { Agency } from '@erevenue/shared'

export default function Agencies() {
  const [agencies, setAgencies] = useState<Agency[]>([])

  useEffect(() => {
    supabase
      .from('agencies')
      .select('*')
      .order('name')
      .then(({ data, error }) => {
        if (!error) setAgencies(data ?? [])
      })
  }, [])

  const toggle = async (a: Agency) => {
    const { error } = await supabase
      .from('agencies')
      .update({ is_active: !a.is_active })
      .eq('id', a.id)
    if (!error) setAgencies((prev) => prev.map((x) => (x.id === a.id ? { ...x, is_active: !x.is_active } : x)))
  }

  return (
    <div>
      <h2>Agencies</h2>
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
        </tbody>
      </table>
    </div>
  )
}
