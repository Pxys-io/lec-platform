import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { Search, Plus, BookOpen, Trash2 } from 'lucide-react'

interface QBank {
  id: string
  title: string
  description: string
  instructor_id: string
  visibility: string
  tags: string[]
  price: number
  created_at: string
}

export default function QBanks() {
  const navigate = useNavigate()
  const { isInstructor } = useAuth()
  const queryClient = useQueryClient()
  const [search, setSearch] = useState('')
  const [showCreate, setShowCreate] = useState(false)
  const [createForm, setCreateForm] = useState({ title: '', description: '', visibility: 'private', tags: '', price: 0 })
  const [createError, setCreateError] = useState('')

  const { data: qbanks, isLoading } = useQuery<QBank[]>({
    queryKey: ['qbanks'],
    queryFn: () => api.get('/qbanks'),
  })

  const createMutation = useMutation({
    mutationFn: (data: typeof createForm) =>
      api.post('/qbanks', {
        ...data,
        tags: data.tags ? data.tags.split(',').map((t: string) => t.trim()) : [],
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['qbanks'] })
      setShowCreate(false)
      setCreateForm({ title: '', description: '', visibility: 'private', tags: '', price: 0 })
      setCreateError('')
    },
    onError: (err: Error) => setCreateError(err.message),
  })

  const filtered = qbanks?.filter((q) =>
    q.title.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">QBanks</h1>
          <p className="text-sm text-gray-500 mt-1">Manage question banks and practice content</p>
        </div>
        {isInstructor && (
          <button
            onClick={() => setShowCreate(true)}
            className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark transition-colors text-sm font-medium"
          >
            <Plus className="h-4 w-4" />
            New QBank
          </button>
        )}
      </div>

      <div className="relative max-w-sm">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full pl-10 pr-4 py-2 rounded-lg border border-border bg-surface text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
          placeholder="Search QBanks..."
        />
      </div>

      {showCreate && (
        <div className="bg-surface rounded-xl border border-border p-6">
          <h2 className="text-lg font-semibold mb-4">Create New QBank</h2>
          {createError && (
            <div className="mb-4 p-3 rounded-lg bg-red-50 border border-red-200 text-red-600 text-sm">{createError}</div>
          )}
          <form
            onSubmit={(e) => {
              e.preventDefault()
              createMutation.mutate(createForm)
            }}
            className="space-y-4"
          >
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Title *</label>
              <input
                type="text"
                value={createForm.title}
                onChange={(e) => setCreateForm({ ...createForm, title: e.target.value })}
                className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
              <textarea
                value={createForm.description}
                onChange={(e) => setCreateForm({ ...createForm, description: e.target.value })}
                className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 min-h-[80px]"
              />
            </div>
            <div className="grid grid-cols-3 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Visibility</label>
                <select
                  value={createForm.visibility}
                  onChange={(e) => setCreateForm({ ...createForm, visibility: e.target.value })}
                  className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                >
                  <option value="public">Public</option>
                  <option value="private">Private</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Price</label>
                <input
                  type="number"
                  value={createForm.price}
                  onChange={(e) => setCreateForm({ ...createForm, price: parseFloat(e.target.value) })}
                  className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Tags</label>
                <input
                  type="text"
                  value={createForm.tags}
                  onChange={(e) => setCreateForm({ ...createForm, tags: e.target.value })}
                  className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                  placeholder="Cardiology, Anatomy"
                />
              </div>
            </div>
            <div className="flex gap-3">
              <button type="submit" className="px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark text-sm font-medium">
                Create QBank
              </button>
              <button type="button" onClick={() => setShowCreate(false)} className="px-4 py-2 border border-border rounded-lg text-sm text-gray-600 hover:bg-surface-alt">
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {isLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {[...Array(6)].map((_, i) => (
            <div key={i} className="h-48 bg-gray-100 rounded-xl animate-pulse" />
          ))}
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered?.map((qbank) => (
            <div
              key={qbank.id}
              className="bg-surface rounded-xl border border-border p-5 hover:shadow-md transition-shadow cursor-pointer"
              onClick={() => navigate(`/qbanks/${qbank.id}`)}
            >
              <div className="flex items-start justify-between mb-3">
                <div className="p-2.5 rounded-lg bg-emerald-100">
                  <BookOpen className="h-5 w-5 text-emerald-600" />
                </div>
                <span className={`text-xs px-2 py-0.5 rounded-full border ${
                  qbank.visibility === 'public' ? 'text-green-600 bg-green-50 border-green-200' :
                  'text-red-600 bg-red-50 border-red-200'
                }`}>
                  {qbank.visibility}
                </span>
              </div>
              <h3 className="font-semibold text-gray-900 mb-1 line-clamp-1">{qbank.title}</h3>
              <p className="text-xs text-gray-500 line-clamp-2 mb-3">
                {qbank.description || 'No description'}
              </p>
              <div className="flex items-center justify-between text-xs text-gray-400">
                <span>{qbank.price === 0 ? 'Free' : `$${qbank.price}`}</span>
                <span className="text-primary">{qbank.tags.length} subjects</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
