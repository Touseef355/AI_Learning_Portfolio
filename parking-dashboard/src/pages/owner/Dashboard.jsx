import React, { useState, useEffect } from 'react'
import api from '../../api/axios'
import { Calendar, TrendingUp, Users, Car, DollarSign, Clock, MapPin, RefreshCw } from 'lucide-react'
import { getUser } from '../../utils/auth'

const OwnerDashboard = () => {
  const [loading, setLoading]           = useState(true)
  const [totalSites, setTotalSites]       = useState(0)
  const [stats, setStats]               = useState({
    totalRevenue: 0, todayRevenue: 0,
    totalBookings: 0, activeBookings: 0,
    totalSlots: 0, occupiedSlots: 0,
  })
  const [recentBookings, setRecentBookings] = useState([])
  const [monthlyRevenue, setMonthlyRevenue] = useState([])

  const fetchDashboardData = async () => {
    setLoading(true)
    try {
      const res = await api.get('/auth/owner/dashboard/')
      const d = res.data
      setTotalSites(d.total_sites || 0)
      setStats({
        totalRevenue:   parseFloat(d.total_revenue) || 0,
        todayRevenue:   parseFloat(d.today_revenue) || 0,
        totalBookings:  d.total_bookings || 0,
        activeBookings: d.active_bookings || 0,
        totalSlots:     d.total_slots || 0,
        occupiedSlots:  d.occupied_slots || 0,
      })
      setRecentBookings(d.recent_bookings || [])

      // Monthly revenue chart — try to get from payments/owner if available
      try {
        const payRes = await api.get('/payments/owner/')
        const monthly = (payRes.data.monthly_revenue || []).map(m => ({
          month: new Date(m.month).toLocaleString('default', { month: 'short' }),
          rev: parseFloat(m.total) || 0,
        }))
        setMonthlyRevenue(monthly)
      } catch (_) {
        setMonthlyRevenue([])
      }
    } catch (err) {
      console.error('Owner dashboard error:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchDashboardData() }, [])

  const maxRev = Math.max(...monthlyRevenue.map(m => m.rev), 1)

  if (loading) {
    return (
      <div className="p-6 flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-blue-600" />
      </div>
    )
  }

  if (totalSites === 0) {
    return (
      <div className="p-6 flex items-center justify-center min-h-screen">
        <div className="text-center">
          <MapPin className="w-12 h-12 text-gray-300 mx-auto mb-4" />
          <p className="text-gray-600 font-medium mb-2">No parking sites found</p>
          <p className="text-sm text-gray-400">Register a site or contact admin to link your account.</p>
        </div>
      </div>
    )
  }

  const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']

  return (
    <div className="p-6 space-y-6 bg-gray-50 min-h-screen">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Owner Dashboard</h1>
          <p className="text-gray-500 mt-1 text-sm">
            Managing {totalSites} site{totalSites > 1 ? 's' : ''}
          </p>
        </div>
        <button onClick={fetchDashboardData} className="flex items-center gap-2 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg text-sm hover:bg-gray-50 transition-colors">
          <RefreshCw className="w-4 h-4" /> Refresh
        </button>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {[
          { label: 'Total Revenue',    val: `Rs. ${stats.totalRevenue.toLocaleString()}`, icon: DollarSign, iconBg: 'bg-green-100',  iconColor: 'text-green-600'  },
          { label: "Today's Revenue",  val: `Rs. ${stats.todayRevenue.toLocaleString()}`, icon: TrendingUp, iconBg: 'bg-blue-100',   iconColor: 'text-blue-600'   },
          { label: 'Total Bookings',   val: stats.totalBookings,                          icon: Calendar,   iconBg: 'bg-purple-100', iconColor: 'text-purple-600' },
          { label: 'Active Bookings',  val: stats.activeBookings,                         icon: Clock,      iconBg: 'bg-orange-100', iconColor: 'text-orange-600' },
          { label: 'Total Slots',      val: stats.totalSlots,                             icon: Car,        iconBg: 'bg-gray-100',   iconColor: 'text-gray-700'   },
          { label: 'Occupied Slots',   val: stats.occupiedSlots,                          icon: Users,      iconBg: 'bg-red-100',    iconColor: 'text-red-600'    },
        ].map(s => {
          const IconComp = s.icon
          return (
            <div key={s.label} className="bg-white rounded-xl p-6 border border-gray-200">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-500">{s.label}</p>
                  <p className="text-2xl font-bold text-gray-900 mt-1">{s.val}</p>
                </div>
                <div className={`p-3 rounded-lg ${s.iconBg}`}>
                  <IconComp className={`w-5 h-5 ${s.iconColor}`} />
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* Monthly Revenue Bar Chart */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-1">Monthly Revenue</h3>
        <p className="text-sm text-gray-500 mb-4">Current year — completed payments</p>
        <div className="flex items-end gap-2 h-28 mb-2">
          {monthlyRevenue.map((m, i) => (
            <div key={i} className="flex-1 flex flex-col items-center gap-1 group relative">
              <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-gray-900 text-white text-[10px] px-1.5 py-0.5 rounded opacity-0 group-hover:opacity-100 whitespace-nowrap pointer-events-none z-10">
                Rs. {m.rev.toLocaleString()}
              </div>
              <div
                className="w-full bg-blue-500 hover:bg-blue-600 rounded-t-sm transition-colors"
                style={{ height: `${maxRev > 0 ? (m.rev / maxRev) * 100 : 0}%`, minHeight: m.rev > 0 ? '4px' : '0' }}
              />
            </div>
          ))}
        </div>
        <div className="flex justify-between">
          {MONTHS.map(m => (
            <p key={m} className="flex-1 text-[10px] text-gray-400 text-center">{m}</p>
          ))}
        </div>
      </div>

      {/* Recent Bookings */}
      <div className="bg-white rounded-xl border border-gray-200">
        <div className="p-6 border-b border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900">Recent Bookings</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">ID</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Plate</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Slot</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Amount</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {recentBookings.length === 0 ? (
                <tr>
                  <td colSpan={5} className="px-6 py-8 text-center text-gray-400 text-sm">No bookings yet</td>
                </tr>
              ) : recentBookings.map(b => (
                  <tr key={b.id} className="hover:bg-gray-50 transition-colors">
                    <td className="px-6 py-4 text-sm font-mono text-gray-500">#{String(b.id).slice(-6)}</td>
                    <td className="px-6 py-4 text-sm text-gray-900">{b.plate_number || '—'}</td>
                    <td className="px-6 py-4 text-sm font-mono text-gray-900">{b.slot_number || '—'}</td>
                    <td className="px-6 py-4 text-sm font-semibold text-green-600">Rs. {(parseFloat(b.estimated_amount) || 0).toLocaleString()}</td>
                    <td className="px-6 py-4">
                      <span className={`px-2 py-1 text-xs rounded-full font-medium ${
                        ['completed','Completed'].includes(b.status || '') ? 'bg-green-100 text-green-700' :
                        ['active','Active','upcoming','Upcoming'].includes(b.status || '') ? 'bg-blue-100 text-blue-700' :
                        'bg-gray-100 text-gray-600'
                      }`}>
                        {b.status || '—'}
                      </span>
                    </td>
                  </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

export default OwnerDashboard