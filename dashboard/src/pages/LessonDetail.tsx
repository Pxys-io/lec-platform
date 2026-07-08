import { useParams, useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { api } from '../lib/api'
import { ArrowLeft, HelpCircle, Paperclip, MessageSquare, Edit3 } from 'lucide-react'

interface Lesson {
  id: number
  title: string
  description: string
  order: number
  lock_type: string
  is_published: boolean
  video_id: string | null
  quiz_id: number | null
  course_id: number
}

interface Material {
  id: number
  title: string
  type: string
  url: string
}

interface Comment {
  id: number
  content: string
  created_at: string
  user?: { email: string }
}

interface Quiz {
  id: number
  title: string
  passing_score: number
  time_limit: number | null
}

export default function LessonDetail() {
  const { id } = useParams()
  const navigate = useNavigate()

  const { data: lesson, isLoading } = useQuery<Lesson>({
    queryKey: ['lesson', id],
    queryFn: () => api.get(`/lessons/${id}`),
  })

  const { data: materials } = useQuery<Material[]>({
    queryKey: ['lesson-materials', id],
    queryFn: () => api.get(`/lessons/${id}/materials`),
  })

  const { data: comments } = useQuery<Comment[]>({
    queryKey: ['lesson-comments', id],
    queryFn: () => api.get(`/lessons/${id}/comments`),
  })

  const { data: quiz } = useQuery({
    queryKey: ['lesson-quiz', id, lesson?.quiz_id],
    queryFn: () => api.get<Quiz>(`/quizzes/${lesson!.quiz_id}`),
    enabled: !!lesson?.quiz_id,
  })

  if (isLoading) return <div className="flex justify-center py-12"><div className="animate-spin h-8 w-8 border-2 border-primary border-t-transparent rounded-full" /></div>
  if (!lesson) return <div className="p-8 text-center text-gray-400">Lesson not found</div>

  return (
    <div className="space-y-6 max-w-3xl">
      <button
        onClick={() => navigate(`/courses/${lesson.course_id}`)}
        className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700 transition-colors"
      >
        <ArrowLeft className="h-4 w-4" />
        Back to Course
      </button>

      <div className="bg-surface rounded-xl border border-border p-6">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">{lesson.title}</h1>
            {!lesson.is_published && (
              <span className="text-xs px-2 py-0.5 rounded bg-yellow-100 text-yellow-700 ml-2">Draft</span>
            )}
          </div>
          <button
            onClick={() => navigate(`/lessons/${lesson.id}/edit`)}
            className="flex items-center gap-2 px-3 py-1.5 border border-border rounded-lg text-sm hover:bg-surface-alt transition-colors"
          >
            <Edit3 className="h-4 w-4" />
            Edit
          </button>
        </div>
        <p className="text-sm text-gray-500">{lesson.description || 'No description'}</p>
        <div className="flex gap-4 mt-4 text-xs text-gray-400">
          <span>Order: {lesson.order}</span>
          {lesson.lock_type !== 'none' && <span>Lock: {lesson.lock_type}</span>}
          {lesson.video_id && <span>Video ID: {lesson.video_id}</span>}
        </div>
      </div>

      {quiz && (
        <div
          className="bg-surface rounded-xl border border-border p-5 hover:shadow-sm transition-shadow cursor-pointer"
          onClick={() => navigate(`/quizzes/${quiz.id}`)}
        >
          <div className="flex items-center gap-3">
            <div className="p-2.5 rounded-lg bg-orange-100">
              <HelpCircle className="h-5 w-5 text-orange-600" />
            </div>
            <div className="flex-1">
              <h3 className="font-medium text-gray-900 text-sm">{quiz.title}</h3>
              <p className="text-xs text-gray-500">Passing score: {quiz.passing_score}%{quiz.time_limit ? ` | Time limit: ${quiz.time_limit} min` : ''}</p>
            </div>
          </div>
        </div>
      )}

      {materials && materials.length > 0 && (
        <div className="bg-surface rounded-xl border border-border p-5">
          <h3 className="text-sm font-semibold text-gray-900 mb-3 flex items-center gap-2">
            <Paperclip className="h-4 w-4" /> Materials ({materials.length})
          </h3>
          <div className="space-y-2">
            {materials.map((m) => (
              <div key={m.id} className="flex items-center justify-between p-2.5 rounded-lg bg-surface-alt border border-border">
                <div>
                  <p className="text-sm font-medium text-gray-900">{m.title}</p>
                  <p className="text-xs text-gray-500">{m.type}</p>
                </div>
                <a href={m.url} target="_blank" rel="noreferrer" className="text-xs text-primary hover:underline">Open</a>
              </div>
            ))}
          </div>
        </div>
      )}

      {comments && comments.length > 0 && (
        <div className="bg-surface rounded-xl border border-border p-5">
          <h3 className="text-sm font-semibold text-gray-900 mb-3 flex items-center gap-2">
            <MessageSquare className="h-4 w-4" /> Comments ({comments.length})
          </h3>
          <div className="space-y-3">
            {comments.slice(0, 5).map((c) => (
              <div key={c.id} className="p-3 rounded-lg bg-surface-alt border border-border">
                <div className="flex items-center justify-between mb-1">
                  <span className="text-xs font-medium text-gray-700">{c.user?.email || 'Unknown'}</span>
                  <span className="text-xs text-gray-400">{new Date(c.created_at).toLocaleDateString()}</span>
                </div>
                <p className="text-sm text-gray-600">{c.content}</p>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
