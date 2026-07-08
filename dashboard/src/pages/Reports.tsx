import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { Flag, Search, CheckCircle, XCircle, Clock } from 'lucide-react'

interface Report {
  id: number
  target_type: string
  target_id: number
  reason: string
  description: string
  status: string
  created_at: string
  resolved_by: number | null
  user?: { email: string }
}

export default function Reports() {
  const { isInstructor } = useAuth()
  const queryClient = useQueryClient()
  const [statusFilter, setStatusFilter] = useState('')

  const { data: reports, isLoading } = useQuery<Report[]>({
    queryKey: ['reports'],
    queryFn: () => api.get('/reports'),
    enabled: isInstructor,
  })

  const updateMutation = useMutation({
    mutationFn: ({ id, status }: { id: number; status: string }) =>
      api.put(`/reports/${id}`, { status }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['reports'] }),
  })

  const filtered = reports?.filter((r) => !statusFilter || r.status === statusFilter)

  const statusColors: Record<string, string> = {
    pending: 'bg-yellow-100 text-yellow-700 border-yellow-200',
    reviewed: 'bg-blue-100 text-blue-700 border-blue-200',
    resolved: 'bg-green-100 text-green-700 border-green-200',
    rejected: 'bg-red-100 text-red-700 border-red-200',
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Reports</h1>
        <p className="text-sm text-gray-500 mt-1">Review and manage user reports</p>
      </div>

      <div className="flex gap-3">
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="px-3 py-2 rounded-lg border border-border bg-surface text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
        >
          <option value="">All Status</option>
          <option value="pending">Pending</option>
          <option value="reviewed">Reviewed</option>
          <option value="resolved">Resolved</option>
          <option value="rejected">Rejected</option>
        </select>
      </div>

      {isLoading ? (
        <div className="space-y-2">
          {[...Array(3)].map((_, i) => <div key={i} className="h-20 bg-gray-100 rounded-xl animate-pulse" />)}
        </div>
      ) : (
        <div className="space-y-2">
          {filtered?.map((report) => (
            <div key={report.id} className="bg-surface rounded-xl border border-border p-4">
              <div className="flex items-start justify-between">
                <div className="flex items-start gap-3">
                  <div className={`p-2 rounded-lg ${
                    report.status === 'pending' ? 'bg-yellow-100' :
                    report.status === 'resolved' ? 'bg-green-100' :
                    report.status === 'rejected' ? 'bg-red-100' : 'bg-blue-100'
                  }`}>
                    <Flag className={`h-4 w-4 ${
                      report.status === 'pending' ? 'text-yellow-600' :
                      report.status === 'resolved' ? 'text-green-600' :
                      report.status === 'rejected' ? 'text-red-600' : 'text-blue-600'
                    }`} />
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <h3 className="text-sm font-medium text-gray-900 capitalize">{report.target_type}</h3>
                      <span className={`text-xs px-2 py-0.5 rounded-full border ${statusColors[report.status] || statusColors.pending}`}>
                        {report.status}
                      </span>
                    </div>
                    <p className="text-sm text-gray-600 mt-1">{report.reason}</p>
                    {report.description && (
                      <p className="text-xs text-gray-500 mt-0.5">{report.description}</p>
                    )}
                    <div className="flex items-center gap-3 mt-2 text-xs text-gray-400">
                      <span>By: {report.user?.email || 'Unknown'}</span>
                      <span>{new Date(report.created_at).toLocaleDateString()}</span>
                    </div>
                  </div>
                </div>

                <div className="flex items-center gap-2 shrink-0">
                  {report.status === 'pending' && (
                    <>
                      <button
                        onClick={() => updateMutation.mutate({ id: report.id, status: 'reviewed' })}
                        className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-blue-50 text-blue-600 text-xs font-medium hover:bg-blue-100 transition-colors"
                      >
                        <Clock className="h-3 w-3" /> Review
                      </button>
                      <button
                        onClick={() => updateMutation.mutate({ id: report.id, status: 'resolved' })}
                        className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-green-50 text-green-600 text-xs font-medium hover:bg-green-100 transition-colors"
                      >
                        <CheckCircle className="h-3 w-3" /> Resolve
                      </button>
                      <button
                        onClick={() => updateMutation.mutate({ id: report.id, status: 'rejected' })}
                        className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-red-50 text-red-600 text-xs font-medium hover:bg-red-100 transition-colors"
                      >
                        <XCircle className="h-3 w-3" /> Reject
                      </button>
                    </>
                  )}
                  {report.status === 'reviewed' && (
                    <>
                      <button
                        onClick={() => updateMutation.mutate({ id: report.id, status: 'resolved' })}
                        className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-green-50 text-green-600 text-xs font-medium hover:bg-green-100 transition-colors"
                      >
                        <CheckCircle className="h-3 w-3" /> Resolve
                      </button>
                      <button
                        onClick={() => updateMutation.mutate({ id: report.id, status: 'rejected' })}
                        className="flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-red-50 text-red-600 text-xs font-medium hover:bg-red-100 transition-colors"
                      >
                        <XCircle className="h-3 w-3" /> Reject
                      </button>
                    </>
                  )}
                </div>
              </div>
            </div>
          ))}
          {filtered?.length === 0 && (
            <div className="p-8 text-center text-sm text-gray-400">No reports found</div>
          )}
        </div>
      )}
    </div>
  )
}
