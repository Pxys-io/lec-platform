import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'
import { useToast } from '../toast'

interface Lesson { id: string; title: string; order: number; video_id: string | null; is_published: boolean; lock_type: string }
interface Course { id: string; title: string; description: string; visibility: string; tags: string[]; instructor_id: string }
interface Vid { id: string; title: string; status: string }

export default function Courses() {
  const { toast } = useToast()
  const [courses, setCourses] = useState<Course[]>([])
  const [openId, setOpenId] = useState<string | null>(null)
  const [lessons, setLessons] = useState<Lesson[]>([])
  const [videos, setVideos] = useState<Vid[]>([])
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    try { setCourses(await api.get<Course[]>('/courses')) }
    catch (e) { toast(e instanceof Error ? e.message : 'Load failed', true) }
    finally { setLoading(false) }
  }, [toast])
  useEffect(() => { load(); api.get<Vid[]>('/videos/manage').then(setVideos).catch(() => {}) }, [load])

  const openCourse = async (id: string) => {
    if (openId === id) { setOpenId(null); return }
    setOpenId(id)
    try { setLessons(await api.get<Lesson[]>(`/courses/${id}/lessons`)) }
    catch (e) { toast(e instanceof Error ? e.message : 'Load lessons failed', true) }
  }

  // create course
  const [cTitle, setCTitle] = useState('')
  const [cDesc, setCDesc] = useState('')
  const [cVis, setCVis] = useState('private')
  const [cTags, setCTags] = useState('')
  const [cOpen, setCOpen] = useState(false)
  const createCourse = async () => {
    try {
      await api.post('/courses', { title: cTitle, description: cDesc, visibility: cVis, tags: cTags.split(',').map((t) => t.trim()).filter(Boolean), thumbnail_url: null })
      toast('Course created'); setCOpen(false); setCTitle(''); setCDesc(''); load()
    } catch (e) { toast(e instanceof Error ? e.message : 'Create failed', true) }
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
      await api.put(`/lessons/${lesson.id}`, { video_id: videoId || null, is_published: !!videoId })
      toast(videoId ? 'Video attached & published' : 'Video detached')
      setLessons(await api.get<Lesson[]>(`/courses/${lesson.id ? courses.find((c) => c.id === openId)?.id : ''}/lessons`))
    } catch (e) { toast(e instanceof Error ? e.message : 'Attach failed', true) }
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
        <button className="btn" onClick={() => setCOpen(true)} data-testid="btn-new-course">＋ New Course</button>
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
                  <button className="btn ghost small" onClick={() => setCOpen(false) /* noop */}>{openId === c.id ? 'Hide' : 'Lessons'}</button>
                  <button className="btn danger small" onClick={() => deleteCourse(c)}>Delete</button>
                </div>
              </div>
              {openId === c.id && (
                <div style={{ padding: '0 18px 18px', borderTop: '1px solid var(--border)' }}>
                  <table>
                    <thead><tr><th>#</th><th>Lesson</th><th>Video</th><th>Lock</th><th>Published</th><th></th></tr></thead>
                    <tbody data-testid="lessons-table">
                      {lessons.map((l) => (
                        <tr key={l.id}>
                          <td>
                            <input type="number" min="0" value={l.order} style={{ width: 62, padding: '5px 8px' }}
                              onChange={(e) => updateLesson(l, { order: +e.target.value })} />
                          </td>
                          <td><b>{l.title}</b></td>
                          <td>
                            <select
                              value={l.video_id || ''}
                              onChange={(e) => attachVideo(l, e.target.value)}
                              style={{ minWidth: 220 }}
                              data-testid={`lesson-video-${l.title}`}
                            >
                              <option value="">— none —</option>
                              {videos.filter((v) => v.status === 'ready').map((v) => (
                                <option key={v.id} value={v.id}>{v.title} ({v.id.slice(0, 8)})</option>
                              ))}
                            </select>
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
                            <button className={`btn small ${l.is_published ? 'ghost' : ''}`} onClick={() => togglePublish(l)}>
                              {l.is_published ? 'Published' : 'Draft'}
                            </button>
                          </td>
                          <td><button className="btn danger small" onClick={() => deleteLesson(l)}>✕</button></td>
                        </tr>
                      ))}
                      {lessons.length === 0 && <tr><td colSpan={6} className="sub" style={{ textAlign: 'center' }}>No lessons yet</td></tr>}
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

      {cOpen && (
        <div className="modal-bg" onClick={(e) => e.target === e.currentTarget && setCOpen(false)}>
          <div className="modal" data-testid="course-modal">
            <h3>New Course</h3>
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
              <button className="btn" onClick={createCourse} disabled={!cTitle} data-testid="course-create">Create</button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
