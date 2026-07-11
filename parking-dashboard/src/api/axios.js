import axios from 'axios'

const BASE_URL = 'http://127.0.0.1:8000/api'

const api = axios.create({
  baseURL: BASE_URL,
  timeout: 15000, // hung requests UI ko hamesha ke liye "loading" mein nahi chhodte
})

// ── Request: access token attach ─────────────────────────────────────
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('access_token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// ── Response: 401 → single-flight token refresh → retry ─────────────
// Access token expire hone pe pehle dashboard chupchaap toot jata tha.
// Ab: pehla 401 refresh endpoint hit karta hai, baqi concurrent 401s
// usi refresh ka intezar karte hain (thundering herd nahi), phir sab
// original requests naye token ke saath retry hoti hain. Refresh bhi
// fail ho toh hi login pe bhejte hain.
let refreshPromise = null

async function refreshAccessToken() {
  const refresh = localStorage.getItem('refresh_token')
  if (!refresh) throw new Error('no refresh token')
  // Plain axios — warna interceptor loop ban jata hai
  const res = await axios.post(`${BASE_URL}/auth/token/refresh/`, { refresh })
  const newAccess = res.data.access
  localStorage.setItem('access_token', newAccess)
  // SimpleJWT ROTATE_REFRESH_TOKENS on ho toh naya refresh bhi aata hai
  if (res.data.refresh) localStorage.setItem('refresh_token', res.data.refresh)
  return newAccess
}

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const original = error.config
    const status = error.response?.status

    if (status === 401 && !original._retried) {
      original._retried = true
      try {
        refreshPromise = refreshPromise ?? refreshAccessToken()
        const newAccess = await refreshPromise
        refreshPromise = null
        original.headers.Authorization = `Bearer ${newAccess}`
        return api(original)
      } catch (refreshErr) {
        refreshPromise = null
        // Session sach mein khatam — clean logout
        localStorage.removeItem('access_token')
        localStorage.removeItem('refresh_token')
        if (!window.location.pathname.startsWith('/login')) {
          window.location.href = '/login'
        }
        return Promise.reject(refreshErr)
      }
    }
    return Promise.reject(error)
  }
)

export default api
