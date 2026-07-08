import { Routes, Route, Navigate } from 'react-router-dom'
import { useAuth } from './lib/auth'
import Layout from './components/Layout'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import Users from './pages/Users'
import UserDetail from './pages/UserDetail'
import Courses from './pages/Courses'
import CourseDetail from './pages/CourseDetail'
import Videos from './pages/Videos'
import Lessons from './pages/Lessons'
import LessonDetail from './pages/LessonDetail'
import LessonEdit from './pages/LessonEdit'
import Quizzes from './pages/Quizzes'
import QuizBuilder from './pages/QuizBuilder'
import QBanks from './pages/QBanks'
import QBankDetail from './pages/QBankDetail'
import PanicMode from './pages/PanicMode'
import Reports from './pages/Reports'
import AccessCodes from './pages/AccessCodes'
import Certificates from './pages/Certificates'
import EnrollmentRequests from './pages/EnrollmentRequests'
import Settings from './pages/Settings'

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth()
  if (loading) return <div className="flex items-center justify-center min-h-screen"><div className="animate-spin h-8 w-8 border-2 border-primary border-t-transparent rounded-full" /></div>
  if (!user) return <Navigate to="/login" replace />
  return <>{children}</>
}

export default function App() {
  return (
        <Routes>
              <Route path="/login" element={<Login />} />
              <Route
                path="/*"
                element={
                  <ProtectedRoute>
                    <Layout>
                      <Routes>
                        <Route path="/" element={<Dashboard />} />
                        <Route path="/users" element={<Users />} />
                        <Route path="/users/:id" element={<UserDetail />} />
                        <Route path="/courses" element={<Courses />} />
                        <Route path="/courses/:id" element={<CourseDetail />} />
                        <Route path="/videos" element={<Videos />} />
                        <Route path="/lessons" element={<Lessons />} />
                        <Route path="/lessons/:id" element={<LessonDetail />} />
                        <Route path="/lessons/:id/edit" element={<LessonEdit />} />
                        <Route path="/quizzes" element={<Quizzes />} />
                        <Route path="/quizzes/new" element={<QuizBuilder />} />
                        <Route path="/quizzes/:id" element={<QuizBuilder />} />
                        <Route path="/qbanks" element={<QBanks />} />
                        <Route path="/qbanks/:id" element={<QBankDetail />} />
                        <Route path="/panic-mode" element={<PanicMode />} />
                        <Route path="/reports" element={<Reports />} />
                        <Route path="/codes" element={<AccessCodes />} />
                        <Route path="/enrollment-requests" element={<EnrollmentRequests />} />
                        <Route path="/certificates" element={<Certificates />} />
                        <Route path="/settings" element={<Settings />} />
                        <Route path="*" element={<Navigate to="/" replace />} />
                      </Routes>
                    </Layout>
                  </ProtectedRoute>
                }
              />
            </Routes>
  )
}
