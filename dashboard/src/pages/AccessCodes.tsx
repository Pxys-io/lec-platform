import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { Ticket, Plus, Copy, Trash2 } from 'lucide-react'

interface AccessCode {
  id: number
  code: string
  access_type: string
  access_duration: number | null
  expires_at: string | null
  max_uses: number
  current_uses: number
  is_active: boolean
  created_at: string
  course_id: number | null
}

export default function AccessCodes() {
  const { isInstructor } = useAuth()
  const queryClient = useQueryClient()
  const [showCreate, setShowCreate] = useState(false)
  const [createForm, setCreateForm] = useState({ access_type: 'course', access_duration: '', course_id: '', max_uses: 100 })
  const [createError, setCreateError] = useState('')
  const [copiedId, setCopiedId] = useState<number | null>(null)

  const { data: codes, isLoading } = useQuery<AccessCode[]>({
    queryKey: ['access-codes'],
    queryFn: () => api.get('/codes'),
    enabled: isInstructor,
  })

  const createMutation = useMutation({
    mutationFn: (data: typeof createForm) =>
      api.post('/codes', {
        ...data,
        access_duration: data.access_duration ? Number(data.access_duration) : null,
        course_id: data.course_id ? Number(data.course_id) : null,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['access-codes'] })
      setShowCreate(false)
      setCreateForm({ access_type: 'course', access_duration: '', course_id: '', max_uses: 100 })
      setCreateError('')
    },
    onError: (err: Error) => setCreateError(err.message),
  })

  const deleteMutation = useMutation({
    mutationFn: (id: number) => api.delete(`/codes/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['access-codes'] }),
  })

  const copyCode = async (code: string, id: number) => {
    await navigator.clipboard.writeText(code)
    setCopiedId(id)
    setTimeout(() => setCopiedId(null), 2000)
  }

  const { data: courses } = useQuery<any[]>({
    queryKey: ['courses'],
    queryFn: () => api.get('/courses'),
    enabled: showCreate,
  })

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Access Codes</h1>
          <p className="text-sm text-gray-500 mt-1">Generate and manage enrollment codes</p>
        </div>
        {isInstructor && (
          <button
            onClick={() => setShowCreate(true)}
            className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark transition-colors text-sm font-medium"
          >
            <Plus className="h-4 w-4" />
            Generate Code
          </button>
        )}
      </div>

      {showCreate && (
        <div className="bg-surface rounded-xl border border-border p-6">
          <h2 className="text-lg font-semibold mb-4">Generate Access Code</h2>
          {createError && (
            <div className="mb-4 p-3 rounded-lg bg-red-50 border border-red-200 text-red-600 text-sm">{createError}</div>
          )}
          <form
            onSubmit={(e) => {
              e.preventDefault()
              createMutation.mutate(createForm)
            }}
            className="grid grid-cols-1 md:grid-cols-2 gap-4"
          >
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Access Type *</label>
              <select
                value={createForm.access_type}
                onChange={(e) => setCreateForm({ ...createForm, access_type: e.target.value })}
                className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
              >
                <option value="course">Course</option>
                <option value="lesson">Lesson</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Course</label>
              <select
                value={createForm.course_id}
                onChange={(e) => setCreateForm({ ...createForm, course_id: e.target.value })}
                className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
              >
                <option value="">All Courses</option>
                {courses?.map((c: any) => (
                  <option key={c.id} value={c.id}>{c.title}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Max Uses</label>
              <input
                type="number"
                value={createForm.max_uses}
                onChange={(e) => setCreateForm({ ...createForm, max_uses: Number(e.target.value) })}
                className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Access Duration (days, optional)</label>
              <input
                type="number"
                value={createForm.access_duration}
                onChange={(e) => setCreateForm({ ...createForm, access_duration: e.target.value })}
                className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
              />
            </div>
            <div className="md:col-span-2 flex gap-3">
              <button type="submit" className="px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark text-sm font-medium">
                Generate Code
              </button>
              <button type="button" onClick={() => setShowCreate(false)} className="px-4 py-2 border border-border rounded-lg text-sm text-gray-600 hover:bg-surface-alt">
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {isLoading ? (
        <div className="space-y-2">
          {[...Array(3)].map((_, i) => <div key={i} className="h-16 bg-gray-100 rounded-xl animate-pulse" />)}
        </div>
      ) : (
        <div className="bg-surface rounded-xl border border-border overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-border bg-surface-alt">
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Code</th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Type</th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Uses</th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Expires</th>
                <th className="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody>
              {codes?.map((code) => (
                <tr key={code.id} className="border-b border-border last:border-0 hover:bg-surface-alt/50 transition-colors">
                  <td className="px-4 py-3">
                    <span className="font-mono text-sm font-medium text-gray-900">{code.code}</span>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500 capitalize">{code.access_type}</td>
                  <td className="px-4 py-3 text-sm text-gray-500">
                    <span className={code.current_uses >= code.max_uses ? 'text-red-600 font-medium' : ''}>
                      {code.current_uses} / {code.max_uses}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    {code.is_active ? (
                      <span className="text-xs text-green-600 bg-green-50 px-2 py-0.5 rounded-full">Active</span>
                    ) : (
                      <span className="text-xs text-red-600 bg-red-50 px-2 py-0.5 rounded-full">Inactive</span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500">
                    {code.expires_at ? new Date(code.expires_at).toLocaleDateString() : 'Never'}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <div className="flex items-center justify-end gap-2">
                      <button
                        onClick={() => copyCode(code.code, code.id)}
                        className="p-1.5 rounded-lg text-gray-400 hover:text-primary hover:bg-primary/5 transition-colors"
                        title="Copy code"
                      >
                        {copiedId === code.id ? (
                          <span className="text-xs text-green-600">Copied!</span>
                        ) : (
                          <Copy className="h-4 w-4" />
                        )}
                      </button>
                      <button
                        onClick={() => deleteMutation.mutate(code.id)}
                        className="p-1.5 rounded-lg text-gray-400 hover:text-red-500 hover:bg-red-50 transition-colors"
                        title="Deactivate"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {codes?.length === 0 && (
            <div className="p-8 text-center text-sm text-gray-400">No access codes generated yet</div>
          )}
        </div>
      )}
    </div>
  )
}
