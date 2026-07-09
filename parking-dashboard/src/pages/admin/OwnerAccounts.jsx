import { useState, useEffect } from 'react'
import {
  Users, CheckCircle, XCircle, Eye, Search,
  X, MapPin, UserCheck, TrendingUp,
  Calendar, Phone, Mail, ArrowLeft, Building2,
  CreditCard, RefreshCw, Trash2
} from 'lucide-react'
import api from '../../api/axios'

// ── HELPERS ──────────────────────────────────────────────────────────────

function fmtDate(str) {
  if (!str) return '—'
  return new Date(str).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

// ── STATUS BADGE ─────────────────────────────────────────────────────────

function StatusBadge({ status }) {
  const styles = {
    active: 'bg-green-100 text-green-700',
    pending: 'bg-yellow-100 text-yellow-700',
    blocked: 'bg-red-100 text-red-700',
    inactive: 'bg-gray-100 text-gray-500',
  }
  return (
    <span className={`text-xs px-2.5 py-1 rounded-full font-medium ${styles[status] || styles.pending}`}>
      {(status || 'unknown').charAt(0).toUpperCase() + (status || 'unknown').slice(1)}
    </span>
  )
}

// ── OWNER DETAIL PANEL ────────────────────────────────────────────────────

function OwnerDetailPanel({ owner, onClose, onApprove, onBlock, onUnblock, onReject }) {
  const [activeTab, setActiveTab] = useState('sites')
  const [sites, setSites] = useState([])
  const [cashiers, setCashiers] = useState([])
  const [revenue, setRevenue] = useState(0)
  const [bookingsCount, setBookingsCount] = useState(0)
  const [monthlyRevenue, setMonthlyRevenue] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetchOwnerDetails()
  }, [owner.id])

  const fetchOwnerDetails = async () => {
    setLoading(true)
    try {
      const res = await api.get(`/auth/admin/owners/${owner.id}/details/`)
      setSites(res.data.sites || [])
      setCashiers(res.data.cashiers || [])
      setRevenue(res.data.revenue || 0)
      setBookingsCount(res.data.bookingsCount || 0)
      setMonthlyRevenue(res.data.monthlyRevenue || [])
    } catch (err) {
      console.error('Owner details fetch error:', err)
    } finally {
      setLoading(false)
    }
  }

  const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
  const maxBar = Math.max(...monthlyRevenue, 1)

  return (
    <div className="p-6 space-y-5 bg-gray-50 min-h-screen">
      {/* Back */}
      <button
        onClick={onClose}
        className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-800 transition-colors"
      >
        <ArrowLeft className="w-4 h-4" />
        Back to Owners
      </button>

      {/* Owner profile card */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <div className="flex items-start justify-between">
          <div className="flex items-center gap-4">
            <div className="w-14 h-14 rounded-full bg-blue-100 flex items-center justify-center text-lg font-bold text-blue-700 flex-shrink-0">
              {(owner.name || 'OW').slice(0, 2).toUpperCase()}
            </div>
            <div>
              <div className="flex items-center gap-3 mb-1">
                <h2 className="text-xl font-semibold text-gray-900">{owner.name}</h2>
                <StatusBadge status={owner.status} />
              </div>
              <div className="flex flex-wrap items-center gap-4 text-sm text-gray-500">
                {owner.email && (
                  <span className="flex items-center gap-1.5"><Mail className="w-3.5 h-3.5" />{owner.email}</span>
                )}
                {owner.phone && (
                  <span className="flex items-center gap-1.5"><Phone className="w-3.5 h-3.5" />{owner.phone}</span>
                )}
                <span className="flex items-center gap-1.5">
                  <Calendar className="w-3.5 h-3.5" />Joined {fmtDate(owner.created_at)}
                </span>
              </div>
            </div>
          </div>

          {/* Action buttons */}
          <div className="flex items-center gap-2">
            {owner.status === 'pending' && (
              <>
                <button
                  onClick={() => onApprove(owner.id)}
                  className="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors"
                >
                  Approve
                </button>
                <button
                  onClick={() => { onReject(owner.id); onClose() }}
                  className="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg text-sm hover:bg-gray-50 transition-colors"
                >
                  Reject
                </button>
              </>
            )}
            {owner.status === 'active' && (
              <button
                onClick={() => onBlock(owner.id)}
                className="px-4 py-2 border border-red-200 text-red-600 rounded-lg text-sm hover:bg-red-50 transition-colors"
              >
                Block Owner
              </button>
            )}
            {owner.status === 'blocked' && (
              <button
                onClick={() => onUnblock(owner.id)}
                className="px-4 py-2 border border-green-200 text-green-600 rounded-lg text-sm hover:bg-green-50 transition-colors"
              >
                Unblock Owner
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Stats row */}
      {loading ? (
        <div className="flex items-center justify-center py-12">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600" />
        </div>
      ) : (
        <>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              { label: 'Total Sites', val: sites.length, color: 'text-gray-900' },
              { label: 'Total Cashiers', val: cashiers.length, color: 'text-blue-700' },
              { label: 'Total Bookings', val: bookingsCount.toLocaleString(), color: 'text-purple-700' },
              { label: 'Total Revenue', val: `Rs. ${revenue.toLocaleString()}`, color: 'text-green-700' },
            ].map(s => (
              <div key={s.label} className="bg-white rounded-xl border border-gray-200 p-5">
                <p className="text-xs text-gray-500 uppercase tracking-wide font-medium mb-1">{s.label}</p>
                <p className={`text-2xl font-bold ${s.color}`}>{s.val}</p>
              </div>
            ))}
          </div>

          {/* Monthly Revenue bar chart */}
          <div className="bg-white rounded-xl border border-gray-200 p-5">
            <div className="flex items-center justify-between mb-4">
              <div>
                <p className="text-sm font-semibold text-gray-900">Monthly Revenue</p>
                <p className="text-xs text-gray-500">Across all sites — current year</p>
              </div>
              <TrendingUp className="w-4 h-4 text-gray-400" />
            </div>
            <div className="flex items-end gap-2 h-24 mb-2">
              {monthlyRevenue.map((val, i) => (
                <div key={i} className="flex-1 flex flex-col items-center gap-1 group relative">
                  <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-gray-900 text-white text-[10px] px-1.5 py-0.5 rounded opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap pointer-events-none z-10">
                    Rs. {val.toLocaleString()}
                  </div>
                  <div
                    className="w-full bg-blue-500 hover:bg-blue-600 rounded-t-sm transition-colors"
                    style={{ height: `${maxBar > 0 ? (val / maxBar) * 100 : 0}%`, minHeight: val > 0 ? '4px' : '0' }}
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

          {/* Tabs: Sites / Cashiers */}
          <div className="bg-white rounded-xl border border-gray-200">
            <div className="flex border-b border-gray-200">
              {['sites', 'cashiers'].map(tab => (
                <button
                  key={tab}
                  onClick={() => setActiveTab(tab)}
                  className={`flex-1 px-6 py-3 text-sm font-medium transition-colors capitalize flex items-center justify-center gap-2 ${activeTab === tab
                      ? 'text-blue-600 border-b-2 border-blue-600 bg-blue-50'
                      : 'text-gray-500 hover:text-gray-700 hover:bg-gray-50'
                    }`}
                >
                  {tab === 'sites' ? <Building2 className="w-4 h-4" /> : <Users className="w-4 h-4" />}
                  {tab === 'sites' ? `Parking Sites (${sites.length})` : `Cashiers (${cashiers.length})`}
                </button>
              ))}
            </div>

            {/* Sites tab */}
            {activeTab === 'sites' && (
              <div className="divide-y divide-gray-100">
                {sites.length === 0 ? (
                  <div className="text-center py-10 text-gray-400 text-sm">No sites registered yet.</div>
                ) : sites.map(site => (
                  <div key={site.id} className="p-5">
                    <div className="flex items-start justify-between mb-3">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-lg bg-blue-50 flex items-center justify-center">
                          <MapPin className="w-4 h-4 text-blue-600" />
                        </div>
                        <div>
                          <p className="text-sm font-semibold text-gray-900">{site.name}</p>
                          <p className="text-xs text-gray-500">{site.city || site.address || '—'}</p>
                        </div>
                      </div>
                      <StatusBadge status={site.status} />
                    </div>

                    <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-3">
                      {[
                        { label: 'Capacity', val: `${site.total_slots || 0} slots` },
                        { label: 'Currently Active', val: `${site.occupied} vehicles` },
                        { label: 'Total Bookings', val: site.bookings },
                        { label: 'Revenue', val: `Rs. ${site.revenue.toLocaleString()}`, green: true },
                      ].map(s => (
                        <div key={s.label} className="bg-gray-50 rounded-lg p-3">
                          <p className="text-xs text-gray-500 mb-0.5">{s.label}</p>
                          <p className={`text-sm font-semibold ${s.green ? 'text-green-600' : 'text-gray-900'}`}>{s.val}</p>
                        </div>
                      ))}
                    </div>

                    <div className="flex items-center gap-4 text-xs text-gray-500">
                      <span className="flex items-center gap-1">
                        <span className="w-2 h-2 rounded-full bg-blue-400 inline-block" />
                        {site.slots.normal} Normal
                      </span>
                      <span className="flex items-center gap-1">
                        <span className="w-2 h-2 rounded-full bg-purple-400 inline-block" />
                        {site.slots.vip} VIP
                      </span>
                      <span className="flex items-center gap-1">
                        <span className="w-2 h-2 rounded-full bg-orange-400 inline-block" />
                        {site.slots.disabled} Disabled
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            )}

            {/* Cashiers tab */}
            {activeTab === 'cashiers' && (
              <div className="divide-y divide-gray-100">
                {cashiers.length === 0 ? (
                  <div className="text-center py-10 text-gray-400 text-sm">No cashiers assigned yet.</div>
                ) : (
                  <>
                    <div className="grid grid-cols-12 gap-4 px-5 py-2 text-xs text-gray-500 uppercase tracking-wide font-medium bg-gray-50">
                      <div className="col-span-4">Name</div>
                      <div className="col-span-5">Assigned Site</div>
                      <div className="col-span-3 text-center">Status</div>
                    </div>
                    {cashiers.map((c) => (
                      <div key={c.id} className="grid grid-cols-12 gap-4 px-5 py-3.5 items-center hover:bg-gray-50 transition-colors">
                        <div className="col-span-4 flex items-center gap-3">
                          <div className="w-8 h-8 rounded-full bg-gray-100 flex items-center justify-center text-xs font-semibold text-gray-600 flex-shrink-0">
                            {(c.name || 'CA').slice(0, 2).toUpperCase()}
                          </div>
                          <span className="text-sm font-medium text-gray-900">{c.name}</span>
                        </div>
                        <div className="col-span-5">
                          <span className="text-sm text-gray-500">{c.parking_sites?.name || '—'}</span>
                        </div>
                        <div className="col-span-3 flex justify-center">
                          <StatusBadge status={c.status || 'active'} />
                        </div>
                      </div>
                    ))}
                  </>
                )}
              </div>
            )}
          </div>
        </>
      )}
    </div>
  )
}

// ── MAIN PAGE ─────────────────────────────────────────────────────────────

export default function OwnerAccounts() {
  const [owners, setOwners] = useState([])
  const [search, setSearch] = useState('')
  const [filterStatus, setFilterStatus] = useState('all')
  const [selectedOwner, setSelectedOwner] = useState(null)
  const [loading, setLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState(null) // id of owner being acted on

  // ── Fetch owners ────────────────────────────────────────────────────────
  const fetchOwners = async () => {
    setLoading(true)
    try {
      const res = await api.get('/auth/admin/users/?role=parking_owner')
      const mapped = (res.data || []).map(o => ({
        id: o.id,
        name: o.full_name || '—',
        email: o.email,
        phone: o.phone_number,
        status: o.status,
        siteCount: o.siteCount || 0,
        cashierCount: o.cashierCount || 0,
        created_at: o.created_at,
      }))
      setOwners(mapped)
    } catch (err) {
      console.error('Owners fetch error:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchOwners()
  }, [])

  // ── Actions ─────────────────────────────────────────────────────────────

  const handleApprove = async (id) => {
    setActionLoading(id)
    try {
      await api.patch(`/auth/admin/owners/${id}/approve/`, { action: 'approve' })
      setOwners(prev => prev.map(o => o.id === id ? { ...o, status: 'active' } : o))
      if (selectedOwner?.id === id) setSelectedOwner(prev => ({ ...prev, status: 'active' }))
    } catch (err) {
      console.error('Approve error:', err)
    } finally {
      setActionLoading(null)
    }
  }

  const handleBlock = async (id) => {
    setActionLoading(id)
    try {
      await api.patch(`/auth/admin/users/${id}/toggle/`, { action: 'block' })
      setOwners(prev => prev.map(o => o.id === id ? { ...o, status: 'blocked' } : o))
      if (selectedOwner?.id === id) setSelectedOwner(prev => ({ ...prev, status: 'blocked' }))
    } catch (err) {
      console.error('Block error:', err)
    } finally {
      setActionLoading(null)
    }
  }

  const handleUnblock = async (id) => {
    setActionLoading(id)
    try {
      await api.patch(`/auth/admin/users/${id}/toggle/`, { action: 'unblock' })
      setOwners(prev => prev.map(o => o.id === id ? { ...o, status: 'active' } : o))
      if (selectedOwner?.id === id) setSelectedOwner(prev => ({ ...prev, status: 'active' }))
    } catch (err) {
      console.error('Unblock error:', err)
    } finally {
      setActionLoading(null)
    }
  }

  const handleReject = async (id) => {
    setActionLoading(id)
    try {
      await api.patch(`/auth/admin/owners/${id}/approve/`, { action: 'reject' })
      setOwners(prev => prev.filter(o => o.id !== id))
      if (selectedOwner?.id === id) setSelectedOwner(null)
    } catch (err) {
      console.error('Reject error:', err)
    } finally {
      setActionLoading(null)
    }
  }

  const handleDeleteOwner = async (email, id) => {
    if (!window.confirm("Are you sure you want to permanently delete this owner? This will allow them to register again.")) return
    setActionLoading(id)
    try {
      await api.delete('/auth/admin/owner-cleanup/', {
        data: { email }
      })
      setOwners(prev => prev.filter(o => o.id !== id))
      if (selectedOwner?.id === id) setSelectedOwner(null)
    } catch (err) {
      console.error('Delete owner error:', err)
      alert('Failed to delete owner')
    } finally {
      setActionLoading(null)
    }
  }

  // ── Filter ───────────────────────────────────────────────────────────────

  const filtered = owners.filter(o => {
    const matchSearch =
      (o.name || '').toLowerCase().includes(search.toLowerCase()) ||
      (o.email || '').toLowerCase().includes(search.toLowerCase())
    const matchStatus = filterStatus === 'all' || o.status === filterStatus
    return matchSearch && matchStatus
  })

  const counts = {
    total: owners.length,
    active: owners.filter(o => o.status === 'active').length,
    pending: owners.filter(o => o.status === 'pending').length,
    blocked: owners.filter(o => o.status === 'blocked').length,
  }

  // ── Detail panel view ────────────────────────────────────────────────────

  if (selectedOwner) {
    return (
      <OwnerDetailPanel
        owner={selectedOwner}
        onClose={() => setSelectedOwner(null)}
        onApprove={handleApprove}
        onBlock={handleBlock}
        onUnblock={handleUnblock}
        onReject={handleReject}
      />
    )
  }

  // ── Main list view ────────────────────────────────────────────────────────

  return (
    <div className="p-6 space-y-6 bg-gray-50 min-h-screen">

      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Owner Accounts</h1>
          <p className="text-gray-500 mt-1 text-sm">
            Approve, block, or manage parking owners. Click <strong>View</strong> to see sites, cashiers & revenue.
          </p>
        </div>
        <button
          onClick={fetchOwners}
          className="flex items-center gap-2 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg text-sm hover:bg-gray-50 transition-colors"
        >
          <RefreshCw className="w-4 h-4" /> Refresh
        </button>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {[
          { label: 'Total Owners', value: counts.total, iconBg: 'bg-blue-100', iconColor: 'text-blue-600', icon: Users },
          { label: 'Active', value: counts.active, iconBg: 'bg-green-100', iconColor: 'text-green-600', icon: CheckCircle },
          { label: 'Pending', value: counts.pending, iconBg: 'bg-yellow-100', iconColor: 'text-yellow-600', icon: UserCheck },
          { label: 'Blocked', value: counts.blocked, iconBg: 'bg-red-100', iconColor: 'text-red-600', icon: XCircle },
        ].map(s => {
          const IconComp = s.icon
          return (
            <div key={s.label} className="bg-white rounded-xl p-6 border border-gray-200">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-500">{s.label}</p>
                  <p className="text-2xl font-bold text-gray-900 mt-1">{s.value}</p>
                </div>
                <div className={`p-3 rounded-lg ${s.iconBg}`}>
                  <IconComp className={`w-5 h-5 ${s.iconColor}`} />
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* Search + Filter + Table */}
      <div className="bg-white rounded-xl border border-gray-200">
        {/* Controls */}
        <div className="p-6 border-b border-gray-200 flex flex-wrap items-center gap-3">
          {/* Search */}
          <div className="relative flex-1 min-w-[200px]">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input
              type="text"
              placeholder="Search by name or email..."
              value={search}
              onChange={e => setSearch(e.target.value)}
              className="pl-9 pr-4 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 w-full"
            />
          </div>

          {/* Status filter tabs */}
          <div className="flex items-center gap-2">
            {['all', 'active', 'pending', 'blocked'].map(s => (
              <button
                key={s}
                onClick={() => setFilterStatus(s)}
                className={`text-xs px-3 py-2 rounded-lg font-medium transition-colors capitalize ${filterStatus === s
                    ? 'bg-blue-600 text-white'
                    : 'border border-gray-300 text-gray-600 hover:bg-gray-50'
                  }`}
              >
                {s}
              </button>
            ))}
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
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Owner</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Email / Phone</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3 text-center">Sites & Cashiers</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Joined</th>
                  <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3 text-center">Status</th>
                  <th className="text-right text-xs font-medium text-gray-500 uppercase px-6 py-3">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {filtered.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="text-center py-12 text-gray-400 text-sm">
                      No owners found.
                    </td>
                  </tr>
                ) : filtered.map(owner => (
                  <tr key={owner.id} className="hover:bg-gray-50 transition-colors">

                    {/* Name + avatar */}
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-full bg-blue-100 flex items-center justify-center text-sm font-bold text-blue-700 flex-shrink-0">
                          {(owner.name || 'OW').slice(0, 2).toUpperCase()}
                        </div>
                        <button
                          onClick={() => setSelectedOwner(owner)}
                          className="text-sm font-medium text-gray-900 hover:text-blue-600 transition-colors text-left truncate max-w-[140px]"
                        >
                          {owner.name || '—'}
                        </button>
                      </div>
                    </td>

                    {/* Email + Phone */}
                    <td className="px-6 py-4">
                      <p className="text-sm text-gray-900 truncate max-w-[180px]">{owner.email || '—'}</p>
                      <p className="text-xs text-gray-400">{owner.phone || '—'}</p>
                    </td>

                    {/* Sites & Cashiers count */}
                    <td className="px-6 py-4 text-center">
                      <div className="flex flex-col items-center justify-center">
                        <span className="text-sm font-semibold text-gray-900">{owner.siteCount} Sites</span>
                        <span className="text-xs text-gray-500">{owner.cashierCount} Cashiers</span>
                      </div>
                    </td>

                    {/* Joined date */}
                    <td className="px-6 py-4 text-sm text-gray-500">
                      {fmtDate(owner.created_at)}
                    </td>

                    {/* Status badge */}
                    <td className="px-6 py-4 text-center">
                      <StatusBadge status={owner.status} />
                    </td>

                    {/* Actions */}
                    <td className="px-6 py-4">
                      <div className="flex items-center justify-end gap-2">

                        {/* View always shown */}
                        <button
                          onClick={() => setSelectedOwner(owner)}
                          className="flex items-center gap-1 text-xs px-3 py-1.5 border border-gray-300 text-gray-600 rounded-lg hover:bg-gray-50 transition-colors"
                        >
                          <Eye className="w-3.5 h-3.5" /> View
                        </button>

                        {/* Pending → Approve + Reject */}
                        {owner.status === 'pending' && (
                          <>
                            <button
                              onClick={() => handleApprove(owner.id)}
                              disabled={actionLoading === owner.id}
                              className="text-xs px-3 py-1.5 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium disabled:opacity-50"
                            >
                              {actionLoading === owner.id ? '...' : 'Approve'}
                            </button>
                            <button
                              onClick={() => handleReject(owner.id)}
                              disabled={actionLoading === owner.id}
                              className="text-xs px-3 py-1.5 border border-gray-300 text-gray-600 rounded-lg hover:bg-gray-50 transition-colors disabled:opacity-50"
                            >
                              Reject
                            </button>
                          </>
                        )}

                        {/* Active → Block */}
                        {owner.status === 'active' && (
                          <button
                            onClick={() => handleBlock(owner.id)}
                            disabled={actionLoading === owner.id}
                            className="text-xs px-3 py-1.5 border border-red-200 text-red-600 rounded-lg hover:bg-red-50 transition-colors disabled:opacity-50"
                          >
                            {actionLoading === owner.id ? '...' : 'Block'}
                          </button>
                        )}

                        {/* Blocked → Unblock */}
                        {owner.status === 'blocked' && (
                          <button
                            onClick={() => handleUnblock(owner.id)}
                            disabled={actionLoading === owner.id}
                            className="text-xs px-3 py-1.5 border border-green-200 text-green-600 rounded-lg hover:bg-green-50 transition-colors disabled:opacity-50"
                          >
                            {actionLoading === owner.id ? '...' : 'Unblock'}
                          </button>
                        )}

                        {/* Delete */}
                        <button
                          onClick={() => handleDeleteOwner(owner.email, owner.id)}
                          disabled={actionLoading === owner.id}
                          className="text-xs px-3 py-1.5 border border-red-200 text-red-600 rounded-lg hover:bg-red-50 transition-colors disabled:opacity-50 flex items-center gap-1"
                        >
                          <Trash2 className="w-3.5 h-3.5" /> {actionLoading === owner.id ? '...' : 'Delete'}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Footer count */}
        {!loading && filtered.length > 0 && (
          <div className="px-6 py-3 border-t border-gray-100">
            <p className="text-xs text-gray-400">
              Showing {filtered.length} of {owners.length} owners
            </p>
          </div>
        )}
      </div>
    </div>
  )
}