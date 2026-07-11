import { useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'

/**
 * RealtimeBridge — server ke change-events ko query cache invalidation
 * se jorta hai. Yeh production pattern hai: data tab refetch hota hai
 * jab KUCH BADLA ho, na ke har X seconds.
 *
 * main.jsx mein QueryClientProvider ke andar ek dafa render hota hai.
 * Connection toot jaye to exponential backoff se reconnect, aur us
 * doran TanStack Query ke polling intervals fallback ka kaam karte
 * hain — system kabhi "stale forever" nahi hota.
 */

const WS_URL = 'ws://127.0.0.1:8000/ws/events/'

// Kaunsa server event kaunsi queries taaza karta hai
const EVENT_MAP = {
  'slots.changed':    [['slots'], ['sites']],
  'bookings.changed': [['bookings'], ['owner', 'dashboard'], ['admin', 'stats']],
  'payments.changed': [['payments'], ['owner', 'dashboard']],
  'notification':     [['notifications']],
}

export default function RealtimeBridge() {
  const queryClient = useQueryClient()

  useEffect(() => {
    let ws = null
    let retryMs = 1000
    let closedByUs = false
    let retryTimer = null

    function connect() {
      const token = localStorage.getItem('access_token')
      if (!token) {
        // Login se pehle koi connection nahi — thodi der baad phir dekho
        retryTimer = setTimeout(connect, 5000)
        return
      }

      ws = new WebSocket(WS_URL)

      ws.onopen = () => {
        // Same auth handshake as gate consumers
        ws.send(JSON.stringify({ token }))
      }

      ws.onmessage = (e) => {
        let msg
        try { msg = JSON.parse(e.data) } catch { return }

        if (msg.type === 'auth_success') {
          retryMs = 1000 // connection healthy — backoff reset
          return
        }
        const keys = EVENT_MAP[msg.event]
        if (keys) {
          keys.forEach((k) => queryClient.invalidateQueries({ queryKey: k }))
        }
      }

      ws.onclose = () => {
        if (closedByUs) return
        // Exponential backoff, max 30s
        retryTimer = setTimeout(connect, retryMs)
        retryMs = Math.min(retryMs * 2, 30_000)
      }

      ws.onerror = () => ws.close()
    }

    connect()

    return () => {
      closedByUs = true
      clearTimeout(retryTimer)
      ws?.close()
    }
  }, [queryClient])

  return null
}
