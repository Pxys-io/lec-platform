import { useState, useRef } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { Paperclip, Plus, Trash2, Upload, Link as LinkIcon, X, Loader2, FileText } from 'lucide-react'

interface Material {
  id: string
  lesson_id: string
  title: string
  type: string
  url: string
  file_size?: number | null
}

const TYPE_OPTIONS = [
  { value: 'pdf', label: 'PDF' },
  { value: 'document', label: 'Document (doc/ppt/xls)' },
  { value: 'image', label: 'Image' },
  { value: 'link', label: 'Webpage link' },
]

export default function MaterialManager({ lessonId }: { lessonId: string }) {
  const { isInstructor } = useAuth()
  const queryClient = useQueryClient()
  const [showAdd, setShowAdd] = useState(false)
  const [mode, setMode] = useState<'file' | 'link'>('file')
  const [title, setTitle] = useState('')
  const [type, setType] = useState('pdf')
  const [url, setUrl] = useState('')
  const [file, setFile] = useState<File | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const fileRef = useRef<HTMLInputElement>(null)

  const { data: materials, isLoading } = useQuery<Material[]>({
    queryKey: ['lesson-materials', lessonId],
    queryFn: () => api.get(`/lessons/${lessonId}/materials`),
  })

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ['lesson-materials', lessonId] })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/materials/${id}`),
    onSuccess: invalidate,
  })

  const reset = () => {
    setTitle('')
    setUrl('')
    setFile(null)
    setType('pdf')
    setMode('file')
    setError('')
    setShowAdd(false)
  }

  const handleAdd = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    if (!title.trim()) {
      setError('Title is required')
      return
    }
    setBusy(true)
    try {
      let finalUrl = url.trim()
      let fileSize: number | undefined

      if (mode === 'file') {
        if (!file) throw new Error('Please choose a file to upload')
        const form = new FormData()
        form.append('file', file)
        const up = await api.post<{ url: string }>('/misc/upload', form)
        finalUrl = up.url
        fileSize = file.size
      } else {
        if (!finalUrl) throw new Error('Please paste a webpage URL')
        if (!/^https?:\/\//i.test(finalUrl)) finalUrl = `https://${finalUrl}`
      }

      await api.post(`/lessons/${lessonId}/materials`, {
        lesson_id: String(lessonId),
        title: title.trim(),
        type: mode === 'link' ? 'link' : type,
        url: finalUrl,
        file_size: fileSize ?? null,
      })
      invalidate()
      reset()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to add material')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="bg-surface rounded-xl border border-border p-5">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-semibold text-gray-900 flex items-center gap-2">
          <Paperclip className="h-4 w-4" /> Materials &amp; Documents ({materials?.length || 0})
        </h3>
        {isInstructor && !showAdd && (
          <button
            onClick={() => setShowAdd(true)}
            className="flex items-center gap-1.5 px-3 py-1.5 bg-primary text-white rounded-lg hover:bg-primary-dark text-xs font-medium"
          >
            <Plus className="h-3.5 w-3.5" /> Add PDF / link
          </button>
        )}
      </div>

      {isLoading ? (
        <div className="h-12 bg-gray-100 rounded-lg animate-pulse" />
      ) : materials && materials.length > 0 ? (
        <div className="space-y-2 mb-2">
          {materials.map((m) => (
            <div key={m.id} className="flex items-center justify-between gap-3 p-2.5 rounded-lg bg-surface-alt border border-border">
              <div className="flex items-center gap-2.5 min-w-0">
                <div className="p-1.5 rounded-md bg-white border border-border shrink-0">
                  {m.type === 'link' ? <LinkIcon className="h-4 w-4 text-blue-500" /> : <FileText className="h-4 w-4 text-red-500" />}
                </div>
                <div className="min-w-0">
                  <p className="text-sm font-medium text-gray-900 truncate">{m.title}</p>
                  <p className="text-xs text-gray-500 truncate">{m.type} · <span className="truncate">{m.url}</span></p>
                </div>
              </div>
              <div className="flex items-center gap-2 shrink-0">
                <a href={m.url} target="_blank" rel="noreferrer" className="text-xs text-primary hover:underline">Open</a>
                {isInstructor && (
                  <button
                    onClick={() => { if (confirm(`Delete "${m.title}"?`)) deleteMutation.mutate(m.id) }}
                    className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors"
                    title="Delete material"
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <p className="text-xs text-gray-400 mb-2">No PDFs, documents or links yet.</p>
      )}

      {isInstructor && showAdd && (
        <form onSubmit={handleAdd} className="mt-3 p-4 rounded-xl border border-dashed border-border bg-white space-y-3">
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => setMode('file')}
              className={`flex-1 px-3 py-2 rounded-lg text-xs font-medium border ${mode === 'file' ? 'bg-primary text-white border-primary' : 'text-gray-600 border-border hover:bg-surface-alt'}`}
            >
              <span className="flex items-center justify-center gap-1.5"><Upload className="h-3.5 w-3.5" /> Upload PDF / file</span>
            </button>
            <button
              type="button"
              onClick={() => setMode('link')}
              className={`flex-1 px-3 py-2 rounded-lg text-xs font-medium border ${mode === 'link' ? 'bg-primary text-white border-primary' : 'text-gray-600 border-border hover:bg-surface-alt'}`}
            >
              <span className="flex items-center justify-center gap-1.5"><LinkIcon className="h-3.5 w-3.5" /> Webpage link</span>
            </button>
          </div>

          {error && <div className="p-2.5 rounded-lg bg-red-50 border border-red-200 text-red-600 text-xs">{error}</div>}

          <div>
            <label className="block text-xs font-medium text-gray-700 mb-1">Title *</label>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
              placeholder={mode === 'link' ? 'e.g. KDIGO Guidelines' : 'e.g. ECG handout'}
              required
            />
          </div>

          {mode === 'file' ? (
            <>
              <div>
                <label className="block text-xs font-medium text-gray-700 mb-1">Type</label>
                <select
                  value={type}
                  onChange={(e) => setType(e.target.value)}
                  className="w-full px-3 py-2 rounded-lg border border-border text-sm bg-white focus:outline-none focus:ring-2 focus:ring-primary/50"
                >
                  {TYPE_OPTIONS.filter((o) => o.value !== 'link').map((o) => (
                    <option key={o.value} value={o.value}>{o.label}</option>
                  ))}
                </select>
              </div>
              <div>
                <label className="block text-xs font-medium text-gray-700 mb-1">File (PDF, doc, image) *</label>
                <div
                  onClick={() => fileRef.current?.click()}
                  className="border-2 border-dashed border-gray-200 rounded-xl p-5 text-center cursor-pointer hover:border-primary/50 hover:bg-primary/5 transition-all"
                >
                  <input
                    type="file"
                    ref={fileRef}
                    className="hidden"
                    accept=".pdf,.doc,.docx,.ppt,.pptx,.xls,.xlsx,.txt,.md,.png,.jpg,.jpeg,.gif,.webp"
                    onChange={(e) => setFile(e.target.files?.[0] || null)}
                  />
                  {file ? (
                    <p className="text-sm font-medium text-primary truncate">{file.name} ({(file.size / 1024).toFixed(0)} KB)</p>
                  ) : (
                    <p className="text-xs text-gray-500">Click to choose a PDF / document / image</p>
                  )}
                </div>
              </div>
            </>
          ) : (
            <div>
              <label className="block text-xs font-medium text-gray-700 mb-1">Webpage URL *</label>
              <input
                type="url"
                value={url}
                onChange={(e) => setUrl(e.target.value)}
                className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                placeholder="https://..."
                required
              />
            </div>
          )}

          <div className="flex gap-2">
            <button
              type="submit"
              disabled={busy}
              className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark text-xs font-medium disabled:opacity-50"
            >
              {busy && <Loader2 className="h-3.5 w-3.5 animate-spin" />}
              {busy ? 'Saving...' : 'Save material'}
            </button>
            <button
              type="button"
              onClick={reset}
              className="flex items-center gap-1 px-3 py-2 border border-border rounded-lg text-xs text-gray-600 hover:bg-surface-alt"
            >
              <X className="h-3.5 w-3.5" /> Cancel
            </button>
          </div>
        </form>
      )}
    </div>
  )
}
