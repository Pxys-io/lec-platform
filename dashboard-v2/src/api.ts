const BASE = '/api/v1'
let token: string | null = localStorage.getItem('lec_token')
let refreshToken: string | null = localStorage.getItem('lec_refresh_token')
let refreshPromise: Promise<boolean> | null = null
let onUnauthorized: (() => void) | null = null

export function setToken(t: string | null) {
  token = t
  if (t) localStorage.setItem('lec_token', t)
  else localStorage.removeItem('lec_token')
}
export function setTokens(access: string | null, refresh: string | null) {
  setToken(access)
  refreshToken = refresh
  if (refresh) localStorage.setItem('lec_refresh_token', refresh)
  else localStorage.removeItem('lec_refresh_token')
}
export function getToken() { return token }
export function setUnauthorizedHandler(fn: () => void) { onUnauthorized = fn }

/** Single-flight refresh: concurrent 401s share one POST /auth/refresh. */
async function tryRefresh(): Promise<boolean> {
  if (!refreshToken) return false
  if (!refreshPromise) {
    refreshPromise = (async () => {
      try {
        const res = await fetch(`${BASE}/auth/refresh?refresh_token=${encodeURIComponent(refreshToken!)}`, { method: 'POST' })
        if (!res.ok) return false
        const j = await res.json()
        setTokens(j.access_token, j.refresh_token)
        return true
      } catch {
        return false
      } finally {
        refreshPromise = null
      }
    })()
  }
  return refreshPromise
}

async function doReq<T>(method: string, path: string, body?: unknown, isForm = false): Promise<T> {
  const headers: Record<string, string> = {}
  if (token) headers['Authorization'] = `Bearer ${token}`
  if (body !== undefined && !isForm) headers['Content-Type'] = 'application/json'
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: isForm ? (body as FormData) : body !== undefined ? JSON.stringify(body) : undefined,
  })
  if (res.status === 401) {
    // Try once to refresh before logging out.
    if (await tryRefresh()) {
      return doReq<T>(method, path, body, isForm)
    }
    setToken(null)
    if (!window.location.pathname.startsWith('/login')) {
      onUnauthorized?.()
    }
    throw new Error('Unauthorized')
  }
  if (!res.ok) {
    let detail = `Error ${res.status}`
    try { const j = await res.json(); detail = typeof j.detail === 'string' ? j.detail : JSON.stringify(j.detail) } catch { /* noop */ }
    throw new Error(detail)
  }
  if (res.status === 204) return undefined as T
  const ct = res.headers.get('content-type') || ''
  return (ct.includes('json') ? res.json() : res.text()) as Promise<T>
}

export const api = {
  get: <T>(p: string) => doReq<T>('GET', p),
  post: <T>(p: string, b?: unknown) => doReq<T>('POST', p, b),
  put: <T>(p: string, b?: unknown) => doReq<T>('PUT', p, b),
  del: <T>(p: string) => doReq<T>('DELETE', p),
  postForm: <T>(p: string, f: FormData) => doReq<T>('POST', p, f, true),
}