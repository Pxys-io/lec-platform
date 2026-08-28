import { useCallback, useEffect, useRef, useState } from 'react'
import { api } from '../api'
import { useToast } from '../toast'

interface Res { resolution: string; status: string; width: number; height: number; bitrate: number }
interface Video {
  id: string; title: string; description: string | null; status: string; folder: string
  streaming_mode: string; transcode_method?: string
  watermark_enabled: boolean; watermark_mode: string; watermark_segments: number
  watermark_text: string | null; watermark_color: string; watermark_font_size: number
  watermark_opacity: number; watermark_overlay_count: number; watermark_insert_duration: number
  watermark_insert_repeat: number; watermark_break_duration: number
  duration_seconds: number | null; width: number | null; height: number | null
  resolutions?: Res[]
}
interface Job { id: string; video_id: string; status: string; progress: number; fail_count: number; transcode_method?: string; created_at?: string }

function humanDur(sec: number | null): string {
  if (sec == null) return '—'
  const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = Math.round(sec % 60)
  if (h > 0) return `${h}h ${m}m`
  if (m > 0) return `${m}m ${String(s).padStart(2, '0')}s`
  return `${s}s`
}
function timeAgo(iso: string | null): string {
  if (!iso) return ''
  const d = new Date(iso + (iso.endsWith('Z') ? '' : 'Z'))
  const diff = (Date.now() - d.getTime()) / 1000
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  return d.toLocaleDateString()
}
const emptyWm = {
  watermark_enabled: true, watermark_mode: 'insert', watermark_segments: 10,
  watermark_text: '', watermark_color: '#FFFFFF', watermark_font_size: 20,
  watermark_opacity: 0.4, watermark_overlay_count: 1, watermark_insert_duration: 1.0,
  watermark_insert_repeat: 1, watermark_break_duration: 60,
}

export default function Videos() {
  const { toast } = useToast()
  const [videos, setVideos] = useState<Video[]>([])
  const [jobs, setJobs] = useState<Job[]>([])
  const [loading, setLoading] = useState(true)
  const [q, setQ] = useState('')
  const [uploadOpen, setUploadOpen] = useState(false)
  const [edit, setEdit] = useState<Video | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)

  const load = useCallback(async () => {
    try {
      const [v, j] = await Promise.all([api.get<Video[]>('/videos/manage'), api.get<Job[]>('/videos/jobs')])
      setVideos(v); setJobs(j)
    } catch (e) { toast(e instanceof Error ? e.message : 'Load failed', true) }
    finally { setLoading(false) }
  }, [toast])

  useEffect(() => { load() }, [load])

  // ---- Upload (chunked, mirrors player flow) ----
  const [upFile, setUpFile] = useState<File | null>(null)
  const [upTitle, setUpTitle] = useState('')
  const [upDesc, setUpDesc] = useState('')
  const [upFolder, setUpFolder] = useState('General')
  const [upMode, setUpMode] = useState('hls')
  const [upPct, setUpPct] = useState(0)
  const [upBusy, setUpBusy] = useState(false)

  const doUpload = async () => {
    if (!upFile || !upTitle) return
    setUpBusy(true); setUpPct(0)
    try {
      const CHUNK = 25 * 1024 * 1024
      const total = Math.ceil(upFile.size / CHUNK)
      const init = await api.post<{ upload_id: string }>('/videos/upload/init', {
        title: upTitle, description: upDesc, filename: upFile.name, total_size: upFile.size,
        total_chunks: total, watermark_enabled: upMode === 'hls', folder: upFolder, streaming_mode: upMode,
      })
      for (let i = 0; i < total; i++) {
        const fd = new FormData()
        fd.append('file', upFile.slice(i * CHUNK, Math.min((i + 1) * CHUNK, upFile.size)), upFile.name)
        await api.postForm(`/videos/upload/${init.upload_id}/chunk?chunk_index=${i}`, fd)
        setUpPct(Math.round(((i + 1) / total) * 100))
      }
      await api.post(`/videos/upload/${init.upload_id}/complete`)
      toast('Upload complete — transcoding started')
      setUploadOpen(false); setUpFile(null); setUpTitle(''); setUpDesc(''); setUpPct(0)
      load()
    } catch (e) { toast(e instanceof Error ? e.message : 'Upload failed', true) }
    finally { setUpBusy(false) }
  }

  const saveWm = async () => {
    if (!edit) return
    try {
      await api.put(`/videos/manage/${edit.id}`, {
        title: edit.title, description: edit.description, folder: edit.folder,
        streaming_mode: edit.streaming_mode, watermark_enabled: edit.watermark_enabled,
        watermark_mode: edit.watermark_mode, watermark_segments: edit.watermark_segments,
        watermark_text: edit.watermark_text || null, watermark_color: edit.watermark_color,
        watermark_font_size: edit.watermark_font_size, watermark_opacity: edit.watermark_opacity,
        watermark_overlay_count: edit.watermark_overlay_count, watermark_insert_duration: edit.watermark_insert_duration,
        watermark_insert_repeat: edit.watermark_insert_repeat, watermark_break_duration: edit.watermark_break_duration,
      })
      toast('Saved'); setEdit(null); load()
    } catch (e) { toast(e instanceof Error ? e.message : 'Save failed', true) }
  }

  const act = async (fn: () => Promise<unknown>, ok: string) => {
    try { await fn(); toast(ok); load() }
    catch (e) { toast(e instanceof Error ? e.message : 'Action failed', true) }
  }

  const filtered = videos.filter((v) => (v.title || '').toLowerCase().includes(q.toLowerCase()) || v.id.includes(q))
  const badge = (s: string) => s === 'ready' ? 'b-green' : s === 'transcoding' ? 'b-blue' : s === 'pending' ? 'b-yellow' : 'b-red'
  const activeJobs = jobs.filter((j) => ['pending', 'running'].includes(j.status))

  return (
    <>
      <div className="spread">
        <div><h1>Videos</h1><p className="sub">Upload, transcode and watermark course videos</p></div>
        <div className="row">
          <button className="btn ghost" onClick={load}>↻ Refresh</button>
          <button className="btn" onClick={() => setUploadOpen(true)} data-testid="btn-upload">＋ Upload Video</button>
        </div>
      </div>

      {activeJobs.length > 0 && (
        <div className="card" style={{ marginBottom: 18 }}>
          <h2 style={{ margin: '0 0 10px' }}>Transcode Queue ({activeJobs.length})</h2>
          {activeJobs.map((j) => (
            <div className="job" key={j.id}>
              <div className="grow">
                <div className="row" style={{ marginBottom: 6 }}>
                  <b>{videos.find((v) => v.id === j.video_id)?.title || 'Video ' + j.video_id.slice(0, 8)}</b>
                  <span className={`badge ${j.status === 'running' ? 'b-blue' : 'b-yellow'}`}>
                    {j.status === 'running' ? 'Transcoding…' : 'Waiting in queue'}
                  </span>
                  {j.transcode_method && <span className="chip b-gray">{j.transcode_method === 'mux' ? '☁ Mux cloud' : '⚙ Server ffmpeg'}</span>}
                  {j.fail_count > 0 && <span className="badge b-red">{j.fail_count} failed attempts</span>}
                  {j.created_at && <span className="sub" style={{ margin: 0 }}>{timeAgo(j.created_at)}</span>}
                </div>
                <div className="progress"><div style={{ width: `${j.progress}%` }} /></div>
              </div>
              <button className="btn ghost small danger" onClick={() => act(() => api.post(`/videos/jobs/${j.id}/kill`), 'Job killed')}>Stop</button>
            </div>
          ))}
        </div>
      )}

      <input placeholder="Search by title or ID…" value={q} onChange={(e) => setQ(e.target.value)} style={{ maxWidth: 380, marginBottom: 14 }} data-testid="videos-search" />

      {loading ? <p className="sub">Loading…</p> : (
        Object.entries(
          filtered.reduce<Record<string, Video[]>>((acc, v) => {
            const f = v.folder || 'General'
            ;(acc[f] = acc[f] || []).push(v)
            return acc
          }, {}),
        ).sort(([a], [b]) => a.localeCompare(b)).map(([folder, vids]) => (
        <div key={folder} style={{ marginBottom: 26 }}>
          <h2 style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10 }}>
            <span style={{ width: 8, height: 8, borderRadius: 99, background: 'var(--primary)', display: 'inline-block' }} />
            {folder} <span className="sub" style={{ margin: 0 }}>({vids.length})</span>
          </h2>
        <div className="card" style={{ padding: 0 }}>
          <table>
            <thead><tr><th>Title</th><th>Status</th><th>Mode</th><th>WM</th><th>Duration</th><th style={{ textAlign: 'right' }}>Actions</th></tr></thead>
            <tbody data-testid="videos-table">
              {vids.map((v) => (
                <tr key={v.id}>
                  <td><b>{v.title || 'Untitled'}</b><div className="mono">{v.id.slice(0, 8)}</div></td>
                  <td><span className={`badge ${badge(v.status)}`}>
                      {v.status === 'ready' ? 'Ready' : v.status === 'transcoding' ? 'Transcoding…' : v.status === 'pending' ? 'Queued' : v.status === 'blocked' ? 'Blocked' : 'Failed'}
                    </span></td>
                  <td>{v.streaming_mode === 'direct' ? <span className="badge b-gray">DIRECT</span> : <span className="badge b-blue">HLS</span>}</td>
                  <td>{v.watermark_enabled
                      ? <span className="badge b-green">{v.watermark_mode === 'insert' ? `Breaks ×${v.watermark_segments}` : `Overlay ×${v.watermark_overlay_count}`}</span>
                      : <span className="badge b-gray">Off</span>}</td>
                  <td>{humanDur(v.duration_seconds)}</td>
                  <td style={{ textAlign: 'right', whiteSpace: 'nowrap' }}>
                    <button className="btn ghost small" onClick={() => setEdit(v)}>Edit</button>{' '}
                    {v.status !== 'transcoding' && v.status !== 'blocked' && (
                      <button className="btn ghost small" onClick={() => act(() => api.post(`/videos/manage/${v.id}/transcode`), 'Queued')}>Re-encode</button>
                    )}{' '}
                    <button className="btn ghost small" onClick={() => act(() => api.put(`/videos/manage/${v.id}`, { status: v.status === 'blocked' ? 'ready' : 'blocked' }), v.status === 'blocked' ? 'Unblocked' : 'Blocked')}>
                      {v.status === 'blocked' ? 'Unblock' : 'Block'}
                    </button>{' '}
                    <button className="btn danger small" onClick={() => { if (confirm('Delete video?')) act(() => api.del(`/videos/manage/${v.id}`), 'Deleted') }}>Delete</button>
                  </td>
                </tr>
              ))}
              {vids.length === 0 && <tr><td colSpan={6} style={{ color: 'var(--muted)', textAlign: 'center' }}>No videos</td></tr>}
            </tbody>
          </table>
        </div>
        </div>
        ))
      )}
      {!loading && filtered.length === 0 && (
        <div className="card" style={{ textAlign: 'center', color: 'var(--muted)' }}>No videos found</div>
      )}

      {uploadOpen && (
        <div className="modal-bg" onClick={(e) => e.target === e.currentTarget && setUploadOpen(false)}>
          <div className="modal" data-testid="upload-modal">
            <h3>Upload Video</h3>
            <div className="field">
              <label>File (MP4/MKV/MOV, max 500MB)</label>
              <input ref={fileRef} type="file" accept="video/*" onChange={(e) => {
                const f = e.target.files?.[0]; if (f) { setUpFile(f); if (!upTitle) setUpTitle(f.name.replace(/\.[^.]+$/, '')) }
              }} data-testid="upload-file" />
            </div>
            <div className="field"><label>Title</label><input value={upTitle} onChange={(e) => setUpTitle(e.target.value)} data-testid="upload-title" /></div>
            <div className="field"><label>Description</label><textarea rows={2} value={upDesc} onChange={(e) => setUpDesc(e.target.value)} /></div>
            <div className="grid g2">
              <div className="field"><label>Folder</label><input value={upFolder} onChange={(e) => setUpFolder(e.target.value)} /></div>
              <div className="field"><label>Mode</label>
                <select value={upMode} onChange={(e) => setUpMode(e.target.value)}>
                  <option value="hls">HLS (watermark)</option>
                  <option value="direct">Direct</option>
                </select>
              </div>
            </div>
            {upBusy && <div className="progress" style={{ marginBottom: 12 }}><div style={{ width: `${upPct}%` }} /></div>}
            <div className="row" style={{ justifyContent: 'flex-end' }}>
              <button className="btn ghost" onClick={() => setUploadOpen(false)} disabled={upBusy}>Cancel</button>
              <button className="btn" onClick={doUpload} disabled={!upFile || !upTitle || upBusy} data-testid="upload-start">
                {upBusy ? `Uploading ${upPct}%` : 'Start Upload'}
              </button>
            </div>
          </div>
        </div>
      )}

      {edit && (
        <div className="modal-bg" onClick={(e) => e.target === e.currentTarget && setEdit(null)}>
          <div className="modal" data-testid="edit-modal">
            <h3>Edit — {edit.title}</h3>
            <div className="row" style={{ marginBottom: 14, flexWrap: 'wrap', gap: 8 }}>
              <span className="badge b-blue">{edit.status}</span>
              {edit.width && edit.height && <span className="badge b-gray">{edit.width}×{edit.height}</span>}
              {edit.duration_seconds != null && <span className="badge b-gray">{humanDur(edit.duration_seconds)}</span>}
              {edit.resolutions?.map((r) => (
                <span key={r.resolution} className={`badge ${r.status === 'ready' ? 'b-green' : 'b-yellow'}`}>{r.resolution} · {r.status}</span>
              ))}
            </div>
            <div className="grid g2">
              <div className="field"><label>Title</label><input value={edit.title} onChange={(e) => setEdit({ ...edit, title: e.target.value })} /></div>
              <div className="field"><label>Folder</label><input value={edit.folder} onChange={(e) => setEdit({ ...edit, folder: e.target.value })} /></div>
            </div>
            <div className="field"><label>Streaming mode</label>
              <select value={edit.streaming_mode} onChange={(e) => setEdit({ ...edit, streaming_mode: e.target.value })}>
                <option value="hls">HLS</option><option value="direct">Direct</option>
              </select>
            </div>
            <div className="field"><label>Description</label><textarea rows={2} value={edit.description || ''} onChange={(e) => setEdit({ ...edit, description: e.target.value })} /></div>

            <h2 style={{ margin: '16px 0 10px' }}>Watermark</h2>
            <div className="row" style={{ marginBottom: 12 }}>
              <label style={{ margin: 0 }}>Enabled</label>
              <input type="checkbox" style={{ width: 'auto' }} checked={edit.watermark_enabled} onChange={(e) => setEdit({ ...edit, watermark_enabled: e.target.checked })} />
            </div>
            {edit.watermark_enabled && (
              <>
                <div className="grid g2">
                  <div className="field"><label>Mode</label>
                    <select value={edit.watermark_mode} onChange={(e) => setEdit({ ...edit, watermark_mode: e.target.value })}>
                      <option value="insert">Insert (break screens)</option>
                      <option value="overlay">Overlay (text)</option>
                    </select>
                  </div>
                  <div className="field"><label>Segments count</label><input type="number" value={edit.watermark_segments} onChange={(e) => setEdit({ ...edit, watermark_segments: +e.target.value })} /></div>
                </div>
                <div className="field"><label>Custom text (blank = user email)</label><input value={edit.watermark_text || ''} onChange={(e) => setEdit({ ...edit, watermark_text: e.target.value })} /></div>
                <div className="grid g3">
                  <div className="field"><label>Color</label><input type="color" value={edit.watermark_color} onChange={(e) => setEdit({ ...edit, watermark_color: e.target.value })} /></div>
                  <div className="field"><label>Font size</label><input type="number" value={edit.watermark_font_size} onChange={(e) => setEdit({ ...edit, watermark_font_size: +e.target.value })} /></div>
                  <div className="field"><label>Opacity ({Math.round(edit.watermark_opacity * 100)}%)</label>
                    <input type="range" min="0" max="1" step="0.05" value={edit.watermark_opacity}
                      onChange={(e) => setEdit({ ...edit, watermark_opacity: +e.target.value })} style={{ padding: 0, accentColor: 'var(--primary)' }} />
                  </div>
                </div>
                {edit.watermark_mode === 'insert' ? (
                  <div className="grid g3">
                    <div className="field"><label>Insert duration (s)</label><input type="number" step="0.1" value={edit.watermark_insert_duration} onChange={(e) => setEdit({ ...edit, watermark_insert_duration: +e.target.value })} /></div>
                    <div className="field"><label>Repeat</label><input type="number" value={edit.watermark_insert_repeat} onChange={(e) => setEdit({ ...edit, watermark_insert_repeat: +e.target.value })} /></div>
                    <div className="field"><label>Break duration (s)</label><input type="number" value={edit.watermark_break_duration} onChange={(e) => setEdit({ ...edit, watermark_break_duration: +e.target.value })} /></div>
                  </div>
                ) : (
                  <div className="field"><label>Overlay count</label><input type="number" value={edit.watermark_overlay_count} onChange={(e) => setEdit({ ...edit, watermark_overlay_count: +e.target.value })} /></div>
                )}
              </>
            )}
            <div className="row" style={{ justifyContent: 'flex-end' }}>
              <button className="btn ghost" onClick={() => setEdit(null)}>Cancel</button>
              <button className="btn" onClick={saveWm} data-testid="edit-save">Save</button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
