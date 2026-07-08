import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { Search, Plus, BookOpen, MoreHorizontal, Eye, Trash2 } from 'lucide-react'

interface Course {
  id: number
  title: string
  description: string
  instructor_id: number
  visibility: string
  tags: unknown
  thumbnail_url: string | null
  created_at: string
}

export default function Courses() {
  const navigate = useNavigate()
  const { isInstructor } = useAuth()
  const queryClient = useQueryClient()
  const [search, setSearch] = useState('')
  const [showCreate, setShowCreate] = useState(false)
  const [createForm, setCreateForm] = useState({ title: '', description: '', visibility: 'public', tags: '' })
  const [createError, setCreateError] = useState('')

  const { data: courses, isLoading } = useQuery<Course[]>({
    queryKey: ['courses'],
    queryFn: () => api.get('/courses'),
  })

  const createMutation = useMutation({
    mutationFn: (data: typeof createForm) =>
      api.post('/courses', {
        ...data,
        tags: data.tags ? JSON.stringify(data.tags.split(',').map((t: string) => t.trim())) : '[]',
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['courses'] })
      setShowCreate(false)
      setCreateForm({ title: '', description: '', visibility: 'public', tags: '' })
      setCreateError('')
    },
    onError: (err: Error) => setCreateError(err.message),
  })

  const deleteMutation = useMutation({
    mutationFn: (id: number) => api.delete(`/courses/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['courses'] }),
  })

  const filtered = courses?.filter((c) =>
    c.title.toLowerCase().includes(search.toLowerCase())
  )

  const getTags = (tags: unknown): string[] => {
    if (!tags) return []
    if (Array.isArray(tags)) return tags as string[]
    if (typeof tags === 'string') {
      if (tags === '[]' || tags.trim() === '') return []
      try {
        const parsed = JSON.parse(tags)
        if (Array.isArray(parsed)) return parsed as string[]
      } catch {}
      return tags.split(',').map((t: string) => t.trim()).filter((t: string) => t.length > 0)
    }
    return []
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Courses</h1>
          <p className="text-sm text-gray-500 mt-1">Manage courses and content</p>
        </div>
        {isInstructor && (
          <button
            onClick={() => setShowCreate(true)}
            className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark transition-colors text-sm font-medium"
          >
            <Plus className="h-4 w-4" />
            New Course
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
          placeholder="Search courses..."
        />
      </div>

      {showCreate && (
        <div className="bg-surface rounded-xl border border-border p-6">
          <h2 className="text-lg font-semibold mb-4">Create New Course</h2>
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
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Visibility</label>
                <select
                  value={createForm.visibility}
                  onChange={(e) => setCreateForm({ ...createForm, visibility: e.target.value })}
                  className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                >
                  <option value="public">Public</option>
                  <option value="private">Private</option>
                  <option value="unlisted">Unlisted</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Tags (comma separated)</label>
                <input
                  type="text"
                  value={createForm.tags}
                  onChange={(e) => setCreateForm({ ...createForm, tags: e.target.value })}
                  className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                  placeholder="math, science"
                />
              </div>
            </div>
            <div className="flex gap-3">
              <button type="submit" className="px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark text-sm font-medium">
                Create Course
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
          {filtered?.map((course) => (
            <div
              key={course.id}
              className="bg-surface rounded-xl border border-border p-5 hover:shadow-md transition-shadow cursor-pointer"
              onClick={() => navigate(`/courses/${course.id}`)}
            >
              <div className="flex items-start justify-between mb-3">
                <div className="p-2.5 rounded-lg bg-violet-100">
                  <BookOpen className="h-5 w-5 text-violet-600" />
                </div>
                <span className={`text-xs px-2 py-0.5 rounded-full border ${
                  course.visibility === 'public' ? 'text-green-600 bg-green-50 border-green-200' :
                  course.visibility === 'private' ? 'text-red-600 bg-red-50 border-red-200' :
                  'text-gray-600 bg-gray-50 border-gray-200'
                }`}>
                  {course.visibility}
                </span>
              </div>
              <h3 className="font-semibold text-gray-900 mb-1 line-clamp-1">{course.title}</h3>
              <p className="text-xs text-gray-500 line-clamp-2 mb-3">
                {course.description || 'No description'}
              </p>
              <div className="flex items-center justify-between text-xs text-gray-400">
                <span>{new Date(course.created_at).toLocaleDateString()}</span>
                {getTags(course.tags).length > 0 && (
                  <span className="text-primary">{getTags(course.tags).length} tags</span>
                )}
              </div>
            </div>
          ))}
          {filtered?.length === 0 && (
            <div className="col-span-full p-8 text-center text-sm text-gray-400">
              No courses found. {isInstructor && 'Create your first course!'}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
