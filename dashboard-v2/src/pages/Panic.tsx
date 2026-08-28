import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'
import { useToast } from '../toast'

interface PanicCfg {
  id: string; is_active: boolean; target_type: string; target_value: string | null; webview_url: string | null
}

export default function Panic() {
  const { toast } = useToast()
  const [cfgs, setCfgs] = useState<PanicCfg[]>([])
  const [type, setType] = useState('global')
  const [value, setValue] = useState('')
  const [url, setUrl] = useState('https://google.com')

  const load = useCallback(async () => {
    try { setCfgs(await api.get<PanicCfg[]>('/misc/panic-mode')) }
    catch (e) { toast(e instanceof Error ? e.message : 'Load failed', true) }
  }, [toast])
  useEffect(() => { load() }, [load])

  const create = async () => {
    try {
      await api.post('/misc/panic-mode', { is_active: true, target_type: type, target_value: value || null, webview_url: url })
      toast('Rule created'); load()
    } catch (e) { toast(e instanceof Error ? e.message : 'Create failed', true) }
  }
  const toggle = async (c: PanicCfg) => {
    try {
      await api.put(`/misc/panic-mode/${c.id}`, { is_active: !c.is_active, target_type: c.target_type, target_value: c.target_value, webview_url: c.webview_url })
      load()
    } catch (e) { toast(e instanceof Error ? e.message : 'Failed', true) }
  }
  const del = async (c: PanicCfg) => {
    try { await api.del(`/misc/panic-mode/${c.id}`); load() } catch (e) { toast(e instanceof Error ? e.message : 'Failed', true) }
  }

  return (
    <>
      <h1>Panic Mode</h1>
      <p className="sub">Redirect the mobile app to a webview (e.g. during raids)</p>

      <div className="card" style={{ marginBottom: 18 }}>
        <div className="grid g3">
          <div><label>Target</label>
            <select value={type} onChange={(e) => setType(e.target.value)} data-testid="panic-type">
              <option value="global">Global</option><option value="user">User ID</option>
              <option value="platform">Platform</option><option value="version">Version</option>
            </select>
          </div>
          <div><label>Value (for non-global)</label><input value={value} onChange={(e) => setValue(e.target.value)} /></div>
          <div><label>Webview URL</label><input value={url} onChange={(e) => setUrl(e.target.value)} /></div>
        </div>
        <button className="btn" style={{ marginTop: 12 }} onClick={create} data-testid="btn-add-panic">＋ Add Rule</button>
      </div>

      <div className="grid" style={{ gap: 10 }}>
        {cfgs.map((c) => (
          <div className="card spread" key={c.id}>
            <div>
              <b>{c.target_type}</b> {c.target_value && <span className="mono">{c.target_value}</span>}
              <div className="sub" style={{ margin: '4px 0 0' }}>{c.webview_url}</div>
            </div>
            <div className="row">
              <span className={`badge ${c.is_active ? 'b-red' : 'b-gray'}`}>{c.is_active ? 'ACTIVE' : 'off'}</span>
              <button className="btn ghost small" onClick={() => toggle(c)}>{c.is_active ? 'Disable' : 'Enable'}</button>
              <button className="btn danger small" onClick={() => del(c)}>✕</button>
            </div>
          </div>
        ))}
        {cfgs.length === 0 && <p className="sub">No rules</p>}
      </div>
    </>
  )
}
