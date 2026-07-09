import { useState, useEffect } from 'react'
import { CreditCard, Search, Download, TrendingUp, Car, RefreshCw, Filter } from 'lucide-react'
import api from '../../api/axios'

const METHOD_COLORS = {
  cash:      'bg-gray-100 text-gray-700',
  Cash:      'bg-gray-100 text-gray-700',
  card:      'bg-violet-100 text-violet-700',
  Card:      'bg-violet-100 text-violet-700',
  easypasisa:'bg-green-100 text-green-700',
  EasyPaisa: 'bg-green-100 text-green-700',
  jazzcash:  'bg-red-100 text-red-600',
  JazzCash:  'bg-red-100 text-red-600',
  online:    'bg-blue-100 text-blue-700',
  Online:    'bg-blue-100 text-blue-700',
}

function fmtDate(str) {
  if (!str) return '—'
  return new Date(str).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

function StatusBadge({ status }) {
  const s = (status || '').toLowerCase()
  const cls =
    s === 'completed' || s === 'paid'   ? 'bg-green-100 text-green-700'  :
    s === 'pending'                     ? 'bg-yellow-100 text-yellow-700' :
    s === 'failed'                      ? 'bg-red-100 text-red-700'       :
    s === 'refunded'                    ? 'bg-blue-100 text-blue-700'     :
                                          'bg-gray-100 text-gray-600'
  return (
    <span className={`text-xs px-2.5 py-1 rounded-full font-medium ${cls}`}>
      {status ? status.charAt(0).toUpperCase() + status.slice(1) : '—'}
    </span>
  )
}

function MethodBadge({ method }) {
  return (
    <span className={`text-xs px-2.5 py-1 rounded-full font-medium ${METHOD_COLORS[method] || 'bg-gray-100 text-gray-600'}`}>
      {method || 'Cash'}
    </span>
  )
}

export default function Payments() {
  const [payments, setPayments]         = useState([])
  const [sites, setSites]               = useState([])
  const [loading, setLoading]           = useState(true)
  const [search, setSearch]             = useState('')
  const [filterStatus, setFilterStatus] = useState('all')
  const [filterMethod, setFilterMethod] = useState('all')
  const [filterSite, setFilterSite]     = useState('all')

  const fetchPayments = async () => {
    setLoading(true)
    try {
      const res = await api.get('/payments/admin/')
      const mapped = (res.data || []).map(p => ({
        id: p.id,
        booking_id: p.booking_id || '—',
        slot_number: p.slot_number || '—',
        vehicle_no: p.plate || '—',
        parking_sites: { name: p.site || '—' },
        amount: parseFloat(p.amount) || 0,
        payment_method: p.method || 'Cash',
        status: p.status,
        created_at: p.paid_at || new Date().toISOString(),
        user_name: p.user || '—',
        user_email: p.user_email || '—',
      }))
      setPayments(mapped)
    } catch (err) {
      console.error('Payments fetch error:', err)
    } finally {
      setLoading(false)
    }
  }

  const fetchSites = async () => {
    try {
      const res = await api.get('/parking/sites/')
      setSites(res.data || [])
    } catch (err) {
      console.error('Sites fetch error:', err)
    }
  }

  useEffect(() => {
    fetchPayments()
    fetchSites()
  }, [])

  // ── Derived stats
  const completed  = payments.filter(p => ['completed','paid'].includes((p.status||'').toLowerCase()))
  const pending    = payments.filter(p => (p.status||'').toLowerCase() === 'pending')
  const failed     = payments.filter(p => (p.status||'').toLowerCase() === 'failed')
  const totalRevenue = completed.reduce((s, p) => s + (p.amount || 0), 0)

  // ── Filter
  const filtered = payments.filter(p => {
    const siteName = p.parking_sites?.name || ''
    const matchSearch =
      (p.vehicle_no || '').toLowerCase().includes(search.toLowerCase()) ||
      siteName.toLowerCase().includes(search.toLowerCase()) ||
      (p.user_name || '').toLowerCase().includes(search.toLowerCase()) ||
      (p.user_email || '').toLowerCase().includes(search.toLowerCase()) ||
      String(p.id).includes(search)
    const matchStatus = filterStatus === 'all' || (p.status || '').toLowerCase() === filterStatus.toLowerCase()
    const matchMethod = filterMethod === 'all' || (p.payment_method || p.method || '').toLowerCase() === filterMethod.toLowerCase()
    const matchSite   = filterSite   === 'all' || siteName === filterSite
    return matchSearch && matchStatus && matchMethod && matchSite
  })

  // ── CSV Export
  const handleExportCSV = () => {
    const headers = ['ID', 'User', 'Email', 'Vehicle', 'Site', 'Amount', 'Method', 'Status', 'Date', 'Booking ID', 'Slot']
    const rows = filtered.map(p => [
      p.id,
      p.user_name || '—',
      p.user_email || '—',
      p.vehicle_no || '—',
      p.parking_sites?.name || '—',
      `Rs. ${p.amount || 0}`,
      p.payment_method || 'Cash',
      p.status || '—',
      fmtDate(p.created_at),
      p.booking_id || '—',
      p.slot_number || '—'
    ])
    const csv  = [headers, ...rows].map(r => r.join(',')).join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const url  = URL.createObjectURL(blob)
    const a    = document.createElement('a')
    a.href     = url
    a.download = `payments_${Date.now()}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <div className="p-6 space-y-6 bg-gray-50 min-h-screen">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Payments</h1>
          <p className="text-gray-500 mt-1 text-sm">Consolidated payment records across all parking sites.</p>
        </div>
        <div className="flex gap-3">
          <button
            onClick={fetchPayments}
            className="flex items-center gap-2 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg text-sm hover:bg-gray-50 transition-colors"
          >
            <RefreshCw className="w-4 h-4" /> Refresh
          </button>
          <button
            onClick={handleExportCSV}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors"
          >
            <Download className="w-4 h-4" /> Export CSV
          </button>
        </div>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {[
          { label: 'Total Revenue',    val: `Rs. ${totalRevenue.toLocaleString()}`, iconBg: 'bg-green-100',  iconColor: 'text-green-600',  icon: TrendingUp  },
          { label: 'Completed',        val: completed.length,                        iconBg: 'bg-blue-100',   iconColor: 'text-blue-600',   icon: CreditCard  },
          { label: 'Pending',          val: pending.length,                          iconBg: 'bg-yellow-100', iconColor: 'text-yellow-600', icon: Car         },
          { label: 'Failed',           val: failed.length,                           iconBg: 'bg-red-100',    iconColor: 'text-red-600',    icon: Filter      },
        ].map(s => {
          const IconComp = s.icon
          return (
            <div key={s.label} className="bg-white rounded-xl p-6 border border-gray-200">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-500">{s.label}</p>
                  <p className="text-2xl font-bold text-gray-900 mt-1">{loading ? '...' : s.val}</p>
                </div>
                <div className={`p-3 rounded-lg ${s.iconBg}`}>
                  <IconComp className={`w-5 h-5 ${s.iconColor}`} />
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* Table Card */}
      <div className="bg-white rounded-xl border border-gray-200">
        {/* Search + Filters */}
        <div className="p-6 border-b border-gray-200 space-y-3">
          <div className="flex flex-wrap items-center gap-3">
            {/* Search */}
            <div className="relative flex-1 min-w-[200px]">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search by plate, site, user or ID..."
                value={search}
                onChange={e => setSearch(e.target.value)}
                className="pl-9 pr-4 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 w-full"
              />
            </div>

            {/* Status filter */}
            <select
              value={filterStatus}
              onChange={e => setFilterStatus(e.target.value)}
              className="text-sm border border-gray-300 rounded-lg px-3 py-2 text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-500 capitalize"
            >
              <option value="all">Status: All</option>
              <option value="completed">Completed</option>
              <option value="pending">Pending</option>
              <option value="failed">Failed</option>
              <option value="refunded">Refunded</option>
            </select>

            {/* Method filter */}
            <select
              value={filterMethod}
              onChange={e => setFilterMethod(e.target.value)}
              className="text-sm border border-gray-300 rounded-lg px-3 py-2 text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-500 capitalize"
            >
              <option value="all">All Methods</option>
              <option value="cash">Cash</option>
              <option value="card">Card</option>
            </select>
          </div>

          {/* Site filter */}
          <div className="flex items-center gap-2 flex-wrap">
            <select
              value={filterSite}
              onChange={e => setFilterSite(e.target.value)}
              className="text-sm border border-gray-300 rounded-lg px-3 py-2 text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="all">All Sites</option>
              {sites.map(s => (
                <option key={s.id} value={s.name}>{s.name}</option>
              ))}
            </select>
          </div>
        </div>

        {/* Table */}
        {loading ? (
          <div className="flex items-center justify-center py-12">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead className="bg-gray-50">
                <tr>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">User (Name / Email)</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Vehicle</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Site</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Amount</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Method</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Status</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Booking ID / Slot</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="text-center py-12 text-gray-400 text-sm">No payment records found.</td>
                  </tr>
                ) : filtered.map(p => (
                  <tr key={p.id} className="hover:bg-gray-50 transition-colors">
                    <td className="px-6 py-4">
                      <p className="text-sm font-medium text-gray-900">{p.user_name}</p>
                      <p className="text-xs text-gray-400">{p.user_email}</p>
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        <div className="w-7 h-7 rounded-lg bg-blue-50 flex items-center justify-center flex-shrink-0">
                          <Car className="w-3.5 h-3.5 text-blue-600" />
                        </div>
                        <span className="text-sm font-medium text-gray-900 font-mono">{p.vehicle_no || '—'}</span>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-600">{p.parking_sites?.name || '—'}</td>
                    <td className="px-6 py-4 text-sm font-semibold text-gray-900">Rs. {(p.amount || 0).toLocaleString()}</td>
                    <td className="px-6 py-4"><MethodBadge method={p.payment_method || 'Cash'} /></td>
                    <td className="px-6 py-4"><StatusBadge status={p.status} /></td>
                    <td className="px-6 py-4">
                      <p className="text-xs font-mono text-gray-500">ID: {p.booking_id ? String(p.booking_id).slice(-6) : '—'}</p>
                      <p className="text-sm text-gray-600">Slot: {p.slot_number}</p>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-500">{fmtDate(p.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Footer */}
        {!loading && filtered.length > 0 && (
          <div className="flex items-center justify-between px-6 py-3 border-t border-gray-100">
            <p className="text-xs text-gray-400">Showing {filtered.length} of {payments.length} records</p>
            <p className="text-sm font-semibold text-gray-900">
              Total: Rs. {filtered.filter(p => ['completed','paid'].includes((p.status||'').toLowerCase())).reduce((s, p) => s + (p.amount || 0), 0).toLocaleString()}
            </p>
          </div>
        )}
      </div>
    </div>
  )
}