import { ReactNode } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { useAuth } from '../auth'

const NAV = [
  { to: '/', ico: '◆', label: 'Overview', end: true },
  { to: '/videos', ico: '▶', label: 'Videos' },
  { to: '/courses', ico: '▤', label: 'Courses' },
  { to: '/users', ico: '☺', label: 'Users' },
  { to: '/codes', ico: '#', label: 'Access Codes' },
  { to: '/reports', ico: '!', label: 'Reports' },
  { to: '/panic', ico: '⚠', label: 'Panic Mode' },
  { to: '/settings', ico: '⚙', label: 'Settings' },
]

export default function Layout({ children }: { children?: ReactNode }) {
  const { user, logout } = useAuth()
  const nav = useNavigate()
  return (
    <div className="layout">
      <aside className="sidebar">
        <div className="logo"><span className="mark">L</span> LEC Admin</div>
        {NAV.map((n) => (
          <NavLink key={n.to} to={n.to} end={n.end} className={({ isActive }) => `nav-item${isActive ? ' active' : ''}`}>
            <span className="ico">{n.ico}</span> {n.label}
          </NavLink>
        ))}
        <div className="spacer" />
        <div className="who">
          <b>{user?.first_name || user?.email?.split('@')[0]}</b>
          {user?.role} · <a href="#" onClick={(e) => { e.preventDefault(); logout(); nav('/login') }}>Sign out</a>
        </div>
      </aside>
      <main className="main"><Outlet /></main>
    </div>
  )
}
