import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { Plus, Trash2, ArrowLeft, HelpCircle, GripVertical } from 'lucide-react'

interface Question {
  id?: number
  type: string
  question: string
  options: string[]
  correct_answer: string
  points: number
  order: number
}

interface QuizData {
  id: number
  title: string
  description: string
  lesson_id: number
  passing_score: number
  time_limit: number | null
}

interface Lesson {
  id: number
  title: string
  course_id: number
}

export default function QuizBuilder() {
  const { id } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const isEditing = !!id

  const [quiz, setQuiz] = useState({
    title: '',
    description: '',
    lesson_id: '',
    passing_score: 70,
    time_limit: '',
  })
  const [questions, setQuestions] = useState<Question[]>([])
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)

  const { data: courses } = useQuery<any[]>({
    queryKey: ['courses'],
    queryFn: () => api.get('/courses'),
  })

  const [lessons, setLessons] = useState<Lesson[]>([])

  useEffect(() => {
    if (isEditing && id) {
      api.get<QuizData>(`/quizzes/${id}`).then((q) => {
        setQuiz({
          title: q.title,
          description: q.description || '',
          lesson_id: String(q.lesson_id),
          passing_score: q.passing_score,
          time_limit: q.time_limit ? String(q.time_limit) : '',
        })
        api.get<Question[]>(`/quizzes/${id}/questions`).then((qs) => {
          setQuestions(qs.sort((a, b) => a.order - b.order))
        })
      })
    }
  }, [isEditing, id])

  const loadLessons = async (courseId: string) => {
    if (!courseId) return
    const ls = await api.get<Lesson[]>(`/courses/${courseId}/lessons`)
    setLessons(ls)
  }

  const addQuestion = () => {
    setQuestions([
      ...questions,
      { type: 'multiple_choice', question: '', options: ['', '', '', ''], correct_answer: '0', points: 1, order: questions.length + 1 },
    ])
  }

  const updateQuestion = (index: number, updates: Partial<Question>) => {
    const updated = [...questions]
    updated[index] = { ...updated[index], ...updates }
    setQuestions(updated)
  }

  const removeQuestion = (index: number) => {
    setQuestions(questions.filter((_, i) => i !== index).map((q, i) => ({ ...q, order: i + 1 })))
  }

  const save = async () => {
    setSaving(true)
    setError('')
    try {
      let quizId: number
      if (isEditing && id) {
        await api.put(`/quizzes/${id}`, {
          title: quiz.title,
          description: quiz.description,
          lesson_id: Number(quiz.lesson_id),
          passing_score: quiz.passing_score,
          time_limit: quiz.time_limit ? Number(quiz.time_limit) : null,
        })
        quizId = Number(id)
      } else {
        const created = await api.post<QuizData>('/quizzes', {
          title: quiz.title,
          description: quiz.description,
          lesson_id: Number(quiz.lesson_id),
          passing_score: quiz.passing_score,
          time_limit: quiz.time_limit ? Number(quiz.time_limit) : null,
        })
        quizId = created.id
      }

      for (const q of questions) {
        if (q.id) {
          await api.put(`/quizzes/${quizId}/questions/${q.id}`, q)
        } else {
          await api.post(`/quizzes/${quizId}/questions`, q)
        }
      }

      queryClient.invalidateQueries({ queryKey: ['quizzes'] })
      navigate('/quizzes')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save quiz')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="space-y-6 max-w-4xl">
      <button
        onClick={() => navigate('/quizzes')}
        className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700 transition-colors"
      >
        <ArrowLeft className="h-4 w-4" />
        Back to Quizzes
      </button>

      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">{isEditing ? 'Edit Quiz' : 'Create Quiz'}</h1>
        <button
          onClick={save}
          disabled={saving}
          className="px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark transition-colors text-sm font-medium disabled:opacity-50"
        >
          {saving ? 'Saving...' : 'Save Quiz'}
        </button>
      </div>

      {error && (
        <div className="p-3 rounded-lg bg-red-50 border border-red-200 text-red-600 text-sm">{error}</div>
      )}

      <div className="bg-surface rounded-xl border border-border p-6 space-y-4">
        <h2 className="text-sm font-semibold text-gray-900">Quiz Details</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-1">Title *</label>
            <input
              type="text"
              value={quiz.title}
              onChange={(e) => setQuiz({ ...quiz, title: e.target.value })}
              className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
              required
            />
          </div>
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-1">Description</label>
            <textarea
              value={quiz.description}
              onChange={(e) => setQuiz({ ...quiz, description: e.target.value })}
              className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Course</label>
            <select
              value={quiz.lesson_id ? lessons.find((l) => l.id === Number(quiz.lesson_id))?.course_id || '' : ''}
              onChange={(e) => loadLessons(e.target.value)}
              className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
            >
              <option value="">Select course</option>
              {courses?.map((c: any) => (
                <option key={c.id} value={c.id}>{c.title}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Lesson *</label>
            <select
              value={quiz.lesson_id}
              onChange={(e) => setQuiz({ ...quiz, lesson_id: e.target.value })}
              className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
              required
            >
              <option value="">Select lesson</option>
              {lessons.map((l) => (
                <option key={l.id} value={l.id}>{l.title}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Passing Score (%)</label>
            <input
              type="number"
              value={quiz.passing_score}
              onChange={(e) => setQuiz({ ...quiz, passing_score: Number(e.target.value) })}
              className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Time Limit (minutes, optional)</label>
            <input
              type="number"
              value={quiz.time_limit}
              onChange={(e) => setQuiz({ ...quiz, time_limit: e.target.value })}
              className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
            />
          </div>
        </div>
      </div>

      <div className="bg-surface rounded-xl border border-border p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-sm font-semibold text-gray-900">Questions ({questions.length})</h2>
          <button
            onClick={addQuestion}
            className="flex items-center gap-2 px-3 py-1.5 border border-border rounded-lg text-sm text-gray-600 hover:bg-surface-alt transition-colors"
          >
            <Plus className="h-4 w-4" />
            Add Question
          </button>
        </div>

        {questions.length === 0 ? (
          <div className="p-8 text-center text-sm text-gray-400">
            <HelpCircle className="h-8 w-8 mx-auto mb-2 text-gray-300" />
            No questions yet. Click "Add Question" to start building your quiz.
          </div>
        ) : (
          <div className="space-y-4">
            {questions.map((q, i) => (
              <div key={i} className="border border-border rounded-lg p-4">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-sm font-medium text-gray-700">Question {i + 1}</span>
                  <button
                    onClick={() => removeQuestion(i)}
                    className="p-1 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>

                <div className="space-y-3">
                  <div className="flex gap-3">
                    <div className="flex-1">
                      <label className="block text-xs font-medium text-gray-500 mb-1">Question Text *</label>
                      <input
                        type="text"
                        value={q.question}
                        onChange={(e) => updateQuestion(i, { question: e.target.value })}
                        className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                        placeholder="Enter your question..."
                      />
                    </div>
                    <div className="w-24">
                      <label className="block text-xs font-medium text-gray-500 mb-1">Points</label>
                      <input
                        type="number"
                        value={q.points}
                        onChange={(e) => updateQuestion(i, { points: Number(e.target.value) })}
                        className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs font-medium text-gray-500 mb-1">Options</label>
                    {q.options.map((opt, oi) => (
                      <div key={oi} className="flex items-center gap-2 mb-1.5">
                        <input
                          type="radio"
                          name={`correct-${i}`}
                          checked={q.correct_answer === String(oi)}
                          onChange={() => updateQuestion(i, { correct_answer: String(oi) })}
                          className="accent-primary"
                        />
                        <input
                          type="text"
                          value={opt}
                          onChange={(e) => {
                            const opts = [...q.options]
                            opts[oi] = e.target.value
                            updateQuestion(i, { options: opts })
                          }}
                          className="flex-1 px-3 py-1.5 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                          placeholder={`Option ${oi + 1}`}
                        />
                        {q.correct_answer === String(oi) && (
                          <span className="text-xs text-green-600 font-medium">Correct</span>
                        )}
                      </div>
                    ))}
                    <p className="text-xs text-gray-400 mt-1">Select the radio button next to the correct answer</p>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
