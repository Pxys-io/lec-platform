import { useEffect, useState } from 'react'
import { api } from '../api'

interface Stats {
  total_users: number
  total_courses: number
  total_lessons: number
  total_watch_time?: number
  new_users_this_month?: number
  active_users_this_month?: number
}

export default function Home() {
  const [stats, setStats] = useState<Stats | null>(null)
  const [err, setErr] = useState('')
  useEffect(() => {
    api.get<Stats>('/stats/overview').then(setStats).catch((e) => setErr(e.message))
  }, [])

  const cards = stats ? [
    { k: 'Total Users', v: stats.total_users },
    { k: 'Courses', v: stats.total_courses },
    { k: 'Lessons', v: stats.total_lessons },
    { k: 'New (30d)', v: stats.new_users_this_month ?? 0 },
    { k: 'Active (30d)', v: stats.active_users_this_month ?? 0 },
    { k: 'Watch Time', v: `${Math.round((stats.total_watch_time ?? 0) / 60)}m` },
  ] : []

  return (
    <>
      <h1>Overview</h1>
      <p className="sub">Platform statistics at a glance</p>
      {err && <div className="error-box">{err}</div>}
      {!stats && !err && <p className="sub">Loading…</p>}
      <div className="grid g3">
        {cards.map((c) => (
          <div className="card stat" key={c.k} data-testid={`stat-${c.k.replace(/\s/g, '-').toLowerCase()}`}>
            <div className="k">{c.k}</div>
            <div className="v">{c.v}</div>
          </div>
        ))}
      </div>
    </>
  )
}
