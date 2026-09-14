import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { ArrowLeft, Save, X, Trash2, Video, Search, HelpCircle } from 'lucide-react'
import VideoSelector from '../components/VideoSelector'
import MaterialManager from '../components/MaterialManager'

interface Lesson {
  id: string
  title: string
  description: string | null
  order: number
  video_id: string | null
  lock_type: string
  is_published: boolean
  quiz_id: string | null
  course_id: string
}

interface QuizOption {
  id: string
  title: string
  lesson_id: string | null
  lesson_title: string | null
  passing_score: number
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
  const [savingGate, setSavingGate] = useState(false)

  const { data: quizzes } = useQuery<QuizOption[]>({
    queryKey: ['quizzes'],
    queryFn: () => api.get('/quizzes'),
  })

  // Quiz gate draft: the quiz attached to THIS lesson plus its minimum
  // passing score. A FOLLOWING lesson with lock "Quiz Required" unlocks only
  // when the student passes this quiz at the threshold below.
  const [gateQuizId, setGateQuizId] = useState<string | undefined>(undefined)
  const [gatePassing, setGatePassing] = useState<number | undefined>(undefined)

  useEffect(() => {
    if (lesson && quizzes && gateQuizId === undefined) {
      setGateQuizId(lesson.quiz_id || '')
      const q = quizzes.find((x) => x.id === (lesson.quiz_id || ''))
      setGatePassing(q ? q.passing_score : 70)
    }
  }, [lesson, quizzes, gateQuizId])

  const linkedQuiz = quizzes?.find((q) => q.id === (gateQuizId || undefined))

  const handleSave = async () => {
    setError('')
    setSavingGate(true)
    try {
      const payload: Record<string, unknown> = { ...form }
      // Backend clears attachments with "" (null is ignored).
      if (payload.video_id === null) payload.video_id = ''
      // Include the quiz-gate link when it changed ("" unlinks).
      if (gateQuizId !== undefined && gateQuizId !== (lesson?.quiz_id || '')) {
        payload.quiz_id = gateQuizId
      }
      const saved = await api.put<Lesson>(`/lessons/${id}`, payload)
      const effectiveQuizId = (payload.quiz_id as string | undefined) ?? saved.quiz_id
      if (effectiveQuizId && gatePassing !== undefined) {
        const q = quizzes?.find((x) => x.id === effectiveQuizId)
        if (q && gatePassing !== q.passing_score) {
          await api.put(`/quizzes/${effectiveQuizId}`, { passing_score: gatePassing })
        }
      }
      queryClient.invalidateQueries({ queryKey: ['lesson', id] })
      queryClient.invalidateQueries({ queryKey: ['course-lessons'] })
      queryClient.invalidateQueries({ queryKey: ['quizzes'] })
      navigate(`/lessons/${id}`)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save lesson')
    } finally {
      setSavingGate(false)
    }
  }

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
      </div>

      <div className="bg-surface rounded-xl border border-border p-6 space-y-4">
        <div className="flex items-center gap-2">
          <HelpCircle className="h-4 w-4 text-orange-500" />
          <h2 className="text-sm font-semibold text-gray-900">Quiz Gate</h2>
          </div>
          <p className="text-xs text-gray-500">
            Attach a quiz to this lesson. A <span className="font-medium">following</span> lesson set to
            “Quiz Required” unlocks only when the student passes this quiz at the minimum score below.
          </p>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Attached Quiz</label>
              <select
                value={gateQuizId ?? ''}
                onChange={(e) => {
                  const v = e.target.value
                  setGateQuizId(v)
                  const q = quizzes?.find((x) => x.id === v)
                  setGatePassing(q ? q.passing_score : 70)
                }}
                className="w-full px-3 py-2 rounded-lg border border-border text-sm bg-white focus:outline-none focus:ring-2 focus:ring-primary/50"
              >
                <option value="">No quiz (no gate)</option>
                {quizzes?.map((q) => (
                  <option key={q.id} value={q.id}>
                    {q.title}{q.lesson_id && q.lesson_id !== lesson.id ? ` (on: ${q.lesson_title || 'another lesson'})` : ''} — pass {q.passing_score}%
                  </option>
                ))}
              </select>
              {gateQuizId !== '' && linkedQuiz?.lesson_id && linkedQuiz.lesson_id !== lesson.id && (
                <p className="text-[11px] text-amber-600 mt-1">Saving will move this quiz here from “{linkedQuiz.lesson_title || 'another lesson'}”.</p>
              )}
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Minimum Passing Score (%)</label>
              <input
                type="number"
                min={0}
                max={100}
                value={gatePassing ?? 70}
                disabled={!gateQuizId}
                onChange={(e) => setGatePassing(Number(e.target.value))}
                className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 disabled:bg-gray-50 disabled:text-gray-400"
              />
              <p className="text-[11px] text-gray-400 mt-1">Applies immediately, including to past attempts.</p>
            </div>
          </div>
          {gateQuizId !== '' && (
            <button
              onClick={() => navigate(`/quizzes/${gateQuizId}`)}
              className="text-xs text-primary hover:underline"
            >
              Open quiz in Quiz Builder →
            </button>
          )}
      </div>

      {id && <MaterialManager lessonId={String(id)} />}

      <div className="flex items-center justify-between pt-4">
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
            onClick={handleSave}
            disabled={savingGate}
            className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark text-sm font-medium disabled:opacity-50"
          >
            <Save className="h-4 w-4" />
            {savingGate ? 'Saving...' : 'Save Changes'}
          </button>
        </div>
      </div>
    </div>
  )
}
