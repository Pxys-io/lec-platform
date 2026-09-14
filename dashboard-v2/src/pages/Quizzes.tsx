import { useCallback, useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { api } from '../api'
import { useToast } from '../toast'

interface Quiz {
  id: string
  title: string
  lesson_id: string | null
  lesson_title: string | null
  course_title: string | null
  passing_score: number
  time_limit: number | null
  questions_count: number
  created_at: string
}

export default function Quizzes() {
  const { toast } = useToast()
  const nav = useNavigate()
  const [quizzes, setQuizzes] = useState<Quiz[]>([])
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    setLoading(true)
    try { setQuizzes(await api.get<Quiz[]>('/quizzes')) }
    catch (e) { toast(e instanceof Error ? e.message : 'Load failed', true) }
    finally { setLoading(false) }
  }, [toast])
  useEffect(() => { load() }, [load])

  const del = async (q: Quiz) => {
    if (!confirm(`Delete quiz "${q.title}"? This detaches it from its lesson.`)) return
    try { await api.del(`/quizzes/${q.id}`); toast('Quiz deleted'); load() }
    catch (e) { toast(e instanceof Error ? e.message : 'Delete failed', true) }
  }

  const filtered = quizzes.filter((q) =>
    q.title.toLowerCase().includes(search.toLowerCase()) ||
    (q.course_title || '').toLowerCase().includes(search.toLowerCase()) ||
    (q.lesson_title || '').toLowerCase().includes(search.toLowerCase())
  )

  return (
    <>
      <div className="spread">
        <div><h1>Quizzes</h1><p className="sub">Manage quizzes and assessments</p></div>
        <button className="btn" onClick={() => nav('/quizzes/new')} data-testid="btn-new-quiz">＋ New Quiz</button>
      </div>

      <input
        placeholder="Search quizzes, lessons, courses…"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{ maxWidth: 360, marginBottom: 14 }}
        data-testid="quiz-search"
      />

      {loading ? <p className="sub">Loading…</p> : (
        <div className="grid" style={{ gap: 10 }}>
          {filtered.map((q) => (
            <div className="card spread" key={q.id} style={{ padding: '14px 18px' }} data-testid={`quiz-${q.title}`}>
              <div>
                <b>{q.title}</b>{' '}
                <span className="badge b-blue">{q.questions_count} questions</span>{' '}
                <span className="badge b-gray">Pass {q.passing_score}%</span>
                {q.time_limit != null && <span className="badge b-gray">{q.time_limit}min</span>}
                <div className="sub" style={{ margin: '4px 0 0' }}>
                  {[q.course_title, q.lesson_title].filter(Boolean).join('  •  ') || 'Detached (no lesson)'}
                </div>
              </div>
              <div className="row">
                <button className="btn ghost small" onClick={() => nav(`/quizzes/${q.id}`)}>Edit</button>
                <button className="btn danger small" onClick={() => del(q)}>Delete</button>
              </div>
            </div>
          ))}
          {filtered.length === 0 && <p className="sub">No quizzes found</p>}
        </div>
      )}
    </>
  )
}