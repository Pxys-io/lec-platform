import { useQuery } from '@tanstack/react-query'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { Users, BookOpen, FileText, Clock, TrendingUp, Award, Activity, Flag } from 'lucide-react'

interface WeeklyEntry {
  week: string
  count: number
}

interface MonthlyWatch {
  month: string
  watch_time: number
}

interface OverviewStats {
  total_users: number
  total_courses: number
  total_lessons: number
  weekly_unique_users: WeeklyEntry[]
  total_watch_time: number
  monthly_watch_stats: MonthlyWatch[]
}

interface Report {
  id: number
  target_type: string
  reason: string
  status: string
  created_at: string
  user?: { email: string }
}

export default function Dashboard() {
  const { user, isInstructor } = useAuth()

  const { data: stats, isLoading: statsLoading } = useQuery<OverviewStats>({
    queryKey: ['stats-overview'],
    queryFn: () => api.get('/stats/overview'),
  })

  const { data: reports } = useQuery<Report[]>({
    queryKey: ['reports'],
    queryFn: () => api.get('/reports'),
    enabled: isInstructor,
  })

  const statCards = [
    { label: 'Total Users', value: stats?.total_users ?? '—', icon: Users, color: 'bg-blue-500' },
    { label: 'Courses', value: stats?.total_courses ?? '—', icon: BookOpen, color: 'bg-violet-500' },
    { label: 'Lessons', value: stats?.total_lessons ?? '—', icon: FileText, color: 'bg-emerald-500' },
    { label: 'Weekly Active', value: stats?.weekly_unique_users?.reduce((sum, w) => sum + w.count, 0) ?? '—', icon: Activity, color: 'bg-orange-500' },
    { label: 'Watch Hours', value: stats ? Math.round(stats.total_watch_time / 3600) : '—', icon: Clock, color: 'bg-rose-500' },
  ]

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p className="text-sm text-gray-500 mt-1">
          Welcome back, {user?.profile?.first_name || user?.email}
        </p>
      </div>

      {statsLoading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-4">
          {[...Array(5)].map((_, i) => (
            <div key={i} className="h-28 bg-gray-100 rounded-xl animate-pulse" />
          ))}
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-4">
          {statCards.map((card) => (
            <div key={card.label} className="bg-surface rounded-xl border border-border p-5 hover:shadow-md transition-shadow">
              <div className="flex items-center justify-between mb-3">
                <div className={`p-2.5 rounded-lg ${card.color} bg-opacity-10`}>
                  <card.icon className={`h-5 w-5 ${card.color.replace('bg-', 'text-')}`} />
                </div>
              </div>
              <p className="text-2xl font-bold text-gray-900">{card.value}</p>
              <p className="text-xs text-gray-500 mt-0.5">{card.label}</p>
            </div>
          ))}
        </div>
      )}

      {isInstructor && reports && (
        <div className="bg-surface rounded-xl border border-border p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
              <Flag className="h-5 w-5 text-danger" />
              Pending Reports
            </h2>
            <span className="text-xs text-gray-500">{reports.filter((r) => r.status === 'pending').length} pending</span>
          </div>
          {reports.filter((r) => r.status === 'pending').length === 0 ? (
            <p className="text-sm text-gray-400 py-4 text-center">No pending reports</p>
          ) : (
            <div className="space-y-2">
              {reports
                .filter((r) => r.status === 'pending')
                .slice(0, 5)
                .map((report) => (
                  <div key={report.id} className="flex items-center justify-between p-3 rounded-lg bg-surface-alt border border-border">
                    <div className="flex items-center gap-3">
                      <div className="p-1.5 rounded-full bg-yellow-100">
                        <Flag className="h-4 w-4 text-yellow-600" />
                      </div>
                      <div>
                        <p className="text-sm font-medium text-gray-700 capitalize">{report.target_type}</p>
                        <p className="text-xs text-gray-500">{report.reason}</p>
                      </div>
                    </div>
                    <span className="text-xs text-gray-400">
                      {new Date(report.created_at).toLocaleDateString()}
                    </span>
                  </div>
                ))}
            </div>
          )}
        </div>
      )}
    </div>
  )
}
