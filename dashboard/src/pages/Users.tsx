import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { Search, Plus, Ban, CheckCircle, ShieldAlert } from 'lucide-react'

interface UserProfile {
  first_name: string | null
  last_name: string | null
}

interface AppUser {
  id: string
  email: string
  role: string
  phone: string | null
  created_at: string
  last_login: string | null
  banned_until: string | null
  profile: UserProfile | null
}

export default function Users() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [search, setSearch] = useState('')
  const [roleFilter, setRoleFilter] = useState('')
  const [showCreate, setShowCreate] = useState(false)
  const [createForm, setCreateForm] = useState({ email: '', password: '', role: 'student', first_name: '', last_name: '', phone: '' })
  const [createError, setCreateError] = useState('')

  const { data: users, isLoading } = useQuery<AppUser[]>({
    queryKey: ['users'],
    queryFn: () => api.get('/users'),
    enabled: user?.role === 'admin' || user?.role === 'super_admin',
  })

  const banMutation = useMutation({
    mutationFn: ({ id, days }: { id: string; days: number }) =>
      api.post(`/users/${id}/ban?days=${days}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['users'] }),
  })

  const unbanMutation = useMutation({
    mutationFn: (id: string) => api.post(`/users/${id}/unban`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['users'] }),
  })

  const roleMutation = useMutation({
    mutationFn: ({ id, role }: { id: string; role: string }) =>
      api.put(`/users/${id}`, { role }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['users'] }),
    onError: (err: Error) => setCreateError(err.message),
  })

  const createMutation = useMutation({
    mutationFn: (data: typeof createForm) => api.post('/users', data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] })
      setShowCreate(false)
      setCreateForm({ email: '', password: '', role: 'student', first_name: '', last_name: '', phone: '' })
      setCreateError('')
    },
    onError: (err: Error) => setCreateError(err.message),
  })

  const filteredUsers = users?.filter((u) => {
    const matchesSearch =
      u.email.toLowerCase().includes(search.toLowerCase()) ||
      u.profile?.first_name?.toLowerCase().includes(search.toLowerCase()) ||
      u.profile?.last_name?.toLowerCase().includes(search.toLowerCase())
    const matchesRole = !roleFilter || u.role === roleFilter
    return matchesSearch && matchesRole
  })

  const getRoleBadge = (role: string) => {
    const colors: Record<string, string> = {
      super_admin: 'bg-purple-100 text-purple-700 border-purple-200',
      admin: 'bg-blue-100 text-blue-700 border-blue-200',
      instructor: 'bg-emerald-100 text-emerald-700 border-emerald-200',
      student: 'bg-gray-100 text-gray-600 border-gray-200',
    }
    return colors[role] || colors.student
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Users</h1>
          <p className="text-sm text-gray-500 mt-1">Manage platform users</p>
        </div>
        <button
          onClick={() => setShowCreate(true)}
          className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark transition-colors text-sm font-medium"
        >
          <Plus className="h-4 w-4" />
          Create User
        </button>
      </div>

      <div className="flex gap-3 items-center">
        <div className="relative flex-1 max-w-sm">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2 rounded-lg border border-border bg-surface text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
            placeholder="Search users..."
          />
        </div>
        <select
          value={roleFilter}
          onChange={(e) => setRoleFilter(e.target.value)}
          className="px-3 py-2 rounded-lg border border-border bg-surface text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
        >
          <option value="">All Roles</option>
          <option value="super_admin">Super Admin</option>
          <option value="admin">Admin</option>
          <option value="instructor">Instructor</option>
          <option value="student">Student</option>
        </select>
      </div>

      {showCreate && (
        <div className="bg-surface rounded-xl border border-border p-6">
          <h2 className="text-lg font-semibold mb-4">Create New User</h2>
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
              <label className="block text-sm font-medium text-gray-700 mb-1">Email *</label>
              <input
                type="email"
                value={createForm.email}
                onChange={(e) => setCreateForm({ ...createForm, email: e.target.value })}
                className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Password *</label>
              <input
                type="password"
                value={createForm.password}
                onChange={(e) => setCreateForm({ ...createForm, password: e.target.value })}
                className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">First Name</label>
              <input
                type="text"
                value={createForm.first_name}
                onChange={(e) => setCreateForm({ ...createForm, first_name: e.target.value })}
                className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Last Name</label>
              <input
                type="text"
                value={createForm.last_name}
                onChange={(e) => setCreateForm({ ...createForm, last_name: e.target.value })}
                className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Role</label>
              <select
                value={createForm.role}
                onChange={(e) => setCreateForm({ ...createForm, role: e.target.value })}
                className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
              >
                <option value="student">Student</option>
                <option value="instructor">Instructor</option>
                <option value="admin">Admin</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Phone</label>
              <input
                type="text"
                value={createForm.phone}
                onChange={(e) => setCreateForm({ ...createForm, phone: e.target.value })}
                className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
              />
            </div>
            <div className="md:col-span-2 flex gap-3">
              <button type="submit" className="px-4 py-2 bg-primary text-white rounded-lg hover:bg-primary-dark text-sm font-medium">
                Create User
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
          {[...Array(5)].map((_, i) => (
            <div key={i} className="h-16 bg-gray-100 rounded-xl animate-pulse" />
          ))}
        </div>
      ) : (
        <div className="bg-surface rounded-xl border border-border overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-border bg-surface-alt">
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">User</th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Role</th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Status</th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Joined</th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Last Login</th>
                <th className="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredUsers?.map((u) => (
                <tr
                  key={u.id}
                  onClick={() => navigate(`/users/${u.id}`)}
                  className="border-b border-border last:border-0 hover:bg-surface-alt/50 transition-colors cursor-pointer"
                >
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-3">
                      <div className="h-9 w-9 rounded-full bg-gray-200 flex items-center justify-center text-sm font-semibold text-gray-600 shrink-0">
                        {(u.profile?.first_name?.[0] || u.email[0]).toUpperCase()}
                      </div>
                      <div>
                        <p className="text-sm font-medium text-gray-900">
                          {u.profile?.first_name ? `${u.profile.first_name} ${u.profile.last_name || ''}` : u.email}
                        </p>
                        <p className="text-xs text-gray-500">{u.email}</p>
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`inline-flex px-2 py-0.5 rounded-full text-xs font-medium border ${getRoleBadge(u.role)}`}>
                      {u.role.replace('_', ' ')}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    {u.banned_until && new Date(u.banned_until) > new Date() ? (
                      <span className="inline-flex items-center gap-1 text-xs text-red-600 bg-red-50 px-2 py-0.5 rounded-full">
                        <Ban className="h-3 w-3" /> Banned
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 text-xs text-green-600 bg-green-50 px-2 py-0.5 rounded-full">
                        <CheckCircle className="h-3 w-3" /> Active
                      </span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500">
                    {new Date(u.created_at).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500">
                    {u.last_login ? new Date(u.last_login).toLocaleDateString() : '—'}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <div className="flex items-center justify-end gap-2" onClick={(e) => e.stopPropagation()}>
                      {u.banned_until && new Date(u.banned_until) > new Date() ? (
                        <button
                          onClick={() => unbanMutation.mutate(u.id)}
                          className="p-1.5 rounded-lg text-green-600 hover:bg-green-50 transition-colors"
                          title="Unban"
                        >
                          <CheckCircle className="h-4 w-4" />
                        </button>
                      ) : (
                        u.role !== 'super_admin' && (
                          <button
                            onClick={() => banMutation.mutate({ id: u.id, days: 7 })}
                            className="p-1.5 rounded-lg text-red-500 hover:bg-red-50 transition-colors"
                            title="Ban (7 days)"
                          >
                            <Ban className="h-4 w-4" />
                          </button>
                        )
                      )}
                      {u.role === 'super_admin' ? (
                        <span className="p-1.5 text-gray-300" title="Cannot modify super admin">
                          <ShieldAlert className="h-4 w-4" />
                        </span>
                      ) : (
                        <select
                          value={u.role}
                          onChange={(e) => {
                            if (confirm(`Change role to ${e.target.value} for ${u.email}?`)) {
                              roleMutation.mutate({ id: u.id, role: e.target.value })
                            }
                          }}
                          className="text-xs px-2 py-1 rounded-lg border border-border bg-surface hover:border-primary/50 cursor-pointer"
                          title="Change role"
                        >
                          <option value="student">Student</option>
                          <option value="instructor">Instructor</option>
                          {(user?.role === 'super_admin') && (
                            <option value="admin">Admin</option>
                          )}
                        </select>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {filteredUsers?.length === 0 && (
            <div className="p-8 text-center text-sm text-gray-400">No users found</div>
          )}
        </div>
      )}
    </div>
  )
}
