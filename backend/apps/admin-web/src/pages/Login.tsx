import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { logLogin } from '../lib/logLogin'

export default function Login() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const navigate = useNavigate()

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) {
      setError(error.message)
      await logLogin({ email, success: false, failure_reason: error.message })
      return
    }
    await logLogin({
      email,
      success: true,
      user_id: data.user?.id ?? null,
      display_name: (data.user?.user_metadata as any)?.display_name ?? null,
    })
    // also bump last_login_at for quick Agents table sorting
    if (data.user?.id) {
      supabase.from('profiles').update({ last_login_at: new Date().toISOString() }).eq('id', data.user.id).then(() => {})
    }
    navigate('/')
  }

  return (
    <div className="login-wrap">
      <div style={{ textAlign: 'center', marginBottom: 20 }}>
        <div style={{ fontSize: '0.8rem', letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--muted)', fontWeight: 600 }}>
          Konshisha IGR
        </div>
        <h1 style={{ margin: '6px 0 4px', fontSize: '1.5rem' }}>Welcome back</h1>
        <p style={{ margin: 0, color: 'var(--muted)', fontSize: '0.9rem', lineHeight: 1.5 }}>
          Official Government Collection Portal
          <br />
          Sign in to continue to the Admin Console
        </p>
      </div>
      <form onSubmit={onSubmit}>
        <div className="form-row">
          <label>Email</label>
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
        </div>
        <div className="form-row">
          <label>Password</label>
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} required />
        </div>
        {error && <div className="error">{error}</div>}
        <button type="submit" className="btn" style={{ width: '100%' }}>
          Sign in
        </button>
      </form>
    </div>
  )
}
