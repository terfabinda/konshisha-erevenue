import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { PrintLog } from '@erevenue/shared'

export default function PrintLogs() {
  const [logs, setLogs] = useState<PrintLog[]>([])

  useEffect(() => {
    supabase
      .from('print_logs')
      .select('*')
      .order('printed_at', { ascending: false })
      .limit(200)
      .then(({ data, error }) => {
        if (!error) setLogs(data ?? [])
      })
  }, [])

  return (
    <div>
      <h2>Print Logs</h2>
      <table>
        <thead>
          <tr>
            <th>Receipt</th>
            <th>Mode</th>
            <th>Copies</th>
            <th>Printer</th>
            <th>Result</th>
            <th>Reprint</th>
            <th>Agent</th>
            <th>Date</th>
          </tr>
        </thead>
        <tbody>
          {logs.map((l) => (
            <tr key={l.id}>
              <td>{l.receipt_ref ?? l.receipt_id}</td>
              <td>{l.print_mode}</td>
              <td>{l.copies}</td>
              <td>{l.printer_name ?? '—'}</td>
              <td>
                <span className={`badge ${l.success ? 'active' : 'voided'}`}>
                  {l.success ? 'Success' : 'Failed'}
                </span>
              </td>
              <td>{l.is_reprint ? 'Yes' : 'No'}</td>
              <td>{l.printed_by?.slice(0, 8)}</td>
              <td>{new Date(l.printed_at).toLocaleString()}</td>
            </tr>
          ))}
          {logs.length === 0 && (
            <tr><td colSpan={8} style={{ textAlign: 'center', color: 'var(--muted)' }}>No print logs</td></tr>
          )}
        </tbody>
      </table>
    </div>
  )
}
