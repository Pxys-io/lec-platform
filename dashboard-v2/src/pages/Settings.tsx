import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'
import { useToast } from '../toast'

interface Mode { server_mode: string; download_policy: string; mode_mismatch_action: string }

export default function Settings() {
  const { toast } = useToast()
  const [mode, setMode] = useState<Mode>({ server_mode: 'hybrid', download_policy: 'allow', mode_mismatch_action: 'warn' })
  const [busy, setBusy] = useState(false)

  const load = useCallback(async () => {
    try { setMode(await api.get<Mode>('/misc/server-mode')) }
    catch (e) { toast(e instanceof Error ? e.message : 'Load failed', true) }
  }, [toast])
  useEffect(() => { load() }, [load])

  const save = async () => {
    setBusy(true)
    try {
      const p = new URLSearchParams({ mode: mode.server_mode, download_policy: mode.download_policy, mode_mismatch_action: mode.mode_mismatch_action })
      const r = await api.put<Mode>(`/misc/server-mode?${p}`)
      setMode(r); toast('Server mode saved')
    } catch (e) { toast(e instanceof Error ? e.message : 'Save failed', true) }
    finally { setBusy(false) }
  }

  return (
    <>
      <h1>Settings</h1>
      <p className="sub">Server mode & download policies — applied to all mobile clients on next handshake</p>
      <div className="card" style={{ maxWidth: 560 }} data-testid="settings-card">
        <div className="field"><label>Server mode</label>
          <select value={mode.server_mode} onChange={(e) => setMode({ ...mode, server_mode: e.target.value })} data-testid="set-mode">
            <option value="hybrid">Hybrid — stream online & allow downloads</option>
            <option value="cloud_only">Cloud only — streaming, downloads blocked</option>
            <option value="local_only">Local only — downloaded content, server storage kept light</option>
          </select>
        </div>
        <div className="field"><label>Download policy</label>
          <select value={mode.download_policy} onChange={(e) => setMode({ ...mode, download_policy: e.target.value })}>
            <option value="allow">Allow — students can download</option>
            <option value="ban">Strict — downloaders get banned</option>
            <option value="auto_delete">Auto-delete — remove downloaded copies</option>
          </select>
        </div>
        <div className="field"><label>On mode mismatch</label>
          <select value={mode.mode_mismatch_action} onChange={(e) => setMode({ ...mode, mode_mismatch_action: e.target.value })}>
            <option value="warn">Warn only — show a notice</option>
            <option value="block">Block — refuse playback</option>
            <option value="auto_delete">Auto-delete — wipe the file</option>
          </select>
        </div>
        <p className="sub" style={{ marginTop: 8 }}>
          Applies to every student app on next launch. Hybrid is the normal mode; use Cloud only to stop leaks, Local only when internet is unreliable.
        </p>
        <button className="btn" onClick={save} disabled={busy} data-testid="btn-save-settings">{busy ? 'Saving…' : 'Save'}</button>
      </div>
    </>
  )
}
