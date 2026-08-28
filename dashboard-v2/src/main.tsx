import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import App from './App'
import { AuthProvider, useAuth } from './auth'
import { ToastProvider } from './toast'
import { setUnauthorizedHandler } from './api'
import './styles.css'

setUnauthorizedHandler(() => { window.location.href = '/login' })

function Boot() {
  const { loading } = useAuth()
  if (loading) return <div className="login-wrap"><div>Loading…</div></div>
  return <App />
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <ToastProvider>
          <Boot />
        </ToastProvider>
      </AuthProvider>
    </BrowserRouter>
  </StrictMode>,
)
