import { NavLink } from 'react-router-dom'
import { supabase } from '../lib/supabase'

export default function Sidebar() {
  const active = 'active'
  const logout = async () => {
    await supabase.auth.signOut()
  }
  return (
    <div className="sidebar">
      <div className="brand">Konshisha IGR</div>
      <nav>
        <NavLink to="/" end className={({ isActive }) => (isActive ? active : '')}>
          Dashboard
        </NavLink>
        <NavLink to="/receipts" className={({ isActive }) => (isActive ? active : '')}>
          Receipts
        </NavLink>
        <NavLink to="/agencies" className={({ isActive }) => (isActive ? active : '')}>
          Agencies
        </NavLink>
        <NavLink to="/agents" className={({ isActive }) => (isActive ? active : '')}>
          Agents
        </NavLink>
        <NavLink to="/prints" className={({ isActive }) => (isActive ? active : '')}>
          Print Logs
        </NavLink>
        <NavLink to="/categories" className={({ isActive }) => (isActive ? active : '')}>
          Categories
        </NavLink>
        <NavLink to="/bills" className={({ isActive }) => (isActive ? active : '')}>
          Bills
        </NavLink>
        <NavLink to="/notifications" className={({ isActive }) => (isActive ? active : '')}>
          Notifications
        </NavLink>
        <NavLink to="/security" className={({ isActive }) => (isActive ? active : '')}>
          Security
        </NavLink>
        <NavLink to="/login-logs" className={({ isActive }) => (isActive ? active : '')}>
          Login Activity
        </NavLink>
      </nav>
      <div style={{ padding: '20px', marginTop: 'auto' }}>
        <button className="btn secondary small" onClick={logout}>
          Log out
        </button>
      </div>
    </div>
  )
}
