import { createContext, useCallback, useContext, useState, type ReactNode } from 'react'

interface Toast { id: number; msg: string; err: boolean }
const Ctx = createContext<{ toast: (m: string, e?: boolean) => void }>({ toast: () => {} })

export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<Toast[]>([])
  const toast = useCallback((msg: string, err = false) => {
    const id = Date.now() + Math.random()
    setItems((x) => [...x, { id, msg, err }])
    setTimeout(() => setItems((x) => x.filter((t) => t.id !== id)), 4200)
  }, [])
  return (
    <Ctx.Provider value={{ toast }}>
      {children}
      {items.map((t) => (
        <div key={t.id} className={`toast${t.err ? ' err' : ''}`}>{t.msg}</div>
      ))}
    </Ctx.Provider>
  )
}
export const useToast = () => useContext(Ctx)
