import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { Plus, Trash2, ArrowLeft, HelpCircle, Loader2 } from 'lucide-react'

interface Question {
  id?: string
  type: string
  question: string
  options: string[]
  correct_answer: string
  explanation: string
  points: number
  order: number
}

interface QuizData {
  id: string
  title: string
  description: string | null
  lesson_id: string | null
  passing_score: number
  time_limit: number | null
}

interface Lesson {
  id: string
  title: string
  course_id: string
  quiz_id: string | null
}

interface Course {
  id: string
  title: string
}

const blankQuestion = (order: number): Question => ({
  type: 'multiple_choice',
  question: '',
  options: ['', '', '', ''],
  correct_answer: '',
  explanation: '',
  points: 1,
  order,
})

export default function QuizBuilder() {
  const { id } = useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const isEditing = !!id && id !== 'new'
  const quizId = isEditing ? (id as string) : null

  const [quiz, setQuiz] = useState({
    title: '',
    description: '',
    lesson_id: '',
    passing_score: 70,
    time_limit: '',
  })
  const [activeCourseId, setActiveCourseId] = useState('')
  const [questions, setQuestions] = useState<Question[]>([])
  const [deletedQuestionIds, setDeletedQuestionIds] = useState<string[]>([])
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)
  const [loading, setLoading] = useState(isEditing)

  const { data: courses } = useQuery<Course[]>({
    queryKey: ['courses'],
    queryFn: () => api.get('/courses'),
  })

  const [lessons, setLessons] = useState<Lesson[]>([])

  const loadLessons = async (courseId: string) => {
    if (!courseId) {
      setLessons([])
      return []
    }
    const ls = await api.get<Lesson[]>(`/courses/${courseId}/lessons`)
    setLessons(ls)
    return ls
  }

  // Edit mode: load quiz + questions, then resolve lesson -> course -> lessons
  // so both dropdowns show the current assignment.
  useEffect(() => {
    if (!isEditing || !quizId) return
    setLoading(true)
    api.get<QuizData>(`/quizzes/${quizId}`).then(async (q) => {
      setQuiz({
        title: q.title,
        description: q.description || '',
        lesson_id: q.lesson_id || '',
        passing_score: q.passing_score,
        time_limit: q.time_limit != null ? String(q.time_limit) : '',
      })
      const qs = await api.get<Question[]>(`/quizzes/${quizId}/questions`)
      setQuestions(
        qs
          .sort((a, b) => a.order - b.order)
          .map((x) => ({ ...x, explanation: x.explanation || '', options: x.options?.length ? x.options : ['', ''] }))
      )
      if (q.lesson_id) {
        try {
          const lesson = await api.get<Lesson>(`/lessons/${q.lesson_id}`)
          setActiveCourseId(lesson.course_id)
          await loadLessons(lesson.course_id)
        } catch {
          // lesson may have been deleted; keep quiz detached-editable
        }
      }
    }).catch((e: Error) => setError(e.message))
      .finally(() => setLoading(false))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isEditing, quizId])

  const addQuestion = () => {
    setQuestions([...questions, blankQuestion(questions.length + 1)])
  }

  const updateQuestion = (index: number, updates: Partial<Question>) => {
    const updated = [...questions]
    updated[index] = { ...updated[index], ...updates }
    setQuestions(updated)
  }

  const updateOptionText = (qi: number, oi: number, text: string) => {
    const q = questions[qi]
    const old = q.options[oi]
    const opts = [...q.options]
    opts[oi] = text
    // Keep the "correct" radio glued to the text, not the position.
    const correct = q.correct_answer === old ? text : q.correct_answer
    updateQuestion(qi, { options: opts, correct_answer: correct })
  }

  const removeOption = (qi: number, oi: number) => {
    const q = questions[qi]
    if (q.options.length <= 2) return
    const removed = q.options[oi]
    const opts = q.options.filter((_, i) => i !== oi)
    updateQuestion(qi, {
      options: opts,
      correct_answer: q.correct_answer === removed ? '' : q.correct_answer,
    })
  }

  const removeQuestion = (index: number) => {
    const q = questions[index]
    if (q.id) setDeletedQuestionIds((ids) => [...ids, q.id as string])
    setQuestions(questions.filter((_, i) => i !== index).map((x, i) => ({ ...x, order: i + 1 })))
  }

  const validate = (): string | null => {
    if (!quiz.title.trim()) return 'Quiz title is required.'
    if (!isEditing && !quiz.lesson_id) return 'Pick the lesson this quiz belongs to.'
    if (quiz.passing_score < 0 || quiz.passing_score > 100) return 'Passing score must be between 0 and 100.'
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i]
      if (!q.question.trim()) return `Question ${i + 1}: text is required.`
      const filled = q.options.map((o) => o.trim()).filter(Boolean)
      if (filled.length < 2) return `Question ${i + 1}: needs at least 2 non-empty options.`
      if (!q.correct_answer.trim()) return `Question ${i + 1}: select the correct answer.`
      if (!filled.includes(q.correct_answer.trim())) return `Question ${i + 1}: correct answer must match one of the options.`
      if (!(q.points > 0)) return `Question ${i + 1}: points must be positive.`
    }
    return null
  }

  const save = async () => {
    const problem = validate()
    if (problem) {
      setError(problem)
      return
    }
    setSaving(true)
    setError('')
    try {
      let qid: string
      if (isEditing && quizId) {
        await api.put(`/quizzes/${quizId}`, {
          title: quiz.title.trim(),
          description: quiz.description.trim() || null,
          passing_score: Number(quiz.passing_score),
          time_limit: quiz.time_limit === '' ? null : Number(quiz.time_limit),
        })
        qid = quizId
      } else {
        const created = await api.post<QuizData>('/quizzes', {
          title: quiz.title.trim(),
          description: quiz.description.trim() || null,
          lesson_id: quiz.lesson_id,
          passing_score: Number(quiz.passing_score),
          time_limit: quiz.time_limit === '' ? null : Number(quiz.time_limit),
        })
        qid = created.id
      }

      for (const delId of deletedQuestionIds) {
        await api.delete(`/quizzes/${qid}/questions/${delId}`)
      }

      for (const q of questions) {
        const payload = {
          type: 'multiple_choice',
          question: q.question.trim(),
          options: q.options.map((o) => o.trim()).filter(Boolean),
          correct_answer: q.correct_answer.trim(),
          explanation: q.explanation.trim() || null,
          points: Number(q.points),
          order: q.order,
        }
        if (q.id) {
          await api.put(`/quizzes/${qid}/questions/${q.id}`, payload)
        } else {
          await api.post(`/quizzes/${qid}/questions`, payload)
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

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center py-16 gap-3">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
        <p className="text-sm text-gray-500">Loading quiz...</p>
      </div>
    )
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
              value={activeCourseId}
              onChange={(e) => {
                setActiveCourseId(e.target.value)
                setQuiz({ ...quiz, lesson_id: '' })
                loadLessons(e.target.value)
              }}
              disabled={isEditing}
              className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 disabled:bg-gray-50 disabled:text-gray-400"
            >
              <option value="">Select course</option>
              {courses?.map((c) => (
                <option key={c.id} value={c.id}>{c.title}</option>
              ))}
            </select>
            {isEditing && <p className="text-[11px] text-gray-400 mt-1">Move the quiz between lessons from the Lessons page.</p>}
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Lesson *</label>
            <select
              value={quiz.lesson_id}
              onChange={(e) => setQuiz({ ...quiz, lesson_id: e.target.value })}
              disabled={isEditing}
              className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50 disabled:bg-gray-50 disabled:text-gray-400"
              required
            >
              <option value="">Select lesson</option>
              {lessons.map((l) => (
                <option key={l.id} value={l.id}>
                  {l.title}{l.quiz_id ? ' (has quiz)' : ''}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Passing Score (%)</label>
            <input
              type="number"
              min={0}
              max={100}
              value={quiz.passing_score}
              onChange={(e) => setQuiz({ ...quiz, passing_score: Number(e.target.value) })}
              className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
            />
            <p className="text-[11px] text-gray-400 mt-1">Takes effect immediately, including for past attempts.</p>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Time Limit (minutes, optional)</label>
            <input
              type="number"
              min={0}
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
              <div key={q.id || `new-${i}`} className="border border-border rounded-lg p-4">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-sm font-medium text-gray-700">Question {i + 1}</span>
                  <button
                    onClick={() => removeQuestion(i)}
                    className="p-1 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors"
                    title={q.id ? 'Delete (saved on Save Quiz)' : 'Remove'}
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
                        min={0}
                        step="0.5"
                        value={q.points}
                        onChange={(e) => updateQuestion(i, { points: Number(e.target.value) })}
                        className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs font-medium text-gray-500 mb-1">Options (radio = correct answer)</label>
                    {q.options.map((opt, oi) => (
                      <div key={oi} className="flex items-center gap-2 mb-1.5">
                        <input
                          type="radio"
                          name={`correct-${q.id || `new-${i}`}`}
                          checked={q.correct_answer !== '' && q.correct_answer === opt && opt.trim() !== ''}
                          onChange={() => updateQuestion(i, { correct_answer: opt })}
                          className="accent-primary"
                          title="Mark as correct answer"
                        />
                        <input
                          type="text"
                          value={opt}
                          onChange={(e) => updateOptionText(i, oi, e.target.value)}
                          className="flex-1 px-3 py-1.5 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                          placeholder={`Option ${oi + 1}`}
                        />
                        {q.options.length > 2 && (
                          <button
                            onClick={() => removeOption(i, oi)}
                            className="text-xs text-gray-400 hover:text-red-500 px-1"
                            title="Remove option"
                          >
                            ✕
                          </button>
                        )}
                        {q.correct_answer !== '' && q.correct_answer === opt && (
                          <span className="text-xs text-green-600 font-medium">Correct</span>
                        )}
                      </div>
                    ))}
                    <button
                      onClick={() => updateQuestion(i, { options: [...q.options, ''] })}
                      className="text-xs text-primary hover:underline mt-1"
                    >
                      + Add option
                    </button>
                  </div>

                  <div>
                    <label className="block text-xs font-medium text-gray-500 mb-1">Explanation (shown after answering)</label>
                    <input
                      type="text"
                      value={q.explanation}
                      onChange={(e) => updateQuestion(i, { explanation: e.target.value })}
                      className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                      placeholder="Why is this the right answer?"
                    />
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
