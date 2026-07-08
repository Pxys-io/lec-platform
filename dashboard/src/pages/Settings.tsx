import { useState, useEffect } from 'react'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { Save, AlertTriangle, CheckCircle, ToggleLeft, Code } from 'lucide-react'

interface EnvConfig {
  module: string
  path: string
  content: string
}

interface EnvEntry {
  key: string
  value: string
  raw: string
}

function parseEnv(content: string): EnvEntry[] {
  return content.split('\n').map(line => {
    const match = line.match(/^([^#=]+)=(.*)$/)
    if (match) {
      return { key: match[1].trim(), value: match[2].trim(), raw: line }
    }
    return { key: '', value: '', raw: line }
  })
}

function serializeEnv(entries: EnvEntry[]): string {
  return entries.map(e => {
    if (!e.key) return e.raw
    return `${e.key}=${e.value}`
  }).join('\n')
}

function isBoolean(val: string) {
  return val === 'true' || val === 'false'
}

function isNumber(val: string) {
  return /^\d+(\.\d+)?$/.test(val)
}

function isUrl(val: string) {
  return val.startsWith('http://') || val.startsWith('https://')
}

function isPort(val: string) {
  return /^\d+$/.test(val) && parseInt(val) >= 0 && parseInt(val) <= 65535
}

export default function Settings() {
  const { user } = useAuth()
  const [configs, setConfigs] = useState<EnvConfig[]>([])
  const [entries, setEntries] = useState<Record<string, EnvEntry[]>>({})
  const [rawMode, setRawMode] = useState<Record<string, boolean>>({})
  const [rawContents, setRawContents] = useState<Record<string, string>>({})
  const [saving, setSaving] = useState<string | null>(null)
  const [msg, setMsg] = useState<{ type: 'ok' | 'err'; text: string } | null>(null)

  useEffect(() => {
    api.get<EnvConfig[]>('/misc/env-config').then(data => {
      setConfigs(data)
      const parsed: Record<string, EnvEntry[]> = {}
      const raws: Record<string, string> = {}
      for (const cfg of data) {
        parsed[cfg.module] = parseEnv(cfg.content)
        raws[cfg.module] = cfg.content
      }
      setEntries(parsed)
      setRawContents(raws)
    }).catch(() => setMsg({ type: 'err', text: 'Failed to load configs' }))
  }, [])

  const updateEntry = (mod: string, idx: number, value: string) => {
    setEntries(prev => {
      const next = { ...prev }
      const copy = [...next[mod]]
      copy[idx] = { ...copy[idx], value }
      next[mod] = copy
      return next
    })
  }

  const save = async (mod: string) => {
    setSaving(mod)
    setMsg(null)
    try {
      const content = rawMode[mod] ? (rawContents[mod] ?? '') : serializeEnv(entries[mod] ?? [])
      await api.put(`/misc/env-config/${mod}`, { content })
      setMsg({ type: 'ok', text: `${mod} .env saved` })
    } catch (e) {
      setMsg({ type: 'err', text: `Failed: ${e}` })
    }
    setSaving(null)
  }

  if (!user || user.role !== 'super_admin') {
    return <div className="text-center py-20 text-gray-500">Super admin access required</div>
  }

  return (
    <div className="space-y-8 max-w-4xl">
      <h1 className="text-2xl font-bold text-gray-900">Server Settings</h1>

      {msg && (
        <div className={`flex items-center gap-2 text-sm px-4 py-3 rounded-lg ${msg.type === 'ok' ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'}`}>
          {msg.type === 'ok' ? <CheckCircle className="h-4 w-4" /> : <AlertTriangle className="h-4 w-4" />}
          {msg.text}
        </div>
      )}

      {configs.map((cfg) => {
        const isRaw = rawMode[cfg.module]
        const moduleEntries = entries[cfg.module] ?? []

        return (
          <div key={cfg.module} className="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
            <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100 bg-gray-50">
              <div>
                <h2 className="text-sm font-semibold text-gray-900">{cfg.module}</h2>
                <p className="text-xs text-gray-500 font-mono">{cfg.path}</p>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setRawMode(prev => ({ ...prev, [cfg.module]: !isRaw }))}
                  className={`flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-lg border transition-colors ${isRaw ? 'bg-primary text-white border-primary' : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50'}`}
                >
                  {isRaw ? <ToggleLeft className="h-3.5 w-3.5" /> : <Code className="h-3.5 w-3.5" />}
                  {isRaw ? 'Form View' : 'Raw'}
                </button>
                <button
                  onClick={() => save(cfg.module)}
                  disabled={saving === cfg.module}
                  className="flex items-center gap-1.5 px-3 py-1.5 bg-primary text-white text-sm rounded-lg hover:bg-primary-dark transition-colors disabled:opacity-50"
                >
                  <Save className="h-3.5 w-3.5" />
                  {saving === cfg.module ? 'Saving...' : 'Save'}
                </button>
              </div>
            </div>

            {isRaw ? (
              <textarea
                value={rawContents[cfg.module] ?? ''}
                onChange={(e) => setRawContents(prev => ({ ...prev, [cfg.module]: e.target.value }))}
                className="w-full p-4 text-xs font-mono bg-white text-gray-800 border-0 resize-y focus:outline-none focus:ring-0"
                style={{ minHeight: '200px' }}
                spellCheck={false}
              />
            ) : (
              <div className="divide-y divide-gray-100">
                {moduleEntries.map((entry, idx) => {
                  if (!entry.key) {
                    return (
                      <div key={idx} className="px-5 py-2 text-xs text-gray-400 italic">
                        {entry.raw || <br />}
                      </div>
                    )
                  }

                  const val = entry.value
                  let input: JSX.Element

                  if (isBoolean(val)) {
                    input = (
                      <label className="relative inline-flex items-center cursor-pointer">
                        <input
                          type="checkbox"
                          checked={val === 'true'}
                          onChange={(e) => updateEntry(cfg.module, idx, e.target.checked ? 'true' : 'false')}
                          className="sr-only peer"
                        />
                        <div className="w-9 h-5 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-primary"></div>
                      </label>
                    )
                  } else if (isPort(val)) {
                    input = (
                      <input
                        type="number"
                        min={0}
                        max={65535}
                        value={val}
                        onChange={(e) => updateEntry(cfg.module, idx, e.target.value)}
                        className="w-24 px-2 py-1.5 border border-gray-200 rounded-lg text-xs font-mono focus:outline-none focus:ring-2 focus:ring-primary/50"
                      />
                    )
                  } else if (isUrl(val)) {
                    input = (
                      <input
                        type="url"
                        value={val}
                        onChange={(e) => updateEntry(cfg.module, idx, e.target.value)}
                        className="flex-1 min-w-0 px-2 py-1.5 border border-gray-200 rounded-lg text-xs font-mono focus:outline-none focus:ring-2 focus:ring-primary/50"
                      />
                    )
                  } else if (isNumber(val)) {
                    input = (
                      <input
                        type="number"
                        value={val}
                        onChange={(e) => updateEntry(cfg.module, idx, e.target.value)}
                        className="w-28 px-2 py-1.5 border border-gray-200 rounded-lg text-xs font-mono focus:outline-none focus:ring-2 focus:ring-primary/50"
                      />
                    )
                  } else {
                    input = (
                      <input
                        type="text"
                        value={val}
                        onChange={(e) => updateEntry(cfg.module, idx, e.target.value)}
                        className="flex-1 min-w-0 px-2 py-1.5 border border-gray-200 rounded-lg text-xs font-mono focus:outline-none focus:ring-2 focus:ring-primary/50"
                      />
                    )
                  }

                  return (
                    <div key={idx} className="flex items-center gap-3 px-5 py-2.5 hover:bg-gray-50/50 transition-colors">
                      <span className="text-xs font-mono font-medium text-gray-700 min-w-[200px] max-w-[200px] truncate" title={entry.key}>
                        {entry.key}
                      </span>
                      <div className="flex-1 flex justify-end">
                        {input}
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        )
      })}
    </div>
  )
}
