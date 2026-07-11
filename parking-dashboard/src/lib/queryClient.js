import { QueryClient } from '@tanstack/react-query'

/**
 * Central cache config — poore dashboard ka data-fetching brain.
 *
 * - staleTime 10s  : is window mein dobara mount hone wala component
 *                    cache se INSTANTLY render hota hai, koi spinner nahi.
 * - refetch on focus/reconnect: tab pe wapas aao ya net wapas aaye
 *                    to data khud taaza ho jata hai.
 * - retry 1        : ek transient failure khud handle, spam nahi.
 * - placeholderData: refetch ke doran purana data dikhta rehta hai
 *                    (stale-while-revalidate) — UI kabhi blank nahi hota.
 */
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 10_000,
      gcTime: 5 * 60_000,
      retry: 1,
      refetchOnWindowFocus: true,
      refetchOnReconnect: true,
      placeholderData: (prev) => prev,
    },
  },
})
