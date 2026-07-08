import { createContext, useContext, useState, useEffect, type ReactNode } from 'react'
import { api, setToken, getToken } from './api'

interface User {
  id: string
  email: string
  phone: string | null
  role: string
  created_at: string
  last_login: string | null
  banned_until: string | null
  profile?: {
    first_name: string | null
    last_name: string | null
    avatar_url: string | null
  }
}

interface AuthContextType {
  user: User | null
  loading: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => void
  isAdmin: boolean
  isSuperAdmin: boolean
  isInstructor: boolean
}

const AuthContext = createContext<AuthContextType | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const t = getToken()
    if (t) {
      api
        .get<User>('/auth/me')
        .then(setUser)
        .catch(() => setToken(null))
        .finally(() => setLoading(false))
    } else {
      setLoading(false)
    }
  }, [])

  const login = async (email: string, password: string) => {
    const data = await api.post<{ access_token: string }>('/auth/login', {
      email,
      password,
    })
    setToken(data.access_token)
    const me = await api.get<User>('/auth/me')
    setUser(me)
  }

  const logout = () => {
    api.post('/auth/logout').catch(() => {})
    setToken(null)
    setUser(null)
  }

  const role = user?.role || ''
  const isAdmin = role === 'admin' || role === 'super_admin'
  const isSuperAdmin = role === 'super_admin'
  const isInstructor = role === 'instructor' || isAdmin

  return (
    <AuthContext.Provider
      value={{ user, loading, login, logout, isAdmin, isSuperAdmin, isInstructor }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
