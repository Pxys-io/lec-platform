import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../lib/api'
import { AlertTriangle, Plus, Trash2, Power, Globe, User, Monitor, Hash, Layers } from 'lucide-react'

interface PanicModeConfig {
  id: string
  is_active: boolean
  target_type: 'global' | 'user' | 'platform' | 'version' | 'build'
  target_value: string | null
  webview_url: string
  created_at: string
}

export default function PanicMode() {
  const queryClient = useQueryClient()
  const [showCreate, setShowCreate] = useState(false)
  const [form, setForm] = useState<Partial<PanicModeConfig>>({
    is_active: true,
    target_type: 'global',
    target_value: '',
    webview_url: '',
  })

  const { data: configs, isLoading } = useQuery<PanicModeConfig[]>({
    queryKey: ['panic-mode'],
    queryFn: () => api.get('/misc/panic-mode'),
  })

  const createMutation = useMutation({
    mutationFn: (data: Partial<PanicModeConfig>) => api.post('/misc/panic-mode', data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['panic-mode'] })
      setShowCreate(false)
      setForm({ is_active: true, target_type: 'global', target_value: '', webview_url: '' })
    },
  })

  const updateMutation = useMutation({
    mutationFn: (config: PanicModeConfig) => api.put(`/misc/panic-mode/${config.id}`, config),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['panic-mode'] }),
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/misc/panic-mode/${id}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['panic-mode'] }),
  })

  const getTargetIcon = (type: string) => {
    switch (type) {
      case 'global': return <Globe className="h-4 w-4" />
      case 'user': return <User className="h-4 w-4" />
      case 'platform': return <Monitor className="h-4 w-4" />
      case 'version': return <Hash className="h-4 w-4" />
      case 'build': return <Layers className="h-4 w-4" />
      default: return <Globe className="h-4 w-4" />
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <AlertTriangle className="text-amber-500" />
            Panic Mode
          </h1>
          <p className="text-sm text-gray-500 mt-1">Configure OTA fallback webview routing</p>
        </div>
        <button
          onClick={() => setShowCreate(true)}
          className="flex items-center gap-2 px-4 py-2 bg-amber-500 text-white rounded-lg hover:bg-amber-600 transition-colors text-sm font-medium"
        >
          <Plus className="h-4 w-4" />
          Add Configuration
        </button>
      </div>

      {showCreate && (
        <div className="bg-surface rounded-xl border-2 border-amber-100 p-6 shadow-sm">
          <h2 className="text-lg font-semibold mb-4 text-amber-900">New Panic Route</h2>
          <form
            onSubmit={(e) => {
              e.preventDefault()
              createMutation.mutate(form)
            }}
            className="space-y-4"
          >
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Target Type</label>
                <select
                  value={form.target_type}
                  onChange={(e) => setForm({ ...form, target_type: e.target.value as any })}
                  className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/50"
                >
                  <option value="global">Global (All Users)</option>
                  <option value="user">Specific User ID</option>
                  <option value="platform">Specific Platform (ios, android)</option>
                  <option value="version">Specific Version (e.g. 1.0.0)</option>
                  <option value="build">Specific Build Number</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Target Value</label>
                <input
                  type="text"
                  value={form.target_value}
                  onChange={(e) => setForm({ ...form, target_value: e.target.value })}
                  placeholder={form.target_type === 'global' ? 'N/A' : 'Enter value...'}
                  disabled={form.target_type === 'global'}
                  className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/50 disabled:bg-gray-50"
                />
              </div>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Fallback Webview URL *</label>
              <input
                type="url"
                value={form.webview_url}
                onChange={(e) => setForm({ ...form, webview_url: e.target.value })}
                placeholder="https://app.beinmed.com/fallback"
                className="w-full px-3 py-2 rounded-lg border border-border text-sm focus:outline-none focus:ring-2 focus:ring-amber-500/50"
                required
              />
            </div>
            <div className="flex gap-3 pt-2">
              <button type="submit" className="px-4 py-2 bg-amber-500 text-white rounded-lg hover:bg-amber-600 text-sm font-medium">
                Activate Route
              </button>
              <button type="button" onClick={() => setShowCreate(false)} className="px-4 py-2 border border-border rounded-lg text-sm text-gray-600 hover:bg-surface-alt">
                Cancel
              </button>
            </div>
          </form>
        </div>
      )}

      {isLoading ? (
        <div className="space-y-3">
          {[...Array(3)].map((_, i) => (
            <div key={i} className="h-20 bg-gray-100 rounded-xl animate-pulse" />
          ))}
        </div>
      ) : (
        <div className="space-y-3">
          {configs?.map((config) => (
            <div key={config.id} className={`bg-surface rounded-xl border ${config.is_active ? 'border-amber-200 shadow-sm' : 'border-border opacity-60'} p-4 flex items-center justify-between`}>
              <div className="flex items-center gap-4">
                <div className={`p-3 rounded-full ${config.is_active ? 'bg-amber-100 text-amber-600' : 'bg-gray-100 text-gray-400'}`}>
                  {getTargetIcon(config.target_type)}
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-semibold text-gray-900 capitalize">{config.target_type}</span>
                    {config.target_value && (
                      <span className="px-1.5 py-0.5 bg-gray-100 text-gray-600 rounded text-xs font-mono">{config.target_value}</span>
                    )}
                  </div>
                  <p className="text-sm text-gray-500 mt-0.5 truncate max-w-md">{config.webview_url}</p>
                </div>
              </div>
              
              <div className="flex items-center gap-3">
                <button
                  onClick={() => updateMutation.mutate({ ...config, is_active: !config.is_active })}
                  className={`p-2 rounded-lg transition-colors ${config.is_active ? 'text-amber-600 hover:bg-amber-50' : 'text-gray-400 hover:bg-gray-100'}`}
                  title={config.is_active ? 'Deactivate' : 'Activate'}
                >
                  <Power className="h-5 w-5" />
                </button>
                <button
                  onClick={() => {
                    if (confirm('Delete this panic configuration?')) {
                      deleteMutation.mutate(config.id)
                    }
                  }}
                  className="p-2 rounded-lg text-red-400 hover:bg-red-50 hover:text-red-600 transition-colors"
                >
                  <Trash2 className="h-5 w-5" />
                </button>
              </div>
            </div>
          ))}
          {configs?.length === 0 && !showCreate && (
            <div className="text-center p-12 bg-surface rounded-xl border border-dashed border-border text-gray-400">
              No panic mode configurations active.
            </div>
          )}
        </div>
      )}
    </div>
  )
}
