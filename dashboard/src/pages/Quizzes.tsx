import { useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { Search, Plus, HelpCircle, Eye, Trash2, AlertTriangle, RefreshCw } from 'lucide-react'
import { useState } from 'react'

interface Quiz {
  id: string
  title: string
  description: string | null
  lesson_id: string | null
  lesson_title: string | null
  course_id: string | null
  course_title: string | null
  passing_score: number
  time_limit: number | null
  questions_count: number
  created_at: string
}

export default function Quizzes() {
  const navigate = useNavigate()
  const { isInstructor } = useAuth()
  const queryClient = useQueryClient()
  const [search, setSearch] = useState('')

  const { data: quizzes, isLoading, isError, error, refetch } = useQuery<Quiz[]>({
    queryKey: ['quizzes'],
    queryFn: () => api.get('/quizzes'),
    enabled: isInstructor,
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/quizzes/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['quizzes'] }),
  })

  const filtered = quizzes?.filter((q) =>
    q.title.toLowerCase().includes(search.toLowerCase()) ||
    (q.course_title || '').toLowerCase().includes(search.toLowerCase()) ||
    (q.lesson_title || '').toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Quizzes</h1>
          <p className="text-sm text-gray-500 mt-1">Manage quizzes and assessments</p>
        </div>
        {isInstructor && (
          <div className="flex items-center gap-2">
            <button
              onClick={() => refetch()}
              className="flex items-center gap-2 px-3 py-2 border border-border rounded-lg text-sm hover:bg-surface-alt transition-colors"
            >
              <RefreshCw className="h-4 w-4" />
              Refresh
            </button>
            <button
              onClick={() => navigate('/quizzes/new')}
              className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark transition-colors text-sm font-medium"
            >
              <Plus className="h-4 w-4" />
              New Quiz
            </button>
          </div>
        )}
      </div>

      <div className="relative max-w-sm">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full pl-10 pr-4 py-2 rounded-lg border border-border bg-surface text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
          placeholder="Search quizzes, lessons, courses..."
        />
      </div>

      {isError ? (
        <div className="p-8 text-center">
          <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-red-100 mb-4">
            <AlertTriangle className="h-6 w-6 text-red-600" />
          </div>
          <h3 className="text-sm font-semibold text-gray-900 mb-1">Failed to load quizzes</h3>
          <p className="text-sm text-gray-500 mb-4">{(error as Error)?.message || 'An unexpected error occurred'}</p>
          <button
            onClick={() => refetch()}
            className="inline-flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium hover:bg-primary-dark transition-colors"
          >
            <RefreshCw className="h-4 w-4" />
            Retry
          </button>
        </div>
      ) : isLoading ? (
        <div className="space-y-2">
          {[...Array(3)].map((_, i) => <div key={i} className="h-16 bg-gray-100 rounded-xl animate-pulse" />)}
        </div>
      ) : (
        <div className="space-y-2">
          {filtered?.map((quiz) => (
            <div
              key={quiz.id}
              className="bg-surface rounded-xl border border-border p-4 hover:shadow-sm transition-shadow cursor-pointer"
              onClick={() => navigate(`/quizzes/${quiz.id}`)}
            >
              <div className="flex items-center gap-4">
                <div className="p-2.5 rounded-lg bg-orange-100">
                  <HelpCircle className="h-5 w-5 text-orange-600" />
                </div>
                <div className="flex-1 min-w-0">
                  <h3 className="font-medium text-gray-900 text-sm">{quiz.title}</h3>
                  <p className="text-xs text-gray-500 mt-0.5 truncate">
                    {[quiz.course_title, quiz.lesson_title].filter(Boolean).join('  •  ') || 'Detached quiz (no lesson)'}
                  </p>
                </div>
                <div className="flex items-center gap-3 shrink-0">
                  <span className="text-xs px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 border border-blue-200">
                    {quiz.questions_count} questions
                  </span>
                  <span className="text-xs text-gray-500">Pass: {quiz.passing_score}%</span>
                  {quiz.time_limit != null && <span className="text-xs text-gray-500">{quiz.time_limit}min</span>}
                  <button
                    onClick={(e) => {
                      e.stopPropagation()
                      navigate(`/quizzes/${quiz.id}`)
                    }}
                    className="p-1.5 rounded-lg text-primary hover:bg-primary/5 transition-colors"
                    title="Edit"
                  >
                    <Eye className="h-4 w-4" />
                  </button>
                  <button
                    onClick={(e) => {
                      e.stopPropagation()
                      if (confirm(`Delete quiz "${quiz.title}"? This detaches it from its lesson.`)) {
                        deleteMutation.mutate(quiz.id)
                      }
                    }}
                    className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors"
                    title="Delete"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              </div>
            </div>
          ))}
          {filtered?.length === 0 && (
            <div className="p-8 text-center text-sm text-gray-400">No quizzes found</div>
          )}
        </div>
      )}
    </div>
  )
}
