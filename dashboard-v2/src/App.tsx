import { Routes, Route, Navigate } from 'react-router-dom'
import { useAuth } from './auth'
import Layout from './components/Layout'
import Login from './pages/Login'
import Home from './pages/Home'
import Videos from './pages/Videos'
import Courses from './pages/Courses'
import Users from './pages/Users'
import Codes from './pages/Codes'
import Reports from './pages/Reports'
import Panic from './pages/Panic'
import Settings from './pages/Settings'
import Quizzes from './pages/Quizzes'
import QuizBuilder from './pages/QuizBuilder'
import QBanks from './pages/QBanks'
import QBankDetail from './pages/QBankDetail'
import EnrollmentRequests from './pages/EnrollmentRequests'
import Certificates from './pages/Certificates'

function Guard({ children }: { children: React.ReactNode }) {
  const { user } = useAuth()
  if (!user) return <Navigate to="/login" replace />
  return <>{children}</>
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route element={<Guard><Layout /></Guard>}>
        <Route path="/" element={<Home />} />
        <Route path="/videos" element={<Videos />} />
        <Route path="/courses" element={<Courses />} />
        <Route path="/users" element={<Users />} />
        <Route path="/codes" element={<Codes />} />
        <Route path="/reports" element={<Reports />} />
        <Route path="/panic" element={<Panic />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/quizzes" element={<Quizzes />} />
        <Route path="/quizzes/:id" element={<QuizBuilder />} />
        <Route path="/qbanks" element={<QBanks />} />
        <Route path="/qbanks/:id" element={<QBankDetail />} />
        <Route path="/enrollment" element={<EnrollmentRequests />} />
        <Route path="/certificates" element={<Certificates />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  )
}
