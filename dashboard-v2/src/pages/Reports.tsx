import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'
import { useToast } from '../toast'

interface Report {
  id: string; user_id: string; target_type: string; target_id: string
  reason: string; description: string | null; status: string; created_at: string
}

export default function Reports() {
  const { toast } = useToast()
  const [reports, setReports] = useState<Report[]>([])

  const load = useCallback(async () => {
    try { setReports(await api.get<Report[]>('/reports')) }
    catch (e) { toast(e instanceof Error ? e.message : 'Load failed', true) }
  }, [toast])
  useEffect(() => { load() }, [load])

  const setStatus = async (r: Report, status: string) => {
    try { await api.put(`/reports/${r.id}`, { status }); toast(status === 'resolved' ? 'Resolved' : 'Dismissed'); load() }
    catch (e) { toast(e instanceof Error ? e.message : 'Failed', true) }
  }

  return (
    <>
      <h1>Reports</h1>
      <p className="sub">User-reported content</p>
      <div className="card" style={{ padding: 0 }}>
        <table>
          <thead><tr><th>Type</th><th>Reason</th><th>Description</th><th>Status</th><th>Date</th><th></th></tr></thead>
          <tbody data-testid="reports-table">
            {reports.map((r) => (
              <tr key={r.id}>
                <td><span className="badge b-blue">{r.target_type === 'lesson' ? '📹 Lesson' : r.target_type === 'comment' ? '💬 Comment' : r.target_type === 'user' ? '👤 User' : r.target_type}</span></td>
                <td><b>{r.reason}</b></td>
                <td className="sub" style={{ margin: 0 }}>{r.description || '—'}</td>
                <td><span className={`badge ${r.status === 'resolved' ? 'b-green' : r.status === 'dismissed' ? 'b-gray' : 'b-yellow'}`}>{r.status === 'resolved' ? 'Resolved' : r.status === 'dismissed' ? 'Dismissed' : 'Pending review'}</span></td>
                <td className="mono">{new Date(r.created_at).toLocaleDateString()}</td>
                <td style={{ whiteSpace: 'nowrap' }}>
                  {r.status === 'pending' && (
                    <>
                      <button className="btn small" onClick={() => setStatus(r, 'resolved')}>✔ Resolve</button>{' '}
                      <button className="btn ghost small" onClick={() => setStatus(r, 'dismissed')}>✕ Dismiss</button>
                    </>
                  )}
                </td>
              </tr>
            ))}
            {reports.length === 0 && <tr><td colSpan={6} className="sub" style={{ textAlign: 'center' }}>No reports</td></tr>}
          </tbody>
        </table>
      </div>
    </>
  )
}
