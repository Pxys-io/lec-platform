import { type ReactNode } from 'react'
import { useAuth } from '../lib/auth'
import Sidebar from './Sidebar'

export default function Layout({ children }: { children: ReactNode }) {
  const { user } = useAuth()

  return (
    <div className="flex min-h-screen bg-surface-alt">
      <Sidebar />
      <main className="flex-1 overflow-auto">
        <header className="h-16 bg-surface border-b border-border flex items-center justify-between px-6 sticky top-0 z-10">
          <div />
          <div className="flex items-center gap-3">
            <span className="text-sm text-gray-500 capitalize">{user?.role?.replace('_', ' ')}</span>
            <div className="h-9 w-9 rounded-full bg-primary flex items-center justify-center text-white font-semibold text-sm">
              {user?.email?.[0].toUpperCase()}
            </div>
          </div>
        </header>
        <div className="p-6">
          {children}
        </div>
      </main>
    </div>
  )
}