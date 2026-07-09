import { useEffect, useState } from 'react'
import { getUser } from '../../utils/auth'
import { Car, SquareParking, Banknote, AlertTriangle, Clock, CheckCircle } from 'lucide-react'
import api from '../../api/axios'

function StatCard({ title, value, subtitle, icon: Icon, colorClass, bgClass }) {
  return (
    <div className="bg-card border border-border rounded-xl p-5 flex items-center gap-4">
      <div className={`w-11 h-11 rounded-xl ${bgClass} flex items-center justify-center flex-shrink-0`}>
        <Icon className={`w-5 h-5 ${colorClass}`} />
      </div>
      <div>
        <p className="text-xs text-muted-foreground font-medium">{title}</p>
        <p className="text-2xl font-bold text-foreground mt-0.5">{value}</p>
        <p className="text-xs text-muted-foreground mt-0.5">{subtitle}</p>
      </div>
    </div>
  )
}

function fmt(dt) {
  if (!dt) return '—'
  return new Date(dt).toLocaleString('en-PK', { timeStyle: 'short' })
}

export default function Dashboard() {
  const { name, role } = getUser()
  const { site_id } = getUser()

  const [stats, setStats] = useState({
    activeVehicles: 0,
    availableSlots: 0,
    totalSlots: 0,
    todayRevenue: 0,
    overstayCount: 0,
    todayEntries: 0,
  })
  const [recentActivity, setRecentActivity] = useState([])
  const [loading, setLoading] = useState(true)
  

  useEffect(() => {
    async function fetchAll() {
      try {
        const today = new Date(); today.setHours(0, 0, 0, 0)

        const [bookingsRes, slotsRes] = await Promise.all([
          api.get('/bookings/'),
          site_id ? api.get(`/parking/sites/${site_id}/slots/`) : Promise.resolve({ data: [] }),
        ])

        const bookings = bookingsRes.data
        const slots    = slotsRes.data

        const activeVehicles = bookings.filter(b => b.status === 'active').length
        const overstayCount  = bookings.filter(b => b.status === 'overstay').length
        const todayEntries   = bookings.filter(b => b.entry_time && new Date(b.entry_time) >= today).length
        const todayRevenue   = bookings
          .filter(b => b.status === 'completed' && b.estimated_amount && new Date(b.updated_at) >= today)
          .reduce((sum, b) => sum + parseFloat(b.estimated_amount), 0)

        const availableSlots = slots.filter(s => !s.is_occupied && !s.is_reserved).length

        setStats({
          activeVehicles,
          availableSlots,
          totalSlots: slots.length,
          todayRevenue: Math.round(todayRevenue),
          overstayCount,
          todayEntries,
        })

        // Recent bookings as activity feed
        const sorted = [...bookings]
          .filter(b => b.entry_time)
          .sort((a, b) => new Date(b.entry_time) - new Date(a.entry_time))
          .slice(0, 8)
        setRecentActivity(sorted)


      } catch (err) {
        console.error('Dashboard fetch error:', err)
      } finally {
        setLoading(false)
      }
    }
    fetchAll()
  }, [])

  const greeting = (() => {
    const h = new Date().getHours()
    if (h < 12) return 'Good morning'
    if (h < 17) return 'Good afternoon'
    return 'Good evening'
  })()

  return (
    <div className="space-y-6">

      {/* Welcome */}
      <div>
        <h2 className="text-2xl font-bold text-foreground">{greeting}, {name?.split(' ')[0]} 👋</h2>
        <p className="text-sm text-muted-foreground mt-1">
          Here's a live overview of your parking site — {new Date().toLocaleDateString('en-PK', { weekday: 'long', dateStyle: 'long' })}
        </p>
      </div>




      {/* Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <StatCard
          title="Active Vehicles"
          value={loading ? '...' : stats.activeVehicles}
          subtitle="Currently parked"
          icon={Car}
          colorClass="text-blue-600"
          bgClass="bg-blue-50"
        />
        <StatCard
          title="Available Slots"
          value={loading ? '...' : `${stats.availableSlots} / ${stats.totalSlots}`}
          subtitle="Open right now"
          icon={SquareParking}
          colorClass="text-green-600"
          bgClass="bg-green-50"
        />
        <StatCard
          title="Today's Revenue"
          value={loading ? '...' : `Rs. ${stats.todayRevenue}`}
          subtitle="From completed exits"
          icon={Banknote}
          colorClass="text-primary"
          bgClass="bg-primary/10"
        />
        <StatCard
          title="Today's Entries"
          value={loading ? '...' : stats.todayEntries}
          subtitle="Vehicles entered today"
          icon={CheckCircle}
          colorClass="text-teal-600"
          bgClass="bg-teal-50"
        />
        <StatCard
          title="Overstay Alerts"
          value={loading ? '...' : stats.overstayCount}
          subtitle={stats.overstayCount > 0 ? 'Requires attention' : 'All clear'}
          icon={AlertTriangle}
          colorClass={stats.overstayCount > 0 ? 'text-orange-600' : 'text-muted-foreground'}
          bgClass={stats.overstayCount > 0 ? 'bg-orange-50' : 'bg-secondary'}
        />
        <StatCard
          title="Current Time"
          value={new Date().toLocaleTimeString('en-PK', { timeStyle: 'short' })}
          subtitle="Gate operating hours"
          icon={Clock}
          colorClass="text-muted-foreground"
          bgClass="bg-secondary"
        />
      </div>

      {/* Recent Activity */}
      <div className="bg-card border border-border rounded-xl overflow-hidden">
        <div className="px-5 py-4 border-b border-border">
          <h3 className="text-sm font-semibold text-foreground">Recent Vehicle Activity</h3>
          <p className="text-xs text-muted-foreground mt-0.5">Latest entries at your gate</p>
        </div>
        <div className="divide-y divide-border">
          {loading ? (
            Array.from({ length: 5 }).map((_, i) => (
              <div key={i} className="px-5 py-3 flex items-center gap-4">
                <div className="w-8 h-8 rounded-full bg-secondary animate-pulse" />
                <div className="flex-1 space-y-2">
                  <div className="h-3 bg-secondary rounded animate-pulse w-32" />
                  <div className="h-3 bg-secondary rounded animate-pulse w-48" />
                </div>
              </div>
            ))
          ) : recentActivity.length === 0 ? (
            <div className="px-5 py-10 text-center text-sm text-muted-foreground">
              No vehicle activity yet today
            </div>
          ) : (
            recentActivity.map((b, i) => {
              const isActive    = b.status === 'active'
              const isOverstay  = b.status === 'overstay'
              const isCompleted = b.status === 'completed'
              return (
                <div key={b.id ?? i} className="px-5 py-3 flex items-center gap-4 hover:bg-secondary/50 transition-colors">
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 text-xs font-bold ${
                    isActive ? 'bg-green-100 text-green-700'
                    : isOverstay ? 'bg-orange-100 text-orange-700'
                    : isCompleted ? 'bg-blue-100 text-blue-700'
                    : 'bg-secondary text-muted-foreground'
                  }`}>
                    <Car className="w-4 h-4" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-mono font-semibold text-foreground tracking-wider">
                      {b.plate_number ?? '—'}
                    </p>
                    <p className="text-xs text-muted-foreground mt-0.5">
                      Slot {b.slot ?? '—'} · Entered {fmt(b.entry_time)}
                      {b.estimated_amount ? ` · Rs. ${b.estimated_amount}` : ''}
                    </p>
                  </div>
                  <span className={`text-xs px-2 py-0.5 rounded-full font-medium border flex-shrink-0 ${
                    isActive ? 'bg-green-50 text-green-700 border-green-200'
                    : isOverstay ? 'bg-orange-50 text-orange-700 border-orange-200'
                    : isCompleted ? 'bg-blue-50 text-blue-700 border-blue-200'
                    : 'bg-secondary text-muted-foreground border-border'
                  }`}>
                    {b.status}
                  </span>
                </div>
              )
            })
          )}
        </div>
      </div>
    </div>
  )
}