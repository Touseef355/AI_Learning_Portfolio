import { useQuery, useQueryClient } from '@tanstack/react-query'
import api from './axios'

/**
 * Poore dashboard ke data hooks — ek jagah, consistent poll intervals.
 *
 * Interval philosophy:
 *   - LIVE     (5–10s) : slot occupancy, pending gate queues — cashier ops
 *   - ACTIVE  (15–30s) : bookings, payments — lists jo demo mein badalti hain
 *   - SLOW  (60s–manual): stats, users, settings — kam badalne wala data
 *
 * Har hook TanStack Query deta hai: pehli load pe `isPending` (spinner),
 * uske baad silent background refetches — placeholderData ki wajah se
 * purana data kabhi gayab nahi hota.
 */

// Realtime events (RealtimeBridge) primary mechanism hain — yeh intervals
// ab sirf FALLBACK hain jab WebSocket disconnected ho. Isi liye dheele.
const LIVE = 30_000
const ACTIVE = 60_000
const SLOW = 120_000

// ── Shared fetcher ───────────────────────────────────────────────────
const get = (url) => api.get(url).then((r) => r.data)

// ── Parking / slots ──────────────────────────────────────────────────
export const useSites = () =>
  useQuery({ queryKey: ['sites'], queryFn: () => get('/parking/sites/'), refetchInterval: SLOW })

export const useSiteSlots = (siteId) =>
  useQuery({
    queryKey: ['slots', siteId],
    queryFn: () => get(`/parking/sites/${siteId}/slots/`),
    enabled: !!siteId,
    refetchInterval: LIVE, // live occupancy grid
  })

// ── Bookings ─────────────────────────────────────────────────────────
export const useOwnerBookings = () =>
  useQuery({ queryKey: ['bookings', 'owner'], queryFn: () => get('/bookings/owner/'), refetchInterval: ACTIVE })

export const useAdminBookings = () =>
  useQuery({ queryKey: ['bookings', 'admin'], queryFn: () => get('/bookings/admin/'), refetchInterval: ACTIVE })

// ── Payments ─────────────────────────────────────────────────────────
export const useOwnerPayments = () =>
  useQuery({ queryKey: ['payments', 'owner'], queryFn: () => get('/payments/owner/'), refetchInterval: ACTIVE })

export const useAdminPayments = () =>
  useQuery({ queryKey: ['payments', 'admin'], queryFn: () => get('/payments/admin/'), refetchInterval: ACTIVE })

// ── Admin ────────────────────────────────────────────────────────────
export const useAdminStats = () =>
  useQuery({ queryKey: ['admin', 'stats'], queryFn: () => get('/auth/admin/stats/'), refetchInterval: ACTIVE })

export const useAdminUsers = (role) =>
  useQuery({
    queryKey: ['admin', 'users', role],
    queryFn: () => get(`/auth/admin/users/?role=${role}`),
    refetchInterval: SLOW,
  })

export const useSystemLogs = () =>
  useQuery({ queryKey: ['admin', 'logs'], queryFn: () => get('/auth/admin/logs/'), refetchInterval: ACTIVE })

// ── Owner ────────────────────────────────────────────────────────────
export const useOwnerDashboard = () =>
  useQuery({ queryKey: ['owner', 'dashboard'], queryFn: () => get('/auth/owner/dashboard/'), refetchInterval: ACTIVE })

export const useCashiers = () =>
  useQuery({ queryKey: ['owner', 'cashiers'], queryFn: () => get('/auth/owner/cashiers/'), refetchInterval: SLOW })

// ── AI gate queues ───────────────────────────────────────────────────
export const usePendingEntries = () =>
  useQuery({ queryKey: ['ai', 'pending-entry'], queryFn: () => get('/ai/pending/'), refetchInterval: LIVE })

export const usePendingExits = () =>
  useQuery({ queryKey: ['ai', 'pending-exit'], queryFn: () => get('/ai/pending-exit/'), refetchInterval: LIVE })

/**
 * Mutation ke baad related lists foran taaza karne ke liye:
 *   const invalidate = useInvalidate()
 *   await api.post('/ai/approve/', ...)
 *   invalidate(['slots'], ['bookings'])
 * WebSocket message aane pe bhi yehi call karo — real-time invalidation.
 */
export const useInvalidate = () => {
  const qc = useQueryClient()
  return (...keys) => keys.forEach((k) => qc.invalidateQueries({ queryKey: k }))
}
