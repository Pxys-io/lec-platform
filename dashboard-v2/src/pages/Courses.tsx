import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'
import { useToast } from '../toast'
import { useAuth } from '../auth'
import SearchSelect from '../components/SearchSelect'

interface Lesson { id: string; title: string; order: number; video_id: string | null; is_published: boolean; lock_type: string; quiz_id?: string | null }
interface Course { id: string; title: string; description: string; visibility: string; tags: string[]; instructor_id: string }
interface Vid { id: string; title: string; status: string; folder?: string }
interface Quiz { id: string; title: string }
interface Material { id: string; title: string; type: string; url: string }

export default function Courses() {
  const { toast } = useToast()
  const { user } = useAuth()
  const [courses, setCourses] = useState<Course[]>([])
  const [openId, setOpenId] = useState<string | null>(null)
  const [lessons, setLessons] = useState<Lesson[]>([])
  const [videos, setVideos] = useState<Vid[]>([])
  const [quizzes, setQuizzes] = useState<Quiz[]>([])
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    try {
      let list = await api.get<Course[]>('/courses')
      if (user?.role === 'instructor') list = list.filter((c) => c.instructor_id === user.id)
      setCourses(list)
    }
    catch (e) { toast(e instanceof Error ? e.message : 'Load failed', true) }
    finally { setLoading(false) }
  }, [toast, user])
  useEffect(() => {
    load()
    api.get<Vid[]>('/videos/manage').then(setVideos).catch(() => {})
    api.get<Quiz[]>('/quizzes').then(setQuizzes).catch(() => setQuizzes([]))
  }, [load])

  const openCourse = async (id: string) => {
    if (openId === id) { setOpenId(null); return }
    setOpenId(id)
    try { setLessons(await api.get<Lesson[]>(`/courses/${id}/lessons`)) }
    catch (e) { toast(e instanceof Error ? e.message : 'Load lessons failed', true) }
  }

  // create / edit course
  const [cTitle, setCTitle] = useState('')
  const [cDesc, setCDesc] = useState('')
  const [cVis, setCVis] = useState('private')
  const [cTags, setCTags] = useState('')
  const [cOpen, setCOpen] = useState(false)
  const [cEditId, setCEditId] = useState<string | null>(null)
  const openCreate = () => { setCEditId(null); setCTitle(''); setCDesc(''); setCVis('private'); setCTags(''); setCOpen(true) }
  const openEdit = (c: Course) => {
    setCEditId(c.id); setCTitle(c.title); setCDesc(c.description)
    setCVis(c.visibility); setCTags((c.tags || []).join(', ')); setCOpen(true)
  }
  const saveCourse = async () => {
    const payload = { title: cTitle, description: cDesc, visibility: cVis, tags: cTags.split(',').map((t) => t.trim()).filter(Boolean) }
    try {
      if (cEditId) { await api.put(`/courses/${cEditId}`, payload); toast('Course updated') }
      else { await api.post('/courses', { ...payload, thumbnail_url: null }); toast('Course created') }
      setCOpen(false); load()
    } catch (e) { toast(e instanceof Error ? e.message : 'Save failed', true) }
  }

  // create lesson
  const [lTitle, setLTitle] = useState('')
  const [lLock, setLLock] = useState('none')
  const createLesson = async (courseId: string) => {
    if (!lTitle) return
    try {
      await api.post('/lessons', { course_id: courseId, title: lTitle, description: '', order: lessons.length, lock_type: lLock, is_published: false })
      setLTitle(''); toast('Lesson created')
      setLessons(await api.get<Lesson[]>(`/courses/${courseId}/lessons`))
    } catch (e) { toast(e instanceof Error ? e.message : 'Create failed', true) }
  }

  const attachVideo = async (lesson: Lesson, videoId: string) => {
    try {
      await api.put(`/lessons/${lesson.id}`, { video_id: videoId || '', is_published: !!videoId })
      toast(videoId ? 'Video attached & published' : 'Video detached')
      if (openId) setLessons(await api.get<Lesson[]>(`/courses/${openId}/lessons`))
    } catch (e) { toast(e instanceof Error ? e.message : 'Attach failed', true) }
  }

  const attachQuiz = async (lesson: Lesson, quizId: string) => {
    try {
      await api.put(`/lessons/${lesson.id}`, { quiz_id: quizId || '' })
      toast(quizId ? 'Quiz attached' : 'Quiz detached')
      setLessons(lessons.map((l) => l.id === lesson.id ? { ...l, quiz_id: quizId || null } : l))
    } catch (e) { toast(e instanceof Error ? e.message : 'Attach failed', true) }
  }

  // materials
  const [matLesson, setMatLesson] = useState<Lesson | null>(null)
  const [materials, setMaterials] = useState<Material[]>([])
  const [mTitle, setMTitle] = useState('')
  const [mType, setMType] = useState('pdf')
  const [mUrl, setMUrl] = useState('')
  const openMaterials = async (lesson: Lesson) => {
    setMatLesson(lesson); setMTitle(''); setMType('pdf'); setMUrl('')
    try { setMaterials(await api.get<Material[]>(`/lessons/${lesson.id}/materials`)) }
    catch (e) { toast(e instanceof Error ? e.message : 'Load materials failed', true) }
  }
  const addMaterial = async () => {
    if (!mTitle.trim() || !mUrl.trim() || !matLesson) return
    try {
      await api.post(`/lessons/${matLesson.id}/materials`, { title: mTitle.trim(), type: mType, url: mUrl.trim() })
      toast('Material added')
      setMaterials(await api.get<Material[]>(`/lessons/${matLesson.id}/materials`))
      setMTitle(''); setMUrl('')
    } catch (e) { toast(e instanceof Error ? e.message : 'Add failed', true) }
  }
  const delMaterial = async (m: Material) => {
    if (!confirm('Delete this material?')) return
    try { await api.del(`/materials/${m.id}`); setMaterials(materials.filter((x) => x.id !== m.id)); toast('Deleted') }
    catch (e) { toast(e instanceof Error ? e.message : 'Delete failed', true) }
  }

  const updateLesson = async (lesson: Lesson, patch: Partial<Lesson>) => {
    try {
      await api.put(`/lessons/${lesson.id}`, patch)
      setLessons(lessons.map((l) => l.id === lesson.id ? { ...l, ...patch } : l))
    } catch (e) { toast(e instanceof Error ? e.message : 'Update failed', true) }
  }

  const togglePublish = async (lesson: Lesson) => {
    try {
      await api.put(`/lessons/${lesson.id}`, { is_published: !lesson.is_published })
      setLessons(lessons.map((l) => l.id === lesson.id ? { ...l, is_published: !l.is_published } : l))
    } catch (e) { toast(e instanceof Error ? e.message : 'Update failed', true) }
  }

  const deleteCourse = async (c: Course) => {
    if (!confirm(`Delete course "${c.title}"?`)) return
    try { await api.del(`/courses/${c.id}`); toast('Deleted'); if (openId === c.id) setOpenId(null); load() }
    catch (e) { toast(e instanceof Error ? e.message : 'Delete failed', true) }
  }

  const deleteLesson = async (l: Lesson) => {
    if (!confirm('Delete lesson?')) return
    try { await api.del(`/lessons/${l.id}`); setLessons(lessons.filter((x) => x.id !== l.id)); toast('Deleted') }
    catch (e) { toast(e instanceof Error ? e.message : 'Delete failed', true) }
  }

  return (
    <>
      <div className="spread">
        <div><h1>Courses</h1><p className="sub">Manage courses, lessons and video assignments</p></div>
        <button className="btn" onClick={openCreate} data-testid="btn-new-course">＋ New Course</button>
      </div>

      {loading ? <p className="sub">Loading…</p> : (
        <div className="grid" style={{ gap: 10 }}>
          {courses.map((c) => (
            <div className="card" key={c.id} style={{ padding: 0 }} data-testid={`course-${c.title}`}>
              <div className="spread" style={{ padding: '15px 18px', cursor: 'pointer' }} onClick={() => openCourse(c.id)}>
                <div>
                  <b>{c.title}</b>{' '}
                  <span className={`badge ${c.visibility === 'public' ? 'b-green' : 'b-gray'}`}>{c.visibility}</span>
                  <div className="sub" style={{ margin: '4px 0 0' }}>{c.description}</div>
                </div>
                <div className="row" onClick={(e) => e.stopPropagation()}>
                  <button className="btn ghost small" onClick={(e) => { e.stopPropagation(); openCourse(c.id) }}>{openId === c.id ? 'Hide lessons' : 'Lessons'}</button>
                  <button className="btn ghost small" onClick={() => openEdit(c)} data-testid="btn-edit-course">Edit</button>
                  <button className="btn danger small" onClick={() => deleteCourse(c)}>Delete</button>
                </div>
              </div>
              {openId === c.id && (
                <div style={{ padding: '0 18px 18px', borderTop: '1px solid var(--border)' }}>
                  <table>
                    <thead><tr><th>#</th><th>Lesson</th><th>Video</th><th>Lock</th><th>Quiz</th><th>Published</th><th></th></tr></thead>
                    <tbody data-testid="lessons-table">
                      {lessons.map((l) => (
                        <tr key={l.id}>
                          <td>
                            <input type="number" min="0" value={l.order} style={{ width: 62, padding: '5px 8px' }}
                              onChange={(e) => updateLesson(l, { order: +e.target.value })} />
                          </td>
                          <td><b>{l.title}</b></td>
                          <td>
                            <SearchSelect
                              testid={`lesson-video-${l.title}`}
                              options={videos.filter((v) => v.status === 'ready').map((v) => ({ id: v.id, label: v.title || v.id.slice(0, 8), folder: v.folder, hint: v.id.slice(0, 8) }))}
                              value={l.video_id || ''}
                              onChange={(vid) => attachVideo(l, vid)}
                              placeholder="Search videos or folders…"
                            />
                          </td>
                          <td>
                            <select value={l.lock_type} style={{ width: 'auto', padding: '5px 8px' }}
                              onChange={(e) => updateLesson(l, { lock_type: e.target.value })}>
                              <option value="none">Unlocked</option>
                              <option value="previous_lesson">Prev lesson</option>
                              <option value="quiz">Quiz gate</option>
                            </select>
                          </td>
                          <td>
                            <select value={l.quiz_id || ''} style={{ width: 'auto', padding: '5px 8px' }}
                              onChange={(e) => attachQuiz(l, e.target.value)}
                              data-testid={`lesson-quiz-${l.title}`}>
                              <option value="">No quiz</option>
                              {quizzes.map((q) => <option key={q.id} value={q.id}>{q.title}</option>)}
                            </select>
                          </td>
                          <td>
                            <button className={`btn small ${l.is_published ? 'ghost' : ''}`} onClick={() => togglePublish(l)}>
                              {l.is_published ? 'Published' : 'Draft'}
                            </button>
                          </td>
                          <td>
                            <div className="row" style={{ gap: 4 }}>
                              <button className="btn ghost small" onClick={() => openMaterials(l)} data-testid={`lesson-materials-${l.title}`}>Files</button>
                              <button className="btn danger small" onClick={() => deleteLesson(l)}>✕</button>
                            </div>
                          </td>
                        </tr>
                      ))}
                      {lessons.length === 0 && <tr><td colSpan={7} className="sub" style={{ textAlign: 'center' }}>No lessons yet</td></tr>}
                    </tbody>
                  </table>
                  <div className="row" style={{ marginTop: 12 }}>
                    <input placeholder="New lesson title…" value={lTitle} onChange={(e) => setLTitle(e.target.value)} style={{ maxWidth: 280 }}
                      onKeyDown={(e) => e.key === 'Enter' && createLesson(c.id)} data-testid="new-lesson-title" />
                    <select value={lLock} onChange={(e) => setLLock(e.target.value)} style={{ width: 'auto' }}>
                      <option value="none">Unlocked</option>
                      <option value="previous_lesson">Prev lesson lock</option>
                      <option value="quiz">Quiz gate</option>
                    </select>
                    <button className="btn" onClick={() => createLesson(c.id)} data-testid="btn-add-lesson">＋ Add Lesson</button>
                  </div>
                </div>
              )}
            </div>
          ))}
          {courses.length === 0 && <p className="sub">No courses</p>}
        </div>
      )}

      {matLesson && (
        <div className="modal-bg" onClick={(e) => e.target === e.currentTarget && setMatLesson(null)}>
          <div className="modal" style={{ maxWidth: 520 }} data-testid="materials-modal">
            <h3>Materials — {matLesson.title}</h3>
            {materials.length > 0 && (
              <div className="grid" style={{ gap: 8, marginBottom: 12 }}>
                {materials.map((m) => (
                  <div className="card spread" key={m.id} style={{ padding: '10px 14px' }}>
                    <div>
                      <b>{m.title}</b> <span className="badge b-gray">{m.type}</span>
                      <div className="sub"><a href={m.url} target="_blank" rel="noreferrer">{m.url}</a></div>
                    </div>
                    <button className="btn danger small" onClick={() => delMaterial(m)}>✕</button>
                  </div>
                ))}
              </div>
            )}
            {materials.length === 0 && <p className="sub">No materials yet.</p>}
            <div className="field"><label>Title</label><input value={mTitle} onChange={(e) => setMTitle(e.target.value)} data-testid="material-title" /></div>
            <div className="row" style={{ gap: 12 }}>
              <div className="field" style={{ flex: 1 }}><label>Type</label>
                <select value={mType} onChange={(e) => setMType(e.target.value)}>
                  <option value="pdf">PDF</option><option value="document">Document</option>
                  <option value="link">Link</option><option value="image">Image</option>
                </select>
              </div>
              <div className="field" style={{ flex: 2 }}><label>URL</label><input value={mUrl} onChange={(e) => setMUrl(e.target.value)} placeholder="https://…" /></div>
            </div>
            <div className="row" style={{ justifyContent: 'flex-end' }}>
              <button className="btn ghost" onClick={() => setMatLesson(null)}>Close</button>
              <button className="btn" onClick={addMaterial} disabled={!mTitle || !mUrl} data-testid="material-add">＋ Add</button>
            </div>
          </div>
        </div>
      )}

      {cOpen && (
        <div className="modal-bg" onClick={(e) => e.target === e.currentTarget && setCOpen(false)}>
          <div className="modal" data-testid="course-modal">
            <h3>{cEditId ? 'Edit Course' : 'New Course'}</h3>
            <div className="field"><label>Title</label><input value={cTitle} onChange={(e) => setCTitle(e.target.value)} data-testid="course-title" /></div>
            <div className="field"><label>Description</label><textarea rows={2} value={cDesc} onChange={(e) => setCDesc(e.target.value)} /></div>
            <div className="field"><label>Tags (comma separated)</label><input value={cTags} onChange={(e) => setCTags(e.target.value)} placeholder="math, beginner" /></div>
            <div className="field"><label>Visibility</label>
              <select value={cVis} onChange={(e) => setCVis(e.target.value)}>
                <option value="private">Private</option><option value="public">Public</option><option value="restricted">Restricted</option>
              </select>
            </div>
            <div className="row" style={{ justifyContent: 'flex-end' }}>
              <button className="btn ghost" onClick={() => setCOpen(false)}>Cancel</button>
              <button className="btn" onClick={saveCourse} disabled={!cTitle} data-testid="course-create">{cEditId ? 'Save changes' : 'Create'}</button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
