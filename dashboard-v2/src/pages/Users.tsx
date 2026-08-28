import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'
import { useToast } from '../toast'

interface U {
  id: string; email: string; phone: string | null; role: string
  banned_until: string | null; last_login: string | null; first_name?: string; last_name?: string
  device_limit?: number
}
function timeAgo(iso: string | null): string {
  if (!iso) return 'Never'
  const d = new Date(iso + (iso.endsWith('Z') ? '' : 'Z'))
  const diff = (Date.now() - d.getTime()) / 1000
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  return d.toLocaleDateString()
}
const ROLE_LABEL: Record<string, string> = {
  super_admin: 'Super Admin', admin: 'Admin', instructor: 'Instructor', student: 'Student',
}
interface Dev { device_id: string; device_type: string; last_login: string }

export default function Users() {
  const { toast } = useToast()
  const [users, setUsers] = useState<U[]>([])
  const [q, setQ] = useState('')
  const [sel, setSel] = useState<U | null>(null)
  const [devices, setDevices] = useState<Dev[]>([])

  const load = useCallback(async () => {
    try { setUsers(await api.get<U[]>('/users')) }
    catch (e) { toast(e instanceof Error ? e.message : 'Load failed', true) }
  }, [toast])
  useEffect(() => { load() }, [load])

  const openUser = async (u: U) => {
    setSel(u)
    try { const d = await api.get<{ devices: Dev[] }>(`/users/${u.id}/devices`); setDevices(d.devices || []) }
    catch { setDevices([]) }
  }

  const act = async (fn: () => Promise<unknown>, ok: string) => {
    try { await fn(); toast(ok); load(); sel && openUser(sel) } catch (e) { toast(e instanceof Error ? e.message : 'Failed', true) }
  }

  const filtered = users.filter((u) => u.email.toLowerCase().includes(q.toLowerCase()))
  const roleBadge = (r: string) => r === 'super_admin' ? 'b-red' : r === 'admin' ? 'b-yellow' : r === 'instructor' ? 'b-blue' : 'b-gray'

  return (
    <>
      <h1>Users</h1>
      <p className="sub">{users.length} accounts</p>
      <input placeholder="Search email…" value={q} onChange={(e) => setQ(e.target.value)} style={{ maxWidth: 360, marginBottom: 14 }} />

      <div className="card" style={{ padding: 0 }}>
        <table>
          <thead><tr><th>Email</th><th>Role</th><th>Status</th><th>Last login</th><th></th></tr></thead>
          <tbody data-testid="users-table">
            {filtered.map((u) => (
              <tr key={u.id}>
                <td><b>{u.email}</b><div className="sub" style={{ margin: 0 }}>{[u.first_name, u.last_name].filter(Boolean).join(' ') || '—'}{u.phone ? ` · ${u.phone}` : ''}</div></td>
                <td><span className={`badge ${roleBadge(u.role)}`}>{ROLE_LABEL[u.role] || u.role}</span></td>
                <td>{u.banned_until && new Date(u.banned_until) > new Date() ? <span className="badge b-red">banned</span> : <span className="badge b-green">active</span>}</td>
                <td>{timeAgo(u.last_login)}</td>
                <td style={{ textAlign: 'right' }}>
                  <button className="btn ghost small" onClick={() => openUser(u)}>Manage</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {sel && (
        <div className="modal-bg" onClick={(e) => e.target === e.currentTarget && setSel(null)}>
          <div className="modal" data-testid="user-modal">
            <h3>{[sel.first_name, sel.last_name].filter(Boolean).join(' ') || sel.email}</h3>
            <p className="sub" style={{ marginBottom: 16 }}>
              {sel.email} · {ROLE_LABEL[sel.role] || sel.role}
              {sel.device_limit != null && <> · up to {sel.device_limit > 999 ? 'unlimited' : sel.device_limit} device{sel.device_limit === 1 ? '' : 's'}</>}
            </p>
            <div className="row" style={{ flexWrap: 'wrap', gap: 8 }}>
              {sel.banned_until && new Date(sel.banned_until) > new Date() ? (
                <button className="btn small" onClick={() => act(() => api.post(`/users/${sel.id}/unban`), 'Unbanned')}>🚫 Lift ban</button>
              ) : (
                <>
                  <select defaultValue="7" style={{ width: 'auto' }} data-testid="ban-days">
                    <option value="1">1 day</option><option value="7">7 days</option>
                    <option value="30">30 days</option><option value="365">1 year</option>
                  </select>
                  <button className="btn danger small" data-testid="btn-ban" onClick={() => {
                    const d = document.querySelector('select[data-testid="ban-days"]') as HTMLSelectElement
                    act(() => api.post(`/users/${sel.id}/ban?ban_duration_days=${d?.value || 7}`), `Banned ${d?.value || 7}d`)
                  }}>🚫 Ban</button>
                </>
              )}
              <button className="btn ghost small" onClick={() => act(() => api.post(`/users/${sel.id}/devices/reset`), 'Devices reset')}>Reset devices</button>
              <select
                value={sel.role} style={{ width: 'auto' }} data-testid="role-select"
                onChange={(e) => act(() => api.put(`/users/${sel.id}`, { role: e.target.value }), `Role -> ${e.target.value}`)}
              >
                <option value="student">🎓 Student</option>
                <option value="instructor">📎 Instructor</option>
                <option value="admin">🛡 Admin</option>
                <option value="super_admin">👑 Super Admin</option>
              </select>
            </div>
            <h2>Devices ({devices.length})</h2>
            {devices.map((d) => (
              <div className="job" key={d.device_id}>
                <div className="grow">
                  <b>{d.device_type === 'mobile' ? '📱 Phone / tablet' : '💻 Desktop'}</b>
                  <div className="sub" style={{ margin: 0 }}>Last active {timeAgo(d.last_login)} · ID {d.device_id.slice(0, 8)}…</div>
                </div>
              </div>
            ))}
            {devices.length === 0 && <p className="sub">No devices</p>}
            <div className="row" style={{ justifyContent: 'flex-end', marginTop: 12 }}>
              <button className="btn ghost" onClick={() => setSel(null)}>Close</button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
