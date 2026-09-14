import { useCallback, useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { api } from '../api'
import { useToast } from '../toast'

interface QBank { id: string; title: string; description: string; visibility: string; tags: string[]; price: number }
interface Question { id: string; question: string; options: string[]; correct_answer: string; explanation: string | null; points: number; order: number }
interface Enrollment { id: string; qbank_id: string; user_id: string; status: string; created_at: string }

export default function QBankDetail() {
  const { id } = useParams()
  const { toast } = useToast()
  const nav = useNavigate()
  const [qbank, setQbank] = useState<QBank | null>(null)
  const [questions, setQuestions] = useState<Question[]>([])
  const [enrollments, setEnrollments] = useState<Enrollment[]>([])
  const [loading, setLoading] = useState(true)

  // question editor state
  const [qOpen, setQOpen] = useState(false)
  const [qEditId, setQEditId] = useState<string | null>(null)
  const [qText, setQText] = useState('')
  const [qOptions, setQOptions] = useState<string[]>(['', '', '', ''])
  const [qCorrect, setQCorrect] = useState('')
  const [qExplain, setQExplain] = useState('')
  const [qPoints, setQPoints] = useState(1)

  const load = useCallback(async () => {
    try {
      const [qb, qs, es] = await Promise.all([
        api.get<QBank>(`/qbanks/${id}`),
        api.get<Question[]>(`/qbanks/${id}/questions`),
        api.get<Enrollment[]>('/qbanks/enrollments/all'),
      ])
      setQbank(qb)
      setQuestions(qs.sort((a, b) => a.order - b.order))
      setEnrollments(es.filter((e) => e.qbank_id === id))
    } catch (e) { toast(e instanceof Error ? e.message : 'Load failed', true) }
    finally { setLoading(false) }
  }, [id, toast])
  useEffect(() => { load() }, [load])

  const openNew = () => {
    setQEditId(null); setQText(''); setQOptions(['', '', '', '']); setQCorrect(''); setQExplain(''); setQPoints(1); setQOpen(true)
  }
  const openEdit = (q: Question) => {
    setQEditId(q.id); setQText(q.question); setQOptions(q.options?.length ? q.options : ['', ''])
    setQCorrect(q.correct_answer); setQExplain(q.explanation || ''); setQPoints(q.points); setQOpen(true)
  }
  const saveQuestion = async () => {
    if (!qText.trim()) return
    const filled = qOptions.map((o) => o.trim()).filter(Boolean)
    if (filled.length < 2) { toast('Needs at least 2 non-empty options', true); return }
    if (!qCorrect.trim() || !filled.includes(qCorrect.trim())) { toast('Pick the correct answer from the options', true); return }
    const payload = {
      type: 'multiple_choice', question: qText.trim(), options: filled,
      correct_answer: qCorrect.trim(), explanation: qExplain.trim() || null,
      points: qPoints, tags: qbank?.tags || [], order: qEditId ? (questions.find((x) => x.id === qEditId)?.order ?? questions.length + 1) : questions.length + 1,
    }
    try {
      if (qEditId) { await api.put(`/qbanks/${id}/questions/${qEditId}`, payload); toast('Question updated') }
      else { await api.post(`/qbanks/${id}/questions`, payload); toast('Question added') }
      setQOpen(false); load()
    } catch (e) { toast(e instanceof Error ? e.message : 'Save failed', true) }
  }
  const delQuestion = async (q: Question) => {
    if (!confirm('Delete this question?')) return
    try { await api.del(`/qbanks/questions/${q.id}`); toast('Deleted'); load() }
    catch (e) { toast(e instanceof Error ? e.message : 'Delete failed', true) }
  }

  const setEnrollmentStatus = async (en: Enrollment, status: 'approved' | 'rejected') => {
    if (!confirm(`${status === 'approved' ? 'Approve' : 'Reject'} this enrollment?`)) return
    try {
      await api.post(`/qbanks/enrollments/${en.id}/${status}`)
      toast(status === 'approved' ? 'Enrollment approved' : 'Enrollment rejected')
      load()
    } catch (e) { toast(e instanceof Error ? e.message : 'Update failed', true) }
  }

  if (loading) return <p className="sub">Loading…</p>
  if (!qbank) return <p className="sub">QBank not found</p>

  return (
    <>
      <div className="spread">
        <div>
          <h1>{qbank.title}</h1>
          <p className="sub">{qbank.description || 'No description'}{qbank.tags.length > 0 && ` — ${qbank.tags.join(', ')}`}</p>
        </div>
        <button className="btn ghost" onClick={() => nav('/qbanks')}>← Back</button>
      </div>

      <div className="card" style={{ padding: 18, marginTop: 12 }}>
        <div className="spread">
          <h3 style={{ margin: 0 }}>Questions ({questions.length})</h3>
          <button className="btn" onClick={openNew} data-testid="btn-add-qbank-question">＋ Add Question</button>
        </div>
        {questions.length === 0 ? <p className="sub" style={{ textAlign: 'center', padding: '20px 0' }}>No questions yet.</p> : (
          <div className="grid" style={{ gap: 10, marginTop: 12 }}>
            {questions.map((q, i) => (
              <div className="card" key={q.id} style={{ padding: 12 }}>
                <div className="spread">
                  <div>
                    <b>Q{i + 1}. {q.question}</b>
                    <div className="sub">Correct: {q.correct_answer}{q.points !== 1 && ` • ${q.points} pts`}</div>
                    {q.explanation && <div className="sub">💡 {q.explanation}</div>}
                  </div>
                  <div className="row">
                    <button className="btn ghost small" onClick={() => openEdit(q)}>Edit</button>
                    <button className="btn danger small" onClick={() => delQuestion(q)}>✕</button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="card" style={{ padding: 18, marginTop: 14 }}>
        <h3 style={{ margin: '0 0 12px' }}>Enrollments ({enrollments.length})</h3>
        {enrollments.length === 0 ? <p className="sub">No enrollment requests yet.</p> : (
          <table>
            <thead><tr><th>User</th><th>Status</th><th>Requested</th><th></th></tr></thead>
            <tbody>
              {enrollments.map((en) => (
                <tr key={en.id}>
                  <td><span className="mono">{en.user_id.slice(0, 12)}…</span></td>
                  <td><span className={`badge ${en.status === 'approved' ? 'b-green' : en.status === 'rejected' ? 'b-red' : 'b-yellow'}`}>{en.status}</span></td>
                  <td>{new Date(en.created_at).toLocaleDateString()}</td>
                  <td>
                    {en.status === 'pending' && (
                      <div className="row">
                        <button className="btn small" onClick={() => setEnrollmentStatus(en, 'approved')}>Approve</button>
                        <button className="btn danger small" onClick={() => setEnrollmentStatus(en, 'rejected')}>Reject</button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {qOpen && (
        <div className="modal-bg" onClick={(e) => e.target === e.currentTarget && setQOpen(false)}>
          <div className="modal" data-testid="qbank-question-modal">
            <h3>{qEditId ? 'Edit Question' : 'New Question'}</h3>
            <div className="field"><label>Question text *</label><input value={qText} onChange={(e) => setQText(e.target.value)} /></div>
            <div className="field">
              <label>Options (radio = correct) *</label>
              {qOptions.map((opt, oi) => (
                <div className="row" key={oi} style={{ marginBottom: 6 }}>
                  <input type="radio" name="qcorrect" checked={qCorrect !== '' && qCorrect === opt && opt.trim() !== ''}
                    onChange={() => setQCorrect(opt)} title="Mark as correct" />
                  <input value={opt} onChange={(e) => {
                    const next = [...qOptions]; const old = opt; next[oi] = e.target.value
                    setQOptions(next)
                    if (qCorrect === old) setQCorrect(e.target.value)
                  }} placeholder={`Option ${oi + 1}`} style={{ flex: 1 }} />
                  {qOptions.length > 2 && <button className="btn danger small" onClick={() => {
                    const next = qOptions.filter((_, i) => i !== oi)
                    setQOptions(next)
                  }}>✕</button>}
                </div>
              ))}
              <button className="btn ghost small" onClick={() => setQOptions([...qOptions, ''])}>＋ Add option</button>
            </div>
            <div className="row" style={{ gap: 12 }}>
              <div className="field" style={{ flex: 1 }}><label>Points</label>
                <input type="number" min={0.5} step={0.5} value={qPoints} onChange={(e) => setQPoints(Number(e.target.value))} />
              </div>
            </div>
            <div className="field"><label>Explanation</label><input value={qExplain} onChange={(e) => setQExplain(e.target.value)} /></div>
            <div className="row" style={{ justifyContent: 'flex-end' }}>
              <button className="btn ghost" onClick={() => setQOpen(false)}>Cancel</button>
              <button className="btn" onClick={saveQuestion} disabled={!qText} data-testid="qbank-question-save">{qEditId ? 'Save changes' : 'Add'}</button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}