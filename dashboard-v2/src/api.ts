const BASE = '/api/v1'
let token: string | null = localStorage.getItem('lec_token')
let onUnauthorized: (() => void) | null = null

export function setToken(t: string | null) {
  token = t
  if (t) localStorage.setItem('lec_token', t)
  else localStorage.removeItem('lec_token')
}
export function getToken() { return token }
export function setUnauthorizedHandler(fn: () => void) { onUnauthorized = fn }

async function req<T>(method: string, path: string, body?: unknown, isForm = false): Promise<T> {
  const headers: Record<string, string> = {}
  if (token) headers['Authorization'] = `Bearer ${token}`
  if (body !== undefined && !isForm) headers['Content-Type'] = 'application/json'
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    body: isForm ? (body as FormData) : body !== undefined ? JSON.stringify(body) : undefined,
  })
  if (res.status === 401) {
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
  get: <T>(p: string) => req<T>('GET', p),
  post: <T>(p: string, b?: unknown) => req<T>('POST', p, b),
  put: <T>(p: string, b?: unknown) => req<T>('PUT', p, b),
  del: <T>(p: string) => req<T>('DELETE', p),
  postForm: <T>(p: string, f: FormData) => req<T>('POST', p, f, true),
}
