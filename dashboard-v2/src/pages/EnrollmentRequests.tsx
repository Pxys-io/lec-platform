import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'
import { useToast } from '../toast'

interface EnrImage { id: string; url: string }
interface EnrRequest {
  id: string
  user_id: string
  course_id: string
  status: string
  form_data: Record<string, unknown>
  admin_comment: string | null
  created_at: string
  user_email: string | null
  course_title: string | null
  images: EnrImage[]
}

const FILTERS = ['pending', 'approved', 'rejected'] as const

export default function EnrollmentRequests() {
  const { toast } = useToast()
  const [filter, setFilter] = useState<(typeof FILTERS)[number]>('pending')
  const [requests, setRequests] = useState<EnrRequest[]>([])
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState<EnrRequest | null>(null)
  const [comment, setComment] = useState('')

  const load = useCallback(async () => {
    setLoading(true)
    try { setRequests(await api.get<EnrRequest[]>(`/enrollment/requests?status=${filter}`)) }
    catch (e) { toast(e instanceof Error ? e.message : 'Load failed', true) }
    finally { setLoading(false) }
  }, [filter, toast])
  useEffect(() => { load() }, [load])

  const decide = async (status: 'approved' | 'rejected') => {
    if (!selected) return
    if (status === 'rejected' && !comment.trim()) { toast('Add a rejection reason', true); return }
    try {
      await api.post(`/enrollment/requests/${selected.id}/${status}?admin_comment=${encodeURIComponent(comment.trim())}`)
      toast(status === 'approved' ? 'Request approved' : 'Request rejected')
      setSelected(null); setComment(''); load()
    } catch (e) { toast(e instanceof Error ? e.message : 'Update failed', true) }
  }

  return (
    <>
      <div className="spread">
        <div><h1>Enrollment Requests</h1><p className="sub">Review and approve student course enrollments</p></div>
        <div className="row" style={{ gap: 6 }}>
          {FILTERS.map((s) => (
            <button key={s} className={`btn small ${filter === s ? '' : 'ghost'}`} onClick={() => setFilter(s)} data-testid={`enr-filter-${s}`}>
              {s}
            </button>
          ))}
        </div>
      </div>

      {loading ? <p className="sub">Loading…</p> : (
        <div className="grid" style={{ gap: 10 }}>
          {requests.map((r) => (
            <div className="card spread" key={r.id} style={{ padding: '14px 18px' }} data-testid={`enr-${r.status}`}>
              <div>
                <b>{r.user_email || `User ${r.user_id.slice(0, 8)}`}</b>{' '}
                <span className={`badge ${r.status === 'approved' ? 'b-green' : r.status === 'rejected' ? 'b-red' : 'b-yellow'}`}>{r.status}</span>
                <div className="sub" style={{ margin: '4px 0 0' }}>
                  {r.course_title || 'Unknown course'} • {new Date(r.created_at).toLocaleString()}
                </div>
              </div>
              <button className="btn ghost small" onClick={() => setSelected(r)}>Review</button>
            </div>
          ))}
          {requests.length === 0 && <p className="sub">No {filter} requests</p>}
        </div>
      )}

      {selected && (
        <div className="modal-bg" onClick={(e) => e.target === e.currentTarget && setSelected(null)}>
          <div className="modal" style={{ maxWidth: 560, maxHeight: '85vh', overflowY: 'auto' }} data-testid="enr-modal">
            <h3>Review Request</h3>
            <p className="sub"><b>{selected.user_email || selected.user_id}</b> → {selected.course_title}</p>
            {Object.keys(selected.form_data).length > 0 && (
              <div className="card" style={{ padding: 12, margin: '10px 0' }}>
                {Object.entries(selected.form_data).map(([k, v]) => (
                  <div key={k} className="sub"><b>{k}:</b> {String(v)}</div>
                ))}
              </div>
            )}
            {selected.images.length > 0 && (
              <div className="row" style={{ flexWrap: 'wrap', gap: 8, margin: '10px 0' }}>
                {selected.images.map((img) => (
                  <a key={img.id} href={img.url} target="_blank" rel="noreferrer">
                    <img src={img.url} alt="proof" style={{ width: 120, height: 80, objectFit: 'cover', borderRadius: 8 }} />
                  </a>
                ))}
              </div>
            )}
            <div className="field">
              <label>Internal note / rejection reason</label>
              <textarea rows={3} value={comment} onChange={(e) => setComment(e.target.value)} placeholder="Add a comment…" />
            </div>
            {selected.status === 'pending' && (
              <div className="row" style={{ justifyContent: 'flex-end', gap: 8 }}>
                <button className="btn danger" onClick={() => decide('rejected')} data-testid="enr-reject">Reject</button>
                <button className="btn" onClick={() => decide('approved')} data-testid="enr-approve">Approve</button>
              </div>
            )}
          </div>
        </div>
      )}
    </>
  )
}