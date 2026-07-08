import { useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { Search, Plus, HelpCircle, Eye, Trash2 } from 'lucide-react'
import { useState } from 'react'

interface Quiz {
  id: number
  title: string
  description: string
  lesson_id: number
  passing_score: number
  time_limit: number | null
  lesson_title?: string
}

interface Lesson {
  id: number
  title: string
}

export default function Quizzes() {
  const navigate = useNavigate()
  const { isInstructor } = useAuth()
  const queryClient = useQueryClient()
  const [search, setSearch] = useState('')

  const { data: quizzes, isLoading } = useQuery<Quiz[]>({
    queryKey: ['quizzes'],
    queryFn: async () => {
      const courses = await api.get<any[]>('/courses')
      const allQuizzes: Quiz[] = []
      for (const c of courses) {
        const lessons = await api.get<Lesson[]>('/courses/' + c.id + '/lessons')
        for (const l of lessons) {
          if (l.id) {
            try {
              const q = await api.get<Quiz>(`/quizzes/${l.id}`).catch(() => null)
              if (q) allQuizzes.push({ ...q, lesson_title: l.title })
            } catch {}
          }
        }
      }
      return allQuizzes
    },
    enabled: isInstructor,
  })

  const deleteMutation = useMutation({
    mutationFn: (id: number) => api.delete(`/quizzes/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['quizzes'] }),
  })

  const filtered = quizzes?.filter((q) =>
    q.title.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Quizzes</h1>
          <p className="text-sm text-gray-500 mt-1">Manage quizzes and assessments</p>
        </div>
        {isInstructor && (
          <button
            onClick={() => navigate('/quizzes/new')}
            className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark transition-colors text-sm font-medium"
          >
            <Plus className="h-4 w-4" />
            New Quiz
          </button>
        )}
      </div>

      <div className="relative max-w-sm">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full pl-10 pr-4 py-2 rounded-lg border border-border bg-surface text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
          placeholder="Search quizzes..."
        />
      </div>

      {isLoading ? (
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
                  <p className="text-xs text-gray-500 mt-0.5">{quiz.lesson_title || `Lesson #${quiz.lesson_id}`}</p>
                </div>
                <div className="flex items-center gap-3 shrink-0">
                  <span className="text-xs text-gray-500">Pass: {quiz.passing_score}%</span>
                  {quiz.time_limit && <span className="text-xs text-gray-500">{quiz.time_limit}min</span>}
                  <button
                    onClick={(e) => {
                      e.stopPropagation()
                      navigate(`/quizzes/${quiz.id}`)
                    }}
                    className="p-1.5 rounded-lg text-primary hover:bg-primary/5 transition-colors"
                  >
                    <Eye className="h-4 w-4" />
                  </button>
                  <button
                    onClick={(e) => {
                      e.stopPropagation()
                      deleteMutation.mutate(quiz.id)
                    }}
                    className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors"
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
