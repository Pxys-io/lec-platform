import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api } from '../api'
import { useToast } from '../toast'

interface QBank { id: string; title: string; description: string; instructor_id: string; visibility: string; tags: string[]; price: number }

export default function QBanks() {
  const { toast } = useToast()
  const nav = useNavigate()
  const [qbanks, setQBanks] = useState<QBank[]>([])
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)

  const [open, setOpen] = useState(false)
  const [editId, setEditId] = useState<string | null>(null)
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [visibility, setVisibility] = useState('private')
  const [tags, setTags] = useState('')
  const [price, setPrice] = useState(0)

  const load = useCallback(async () => {
    setLoading(true)
    try { setQBanks(await api.get<QBank[]>('/qbanks')) }
    catch (e) { toast(e instanceof Error ? e.message : 'Load failed', true) }
    finally { setLoading(false) }
  }, [toast])
  useEffect(() => { load() }, [load])

  const openCreate = () => { setEditId(null); setTitle(''); setDescription(''); setVisibility('private'); setTags(''); setPrice(0); setOpen(true) }
  const openEdit = (q: QBank) => {
    setEditId(q.id); setTitle(q.title); setDescription(q.description || '')
    setVisibility(q.visibility); setTags((q.tags || []).join(', ')); setPrice(q.price); setOpen(true)
  }
  const save = async () => {
    if (!title.trim()) return
    const payload = {
      title: title.trim(), description: description.trim(), visibility,
      tags: tags.split(',').map((t) => t.trim()).filter(Boolean), price,
    }
    try {
      if (editId) { await api.put(`/qbanks/${editId}`, payload); toast('QBank updated') }
      else { await api.post('/qbanks', payload); toast('QBank created') }
      setOpen(false); load()
    } catch (e) { toast(e instanceof Error ? e.message : 'Save failed', true) }
  }
  const del = async (q: QBank) => {
    if (!confirm(`Delete QBank "${q.title}"? This removes its questions.`)) return
    try { await api.del(`/qbanks/${q.id}`); toast('Deleted'); load() }
    catch (e) { toast(e instanceof Error ? e.message : 'Delete failed', true) }
  }

  const filtered = qbanks.filter((q) => q.title.toLowerCase().includes(search.toLowerCase()))

  return (
    <>
      <div className="spread">
        <div><h1>QBanks</h1><p className="sub">Question banks and practice content</p></div>
        <button className="btn" onClick={openCreate} data-testid="btn-new-qbank">＋ New QBank</button>
      </div>

      <input placeholder="Search QBanks…" value={search} onChange={(e) => setSearch(e.target.value)} style={{ maxWidth: 360, marginBottom: 14 }} />

      {loading ? <p className="sub">Loading…</p> : (
        <div className="grid" style={{ gap: 10 }}>
          {filtered.map((q) => (
            <div className="card" key={q.id} style={{ padding: 0 }} data-testid={`qbank-${q.title}`}>
              <div className="spread" style={{ padding: '15px 18px', cursor: 'pointer' }} onClick={() => nav(`/qbanks/${q.id}`)}>
                <div>
                  <b>{q.title}</b>{' '}
                  <span className={`badge ${q.visibility === 'public' ? 'b-green' : 'b-gray'}`}>{q.visibility}</span>
                  {q.price > 0 && <span className="badge b-yellow">${q.price}</span>}
                  <div className="sub" style={{ margin: '4px 0 0' }}>
                    {q.description || 'No description'}{q.tags.length > 0 && ` — ${q.tags.join(', ')}`}
                  </div>
                </div>
                <div className="row" onClick={(e) => e.stopPropagation()}>
                  <button className="btn ghost small" onClick={() => nav(`/qbanks/${q.id}`)}>Open</button>
                  <button className="btn ghost small" onClick={() => openEdit(q)}>Edit</button>
                  <button className="btn danger small" onClick={() => del(q)}>Delete</button>
                </div>
              </div>
            </div>
          ))}
          {filtered.length === 0 && <p className="sub">No QBanks found</p>}
        </div>
      )}

      {open && (
        <div className="modal-bg" onClick={(e) => e.target === e.currentTarget && setOpen(false)}>
          <div className="modal" data-testid="qbank-modal">
            <h3>{editId ? 'Edit QBank' : 'New QBank'}</h3>
            <div className="field"><label>Title *</label><input value={title} onChange={(e) => setTitle(e.target.value)} data-testid="qbank-title" /></div>
            <div className="field"><label>Description</label><textarea rows={2} value={description} onChange={(e) => setDescription(e.target.value)} /></div>
            <div className="field"><label>Tags (comma separated)</label><input value={tags} onChange={(e) => setTags(e.target.value)} placeholder="Cardiology, Anatomy" /></div>
            <div className="row" style={{ gap: 12 }}>
              <div className="field" style={{ flex: 1 }}><label>Visibility</label>
                <select value={visibility} onChange={(e) => setVisibility(e.target.value)}>
                  <option value="private">Private</option><option value="public">Public</option>
                </select>
              </div>
              <div className="field" style={{ flex: 1 }}><label>Price (0 = free)</label>
                <input type="number" min={0} value={price} onChange={(e) => setPrice(Number(e.target.value))} />
              </div>
            </div>
            <div className="row" style={{ justifyContent: 'flex-end' }}>
              <button className="btn ghost" onClick={() => setOpen(false)}>Cancel</button>
              <button className="btn" onClick={save} disabled={!title} data-testid="qbank-create">{editId ? 'Save changes' : 'Create'}</button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}