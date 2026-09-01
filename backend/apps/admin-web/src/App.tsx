import { useEffect, useState } from 'react'
import { Routes, Route, useNavigate, useLocation } from 'react-router-dom'
import { supabase, isConfigured } from './lib/supabase'
import Dashboard from './pages/Dashboard'
import Receipts from './pages/Receipts'
import Agencies from './pages/Agencies'
import Agents from './pages/Agents'
import PrintLogs from './pages/PrintLogs'
import Categories from './pages/Categories'
import Notifications from './pages/Notifications'
import Security from './pages/Security'
import Bills from './pages/Bills'
import LoginLogs from './pages/LoginLogs'
import Reports from './pages/Reports'
import Sidebar from './components/Sidebar'
import Login from './pages/Login'

export default function App() {
  const [session, setSession] = useState<null | object>(null)
  const [loading, setLoading] = useState(true)
  const navigate = useNavigate()
  const location = useLocation()

  useEffect(() => {
    if (!isConfigured) {
      setLoading(false)
      return
    }
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session)
      setLoading(false)
    })
    const { data: listener } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session)
    })
    return () => listener?.subscription.unsubscribe()
  }, [])

  useEffect(() => {
    if (!loading && !session && location.pathname !== '/login') navigate('/login')
  }, [loading, session, navigate, location])

  if (!isConfigured) {
    return (
      <div className="login-wrap">
        <h1>Missing configuration</h1>
        <p>
          Set <code>VITE_SUPABASE_URL</code> and <code>VITE_SUPABASE_PUBLISHABLE_KEY</code> in{' '}
          <code>apps/admin-web/.env</code>, then restart.
        </p>
      </div>
    )
  }

  if (loading) return <div className="content">Loading…</div>

  if (!session) {
    return (
      <Routes>
        <Route path="*" element={<Login />} />
      </Routes>
    )
  }

  return (
    <div className="layout">
      <Sidebar />
      <div className="content">
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/receipts" element={<Receipts />} />
          <Route path="/agencies" element={<Agencies />} />
          <Route path="/agents" element={<Agents />} />
          <Route path="/prints" element={<PrintLogs />} />
          <Route path="/categories" element={<Categories />} />
          <Route path="/bills" element={<Bills />} />
          <Route path="/notifications" element={<Notifications />} />
          <Route path="/security" element={<Security />} />
          <Route path="/login-logs" element={<LoginLogs />} />
          <Route path="/reports" element={<Reports />} />
          <Route path="*" element={<Dashboard />} />
        </Routes>
      </div>
    </div>
  )
}
