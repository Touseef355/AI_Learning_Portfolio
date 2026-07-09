import { useState, useEffect } from 'react'
import { BarChart2, Download, FileText, TrendingUp, Car, CreditCard, Calendar, RefreshCw } from 'lucide-react'
import api from '../../api/axios'
import * as XLSX from 'xlsx'

function fmtDate(str) {
  if (!str) return '—'
  return new Date(str).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

export default function Reports() {
  const [payments,  setPayments]  = useState([])
  const [bookings,  setBookings]  = useState([])
  const [sites,     setSites]     = useState([])
  const [loading,   setLoading]   = useState(true)
  const [dateRange, setDateRange] = useState('month') // today / week / month / all

  const getDateFrom = (range) => {
    const now = new Date()
    if (range === 'today') { const d = new Date(now); d.setHours(0,0,0,0); return d.toISOString() }
    if (range === 'week')  return new Date(now - 7  * 86400000).toISOString()
    if (range === 'month') return new Date(now - 30 * 86400000).toISOString()
    return null // all
  }

  const fetchReport = async (range) => {
    setLoading(true)
    try {
      const from = getDateFrom(range)

      const [payRes, bkRes, stRes] = await Promise.all([
        api.get('/payments/admin/'),
        api.get('/bookings/admin/'),
        api.get('/parking/sites/'),
      ])

      let paymentsData = payRes.data || []
      let bookingsData = bkRes.data || []
      let sitesData = stRes.data || []

      if (from) {
        paymentsData = paymentsData.filter(p => new Date(p.created_at || p.paid_at) >= new Date(from))
        bookingsData = bookingsData.filter(b => new Date(b.created_at) >= new Date(from))
      }

      setPayments(paymentsData)
      setBookings(bookingsData)
      setSites(sitesData)
    } catch (err) {
      console.error('Reports fetch error:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { fetchReport(dateRange) }, [dateRange])

  // ── Aggregations
  const completed  = payments.filter(p => ['completed','paid'].includes((p.status||'').toLowerCase()))
  const totalRev   = completed.reduce((s, p) => s + (p.amount || 0), 0)
  const avgPerBook = bookings.length > 0 ? Math.round(totalRev / bookings.length) : 0

  // Revenue + bookings by site
  const bySite = sites.map(site => {
    const sitePayments  = completed.filter(p => p.site === site.name || (p.parking_sites && p.parking_sites.id === site.id))
    const siteBookings  = bookings.filter(b  => b.site_name === site.name || (b.parking_slot && b.parking_slot.parking_site === site.id))
    const siteRevenue   = sitePayments.reduce((s, p) => s + (parseFloat(p.amount) || 0), 0)
    return { id: site.id, name: site.name, revenue: siteRevenue, bookings: siteBookings.length }
  }).sort((a, b) => b.revenue - a.revenue)

  const topSite = bySite[0]?.name || '—'
  const maxRev  = Math.max(...bySite.map(s => s.revenue), 1)

  // Booking status breakdown
  const statusGroups = ['active','completed','cancelled','disputed'].map(s => ({
    status: s,
    count: bookings.filter(b => (b.status||'').toLowerCase() === s).length,
  }))

  // Monthly revenue (current year)
  const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']
  const monthly = MONTHS.map((m, i) => ({
    month: m,
    rev: completed.filter(p => new Date(p.created_at).getMonth() === i).reduce((s, p) => s + (p.amount || 0), 0)
  }))
  const maxMonthly = Math.max(...monthly.map(m => m.rev), 1)

  // CSV Export
  const exportCSV = () => {
    const headers = ['Site', 'Bookings', 'Revenue (Rs.)']
    const rows = bySite.map(s => [s.name, s.bookings, s.revenue])
    const csv  = [headers, ...rows].map(r => r.join(',')).join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const a    = document.createElement('a')
    a.href     = URL.createObjectURL(blob)
    a.download = `report_${dateRange}_${Date.now()}.csv`
    a.click()
  }

  // Excel Export using SheetJS
  const exportExcel = () => {
    const wb = XLSX.utils.book_new()
    
    // Sheet 1: Revenue by Site
    const siteData = bySite.map(s => ({
      'Site Name': s.name,
      'Total Bookings': s.bookings,
      'Revenue (Rs.)': s.revenue
    }))
    const wsSite = XLSX.utils.json_to_sheet(siteData)
    XLSX.utils.book_append_sheet(wb, wsSite, 'Revenue by Site')
    
    // Sheet 2: Payments Detail
    const paymentsData = payments.map(p => ({
      'Payment ID': p.id,
      'Site': p.parking_sites?.name || '—',
      'Amount (Rs.)': p.amount,
      'Status': p.status,
      'Date': fmtDate(p.created_at)
    }))
    const wsPay = XLSX.utils.json_to_sheet(paymentsData)
    XLSX.utils.book_append_sheet(wb, wsPay, 'Payments Detail')

    // Sheet 3: Bookings Detail
    const bookingsData = bookings.map(b => ({
      'Booking ID': b.id,
      'Site ID': b.site_id,
      'Status': b.status,
      'Date': fmtDate(b.created_at)
    }))
    const wsBook = XLSX.utils.json_to_sheet(bookingsData)
    XLSX.utils.book_append_sheet(wb, wsBook, 'Bookings Detail')
    
    XLSX.writeFile(wb, `system_reports_excel_${dateRange}_${Date.now()}.xlsx`)
  }

  // PDF Export using Browser Print
  const exportPDF = () => {
    window.print()
  }

  const STATUS_COLORS = {
    active:    'bg-blue-100 text-blue-700',
    completed: 'bg-green-100 text-green-700',
    cancelled: 'bg-gray-100 text-gray-700',
    disputed:  'bg-red-100 text-red-700',
  }

  return (
    <div className="p-6 space-y-6 bg-gray-50 min-h-screen">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Reports</h1>
          <p className="text-gray-500 mt-1 text-sm">Revenue and booking analytics across all sites.</p>
        </div>
        <div className="flex gap-3">
          <div className="flex gap-1 bg-white border border-gray-200 rounded-lg p-0.5">
            {[['today','Today'],['week','Week'],['month','Month'],['all','All Time']].map(([k,l]) => (
              <button
                key={k}
                onClick={() => setDateRange(k)}
                className={`text-xs px-3 py-1.5 rounded-md font-medium transition-colors ${
                  dateRange === k ? 'bg-blue-600 text-white' : 'text-gray-600 hover:bg-gray-50'
                }`}
              >
                {l}
              </button>
            ))}
          </div>
          <button onClick={() => fetchReport(dateRange)} className="flex items-center gap-2 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg text-sm hover:bg-gray-50 transition-colors">
            <RefreshCw className="w-4 h-4" />
          </button>
          <button onClick={exportCSV} className="flex items-center gap-2 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg text-sm hover:bg-gray-50 transition-colors">
            <Download className="w-4 h-4" /> Export CSV
          </button>
          <button onClick={exportExcel} className="flex items-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-lg text-sm font-medium hover:bg-emerald-700 transition-colors">
            <Download className="w-4 h-4" /> Export Excel
          </button>
          <button onClick={exportPDF} className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors">
            <FileText className="w-4 h-4" /> Export PDF
          </button>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-6">
        {[
          { label: 'Total Revenue',    val: `Rs. ${totalRev.toLocaleString()}`, icon: CreditCard, iconBg: 'bg-green-100',  iconColor: 'text-green-600' },
          { label: 'Total Bookings',   val: bookings.length,                     icon: Car,        iconBg: 'bg-blue-100',   iconColor: 'text-blue-600'  },
          { label: 'Avg per Booking',  val: `Rs. ${avgPerBook.toLocaleString()}`,icon: TrendingUp, iconBg: 'bg-purple-100', iconColor: 'text-purple-600'},
          { label: 'Top Site',         val: topSite,                             icon: BarChart2,  iconBg: 'bg-orange-100', iconColor: 'text-orange-600'},
        ].map(s => {
          const IconComp = s.icon
          return (
            <div key={s.label} className="bg-white rounded-xl p-6 border border-gray-200">
              <div className="flex items-center justify-between">
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-gray-500">{s.label}</p>
                  <p className={`text-xl font-bold text-gray-900 mt-1 ${s.label === 'Top Site' ? 'text-base truncate' : ''}`}>
                    {loading ? '...' : s.val}
                  </p>
                </div>
                <div className={`p-3 rounded-lg ml-3 flex-shrink-0 ${s.iconBg}`}>
                  <IconComp className={`w-5 h-5 ${s.iconColor}`} />
                </div>
              </div>
            </div>
          )
        })}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Monthly Revenue bar chart */}
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-1">Monthly Revenue</h3>
          <p className="text-sm text-gray-500 mb-4">Current year — completed payments</p>
          {loading ? (
            <div className="flex items-center justify-center h-32">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
            </div>
          ) : (
            <>
              <div className="flex items-end gap-1.5 h-32 mb-2">
                {monthly.map((m, i) => {
                  const h = Math.round((m.rev / maxMonthly) * 100)
                  return (
                    <div key={i} className="flex-1 flex flex-col items-center gap-1 group relative">
                      <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-gray-900 text-white text-[10px] px-1.5 py-0.5 rounded opacity-0 group-hover:opacity-100 whitespace-nowrap pointer-events-none z-10">
                        Rs. {m.rev.toLocaleString()}
                      </div>
                      <div className="w-full bg-gray-100 rounded-t flex flex-col justify-end" style={{ height: 100 }}>
                        <div className="w-full bg-blue-500 hover:bg-blue-600 rounded-t transition-colors" style={{ height: `${Math.max(h, m.rev > 0 ? 4 : 0)}%` }} />
                      </div>
                      <span className="text-[9px] text-gray-400">{m.month}</span>
                    </div>
                  )
                })}
              </div>
            </>
          )}
        </div>

        {/* Booking Status Breakdown */}
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-1">Booking Status Breakdown</h3>
          <p className="text-sm text-gray-500 mb-4">All bookings for selected period</p>
          {loading ? (
            <div className="flex items-center justify-center h-32">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
            </div>
          ) : (
            <div className="space-y-3">
              {statusGroups.map(s => {
                const pct = bookings.length > 0 ? Math.round((s.count / bookings.length) * 100) : 0
                return (
                  <div key={s.status} className="flex items-center gap-3">
                    <span className={`text-xs px-2 py-1 rounded-full font-medium w-24 text-center ${STATUS_COLORS[s.status] || 'bg-gray-100 text-gray-600'}`}>
                      {s.status}
                    </span>
                    <div className="flex-1 bg-gray-100 rounded-full h-2">
                      <div className="bg-blue-500 h-2 rounded-full transition-all" style={{ width: `${pct}%` }} />
                    </div>
                    <span className="text-sm font-semibold text-gray-900 w-8 text-right">{s.count}</span>
                    <span className="text-xs text-gray-400 w-8">{pct}%</span>
                  </div>
                )
              })}
            </div>
          )}
        </div>
      </div>

      {/* Revenue by Site Table */}
      <div className="bg-white rounded-xl border border-gray-200">
        <div className="p-6 border-b border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900">Revenue by Site</h3>
          <p className="text-sm text-gray-500 mt-0.5">Breakdown per parking location</p>
        </div>
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50">
                <tr>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Site</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Bookings</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Revenue</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Share</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {bySite.length === 0 ? (
                  <tr><td colSpan={4} className="text-center py-12 text-gray-400 text-sm">No data for this period.</td></tr>
                ) : bySite.map(s => {
                  const pct = totalRev > 0 ? Math.round((s.revenue / totalRev) * 100) : 0
                  return (
                    <tr key={s.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-6 py-4 text-sm font-medium text-gray-900">{s.name}</td>
                      <td className="px-6 py-4 text-sm text-gray-600">{s.bookings}</td>
                      <td className="px-6 py-4 text-sm font-semibold text-gray-900">Rs. {s.revenue.toLocaleString()}</td>
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-2">
                          <div className="flex-1 bg-gray-100 rounded-full h-1.5" style={{ minWidth: 80 }}>
                            <div className="bg-blue-500 h-1.5 rounded-full" style={{ width: `${pct}%` }} />
                          </div>
                          <span className="text-xs text-gray-500 w-8">{pct}%</span>
                        </div>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}