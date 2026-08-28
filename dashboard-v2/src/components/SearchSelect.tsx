import { useEffect, useRef, useState } from 'react'

export interface Opt { id: string; label: string; folder?: string; hint?: string }

export default function SearchSelect({
  options, value, onChange, placeholder = 'Search…', testid = 'ss',
}: {
  options: Opt[]
  value: string
  onChange: (id: string) => void
  placeholder?: string
  testid?: string
}) {
  const [open, setOpen] = useState(false)
  const [q, setQ] = useState('')
  const ref = useRef<HTMLDivElement>(null)
  const current = options.find((o) => o.id === value)

  useEffect(() => {
    const close = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', close)
    return () => document.removeEventListener('mousedown', close)
  }, [])

  const filtered = options.filter((o) =>
    o.label.toLowerCase().includes(q.toLowerCase()) ||
    (o.folder || '').toLowerCase().includes(q.toLowerCase()))
  const folders = [...new Set(filtered.map((o) => o.folder || 'General'))].sort()

  return (
    <div ref={ref} style={{ position: 'relative', minWidth: 240 }} data-testid={testid}>
      <button type="button" className="btn ghost" style={{ width: '100%', justifyContent: 'space-between', fontWeight: 400 }}
        onClick={() => { setOpen(!open); setQ('') }}>
        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {current ? `${current.folder ? current.folder + ' / ' : ''}${current.label}` : '— pick a video —'}
        </span>
        <span style={{ color: 'var(--muted)' }}>▾</span>
      </button>
      {open && (
        <div style={{
          position: 'absolute', top: 'calc(100% + 6px)', left: 0, right: 0, zIndex: 40,
          background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 10,
          boxShadow: '0 10px 34px rgba(0,0,0,.5)', maxHeight: 320, overflow: 'auto',
        }}>
          <div style={{ position: 'sticky', top: 0, background: 'var(--surface)', padding: 8, borderBottom: '1px solid var(--border)' }}>
            <input autoFocus placeholder={placeholder} value={q} onChange={(e) => setQ(e.target.value)}
              data-testid={`${testid}-search`} style={{ margin: 0 }} />
          </div>
          {folders.map((f) => (
            <div key={f}>
              <div style={{ padding: '7px 12px 3px', fontSize: 10, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '.05em', color: 'var(--muted)' }}>{f}</div>
              {filtered.filter((o) => (o.folder || 'General') === f).map((o) => (
                <div key={o.id}
                  data-testid={`${testid}-option`}
                  onClick={() => { onChange(o.id); setOpen(false) }}
                  style={{
                    padding: '9px 12px', cursor: 'pointer', fontSize: 13,
                    background: o.id === value ? 'var(--surface2)' : 'transparent',
                    borderLeft: o.id === value ? '2px solid var(--primary)' : '2px solid transparent',
                  }}
                  onMouseEnter={(e) => (e.currentTarget.style.background = 'var(--surface2)')}
                  onMouseLeave={(e) => (e.currentTarget.style.background = o.id === value ? 'var(--surface2)' : 'transparent')}
                >
                  {o.label}{o.hint && <span className="sub" style={{ margin: '0 0 0 8px' }}>{o.hint}</span>}
                </div>
              ))}
            </div>
          ))}
          {filtered.length === 0 && <div className="sub" style={{ padding: 14, textAlign: 'center' }}>No matches</div>}
          {value && (
            <div style={{ borderTop: '1px solid var(--border)' }}>
              <div data-testid={`${testid}-clear`} onClick={() => { onChange(''); setOpen(false) }}
                style={{ padding: '9px 12px', cursor: 'pointer', color: 'var(--red)', fontSize: 13 }}>
                ✕ Detach video
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
