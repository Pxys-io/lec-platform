import { useCallback, useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { api } from '../api'
import { useToast } from '../toast'

interface Question {
  id?: string
  question: string
  options: string[]
  correct_answer: string
  explanation: string
  points: number
  order: number
}
interface Course { id: string; title: string }
interface Lesson { id: string; title: string; course_id: string; quiz_id: string | null }

const blankQuestion = (order: number): Question => ({
  question: '', options: ['', '', '', ''], correct_answer: '',
  explanation: '', points: 1, order,
})

export default function QuizBuilder() {
  const { id } = useParams()
  const nav = useNavigate()
  const { toast } = useToast()
  const isEditing = !!id && id !== 'new'

  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [passing, setPassing] = useState(70)
  const [timeLimit, setTimeLimit] = useState('')
  const [courseId, setCourseId] = useState('')
  const [lessonId, setLessonId] = useState('')
  const [questions, setQuestions] = useState<Question[]>([])
  const [deletedIds, setDeletedIds] = useState<string[]>([])
  const [courses, setCourses] = useState<Course[]>([])
  const [lessons, setLessons] = useState<Lesson[]>([])
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)
  const [loading, setLoading] = useState(isEditing)

  useEffect(() => {
    api.get<Course[]>('/courses').then(setCourses).catch(() => setCourses([]))
  }, [])

  const loadLessons = useCallback(async (cid: string) => {
    if (!cid) { setLessons([]); return }
    try { setLessons(await api.get<Lesson[]>(`/courses/${cid}/lessons`)) }
    catch { setLessons([]) }
  }, [])

  // Edit mode: load quiz + questions, resolve lesson -> course.
  useEffect(() => {
    if (!isEditing) return
    setLoading(true)
    api.get<any>(`/quizzes/${id}`).then(async (q) => {
      setTitle(q.title)
      setDescription(q.description || '')
      setPassing(q.passing_score)
      setTimeLimit(q.time_limit != null ? String(q.time_limit) : '')
      setLessonId(q.lesson_id || '')
      const qs = await api.get<Question[]>(`/quizzes/${id}/questions`)
      setQuestions(qs.sort((a, b) => a.order - b.order).map((x) => ({
        ...x, explanation: x.explanation || '', options: x.options?.length ? x.options : ['', ''],
      })))
      if (q.lesson_id) {
        try {
          const lesson = await api.get<Lesson>(`/lessons/${q.lesson_id}`)
          setCourseId(lesson.course_id)
          await loadLessons(lesson.course_id)
        } catch { /* lesson deleted; keep detached */ }
      }
    }).catch((e: Error) => setError(e.message)).finally(() => setLoading(false))
  }, [isEditing, id, loadLessons])

  const addQuestion = () => setQuestions([...questions, blankQuestion(questions.length + 1)])
  const updateQuestion = (i: number, patch: Partial<Question>) =>
    setQuestions(questions.map((q, qi) => qi === i ? { ...q, ...patch } : q))

  const updateOption = (qi: number, oi: number, text: string) => {
    const q = questions[qi]
    const old = q.options[oi]
    const options = [...q.options]
    options[oi] = text
    // Keep the correct radio glued to the text, not the position.
    updateQuestion(qi, { options, correct_answer: q.correct_answer === old ? text : q.correct_answer })
  }
  const removeOption = (qi: number, oi: number) => {
    const q = questions[qi]
    if (q.options.length <= 2) return
    const removed = q.options[oi]
    updateQuestion(qi, {
      options: q.options.filter((_, i) => i !== oi),
      correct_answer: q.correct_answer === removed ? '' : q.correct_answer,
    })
  }
  const removeQuestion = (i: number) => {
    const q = questions[i]
    if (q.id) setDeletedIds((ids) => [...ids, q.id as string])
    setQuestions(questions.filter((_, qi) => qi !== i).map((x, qi) => ({ ...x, order: qi + 1 })))
  }

  const validate = (): string | null => {
    if (!title.trim()) return 'Quiz title is required.'
    if (!isEditing && !lessonId) return 'Pick the lesson this quiz belongs to.'
    if (passing < 0 || passing > 100) return 'Passing score must be between 0 and 100.'
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i]
      if (!q.question.trim()) return `Question ${i + 1}: text is required.`
      const filled = q.options.map((o) => o.trim()).filter(Boolean)
      if (filled.length < 2) return `Question ${i + 1}: needs at least 2 non-empty options.`
      if (!q.correct_answer.trim()) return `Question ${i + 1}: select the correct answer.`
      if (!filled.includes(q.correct_answer.trim())) return `Question ${i + 1}: correct answer must match an option.`
      if (!(q.points > 0)) return `Question ${i + 1}: points must be positive.`
    }
    return null
  }

  const save = async () => {
    const problem = validate()
    if (problem) { setError(problem); return }
    setSaving(true); setError('')
    try {
      let qid: string
      if (isEditing) {
        await api.put(`/quizzes/${id}`, {
          title: title.trim(), description: description.trim() || null,
          passing_score: Number(passing), time_limit: timeLimit === '' ? null : Number(timeLimit),
        })
        qid = id as string
      } else {
        const created = await api.post<any>('/quizzes', {
          title: title.trim(), description: description.trim() || null, lesson_id: lessonId,
          passing_score: Number(passing), time_limit: timeLimit === '' ? null : Number(timeLimit),
        })
        qid = created.id
      }
      for (const delId of deletedIds) await api.del(`/quizzes/${qid}/questions/${delId}`)
      for (const q of questions) {
        const payload = {
          type: 'multiple_choice', question: q.question.trim(),
          options: q.options.map((o) => o.trim()).filter(Boolean),
          correct_answer: q.correct_answer.trim(),
          explanation: q.explanation.trim() || null,
          points: Number(q.points), order: q.order,
        }
        if (q.id) await api.put(`/quizzes/${qid}/questions/${q.id}`, payload)
        else await api.post(`/quizzes/${qid}/questions`, payload)
      }
      toast('Quiz saved')
      nav('/quizzes')
    } catch (e) { setError(e instanceof Error ? e.message : 'Failed to save quiz') }
    finally { setSaving(false) }
  }

  if (loading) return <p className="sub">Loading quiz…</p>

  return (
    <>
      <div className="spread">
        <div>
          <h1>{isEditing ? 'Edit Quiz' : 'Create Quiz'}</h1>
          <p className="sub">Questions are graded by exact answer text</p>
        </div>
        <div className="row">
          <button className="btn ghost" onClick={() => nav('/quizzes')}>Back</button>
          <button className="btn" onClick={save} disabled={saving} data-testid="btn-save-quiz">
            {saving ? 'Saving…' : 'Save Quiz'}
          </button>
        </div>
      </div>

      {error && <div className="error-box">{error}</div>}

      <div className="card" style={{ padding: 18 }}>
        <h3 style={{ margin: '0 0 12px' }}>Quiz Details</h3>
        <div className="row" style={{ alignItems: 'flex-start', flexWrap: 'wrap', gap: 12 }}>
          <div style={{ flex: '2 1 260px' }}>
            <label className="sub" style={{ display: 'block', marginBottom: 4 }}>Title *</label>
            <input value={title} onChange={(e) => setTitle(e.target.value)} data-testid="quiz-title" />
          </div>
          <div style={{ flex: '1 1 180px' }}>
            <label className="sub" style={{ display: 'block', marginBottom: 4 }}>Passing score (%)</label>
            <input type="number" min={0} max={100} value={passing} onChange={(e) => setPassing(Number(e.target.value))} />
          </div>
          <div style={{ flex: '1 1 180px' }}>
            <label className="sub" style={{ display: 'block', marginBottom: 4 }}>Time limit (min, optional)</label>
            <input type="number" min={0} value={timeLimit} onChange={(e) => setTimeLimit(e.target.value)} />
          </div>
        </div>
        <div className="row" style={{ alignItems: 'flex-start', flexWrap: 'wrap', gap: 12, marginTop: 12 }}>
          <div style={{ flex: '1 1 220px' }}>
            <label className="sub" style={{ display: 'block', marginBottom: 4 }}>Course</label>
            <select
              value={courseId}
              disabled={isEditing}
              onChange={(e) => { setCourseId(e.target.value); setLessonId(''); loadLessons(e.target.value) }}
              data-testid="quiz-course"
            >
              <option value="">Select course</option>
              {courses.map((c) => <option key={c.id} value={c.id}>{c.title}</option>)}
            </select>
          </div>
          <div style={{ flex: '1 1 220px' }}>
            <label className="sub" style={{ display: 'block', marginBottom: 4 }}>Lesson *</label>
            <select value={lessonId} disabled={isEditing} onChange={(e) => setLessonId(e.target.value)} data-testid="quiz-lesson">
              <option value="">Select lesson</option>
              {lessons.map((l) => <option key={l.id} value={l.id}>{l.title}{l.quiz_id ? ' (has quiz)' : ''}</option>)}
            </select>
          </div>
        </div>
        <div style={{ marginTop: 12 }}>
          <label className="sub" style={{ display: 'block', marginBottom: 4 }}>Description</label>
          <textarea rows={2} value={description} onChange={(e) => setDescription(e.target.value)} />
        </div>
      </div>

      <div className="card" style={{ padding: 18, marginTop: 14 }}>
        <div className="spread">
          <h3 style={{ margin: 0 }}>Questions ({questions.length})</h3>
          <button className="btn ghost" onClick={addQuestion} data-testid="btn-add-question">＋ Add Question</button>
        </div>

        {questions.length === 0 ? (
          <p className="sub" style={{ textAlign: 'center', padding: '24px 0' }}>No questions yet.</p>
        ) : (
          <div className="grid" style={{ gap: 12, marginTop: 14 }}>
            {questions.map((q, i) => (
              <div className="card" key={q.id || `new-${i}`} style={{ padding: 14 }}>
                <div className="spread">
                  <b>Question {i + 1}</b>
                  <button className="btn danger small" onClick={() => removeQuestion(i)}>✕</button>
                </div>
                <div className="row" style={{ alignItems: 'flex-start', gap: 12, marginTop: 10 }}>
                  <div style={{ flex: 1 }}>
                    <label className="sub" style={{ display: 'block', marginBottom: 4 }}>Question text *</label>
                    <input value={q.question} onChange={(e) => updateQuestion(i, { question: e.target.value })} placeholder="Enter your question…" />
                  </div>
                  <div style={{ width: 90 }}>
                    <label className="sub" style={{ display: 'block', marginBottom: 4 }}>Points</label>
                    <input type="number" min={0} step="0.5" value={q.points} onChange={(e) => updateQuestion(i, { points: Number(e.target.value) })} />
                  </div>
                </div>
                <div style={{ marginTop: 10 }}>
                  <label className="sub" style={{ display: 'block', marginBottom: 4 }}>Options (radio = correct)</label>
                  {q.options.map((opt, oi) => (
                    <div className="row" key={oi} style={{ marginBottom: 6 }}>
                      <input
                        type="radio"
                        name={`correct-${q.id || `new-${i}`}`}
                        checked={q.correct_answer !== '' && q.correct_answer === opt && opt.trim() !== ''}
                        onChange={() => updateQuestion(i, { correct_answer: opt })}
                        title="Mark as correct"
                      />
                      <input
                        value={opt}
                        onChange={(e) => updateOption(i, oi, e.target.value)}
                        placeholder={`Option ${oi + 1}`}
                        style={{ flex: 1 }}
                      />
                      {q.options.length > 2 && (
                        <button className="btn danger small" onClick={() => removeOption(i, oi)} title="Remove option">✕</button>
                      )}
                      {q.correct_answer !== '' && q.correct_answer === opt && <span className="badge b-green">Correct</span>}
                    </div>
                  ))}
                  <button className="btn ghost small" onClick={() => updateQuestion(i, { options: [...q.options, ''] })}>＋ Add option</button>
                </div>
                <div style={{ marginTop: 10 }}>
                  <label className="sub" style={{ display: 'block', marginBottom: 4 }}>Explanation (shown after answering)</label>
                  <input value={q.explanation} onChange={(e) => updateQuestion(i, { explanation: e.target.value })} placeholder="Why is this right?" />
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </>
  )
}