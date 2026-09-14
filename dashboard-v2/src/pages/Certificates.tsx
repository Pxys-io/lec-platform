import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'
import { useToast } from '../toast'

interface Certificate {
  id: string
  user_id: string
  course_id: string
  title: string
  description: string | null
  issued_at: string
  expiry_date: string | null
  certificate_hash: string
}

export default function Certificates() {
  const { toast } = useToast()
  const [certs, setCerts] = useState<Certificate[]>([])
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    try { setCerts(await api.get<Certificate[]>('/certificates/all')) }
    catch (e) { toast(e instanceof Error ? e.message : 'Load failed', true) }
    finally { setLoading(false) }
  }, [toast])
  useEffect(() => { load() }, [load])

  const filtered = certs.filter((c) =>
    c.title.toLowerCase().includes(search.toLowerCase()) ||
    c.user_id.toLowerCase().includes(search.toLowerCase()) ||
    c.course_id.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <>
      <div className="spread">
        <div><h1>Certificates</h1><p className="sub">All issued certificates</p></div>
      </div>

      <input placeholder="Search by title, user or course…" value={search} onChange={(e) => setSearch(e.target.value)} style={{ maxWidth: 360, marginBottom: 14 }} />

      {loading ? <p className="sub">Loading…</p> : (
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <table>
            <thead><tr><th>Certificate</th><th>User</th><th>Course</th><th>Issued</th><th>Expiry</th><th>Hash</th></tr></thead>
            <tbody>
              {filtered.map((c) => (
                <tr key={c.id}>
                  <td><b>{c.title}</b></td>
                  <td><span className="mono">{c.user_id.slice(0, 12)}…</span></td>
                  <td><span className="mono">{c.course_id.slice(0, 12)}…</span></td>
                  <td>{new Date(c.issued_at).toLocaleDateString()}</td>
                  <td>{c.expiry_date ? new Date(c.expiry_date).toLocaleDateString() : 'Never'}</td>
                  <td><span className="mono">{c.certificate_hash.slice(0, 12)}…</span></td>
                </tr>
              ))}
              {filtered.length === 0 && <tr><td colSpan={6} className="sub" style={{ textAlign: 'center' }}>No certificates issued yet</td></tr>}
            </tbody>
          </table>
        </div>
      )}
    </>
  )
}