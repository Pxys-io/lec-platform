import { useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { useAuth } from '../lib/auth'
import { api } from '../lib/api'
import { Search, FileText, Eye } from 'lucide-react'
import { useState } from 'react'

interface Lesson {
  id: number
  title: string
  description: string
  course_id: number
  order: number
  is_published: boolean
}

interface Course {
  id: number
  title: string
}

export default function Lessons() {
  const navigate = useNavigate()
  const { isInstructor } = useAuth()
  const [search, setSearch] = useState('')

  const { data: lessons, isLoading } = useQuery<Lesson[]>({
    queryKey: ['all-lessons'],
    queryFn: async () => {
      const courses = await api.get<Course[]>('/courses')
      const allLessons = await Promise.all(
        courses.map((c) => api.get<Lesson[]>(`/courses/${c.id}/lessons`).then((ls) => ls.map((l) => ({ ...l, course_title: c.title }))))
      )
      return allLessons.flat()
    },
    enabled: isInstructor,
  })

  const filtered = lessons?.filter((l) =>
    l.title.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Lessons</h1>
        <p className="text-sm text-gray-500 mt-1">View all lessons across courses</p>
      </div>

      <div className="relative max-w-sm">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full pl-10 pr-4 py-2 rounded-lg border border-border bg-surface text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
          placeholder="Search lessons..."
        />
      </div>

      {isLoading ? (
        <div className="space-y-2">
          {[...Array(5)].map((_, i) => <div key={i} className="h-16 bg-gray-100 rounded-xl animate-pulse" />)}
        </div>
      ) : (
        <div className="bg-surface rounded-xl border border-border overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-border bg-surface-alt">
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Lesson</th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Course</th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Order</th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered?.map((lesson) => (
                <tr key={lesson.id} className="border-b border-border last:border-0 hover:bg-surface-alt/50 transition-colors">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-3">
                      <div className="p-2 rounded-lg bg-emerald-100">
                        <FileText className="h-4 w-4 text-emerald-600" />
                      </div>
                      <div>
                        <p className="text-sm font-medium text-gray-900">{lesson.title}</p>
                        <p className="text-xs text-gray-500 line-clamp-1">{lesson.description}</p>
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500">{(lesson as any).course_title || `Course #${lesson.course_id}`}</td>
                  <td className="px-4 py-3 text-sm text-gray-500">{lesson.order}</td>
                  <td className="px-4 py-3">
                    {lesson.is_published ? (
                      <span className="text-xs text-green-600 bg-green-50 px-2 py-0.5 rounded-full">Published</span>
                    ) : (
                      <span className="text-xs text-yellow-600 bg-yellow-50 px-2 py-0.5 rounded-full">Draft</span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <button
                      onClick={() => navigate(`/lessons/${lesson.id}`)}
                      className="p-1.5 rounded-lg text-primary hover:bg-primary/5 transition-colors"
                    >
                      <Eye className="h-4 w-4" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {filtered?.length === 0 && (
            <div className="p-8 text-center text-sm text-gray-400">No lessons found</div>
          )}
        </div>
      )}
    </div>
  )
}
