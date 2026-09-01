import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

interface Notification {
  id: string
  user_id: string
  title: string
  body: string | null
  is_read: boolean
  created_at: string
}

export default function Notifications() {
  const [items, setItems] = useState<Notification[]>([])
  const [filter, setFilter] = useState<'all' | 'unread'>('all')
  const [error, setError] = useState('')

  const load = () => {
    let q = supabase.from('notifications').select('*').order('created_at', { ascending: false }).limit(200)
    if (filter === 'unread') q = q.eq('is_read', false)
    q.then(({ data, error }) => {
      if (error) setError(error.message)
      else { setItems(data ?? []); setError('') }
    })
  }

  useEffect(load, [filter])

  const markRead = async (n: Notification) => {
    const { error } = await supabase.from('notifications').update({ is_read: true }).eq('id', n.id)
    if (error) return setError(error.message)
    setItems((prev) => prev.map((x) => (x.id === n.id ? { ...x, is_read: true } : x)))
  }

  const markAllRead = async () => {
    const { error } = await supabase.from('notifications').update({ is_read: true }).eq('is_read', false)
    if (error) return setError(error.message)
    load()
  }

  const remove = async (n: Notification) => {
    const { error } = await supabase.from('notifications').delete().eq('id', n.id)
    if (error) return setError(error.message)
    setItems((prev) => prev.filter((x) => x.id !== n.id))
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
        <h2 style={{ margin: 0 }}>Notifications</h2>
        <div style={{ display: 'flex', gap: 8 }}>
          <select value={filter} onChange={(e) => setFilter(e.target.value as any)}>
            <option value="all">All</option>
            <option value="unread">Unread only</option>
          </select>
          <button className="btn secondary small" onClick={markAllRead}>Mark all read</button>
        </div>
      </div>

      {error && <div className="error">{error}</div>}

      <table>
        <thead>
          <tr>
            <th>Title</th>
            <th>Body</th>
            <th>Status</th>
            <th>Date</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          {items.map((n) => (
            <tr key={n.id} style={{ opacity: n.is_read ? 0.7 : 1 }}>
              <td><strong>{n.title}</strong></td>
              <td style={{ maxWidth: 360, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{n.body ?? '—'}</td>
              <td>
                <span className={`badge ${n.is_read ? 'voided' : 'active'}`}>
                  {n.is_read ? 'Read' : 'Unread'}
                </span>
              </td>
              <td>{new Date(n.created_at).toLocaleString()}</td>
              <td>
                {!n.is_read && <button className="btn small secondary" onClick={() => markRead(n)}>Mark read</button>}{' '}
                <button className="btn small danger" onClick={() => remove(n)}>Delete</button>
              </td>
            </tr>
          ))}
          {items.length === 0 && (
            <tr><td colSpan={5} style={{ textAlign: 'center', color: 'var(--muted)' }}>No notifications</td></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}
