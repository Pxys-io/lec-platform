import { useQuery } from '@tanstack/react-query'
import { api } from '../lib/api'
import { useAuth } from '../lib/auth'
import { Award, Search, ExternalLink } from 'lucide-react'
import { useState } from 'react'

interface Certificate {
  id: number
  title: string
  description: string
  issued_at: string
  expiry_date: string | null
  certificate_hash: string
  user_id: number
  course_id: number
  user?: { email: string }
  course?: { title: string }
}

export default function Certificates() {
  const { isInstructor } = useAuth()
  const [search, setSearch] = useState('')

  const { data: certs, isLoading } = useQuery<Certificate[]>({
    queryKey: ['certificates'],
    queryFn: () => api.get('/certificates/all'),
    enabled: isInstructor,
  })

  const filtered = certs?.filter((c) =>
    c.title.toLowerCase().includes(search.toLowerCase()) ||
    c.user?.email?.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Certificates</h1>
        <p className="text-sm text-gray-500 mt-1">View all issued certificates</p>
      </div>

      <div className="relative max-w-sm">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full pl-10 pr-4 py-2 rounded-lg border border-border bg-surface text-sm focus:outline-none focus:ring-2 focus:ring-primary/50"
          placeholder="Search certificates..."
        />
      </div>

      {isLoading ? (
        <div className="space-y-2">
          {[...Array(3)].map((_, i) => <div key={i} className="h-16 bg-gray-100 rounded-xl animate-pulse" />)}
        </div>
      ) : (
        <div className="bg-surface rounded-xl border border-border overflow-hidden">
          <table className="w-full">
            <thead>
              <tr className="border-b border-border bg-surface-alt">
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Certificate</th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">User</th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Course</th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Issued</th>
                <th className="text-left px-4 py-3 text-xs font-medium text-gray-500 uppercase">Expiry</th>
                <th className="text-right px-4 py-3 text-xs font-medium text-gray-500 uppercase">Hash</th>
              </tr>
            </thead>
            <tbody>
              {filtered?.map((cert) => (
                <tr key={cert.id} className="border-b border-border last:border-0 hover:bg-surface-alt/50 transition-colors">
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-3">
                      <div className="p-2 rounded-lg bg-amber-100">
                        <Award className="h-4 w-4 text-amber-600" />
                      </div>
                      <span className="text-sm font-medium text-gray-900">{cert.title}</span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500">{cert.user?.email || `User #${cert.user_id}`}</td>
                  <td className="px-4 py-3 text-sm text-gray-500">{cert.course?.title || `Course #${cert.course_id}`}</td>
                  <td className="px-4 py-3 text-sm text-gray-500">
                    {new Date(cert.issued_at).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-500">
                    {cert.expiry_date ? new Date(cert.expiry_date).toLocaleDateString() : 'Never'}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <span className="font-mono text-xs text-gray-400">
                      {cert.certificate_hash.slice(0, 12)}...
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {filtered?.length === 0 && (
            <div className="p-8 text-center text-sm text-gray-400">No certificates issued yet</div>
          )}
        </div>
      )}
    </div>
  )
}
