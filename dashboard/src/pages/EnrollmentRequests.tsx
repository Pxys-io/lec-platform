import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { Check, X, Eye, Clock, User, BookOpen, AlertCircle } from 'lucide-react'
import { format } from 'date-fns'

interface EnrollmentRequest {
  id: string
  user_id: string
  course_id: string
  status: string
  form_data: Record<string, any>
  admin_comment: string | null
  created_at: string
  user_email: string
  course_title: string
  images: { id: string; url: string }[]
}

export default function EnrollmentRequests() {
  const { isInstructor } = useAuth()
  const queryClient = useQueryClient()
  const [filter, setFilter] = useState('pending')
  const [selectedRequest, setSelectedRequest] = useState<EnrollmentRequest | null>(null)
  const [adminComment, setAdminComment] = useState('')

  const { data: requests, isLoading } = useQuery<EnrollmentRequest[]>({
    queryKey: ['enrollment-requests', filter],
    queryFn: () => api.get(`/enrollment/requests?status=${filter}`),
    enabled: isInstructor,
  })

  const approveMutation = useMutation({
    mutationFn: ({ id, comment }: { id: string; comment?: string }) =>
      api.post(`/enrollment/requests/${id}/approve`, { admin_comment: comment }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['enrollment-requests'] })
      setSelectedRequest(null)
      setAdminComment('')
    },
  })

  const rejectMutation = useMutation({
    mutationFn: ({ id, comment }: { id: string; comment: string }) =>
      api.post(`/enrollment/requests/${id}/reject`, { admin_comment: comment }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['enrollment-requests'] })
      setSelectedRequest(null)
      setAdminComment('')
    },
  })

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'approved': return 'bg-green-100 text-green-700 border-green-200'
      case 'rejected': return 'bg-red-100 text-red-700 border-red-200'
      case 'pending': return 'bg-yellow-100 text-yellow-700 border-yellow-200'
      default: return 'bg-gray-100 text-gray-600 border-gray-200'
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Enrollment Requests</h1>
          <p className="text-sm text-gray-500 mt-1">Review and approve student course enrollments</p>
        </div>
        <div className="flex bg-surface border border-border rounded-lg p-1">
          {['pending', 'approved', 'rejected'].map((s) => (
            <button
              key={s}
              onClick={() => setFilter(s)}
              className={`px-3 py-1.5 text-xs font-medium rounded-md capitalize transition-colors ${
                filter === s ? 'bg-primary text-white' : 'text-gray-500 hover:bg-surface-alt'
              }`}
            >
              {s}
            </button>
          ))}
        </div>
      </div>

      {isLoading ? (
        <div className="space-y-4">
          {[...Array(3)].map((_, i) => <div key={i} className="h-24 bg-gray-100 rounded-xl animate-pulse" />)}
        </div>
      ) : (
        <div className="grid gap-4">
          {requests?.map((req) => (
            <div key={req.id} className="bg-surface border border-border rounded-xl p-4 flex items-center justify-between">
              <div className="flex items-center gap-4">
                <div className="p-3 bg-gray-100 rounded-full text-gray-400">
                  <User className="h-6 w-6" />
                </div>
                <div>
                  <h3 className="text-sm font-semibold text-gray-900">{req.user_email}</h3>
                  <div className="flex items-center gap-3 mt-1">
                    <span className="text-xs text-gray-500 flex items-center gap-1">
                      <BookOpen className="h-3 w-3" /> {req.course_title}
                    </span>
                    <span className="text-xs text-gray-400 flex items-center gap-1">
                      <Clock className="h-3 w-3" /> {format(new Date(req.created_at), 'MMM d, yyyy HH:mm')}
                    </span>
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-3">
                <span className={`text-[10px] px-2 py-0.5 rounded-full border uppercase font-bold ${getStatusBadge(req.status)}`}>
                  {req.status}
                </span>
                <button
                  onClick={() => setSelectedRequest(req)}
                  className="flex items-center gap-2 px-3 py-1.5 bg-gray-900 text-white rounded-lg text-xs font-medium hover:bg-gray-800 transition-colors"
                >
                  <Eye className="h-3.5 w-3.5" />
                  Review
                </button>
              </div>
            </div>
          ))}
          {requests?.length === 0 && (
            <div className="text-center py-12 bg-surface border border-dashed border-border rounded-xl">
              <AlertCircle className="h-8 w-8 text-gray-300 mx-auto mb-3" />
              <p className="text-sm text-gray-500">No {filter} requests found</p>
            </div>
          )}
        </div>
      )}

      {selectedRequest && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl w-full max-w-2xl max-h-[90vh] overflow-hidden flex flex-col shadow-2xl">
            <div className="p-6 border-b border-border flex items-center justify-between">
              <h2 className="text-lg font-bold">Review Request</h2>
              <button onClick={() => setSelectedRequest(null)} className="p-2 hover:bg-gray-100 rounded-full">
                <X className="h-5 w-5" />
              </button>
            </div>
            
            <div className="p-6 overflow-y-auto space-y-6">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-[10px] uppercase font-bold text-gray-400 mb-1">Student</p>
                  <p className="text-sm font-medium">{selectedRequest.user_email}</p>
                </div>
                <div>
                  <p className="text-[10px] uppercase font-bold text-gray-400 mb-1">Course</p>
                  <p className="text-sm font-medium">{selectedRequest.course_title}</p>
                </div>
              </div>

              <div>
                <p className="text-[10px] uppercase font-bold text-gray-400 mb-3">Submitted Form Data</p>
                <div className="bg-gray-50 rounded-xl p-4 grid gap-3 border border-border">
                  {Object.entries(selectedRequest.form_data).map(([label, value]) => (
                    <div key={label} className="flex flex-col">
                      <span className="text-[10px] font-bold text-gray-500">{label}</span>
                      <span className="text-sm">{String(value)}</span>
                    </div>
                  ))}
                </div>
              </div>

              {selectedRequest.images.length > 0 && (
                <div>
                  <p className="text-[10px] uppercase font-bold text-gray-400 mb-3">Proof Images</p>
                  <div className="grid grid-cols-2 gap-4">
                    {selectedRequest.images.map((img) => (
                      <a 
                        key={img.id} 
                        href={img.url} 
                        target="_blank" 
                        rel="noreferrer"
                        className="aspect-video bg-gray-100 rounded-lg overflow-hidden border border-border group relative"
                      >
                        <img src={img.url} alt="Proof" className="w-full h-full object-cover transition-transform group-hover:scale-105" />
                        <div className="absolute inset-0 bg-black/20 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                          <Eye className="h-6 w-6 text-white" />
                        </div>
                      </a>
                    ))}
                  </div>
                </div>
              )}

              <div>
                <p className="text-[10px] uppercase font-bold text-gray-400 mb-2">Internal Note / Rejection Reason</p>
                <textarea
                  value={adminComment}
                  onChange={(e) => setAdminComment(e.target.value)}
                  className="w-full p-3 rounded-xl border border-border text-sm min-h-[100px] focus:ring-2 focus:ring-primary/20"
                  placeholder="Add a comment or reason for rejection..."
                />
              </div>
            </div>

            {selectedRequest.status === 'pending' && (
              <div className="p-6 border-t border-border flex items-center gap-3">
                <button
                  onClick={() => rejectMutation.mutate({ id: selectedRequest.id, comment: adminComment })}
                  disabled={!adminComment}
                  className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl border border-red-200 text-red-600 font-semibold hover:bg-red-50 disabled:opacity-50 transition-colors"
                >
                  <X className="h-4 w-4" />
                  Reject
                </button>
                <button
                  onClick={() => approveMutation.mutate({ id: selectedRequest.id, comment: adminComment })}
                  className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl bg-green-600 text-white font-semibold hover:bg-green-700 transition-colors shadow-lg shadow-green-100"
                >
                  <Check className="h-4 w-4" />
                  Approve
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
