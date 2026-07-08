import { useState } from 'react'
import { NavLink, useNavigate } from 'react-router-dom'
import { useAuth } from '../lib/auth'
import {
  LayoutDashboard,
  Users,
  BookOpen,
  FileText,
  HelpCircle,
  Flag,
  Ticket,
  Award,
  LogOut,
  Menu,
  X,
  ChevronDown,
  Video,
  AlertTriangle,
  Settings,
} from 'lucide-react'
import { cn } from '../lib/cn'

const navItems = [
  { to: '/', icon: LayoutDashboard, label: 'Dashboard', roles: ['super_admin', 'admin', 'instructor'] },
  { to: '/users', icon: Users, label: 'Users', roles: ['super_admin', 'admin'] },
  { to: '/courses', icon: BookOpen, label: 'Courses', roles: ['super_admin', 'admin', 'instructor'] },
  { to: '/qbanks', icon: HelpCircle, label: 'QBanks', roles: ['super_admin', 'admin', 'instructor'] },
  { to: '/videos', icon: Video, label: 'Videos', roles: ['super_admin', 'admin', 'instructor'] },
  { to: '/lessons', icon: FileText, label: 'Lessons', roles: ['super_admin', 'admin', 'instructor'] },
  { to: '/quizzes', icon: HelpCircle, label: 'Quizzes', roles: ['super_admin', 'admin', 'instructor'] },
  { to: '/panic-mode', icon: AlertTriangle, label: 'Panic Mode', roles: ['super_admin', 'admin'] },
  { to: '/reports', icon: Flag, label: 'Reports', roles: ['super_admin', 'admin', 'instructor'] },
  { to: '/codes', icon: Ticket, label: 'Access Codes', roles: ['super_admin', 'admin', 'instructor'] },
  { to: '/enrollment-requests', icon: FileText, label: 'Enrollment Requests', roles: ['super_admin', 'admin', 'instructor'] },
  { to: '/certificates', icon: Award, label: 'Certificates', roles: ['super_admin', 'admin', 'instructor'] },
  { to: '/settings', icon: Settings, label: 'Settings', roles: ['super_admin'] },
]

export default function Sidebar() {
  const { user, logout, isInstructor } = useAuth()
  const navigate = useNavigate()
  const [collapsed, setCollapsed] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)

  const handleLogout = () => {
    logout()
    navigate('/login')
  }

  const filteredNav = navItems.filter(
    (item) => user && item.roles.some((r) => user.role === r || (r === 'admin' && user.role === 'super_admin') || (r === 'instructor' && isInstructor))
  )

  const navLinks = (
    <nav className="flex flex-col gap-1 px-3">
      {filteredNav.map((item) => (
        <NavLink
          key={item.to}
          to={item.to}
          onClick={() => setMobileOpen(false)}
          className={({ isActive }) =>
            cn(
              'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors',
              isActive
                ? 'bg-primary text-white'
                : 'text-sidebar-text hover:bg-sidebar-hover hover:text-white'
            )
          }
        >
          <item.icon className="h-5 w-5 shrink-0" />
          {!collapsed && <span>{item.label}</span>}
        </NavLink>
      ))}
    </nav>
  )

  return (
    <>
      <button
        onClick={() => setMobileOpen(true)}
        className="lg:hidden fixed top-4 left-4 z-50 p-2 rounded-lg bg-sidebar text-white"
      >
        <Menu className="h-5 w-5" />
      </button>

      {mobileOpen && (
        <div className="lg:hidden fixed inset-0 z-40 bg-black/50" onClick={() => setMobileOpen(false)} />
      )}

      <aside
        className={cn(
          'fixed lg:static inset-y-0 left-0 z-50 flex flex-col bg-sidebar transition-all duration-200',
          collapsed ? 'w-20' : 'w-64',
          mobileOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'
        )}
      >
        <div className="flex items-center justify-between h-16 px-4 border-b border-sidebar-hover shrink-0">
          {!collapsed && <h1 className="text-white font-bold text-lg">LEC Admin</h1>}
          <button
            onClick={() => setMobileOpen(false)}
            className="lg:hidden text-sidebar-text hover:text-white"
          >
            <X className="h-5 w-5" />
          </button>
          <button
            onClick={() => setCollapsed(!collapsed)}
            className="hidden lg:block text-sidebar-text hover:text-white"
          >
            <ChevronDown className={cn('h-5 w-5 transition-transform', collapsed && '-rotate-90')} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto py-4">
          {navLinks}
        </div>

        <div className="px-3 py-4 border-t border-sidebar-hover shrink-0">
          <button
            onClick={handleLogout}
            className="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium text-sidebar-text hover:bg-red-500/10 hover:text-red-400 transition-colors w-full"
          >
            <LogOut className="h-5 w-5 shrink-0" />
            {!collapsed && <span>Logout</span>}
          </button>
        </div>
      </aside>
    </>
  )
}