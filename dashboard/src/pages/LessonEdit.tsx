import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { ArrowLeft, Save, X, Trash2, Video, Search } from 'lucide-react'
import VideoSelector from '../components/VideoSelector'

interface Lesson {
  id: number
  title: string
  description: string
  order: number
  video_id: string | null
  lock_type: string
  is_published: boolean
  quiz_id: number | null
  course_id: number
}

export default function LessonEdit() {
  const { id } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [showSelector, setShowSelector] = useState(false)

  const { data: lesson, isLoading } = useQuery<Lesson>({
    queryKey: ['lesson', id],
    queryFn: () => api.get(`/lessons/${id}`),
  })

  const [form, setForm] = useState<Partial<Lesson>>({})
  const [error, setError] = useState('')

  const updateMutation = useMutation({
    mutationFn: (data: Partial<Lesson>) => api.put(`/lessons/${id}`, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['lesson', id] })
      queryClient.invalidateQueries({ queryKey: ['course-lessons'] })
      navigate(`/lessons/${id}`)
    },
    onError: (err: Error) => setError(err.message),
  })

  const deleteMutation = useMutation({
    mutationFn: () => api.delete(`/lessons/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['course-lessons'] })
      navigate('/courses')
    },
  })

  if (isLoading) return <div className="flex justify-center py-12"><div className="animate-spin h-8 w-8 border-2 border-primary border-t-transparent rounded-full" /></div>
  if (!lesson) return <div className="p-8 text-center text-gray-400">Lesson not found</div>

  const current = { ...lesson, ...form }

  return (
    <div className="space-y-6 max-w-2xl">
      <div className="flex items-center gap-3">
        <button onClick={() => navigate(-1)} className="p-1.5 rounded-lg hover:bg-gray-100 transition-colors">
          <ArrowLeft className="h-5 w-5" />
        </button>
        <h1 className="text-2xl font-bold text-gray-900">Edit Lesson</h1>
      </div>

      {error && <div className="p-3 rounded-lg bg-red-50 border border-red-200 text-red-600 text-sm">{error}</div>}

      <div className="bg-surface rounded-xl border border-border p-6 space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Title</label>
          <input
            type="text"
            value={current.title}
            onChange={(e) => setForm({ ...form, title: e.target.value })}
            className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
          <textarea
            value={current.description || ''}
            onChange={(e) => setForm({ ...form, description: e.target.value })}
            className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 min-h-[80px]"
          />
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Order</label>
            <input
              type="number"
              value={current.order}
              onChange={(e) => setForm({ ...form, order: Number(e.target.value) })}
              className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Attached Video</label>
            <div className="flex items-center gap-2">
              <button
                onClick={() => setShowSelector(true)}
                className="flex-1 flex items-center justify-between gap-2 px-3 py-2 rounded-lg border border-border bg-white text-sm hover:border-primary/50 transition-colors"
              >
                <div className="flex items-center gap-2 text-gray-600 truncate">
                  <Video className="h-4 w-4 shrink-0" />
                  <span className="truncate">{current.video_id ? `ID: ${current.video_id}` : 'No video selected'}</span>
                </div>
                <Search className="h-4 w-4 text-gray-400 shrink-0" />
              </button>
              {current.video_id && (
                <button
                  onClick={() => setForm({ ...form, video_id: null })}
                  className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
                  title="Remove video"
                >
                  <X className="h-4 w-4" />
                </button>
              )}
            </div>
          </div>
        </div>

        {showSelector && (
          <VideoSelector
            selectedId={current.video_id}
            onSelect={(id) => {
              setForm({ ...form, video_id: id })
            }}
            onClose={() => setShowSelector(false)}
          />
        )}

        <div className="grid grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Lock Type</label>
            <select
              value={current.lock_type}
              onChange={(e) => setForm({ ...form, lock_type: e.target.value })}
              className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
            >
              <option value="none">None</option>
              <option value="previous_lesson">Previous Lesson</option>
              <option value="quiz">Quiz Required</option>
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Status</label>
            <select
              value={current.is_published ? 'true' : 'false'}
              onChange={(e) => setForm({ ...form, is_published: e.target.value === 'true' })}
              className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
            >
              <option value="true">Published</option>
              <option value="false">Draft</option>
            </select>
          </div>
        </div>

        <div className="flex items-center justify-between pt-4 border-t border-border">
          <button
            onClick={() => deleteMutation.mutate()}
            className="flex items-center gap-2 px-3 py-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors text-sm"
          >
            <Trash2 className="h-4 w-4" />
            Delete Lesson
          </button>
          <div className="flex gap-3">
            <button onClick={() => navigate(-1)} className="px-4 py-2 border border-border rounded-lg text-sm text-gray-600 hover:bg-surface-alt">
              Cancel
            </button>
            <button
              onClick={() => updateMutation.mutate(form)}
              className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark text-sm font-medium"
            >
              <Save className="h-4 w-4" />
              Save Changes
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
