import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { api, setTokens, getToken } from './api'

export interface User {
  id: string
  email: string
  phone: string | null
  role: string
  banned_until: string | null
  first_name?: string
  last_name?: string
}

interface AuthCtx {
  user: User | null
  loading: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => void
  isStaff: boolean
}

const Ctx = createContext<AuthCtx>({ user: null, loading: true, login: async () => {}, logout: () => {}, isStaff: false })

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!getToken()) { setLoading(false); return }
    api.get<User>('/auth/me')
      .then(setUser)
      .catch(() => setTokens(null, null))
      .finally(() => setLoading(false))
  }, [])

  const login = async (email: string, password: string) => {
    const d = await api.post<{ access_token: string; refresh_token: string }>('/auth/login', { email, password })
    setTokens(d.access_token, d.refresh_token)
    setUser(await api.get<User>('/auth/me'))
  }
  const logout = () => { api.post('/auth/logout').catch(() => {}); setTokens(null, null); setUser(null) }

  const isStaff = !!user && ['admin', 'super_admin', 'instructor'].includes(user.role)
  return <Ctx.Provider value={{ user, loading, login, logout, isStaff }}>{children}</Ctx.Provider>
}
export const useAuth = () => useContext(Ctx)
