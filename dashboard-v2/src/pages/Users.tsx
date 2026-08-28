import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'
import { useToast } from '../toast'

interface U {
  id: string; email: string; phone: string | null; role: string
  banned_until: string | null; last_login: string | null; first_name?: string; last_name?: string
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
    try { await fn(); toast(ok); load() } catch (e) { toast(e instanceof Error ? e.message : 'Failed', true) }
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
                <td><b>{u.email}</b></td>
                <td><span className={`badge ${roleBadge(u.role)}`}>{u.role}</span></td>
                <td>{u.banned_until && new Date(u.banned_until) > new Date() ? <span className="badge b-red">banned</span> : <span className="badge b-green">active</span>}</td>
                <td className="mono">{u.last_login ? new Date(u.last_login).toLocaleDateString() : '—'}</td>
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
            <h3>{sel.email}</h3>
            <p className="sub" style={{ marginBottom: 16 }}>Role: {sel.role} · ID {sel.id.slice(0, 8)}</p>
            <div className="row" style={{ flexWrap: 'wrap', gap: 8 }}>
              {sel.banned_until && new Date(sel.banned_until) > new Date() ? (
                <button className="btn small" onClick={() => act(() => api.post(`/users/${sel.id}/unban`), 'Unbanned')}>Unban</button>
              ) : (
                <button className="btn danger small" onClick={() => act(() => api.post(`/users/${sel.id}/ban?ban_duration_days=7`), 'Banned 7d')}>Ban 7d</button>
              )}
              <button className="btn ghost small" onClick={() => act(() => api.post(`/users/${sel.id}/devices/reset`), 'Devices reset')}>Reset devices</button>
              {sel.role === 'student' && <button className="btn ghost small" onClick={() => act(() => api.put(`/users/${sel.id}`, { role: 'instructor' }), 'Promoted')}>Make instructor</button>}
              {sel.role === 'instructor' && <button className="btn ghost small" onClick={() => act(() => api.put(`/users/${sel.id}`, { role: 'student' }), 'Demoted')}>Make student</button>}
            </div>
            <h2>Devices ({devices.length})</h2>
            {devices.map((d) => (
              <div className="job" key={d.device_id}>
                <div className="grow"><b className="mono">{d.device_id.slice(0, 14)}…</b><div className="sub" style={{ margin: 0 }}>{d.device_type} · {d.last_login ? new Date(d.last_login).toLocaleString() : 'never'}</div></div>
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
