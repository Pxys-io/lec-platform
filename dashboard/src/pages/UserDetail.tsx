import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import {
  ChevronLeft, Ban, CheckCircle, Shield, ShieldAlert, Trash2,
  Plus, Smartphone, Monitor, RotateCw, X, Clock
} from 'lucide-react'

interface UserDetail {
  id: string
  email: string
  phone: string
  role: string
  created_at: string
  last_login: string | null
  banned_until: string | null
  first_name: string
  last_name: string
  avatar_url: string | null
}

interface CourseAccess {
  access_id: string
  course_id: string
  course_title: string
  access_type: string
  expires_at: string | null
  granted_by: string
  created_at: string
}

interface Device {
  device_id: string
  device_type: string
  last_login: string
  created_at: string
}

interface DevicesResponse {
  user_id: string
  device_limit: number
  devices: Device[]
}

interface CourseOption {
  id: string
  title: string
  visibility: string
}

interface QBankOption {
  id: string
  title: string
}

interface QBankEnrollment {
  id: string
  user_id: string
  qbank_id: string
  status: string
  form_data_json: string
  expires_at: string | null
  created_at: string
}

export default function UserDetail() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { isSuperAdmin, isAdmin } = useAuth()
  const [activeTab, setActiveTab] = useState<'overview' | 'courses' | 'qbanks' | 'devices'>('overview')

  const [banDays, setBanDays] = useState(7)
  const [showBanInput, setShowBanInput] = useState(false)
  const [selectRole, setSelectRole] = useState('')

  const [showAddCourse, setShowAddCourse] = useState(false)
  const [addCourseForm, setAddCourseForm] = useState({ course_id: '', access_duration: '' })

  const [showAddQBank, setShowAddQBank] = useState(false)
  const [addQBankForm, setAddQBankForm] = useState({ qbank_id: '' })

  const { data: user, isLoading: userLoading } = useQuery<UserDetail>({
    queryKey: ['user', id],
    queryFn: () => api.get(`/users/${id}`),
    enabled: !!id && (isAdmin || isSuperAdmin),
  })

  const { data: accesses, isLoading: accessesLoading } = useQuery<CourseAccess[]>({
    queryKey: ['userAccesses', id],
    queryFn: () => api.get(`/users/${id}/access`),
    enabled: !!id && (isAdmin || isSuperAdmin) && activeTab === 'courses',
  })

  const { data: courses } = useQuery<CourseOption[]>({
    queryKey: ['courses'],
    queryFn: () => api.get('/courses'),
    enabled: !!id && (isAdmin || isSuperAdmin) && activeTab === 'courses',
  })

  const { data: qbanks } = useQuery<QBankOption[]>({
    queryKey: ['qbanks'],
    queryFn: () => api.get('/qbanks'),
    enabled: !!id && (isAdmin || isSuperAdmin) && activeTab === 'qbanks',
  })

  const { data: allEnrollments } = useQuery<QBankEnrollment[]>({
    queryKey: ['qbankEnrollments'],
    queryFn: () => api.get('/qbanks/enrollments/all'),
    enabled: !!id && (isAdmin || isSuperAdmin) && activeTab === 'qbanks',
  })

  const { data: devices } = useQuery<DevicesResponse>({
    queryKey: ['userDevices', id],
    queryFn: () => api.get(`/users/${id}/devices`),
    enabled: !!id && (isAdmin || isSuperAdmin) && activeTab === 'devices',
  })

  const banMutation = useMutation({
    mutationFn: (days: number) => api.post(`/users/${id}/ban?ban_duration_days=${days}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user', id] })
      queryClient.invalidateQueries({ queryKey: ['users'] })
      setShowBanInput(false)
    },
  })

  const unbanMutation = useMutation({
    mutationFn: () => api.post(`/users/${id}/unban`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user', id] })
      queryClient.invalidateQueries({ queryKey: ['users'] })
    },
  })

  const roleMutation = useMutation({
    mutationFn: (role: string) => api.put(`/users/${id}`, { role }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['user', id] })
      queryClient.invalidateQueries({ queryKey: ['users'] })
    },
  })

  const grantCourseMutation = useMutation({
    mutationFn: (data: { course_id: string; access_duration?: number }) =>
      api.post(`/users/${id}/access`, {
        course_id: data.course_id,
        access_duration: data.access_duration ? Number(data.access_duration) : undefined,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['userAccesses', id] })
      setShowAddCourse(false)
      setAddCourseForm({ course_id: '', access_duration: '' })
    },
  })

  const revokeCourseMutation = useMutation({
    mutationFn: (accessId: string) => api.delete(`/users/${id}/access/${accessId}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['userAccesses', id] }),
  })

  const grantQBankMutation = useMutation({
    mutationFn: (qbank_id: string) => api.post(`/users/${id}/qbank-access`, { qbank_id }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['qbankEnrollments'] })
      setShowAddQBank(false)
      setAddQBankForm({ qbank_id: '' })
    },
  })

  const revokeQBankMutation = useMutation({
    mutationFn: (enrollmentId: string) => api.delete(`/users/${id}/qbank-access/${enrollmentId}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['qbankEnrollments'] }),
  })

  const approveQbankMutation = useMutation({
    mutationFn: (enrollmentId: string) => api.post(`/qbanks/enrollments/${enrollmentId}/approve`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['qbankEnrollments'] }),
  })

  const rejectQbankMutation = useMutation({
    mutationFn: (enrollmentId: string) => api.post(`/qbanks/enrollments/${enrollmentId}/reject`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['qbankEnrollments'] }),
  })

  const resetDevicesMutation = useMutation({
    mutationFn: () => api.post(`/users/${id}/devices/reset`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['userDevices', id] }),
  })

  const userEnrollments = allEnrollments?.filter((e) => e.user_id === id) || []

  const getRoleBadge = (role: string) => {
    const colors: Record<string, string> = {
      super_admin: 'bg-purple-100 text-purple-700 border-purple-200',
      admin: 'bg-blue-100 text-blue-700 border-blue-200',
      instructor: 'bg-emerald-100 text-emerald-700 border-emerald-200',
      student: 'bg-gray-100 text-gray-600 border-gray-200',
    }
    return colors[role] || colors.student
  }

  const getStatusBadge = () => {
    if (!user) return null
    if (user.banned_until && new Date(user.banned_until) > new Date()) {
      return (
        <span className="inline-flex items-center gap-1 text-xs text-red-600 bg-red-50 px-2 py-0.5 rounded-full border border-red-200">
          <Ban className="h-3 w-3" /> Banned until {new Date(user.banned_until).toLocaleDateString()}
        </span>
      )
    }
    return (
      <span className="inline-flex items-center gap-1 text-xs text-green-600 bg-green-50 px-2 py-0.5 rounded-full border border-green-200">
        <CheckCircle className="h-3 w-3" /> Active
      </span>
    )
  }

  if (!isAdmin && !isSuperAdmin) {
    return (
      <div className="text-center py-12">
        <ShieldAlert className="h-12 w-12 text-red-300 mx-auto mb-3" />
        <p className="text-lg font-medium text-gray-900">Unauthorized</p>
        <p className="text-sm text-gray-500">You do not have permission to view this page.</p>
      </div>
    )
  }

  if (userLoading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="animate-spin h-8 w-8 border-2 border-primary border-t-transparent rounded-full" />
      </div>
    )
  }

  if (!user) {
    return (
      <div className="text-center py-12">
        <p className="text-gray-500">User not found</p>
      </div>
    )
  }

  const isBanned = user.banned_until && new Date(user.banned_until) > new Date()
  const isSuperAdminUser = user.role === 'super_admin'
  const availableCourses = courses?.filter(
    (c) => !accesses?.some((a) => a.course_id === c.id)
  )
  const availableQBanks = qbanks?.filter(
    (q) => !userEnrollments.some((e) => e.qbank_id === q.id && e.status === 'approved')
  )

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <button
          onClick={() => navigate('/users')}
          className="p-2 rounded-lg hover:bg-gray-100 transition-colors"
        >
          <ChevronLeft className="h-5 w-5 text-gray-500" />
        </button>
        <div>
          <h1 className="text-2xl font-bold text-gray-900">
            {user.first_name || user.last_name
              ? `${user.first_name} ${user.last_name}`.trim()
              : user.email}
          </h1>
          <p className="text-sm text-gray-500">{user.email}</p>
        </div>
        <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-medium border ${getRoleBadge(user.role)}`}>
          {user.role.replace('_', ' ')}
        </span>
        {getStatusBadge()}
      </div>

      <div className="flex gap-1 border-b border-border">
        {(['overview', 'courses', 'qbanks', 'devices'] as const).map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`px-4 py-2 text-sm font-medium capitalize transition-colors border-b-2 -mb-px ${
              activeTab === tab
                ? 'border-primary text-primary'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            {tab}
          </button>
        ))}
      </div>

      {activeTab === 'overview' && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="bg-surface rounded-xl border border-border p-6">
            <h2 className="text-lg font-semibold mb-4">User Information</h2>
            <dl className="space-y-3">
              <div className="flex justify-between">
                <dt className="text-sm text-gray-500">User ID</dt>
                <dd className="text-sm font-mono text-gray-700 max-w-[200px] truncate">{user.id}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-sm text-gray-500">Email</dt>
                <dd className="text-sm text-gray-900">{user.email}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-sm text-gray-500">Phone</dt>
                <dd className="text-sm text-gray-900">{user.phone || '—'}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-sm text-gray-500">Role</dt>
                <dd className="text-sm">
                  <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-medium border ${getRoleBadge(user.role)}`}>
                    {user.role.replace('_', ' ')}
                  </span>
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-sm text-gray-500">Joined</dt>
                <dd className="text-sm text-gray-900">{new Date(user.created_at).toLocaleString()}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-sm text-gray-500">Last Login</dt>
                <dd className="text-sm text-gray-900">
                  {user.last_login ? new Date(user.last_login).toLocaleString() : '—'}
                </dd>
              </div>
            </dl>
          </div>

          <div className="space-y-6">
            <div className="bg-surface rounded-xl border border-border p-6">
              <h2 className="text-lg font-semibold mb-4">Account Status</h2>
              {isBanned ? (
                <div>
                  <p className="text-sm text-red-600 mb-3">
                    Banned until {new Date(user.banned_until!).toLocaleString()}
                  </p>
                  <button
                    onClick={() => unbanMutation.mutate()}
                    disabled={unbanMutation.isPending}
                    className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 text-sm font-medium disabled:opacity-50"
                  >
                    <CheckCircle className="h-4 w-4" />
                    {unbanMutation.isPending ? 'Unbanning...' : 'Unban User'}
                  </button>
                </div>
              ) : isSuperAdminUser ? (
                <p className="text-sm text-gray-400">Cannot ban super admin</p>
              ) : (
                <div>
                  {!showBanInput ? (
                    <button
                      onClick={() => setShowBanInput(true)}
                      className="flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 text-sm font-medium"
                    >
                      <Ban className="h-4 w-4" />
                      Ban User
                    </button>
                  ) : (
                    <div className="space-y-3">
                      <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Ban Duration (days, 0 = permanent)</label>
                        <input
                          type="number"
                          min={0}
                          value={banDays}
                          onChange={(e) => setBanDays(Number(e.target.value))}
                          className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                        />
                      </div>
                      <div className="flex gap-2">
                        <button
                          onClick={() => banMutation.mutate(banDays)}
                          disabled={banMutation.isPending}
                          className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 text-sm font-medium disabled:opacity-50"
                        >
                          {banMutation.isPending ? 'Banning...' : `Ban for ${banDays} days`}
                        </button>
                        <button
                          onClick={() => setShowBanInput(false)}
                          className="px-4 py-2 border border-border rounded-lg text-sm text-gray-600 hover:bg-surface-alt"
                        >
                          Cancel
                        </button>
                      </div>
                    </div>
                  )}
                  {banMutation.isError && (
                    <p className="mt-2 text-sm text-red-500">{(banMutation.error as Error).message}</p>
                  )}
                </div>
              )}
            </div>

            {!isSuperAdminUser && (
              <div className="bg-surface rounded-xl border border-border p-6">
                <h2 className="text-lg font-semibold mb-4">Role Management</h2>
                <div className="flex items-center gap-3">
                  <select
                    value={selectRole || user.role}
                    onChange={(e) => setSelectRole(e.target.value)}
                    className="px-3 py-2 rounded-lg border border-border bg-surface text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                  >
                    <option value="student">Student</option>
                    <option value="instructor">Instructor</option>
                    {isSuperAdmin && <option value="admin">Admin</option>}
                  </select>
                  <button
                    onClick={() => {
                      if (confirm(`Change role to ${selectRole || user.role} for ${user.email}?`)) {
                        roleMutation.mutate(selectRole || user.role)
                      }
                    }}
                    disabled={roleMutation.isPending || (!selectRole || selectRole === user.role)}
                    className="px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark text-sm font-medium disabled:opacity-50"
                  >
                    {roleMutation.isPending ? 'Updating...' : 'Change Role'}
                  </button>
                  <Shield className="h-4 w-4 text-gray-400" />
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {activeTab === 'courses' && (
        <div className="space-y-6">
          {!showAddCourse ? (
            <button
              onClick={() => setShowAddCourse(true)}
              className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark transition-colors text-sm font-medium"
            >
              <Plus className="h-4 w-4" />
              Add Course
            </button>
          ) : (
            <div className="bg-surface rounded-xl border border-border p-6">
              <h3 className="text-lg font-semibold mb-4">Grant Course Access</h3>
              {grantCourseMutation.isError && (
                <div className="mb-4 p-3 rounded-lg bg-red-50 border border-red-200 text-red-600 text-sm">
                  {(grantCourseMutation.error as Error).message}
                </div>
              )}
              <div className="flex items-end gap-4">
                <div className="flex-1">
                  <label className="block text-sm font-medium text-gray-700 mb-1">Course</label>
                  <select
                    value={addCourseForm.course_id}
                    onChange={(e) => setAddCourseForm({ ...addCourseForm, course_id: e.target.value })}
                    className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                  >
                    <option value="">Select course...</option>
                    {availableCourses?.map((c) => (
                      <option key={c.id} value={c.id}>{c.title}</option>
                    ))}
                  </select>
                </div>
                <div className="w-32">
                  <label className="block text-sm font-medium text-gray-700 mb-1">Days (opt)</label>
                  <input
                    type="number"
                    value={addCourseForm.access_duration}
                    onChange={(e) => setAddCourseForm({ ...addCourseForm, access_duration: e.target.value })}
                    className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                    placeholder="No limit"
                    min={1}
                  />
                </div>
                <button
                  onClick={() => grantCourseMutation.mutate({
                    course_id: addCourseForm.course_id,
                    access_duration: addCourseForm.access_duration ? Number(addCourseForm.access_duration) : undefined,
                  })}
                  disabled={!addCourseForm.course_id || grantCourseMutation.isPending}
                  className="px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark text-sm font-medium disabled:opacity-50"
                >
                  {grantCourseMutation.isPending ? 'Granting...' : 'Grant Access'}
                </button>
                <button
                  onClick={() => { setShowAddCourse(false); setAddCourseForm({ course_id: '', access_duration: '' }) }}
                  className="px-4 py-2 border border-border rounded-lg text-sm text-gray-600 hover:bg-surface-alt"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}

          {accessesLoading ? (
            <div className="space-y-2">
              {[...Array(3)].map((_, i) => (
                <div key={i} className="h-14 bg-gray-100 rounded-xl animate-pulse" />
              ))}
            </div>
          ) : (
            <div className="bg-surface rounded-xl border border-border overflow-hidden">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-border bg-surface-alt">
                    <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Course</th>
                    <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Type</th>
                    <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Expires</th>
                    <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Granted</th>
                    <th className="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {accesses?.map((a) => (
                    <tr key={a.access_id} className="border-b border-border last:border-0 hover:bg-surface-alt/50">
                      <td className="px-4 py-3 text-sm font-medium text-gray-900">{a.course_title}</td>
                      <td className="px-4 py-3 text-sm text-gray-500">{a.access_type}</td>
                      <td className="px-4 py-3 text-sm text-gray-500">
                        {a.expires_at ? new Date(a.expires_at).toLocaleDateString() : 'Never'}
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-500">
                        {new Date(a.created_at).toLocaleDateString()}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <button
                          onClick={() => {
                            if (confirm(`Revoke access to "${a.course_title}"?`)) {
                              revokeCourseMutation.mutate(a.access_id)
                            }
                          }}
                          className="p-1.5 rounded-lg text-red-500 hover:bg-red-50 transition-colors"
                          title="Revoke access"
                        >
                          <X className="h-4 w-4" />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {(!accesses || accesses.length === 0) && (
                <div className="p-8 text-center text-sm text-gray-400">No course accesses</div>
              )}
            </div>
          )}
        </div>
      )}

      {activeTab === 'qbanks' && (
        <div className="space-y-6">
          {!showAddQBank ? (
            <button
              onClick={() => setShowAddQBank(true)}
              className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark transition-colors text-sm font-medium"
            >
              <Plus className="h-4 w-4" />
              Add QBank
            </button>
          ) : (
            <div className="bg-surface rounded-xl border border-border p-6">
              <h3 className="text-lg font-semibold mb-4">Add QBank Enrollment</h3>
              {grantQBankMutation.isError && (
                <div className="mb-4 p-3 rounded-lg bg-red-50 border border-red-200 text-red-600 text-sm">
                  {(grantQBankMutation.error as Error).message}
                </div>
              )}
              <div className="flex items-end gap-4">
                <div className="flex-1">
                  <label className="block text-sm font-medium text-gray-700 mb-1">QBank</label>
                  <select
                    value={addQBankForm.qbank_id}
                    onChange={(e) => setAddQBankForm({ qbank_id: e.target.value })}
                    className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                  >
                    <option value="">Select qbank...</option>
                    {availableQBanks?.map((q) => (
                      <option key={q.id} value={q.id}>{q.title}</option>
                    ))}
                  </select>
                </div>
                <button
                  onClick={() => grantQBankMutation.mutate(addQBankForm.qbank_id)}
                  disabled={!addQBankForm.qbank_id || grantQBankMutation.isPending}
                  className="px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark text-sm font-medium disabled:opacity-50"
                >
                  {grantQBankMutation.isPending ? 'Adding...' : 'Add Access'}
                </button>
                <button
                  onClick={() => { setShowAddQBank(false); setAddQBankForm({ qbank_id: '' }) }}
                  className="px-4 py-2 border border-border rounded-lg text-sm text-gray-600 hover:bg-surface-alt"
                >
                  Cancel
                </button>
              </div>
            </div>
          )}

          <div className="bg-surface rounded-xl border border-border overflow-hidden">
            <table className="w-full">
              <thead>
                <tr className="border-b border-border bg-surface-alt">
                  <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">QBank</th>
                  <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Status</th>
                  <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Enrolled</th>
                  <th className="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">Actions</th>
                </tr>
              </thead>
              <tbody>
                {userEnrollments.map((e) => {
                  const qbank = qbanks?.find((q) => q.id === e.qbank_id)
                  return (
                    <tr key={e.id} className="border-b border-border last:border-0 hover:bg-surface-alt/50">
                      <td className="px-4 py-3 text-sm font-medium text-gray-900">
                        {qbank?.title || e.qbank_id}
                      </td>
                      <td className="px-4 py-3">
                        <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-medium border ${
                          e.status === 'approved'
                            ? 'bg-green-50 text-green-600 border-green-200'
                            : e.status === 'rejected'
                            ? 'bg-red-50 text-red-600 border-red-200'
                            : 'bg-yellow-50 text-yellow-600 border-yellow-200'
                        }`}>
                          {e.status}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-500">
                        {new Date(e.created_at).toLocaleDateString()}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <div className="flex items-center justify-end gap-1">
                          {e.status === 'pending' && (
                            <>
                              <button
                                onClick={() => approveQbankMutation.mutate(e.id)}
                                className="p-1.5 rounded-lg text-green-600 hover:bg-green-50 transition-colors"
                                title="Approve"
                              >
                                <CheckCircle className="h-4 w-4" />
                              </button>
                              <button
                                onClick={() => rejectQbankMutation.mutate(e.id)}
                                className="p-1.5 rounded-lg text-red-500 hover:bg-red-50 transition-colors"
                                title="Reject"
                              >
                                <X className="h-4 w-4" />
                              </button>
                            </>
                          )}
                          <button
                            onClick={() => {
                              if (confirm(`Remove this QBank enrollment?`)) {
                                revokeQBankMutation.mutate(e.id)
                              }
                            }}
                            className="p-1.5 rounded-lg text-red-500 hover:bg-red-50 transition-colors"
                            title="Remove"
                          >
                            <Trash2 className="h-4 w-4" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
            {userEnrollments.length === 0 && (
              <div className="p-8 text-center text-sm text-gray-400">No QBank enrollments</div>
            )}
          </div>
        </div>
      )}

      {activeTab === 'devices' && (
        <div className="space-y-6">
          <div className="bg-surface rounded-xl border border-border p-6">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-semibold">Devices</h2>
                <p className="text-sm text-gray-500 mt-1">
                  {devices?.devices.length || 0} / {devices?.device_limit || 2} devices used
                </p>
              </div>
              <button
                onClick={() => {
                  if (confirm(`Reset all devices for ${user.email}? This will log out all sessions.`)) {
                    resetDevicesMutation.mutate()
                  }
                }}
                disabled={resetDevicesMutation.isPending}
                className="flex items-center gap-2 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 text-sm font-medium disabled:opacity-50"
              >
                <RotateCw className={`h-4 w-4 ${resetDevicesMutation.isPending ? 'animate-spin' : ''}`} />
                {resetDevicesMutation.isPending ? 'Resetting...' : 'Reset All Devices'}
              </button>
            </div>
          </div>

          <div className="bg-surface rounded-xl border border-border overflow-hidden">
            <table className="w-full">
              <thead>
                <tr className="border-b border-border bg-surface-alt">
                  <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Device</th>
                  <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Type</th>
                  <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Last Active</th>
                  <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">First Seen</th>
                </tr>
              </thead>
              <tbody>
                {devices?.devices.map((d) => (
                  <tr key={d.device_id} className="border-b border-border last:border-0 hover:bg-surface-alt/50">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        {d.device_type === 'mobile' ? (
                          <Smartphone className="h-4 w-4 text-gray-400" />
                        ) : (
                          <Monitor className="h-4 w-4 text-gray-400" />
                        )}
                        <span className="text-sm font-mono text-gray-700 max-w-[120px] truncate">{d.device_id}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-500 capitalize">{d.device_type}</td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-1 text-sm text-gray-500">
                        <Clock className="h-3 w-3" />
                        {new Date(d.last_login).toLocaleString()}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-500">
                      {new Date(d.created_at).toLocaleDateString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {(!devices || devices.devices.length === 0) && (
              <div className="p-8 text-center text-sm text-gray-400">No devices registered</div>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
