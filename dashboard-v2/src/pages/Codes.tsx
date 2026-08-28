import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'
import { useToast } from '../toast'

interface Code {
  id: string; code: string; course_id: string | null; access_type: string
  access_duration: number | null; max_uses: number | null; current_uses: number
  is_active: boolean; created_at: string
}
function expiryText(days: number | null): string {
  if (days == null) return 'Never expires'
  if (days === 1) return '1 day'
  if (days >= 365) return `${Math.round(days / 365)} year${days >= 730 ? 's' : ''}`
  return `${days} days`
}
interface Course { id: string; title: string }

export default function Codes() {
  const { toast } = useToast()
  const [codes, setCodes] = useState<Code[]>([])
  const [courses, setCourses] = useState<Course[]>([])
  const [courseId, setCourseId] = useState('')
  const [type, setType] = useState('full')
  const [days, setDays] = useState('30')
  const [maxUses, setMaxUses] = useState('1')

  const load = useCallback(async () => {
    try { setCodes(await api.get<Code[]>('/codes')); setCourses(await api.get<Course[]>('/courses')) }
    catch (e) { toast(e instanceof Error ? e.message : 'Load failed', true) }
  }, [toast])
  useEffect(() => { load() }, [load])

  const create = async () => {
    try {
      await api.post('/codes', {
        course_id: courseId || null, lesson_id: null, access_type: type,
        access_duration: days ? +days : null, max_uses: maxUses ? +maxUses : null, expires_at: null,
      })
      toast('Code created'); load()
    } catch (e) { toast(e instanceof Error ? e.message : 'Create failed', true) }
  }

  return (
    <>
      <h1>Access Codes</h1>
      <p className="sub">Generate enrollment codes for courses</p>

      <div className="card" style={{ marginBottom: 18 }}>
        <div className="grid g4">
          <div><label>Course</label>
            <select value={courseId} onChange={(e) => setCourseId(e.target.value)} data-testid="code-course">
              <option value="">— pick course —</option>
              {courses.map((c) => <option key={c.id} value={c.id}>{c.title}</option>)}
            </select>
          </div>
          <div><label>Type</label>
            <select value={type} onChange={(e) => setType(e.target.value)}>
              <option value="full">Full</option><option value="trial">Trial</option>
            </select>
          </div>
          <div><label>Duration (days)</label><input type="number" value={days} onChange={(e) => setDays(e.target.value)} /></div>
          <div><label>Max uses</label><input type="number" value={maxUses} onChange={(e) => setMaxUses(e.target.value)} /></div>
        </div>
        <button className="btn" style={{ marginTop: 12 }} onClick={create} disabled={!courseId} data-testid="btn-generate-code">Generate Code</button>
      </div>

      <div className="card" style={{ padding: 0 }}>
        <table>
          <thead><tr><th>Code</th><th>Course</th><th>Type</th><th>Uses</th><th>Active</th><th></th></tr></thead>
          <tbody data-testid="codes-table">
            {codes.map((c) => (
              <tr key={c.id}>
                <td><b className="mono">{c.code}</b></td>
                <td>{courses.find((x) => x.id === c.course_id)?.title || c.course_id?.slice(0, 8) || '—'}</td>
                <td>
                  <span className={`badge ${c.access_type === 'full' ? 'b-green' : 'b-blue'}`}>{c.access_type === 'full' ? 'Full access' : 'Trial'}</span>
                  <div className="sub" style={{ margin: 0 }}>{expiryText(c.access_duration)}</div>
                </td>
                <td>
                  {c.current_uses} of {c.max_uses ?? '∞'} used
                  {c.max_uses != null && c.current_uses >= c.max_uses && <div><span className="badge b-red">Used up</span></div>}
                </td>
                <td>{c.is_active ? <span className="badge b-green">yes</span> : <span className="badge b-gray">no</span>}</td>
                <td><button className="btn danger small" disabled={!c.is_active} onClick={async () => { await api.del(`/codes/${c.id}`); load() }}>{c.is_active ? 'Deactivate' : 'Inactive'}</button></td>
              </tr>
            ))}
            {codes.length === 0 && <tr><td colSpan={6} className="sub" style={{ textAlign: 'center' }}>No codes</td></tr>}
          </tbody>
        </table>
      </div>
    </>
  )
}
