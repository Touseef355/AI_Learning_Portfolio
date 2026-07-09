import { useEffect, useState, useRef, useCallback } from 'react'
import API from '../../services/api'
import {
  Mail, Phone, User, MessageSquare, CheckCircle, XCircle,
  Search, Building, Copy, RefreshCw, Send, AlertCircle,
  Clock, ChevronDown, Eye, X, Check
} from 'lucide-react'
import { useNotifications } from '../../utils/NotificationContext'

export default function Queries() {
  const [queries, setQueries] = useState([])
  const [ownerRequests, setOwnerRequests] = useState([])
  const [loading, setLoading] = useState(true)
  const [activeTab, setActiveTab] = useState('owner')
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')

  // Credentials Modal State
  const [showCreds, setShowCreds] = useState(false)
  const [creds, setCreds] = useState(null)

  // Respond Modal State (for general queries)
  const [showRespond, setShowRespond] = useState(false)
  const [respondQuery, setRespondQuery] = useState(null)
  const [respondMsg, setRespondMsg] = useState('')
  const [respondLoading, setRespondLoading] = useState(false)

  // Reject Modal State
  const [showReject, setShowReject] = useState(false)
  const [rejectQuery, setRejectQuery] = useState(null)
  const [rejectReason, setRejectReason] = useState('')
  const [rejectLoading, setRejectLoading] = useState(false)

  // Polling state
  const [isPolling, setIsPolling] = useState(false)
  const [lastFetchTime, setLastFetchTime] = useState(null)
  const prevCountRef = useRef(0)

  const { markAsSeen, addToast, refetch: refetchNotifications } = useNotifications()

  useEffect(() => {
    fetchAllQueries()
    markAsSeen()
  }, [])

  // Auto-poll for new queries every 20 seconds
  useEffect(() => {
    const interval = setInterval(() => {
      fetchAllQueries(true)
    }, 20000)
    return () => clearInterval(interval)
  }, [])

  const fetchAllQueries = useCallback(async (silent = false) => {
    if (!silent) setLoading(true)
    setIsPolling(true)
    try {
      const response = await API.get('auth/admin/registration-queries/')
      const data = response.data

      const now = new Date()
      const validData = data.filter(q => {
        const isPendingOrApproved = q.status === 'PENDING' || q.status === 'APPROVED'
        const isOlderThan24h = (now - new Date(q.created_at)) > 24 * 60 * 60 * 1000
        if (isPendingOrApproved && isOlderThan24h) return false
        return true
      })

      const newOwnerRequests = validData.filter(q => q.query_type === 'owner_registration')
      const newQueries = validData.filter(q => q.query_type === 'general_support')

      if (silent) {
        const totalNow = data.filter(q => q.status === 'PENDING').length
        const totalBefore = prevCountRef.current
        if (totalNow > totalBefore) {
          const diff = totalNow - totalBefore
          addToast(`📩 ${diff} new ${diff === 1 ? 'query' : 'queries'} arrived!`, 'info')
          refetchNotifications()
        }
        prevCountRef.current = totalNow
      } else {
        prevCountRef.current = data.filter(q => q.status === 'PENDING').length
      }

      setOwnerRequests(newOwnerRequests)
      setQueries(newQueries)
      setLastFetchTime(new Date())
    } catch (err) {
      console.error('Error fetching queries:', err)
      if (!silent) addToast('Failed to load queries', 'error')
    } finally {
      setLoading(false)
      setIsPolling(false)
    }
  }, [addToast, refetchNotifications])

  // ── Approve Owner ──────────────────────────────────────────────────────────
  async function approveOwner(query) {
    if (!confirm(`Approve ${query.full_name} as Parking Owner?\n\nThis will:\n• Create an owner account\n• Generate a temporary password\n• Send credentials to ${query.email}`)) return

    try {
      const response = await API.post(`auth/admin/queries/${query.id}/approve-onboard/`)

      setOwnerRequests(prev =>
        prev.map(q => q.id === query.id ? { ...q, status: 'APPROVED' } : q)
      )

      setCreds(response.data.credentials)
      setShowCreds(true)

      refetchNotifications()

      const emailNote = response.data.email_sent
        ? '✅ Credentials email sent to owner!'
        : '⚠️ Owner approved but email could not be sent. Share credentials manually.'

      addToast(emailNote, response.data.email_sent ? 'success' : 'warning')
      addToast(`✅ ${query.full_name} approved as Parking Owner!`, 'success')

    } catch (err) {
      console.error(err)
      addToast(err.response?.data?.error || 'Failed to approve owner', 'error')
    }
  }

  // ── Reject Query ───────────────────────────────────────────────────────────
  function openRejectModal(query) {
    setRejectQuery(query)
    setRejectReason('')
    setShowReject(true)
  }

  async function submitReject() {
    if (!rejectQuery) return
    setRejectLoading(true)
    try {
      await API.post(`auth/admin/queries/${rejectQuery.id}/reject/`, { reason: rejectReason })

      setOwnerRequests(prev =>
        prev.map(q => q.id === rejectQuery.id ? { ...q, status: 'REJECTED' } : q)
      )

      setShowReject(false)
      refetchNotifications()
      addToast(`❌ Query from ${rejectQuery.full_name} rejected.`, 'info')
    } catch (err) {
      addToast(err.response?.data?.error || 'Failed to reject query', 'error')
    } finally {
      setRejectLoading(false)
    }
  }

  // ── Respond to General Query ───────────────────────────────────────────────
  function openRespondModal(query) {
    setRespondQuery(query)
    setRespondMsg('')
    setShowRespond(true)
  }

  async function submitResponse() {
    if (!respondQuery || !respondMsg.trim()) return
    setRespondLoading(true)
    try {
      await API.post(`auth/admin/queries/${respondQuery.id}/respond/`, { message: respondMsg })

      setQueries(prev =>
        prev.map(q => q.id === respondQuery.id ? { ...q, status: 'RESOLVED' } : q)
      )

      setShowRespond(false)
      refetchNotifications()
      addToast(`✅ Response sent to ${respondQuery.email}!`, 'success')
    } catch (err) {
      addToast(err.response?.data?.error || 'Failed to send response', 'error')
    } finally {
      setRespondLoading(false)
    }
  }

  const currentData = activeTab === 'owner' ? ownerRequests : queries
  const filteredData = currentData.filter(q => {
    const matchesSearch =
      q.full_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      q.email.toLowerCase().includes(searchTerm.toLowerCase())
    const matchesStatus = statusFilter === 'all' || q.status === statusFilter.toUpperCase()
    return matchesSearch && matchesStatus
  })

  const stats = {
    totalQueries: queries.length,
    pendingQueries: queries.filter(q => q.status === 'PENDING').length,
    ownerRequests: ownerRequests.length,
    pendingApprovals: ownerRequests.filter(q => q.status === 'PENDING').length,
  }

  const getStatusBadge = (status) => {
    const styles = {
      PENDING: 'bg-amber-100 text-amber-800 border border-amber-200',
      APPROVED: 'bg-emerald-100 text-emerald-800 border border-emerald-200',
      REJECTED: 'bg-red-100 text-red-800 border border-red-200',
      RESOLVED: 'bg-blue-100 text-blue-800 border border-blue-200',
    }
    const icons = {
      PENDING: <Clock size={11} className="inline mr-1" />,
      APPROVED: <Check size={11} className="inline mr-1" />,
      REJECTED: <X size={11} className="inline mr-1" />,
      RESOLVED: <CheckCircle size={11} className="inline mr-1" />,
    }
    return { cls: styles[status] || styles.PENDING, icon: icons[status] || icons.PENDING }
  }

  if (loading) return (
    <div className="flex items-center justify-center h-screen bg-gray-50">
      <div className="flex flex-col items-center gap-3">
        <RefreshCw className="animate-spin text-blue-500" size={28} />
        <span className="text-gray-600">Loading queries...</span>
      </div>
    </div>
  )

  return (
    <div className="p-6 bg-gray-50 min-h-screen">
      {/* Header */}
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 mb-1">Queries & Registrations</h1>
          <p className="text-gray-500 text-sm">Manage contact queries and owner registration requests</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-emerald-50 border border-emerald-200">
            <span style={{
              width: '8px', height: '8px', borderRadius: '50%',
              backgroundColor: '#22c55e', display: 'inline-block',
              animation: 'livePulse 2s infinite',
            }}></span>
            <span className="text-xs font-medium text-emerald-700">Live Updates</span>
          </div>
          {lastFetchTime && (
            <span className="text-xs text-gray-400">
              Last updated: {lastFetchTime.toLocaleTimeString()}
            </span>
          )}
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <div className="bg-white border border-gray-200 rounded-xl p-5 shadow-sm">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-9 h-9 bg-blue-50 rounded-lg flex items-center justify-center">
              <MessageSquare className="text-blue-600" size={18} />
            </div>
            <span className="text-gray-500 text-sm">Total Queries</span>
          </div>
          <div className="text-3xl font-bold text-gray-900">{stats.totalQueries}</div>
        </div>
        <div className="bg-white border border-gray-200 rounded-xl p-5 shadow-sm relative overflow-hidden">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-9 h-9 bg-amber-50 rounded-lg flex items-center justify-center">
              <Clock className="text-amber-600" size={18} />
            </div>
            <span className="text-gray-500 text-sm">Pending Queries</span>
          </div>
          <div className="text-3xl font-bold text-amber-600">{stats.pendingQueries}</div>
          {stats.pendingQueries > 0 && (
            <div style={{
              position: 'absolute', top: '12px', right: '12px',
              width: '10px', height: '10px', borderRadius: '50%',
              backgroundColor: '#eab308', animation: 'livePulse 2s infinite'
            }}></div>
          )}
        </div>
        <div className="bg-white border border-gray-200 rounded-xl p-5 shadow-sm">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-9 h-9 bg-indigo-50 rounded-lg flex items-center justify-center">
              <Building className="text-indigo-600" size={18} />
            </div>
            <span className="text-gray-500 text-sm">Owner Requests</span>
          </div>
          <div className="text-3xl font-bold text-indigo-600">{stats.ownerRequests}</div>
        </div>
        <div className="bg-white border border-gray-200 rounded-xl p-5 shadow-sm relative overflow-hidden">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-9 h-9 bg-orange-50 rounded-lg flex items-center justify-center">
              <AlertCircle className="text-orange-600" size={18} />
            </div>
            <span className="text-gray-500 text-sm">Pending Approvals</span>
          </div>
          <div className="text-3xl font-bold text-orange-600">{stats.pendingApprovals}</div>
          {stats.pendingApprovals > 0 && (
            <div style={{
              position: 'absolute', top: '12px', right: '12px',
              width: '10px', height: '10px', borderRadius: '50%',
              backgroundColor: '#f97316', animation: 'livePulse 2s infinite'
            }}></div>
          )}
        </div>
      </div>

      {/* Tabs */}
      <div className="flex gap-1 mb-6 bg-white border border-gray-200 rounded-xl p-1 w-fit shadow-sm">
        <button
          onClick={() => setActiveTab('owner')}
          className={`flex items-center gap-2 px-5 py-2.5 rounded-lg text-sm font-medium transition-all ${
            activeTab === 'owner'
              ? 'bg-blue-600 text-white shadow-sm'
              : 'text-gray-600 hover:bg-gray-50'
          }`}
        >
          <Building size={16} />
          Owner Registrations ({ownerRequests.length})
          {stats.pendingApprovals > 0 && (
            <span className={`text-xs font-bold px-2 py-0.5 rounded-full ${
              activeTab === 'owner' ? 'bg-white/20 text-white' : 'bg-red-500 text-white'
            }`}>{stats.pendingApprovals}</span>
          )}
        </button>
        <button
          onClick={() => setActiveTab('general')}
          className={`flex items-center gap-2 px-5 py-2.5 rounded-lg text-sm font-medium transition-all ${
            activeTab === 'general'
              ? 'bg-blue-600 text-white shadow-sm'
              : 'text-gray-600 hover:bg-gray-50'
          }`}
        >
          <MessageSquare size={16} />
          General Queries ({queries.length})
          {stats.pendingQueries > 0 && (
            <span className={`text-xs font-bold px-2 py-0.5 rounded-full ${
              activeTab === 'general' ? 'bg-white/20 text-white' : 'bg-amber-500 text-white'
            }`}>{stats.pendingQueries}</span>
          )}
        </button>
      </div>

      {/* Search & Filter */}
      <div className="flex gap-3 mb-6">
        <div className="flex-1 relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" size={18} />
          <input
            type="text"
            placeholder="Search by name or email..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full bg-white border border-gray-300 rounded-lg pl-10 pr-4 py-2.5 text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm"
          />
        </div>
        <div className="relative">
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="appearance-none bg-white border border-gray-300 rounded-lg pl-4 pr-10 py-2.5 text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm cursor-pointer"
          >
            <option value="all">All Status</option>
            <option value="pending">Pending</option>
            <option value="approved">Approved</option>
            <option value="rejected">Rejected</option>
            <option value="resolved">Resolved</option>
          </select>
          <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" size={16} />
        </div>
        <button
          onClick={() => fetchAllQueries()}
          disabled={isPolling}
          className={`bg-white border border-gray-300 px-4 py-2.5 rounded-lg hover:bg-gray-50 flex items-center gap-2 text-sm text-gray-700 transition-all ${isPolling ? 'opacity-60' : ''}`}
        >
          <RefreshCw size={15} className={isPolling ? 'animate-spin' : ''} />
          Refresh
        </button>
      </div>

      {/* Query List */}
      <div className="space-y-4">
        {filteredData.length === 0 ? (
          <div className="bg-white border border-gray-200 rounded-xl p-16 text-center">
            <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <MessageSquare className="text-gray-400" size={24} />
            </div>
            <h3 className="text-gray-700 font-medium mb-1">No queries found</h3>
            <p className="text-gray-400 text-sm">
              {statusFilter !== 'all'
                ? `No ${statusFilter} queries in this category.`
                : activeTab === 'owner'
                  ? 'No owner registration requests yet.'
                  : 'No general support queries yet.'
              }
            </p>
          </div>
        ) : (
          filteredData.map((q) => {
            const badge = getStatusBadge(q.status)
            return (
              <div
                key={q.id}
                className="bg-white border border-gray-200 rounded-xl shadow-sm hover:shadow-md transition-all duration-200"
                style={{ animation: 'fadeInUp 0.3s ease-out' }}
              >
                <div className="p-5">
                  <div className="flex justify-between items-start mb-4">
                    <div className="flex items-center gap-3">
                      <div className="w-11 h-11 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-full flex items-center justify-center text-white font-semibold text-lg">
                        {q.full_name.charAt(0).toUpperCase()}
                      </div>
                      <div>
                        <h3 className="font-semibold text-gray-900 text-base">{q.full_name}</h3>
                        <div className="flex flex-wrap items-center gap-3 text-xs text-gray-500 mt-0.5">
                          <span className="flex items-center gap-1">
                            <Mail size={12} /> {q.email}
                          </span>
                          {q.phone_number && (
                            <span className="flex items-center gap-1">
                              <Phone size={12} /> {q.phone_number}
                            </span>
                          )}
                        </div>
                      </div>
                    </div>
                    <div className="flex flex-col items-end gap-1.5">
                      <span className={`px-3 py-1 rounded-full text-xs font-semibold ${badge.cls}`}>
                        {badge.icon}{q.status}
                      </span>
                      <span className="text-xs text-gray-400">
                        {new Date(q.created_at).toLocaleString('en-PK', {
                          day: '2-digit', month: 'short', year: 'numeric',
                          hour: '2-digit', minute: '2-digit'
                        })}
                      </span>
                    </div>
                  </div>

                  {/* Owner registration extra info */}
                  {activeTab === 'owner' && (q.proposed_site_name || q.site_capacity) && (
                    <div className="bg-blue-50 border border-blue-100 rounded-lg p-3 mb-3 grid grid-cols-2 gap-3 text-sm">
                      {q.proposed_site_name && (
                        <div>
                          <span className="text-gray-400 text-xs uppercase tracking-wide">Site Name</span>
                          <div className="font-semibold text-gray-800 mt-0.5">{q.proposed_site_name}</div>
                        </div>
                      )}
                      {q.site_capacity && (
                        <div>
                          <span className="text-gray-400 text-xs uppercase tracking-wide">Capacity</span>
                          <div className="font-semibold text-gray-800 mt-0.5">{q.site_capacity} slots</div>
                        </div>
                      )}
                    </div>
                  )}

                  {/* Message */}
                  {q.message && (
                    <div className="bg-gray-50 rounded-lg p-4 mb-4 border border-gray-100">
                      <div className="text-xs text-gray-400 uppercase tracking-wide mb-1.5">Message</div>
                      <p className="text-gray-700 text-sm whitespace-pre-wrap leading-relaxed">{q.message}</p>
                    </div>
                  )}

                  {/* Admin response (for resolved general queries) */}
                  {q.admin_response && (
                    <div className="bg-emerald-50 rounded-lg p-4 mb-4 border border-emerald-100">
                      <div className="text-xs text-emerald-600 uppercase tracking-wide mb-1.5 font-semibold">Admin Response</div>
                      <p className="text-gray-700 text-sm whitespace-pre-wrap leading-relaxed">{q.admin_response}</p>
                    </div>
                  )}

                  {/* Action Buttons */}
                  <div className="flex gap-2 pt-2">
                    {activeTab === 'owner' && q.status === 'PENDING' && (
                      <>
                        <button
                          onClick={() => approveOwner(q)}
                          className="flex items-center gap-2 bg-emerald-600 hover:bg-emerald-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors"
                        >
                          <CheckCircle size={15} /> Approve & Onboard
                        </button>
                        <button
                          onClick={() => openRejectModal(q)}
                          className="flex items-center gap-2 bg-white border border-red-200 text-red-600 hover:bg-red-50 px-4 py-2 rounded-lg text-sm font-medium transition-colors"
                        >
                          <XCircle size={15} /> Reject
                        </button>
                      </>
                    )}

                    {activeTab === 'general' && q.status === 'PENDING' && (
                      <button
                        onClick={() => openRespondModal(q)}
                        className="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors"
                      >
                        <Send size={15} /> Respond via Email
                      </button>
                    )}

                    {q.status === 'APPROVED' && (
                      <div className="flex items-center gap-2 text-emerald-600 text-sm font-medium">
                        <CheckCircle size={15} /> Owner account created & onboarded
                      </div>
                    )}

                    {q.status === 'RESOLVED' && (
                      <div className="flex items-center gap-2 text-blue-600 text-sm font-medium">
                        <CheckCircle size={15} /> Response sent to {q.email}
                      </div>
                    )}

                    {q.status === 'REJECTED' && (
                      <div className="flex items-center gap-2 text-red-500 text-sm font-medium">
                        <XCircle size={15} /> Request rejected
                      </div>
                    )}
                  </div>
                </div>
              </div>
            )
          })
        )}
      </div>

      {/* ── Credentials Modal ────────────────────────────────────────────────── */}
      {showCreds && creds && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl max-w-md w-full p-7" style={{ animation: 'slideUp 0.25s ease-out' }}>
            <div className="text-center mb-6">
              <div className="mx-auto w-16 h-16 bg-emerald-100 rounded-full flex items-center justify-center mb-4">
                <CheckCircle className="w-8 h-8 text-emerald-600" />
              </div>
              <h2 className="text-2xl font-bold text-gray-900">Owner Approved!</h2>
              <p className="text-gray-500 mt-1.5 text-sm">Account and parking site created successfully.</p>
            </div>

            <div className="bg-gray-50 border border-gray-200 rounded-xl p-5 space-y-4 mb-5">
              <div>
                <label className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Email (Username)</label>
                <div className="flex items-center justify-between mt-1.5 bg-white border border-gray-200 rounded-lg px-3 py-2">
                  <code className="text-gray-900 text-sm">{creds.email}</code>
                  <button
                    onClick={() => { navigator.clipboard.writeText(creds.email); addToast('Email copied!', 'success') }}
                    className="text-blue-600 hover:text-blue-800 text-xs flex items-center gap-1 ml-2"
                  >
                    <Copy size={13} /> Copy
                  </button>
                </div>
              </div>
              <div>
                <label className="text-xs font-semibold text-gray-400 uppercase tracking-wider">Temporary Password</label>
                <div className="flex items-center justify-between mt-1.5 bg-white border border-gray-200 rounded-lg px-3 py-2">
                  <code className="text-gray-900 text-sm font-mono">{creds.temporary_password}</code>
                  <button
                    onClick={() => { navigator.clipboard.writeText(creds.temporary_password); addToast('Password copied!', 'success') }}
                    className="text-blue-600 hover:text-blue-800 text-xs flex items-center gap-1 ml-2"
                  >
                    <Copy size={13} /> Copy
                  </button>
                </div>
              </div>
            </div>

            <div className="bg-blue-50 border border-blue-100 text-blue-800 text-sm p-4 rounded-xl mb-5 flex gap-3">
              <Mail size={16} className="shrink-0 mt-0.5" />
              <span>Credentials have been emailed to the owner automatically. You can also share them manually below.</span>
            </div>

            <div className="flex gap-3">
              <a
                href={`mailto:${creds.email}?subject=Your SmartPark Owner Account Credentials&body=Dear Owner,%0A%0AYour parking owner account has been approved.%0A%0ALogin Credentials:%0AEmail: ${creds.email}%0APassword: ${creds.temporary_password}%0A%0APlease visit the SmartPark landing page to sign in.%0A%0ARegards,%0ASmartPark Admin`}
                className="flex-1 bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 rounded-xl transition-colors flex items-center justify-center gap-2 text-sm"
              >
                <Mail size={16} /> Email Again
              </a>
              <button
                onClick={() => setShowCreds(false)}
                className="flex-1 bg-gray-900 hover:bg-gray-800 text-white font-semibold py-3 rounded-xl transition-colors text-sm"
              >
                Done
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Respond Modal ────────────────────────────────────────────────────── */}
      {showRespond && respondQuery && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl max-w-lg w-full p-7" style={{ animation: 'slideUp 0.25s ease-out' }}>
            <div className="flex items-center gap-3 mb-5">
              <div className="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center">
                <Send className="text-blue-600" size={20} />
              </div>
              <div>
                <h2 className="text-xl font-bold text-gray-900">Respond to Query</h2>
                <p className="text-gray-500 text-sm">Reply will be sent to <strong>{respondQuery.email}</strong></p>
              </div>
            </div>

            {/* Original message */}
            <div className="bg-gray-50 border border-gray-200 rounded-xl p-4 mb-4">
              <div className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-2">Original Query from {respondQuery.full_name}</div>
              <p className="text-gray-700 text-sm leading-relaxed">{respondQuery.message}</p>
            </div>

            {/* Response textarea */}
            <div className="mb-5">
              <label className="block text-sm font-semibold text-gray-700 mb-2">Your Response</label>
              <textarea
                value={respondMsg}
                onChange={(e) => setRespondMsg(e.target.value)}
                rows={5}
                placeholder="Type your response here. This will be sent directly to the user's email..."
                className="w-full border border-gray-300 rounded-xl p-4 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none"
              />
              <div className="text-xs text-gray-400 mt-1 text-right">{respondMsg.length} characters</div>
            </div>

            <div className="flex gap-3">
              <button
                onClick={() => setShowRespond(false)}
                className="flex-1 bg-gray-100 hover:bg-gray-200 text-gray-700 font-semibold py-3 rounded-xl transition-colors text-sm"
              >
                Cancel
              </button>
              <button
                onClick={submitResponse}
                disabled={respondLoading || !respondMsg.trim()}
                className="flex-1 bg-blue-600 hover:bg-blue-700 disabled:opacity-60 text-white font-semibold py-3 rounded-xl transition-colors flex items-center justify-center gap-2 text-sm"
              >
                {respondLoading ? <RefreshCw size={15} className="animate-spin" /> : <Send size={15} />}
                {respondLoading ? 'Sending...' : 'Send Response'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Reject Modal ─────────────────────────────────────────────────────── */}
      {showReject && rejectQuery && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl max-w-md w-full p-7" style={{ animation: 'slideUp 0.25s ease-out' }}>
            <div className="flex items-center gap-3 mb-5">
              <div className="w-12 h-12 bg-red-100 rounded-xl flex items-center justify-center">
                <XCircle className="text-red-600" size={20} />
              </div>
              <div>
                <h2 className="text-xl font-bold text-gray-900">Reject Registration</h2>
                <p className="text-gray-500 text-sm">Rejecting request from <strong>{rejectQuery.full_name}</strong></p>
              </div>
            </div>

            <div className="mb-5">
              <label className="block text-sm font-semibold text-gray-700 mb-2">Reason (optional)</label>
              <textarea
                value={rejectReason}
                onChange={(e) => setRejectReason(e.target.value)}
                rows={4}
                placeholder="Provide a reason for rejection. This will be included in the email sent to the applicant..."
                className="w-full border border-gray-300 rounded-xl p-4 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-red-400 focus:border-red-400 resize-none"
              />
            </div>

            <div className="bg-amber-50 border border-amber-100 text-amber-800 text-sm p-3.5 rounded-xl mb-5 flex gap-2">
              <AlertCircle size={15} className="shrink-0 mt-0.5" />
              <span>A rejection email will be sent to <strong>{rejectQuery.email}</strong>.</span>
            </div>

            <div className="flex gap-3">
              <button
                onClick={() => setShowReject(false)}
                className="flex-1 bg-gray-100 hover:bg-gray-200 text-gray-700 font-semibold py-3 rounded-xl transition-colors text-sm"
              >
                Cancel
              </button>
              <button
                onClick={submitReject}
                disabled={rejectLoading}
                className="flex-1 bg-red-600 hover:bg-red-700 disabled:opacity-60 text-white font-semibold py-3 rounded-xl transition-colors flex items-center justify-center gap-2 text-sm"
              >
                {rejectLoading ? <RefreshCw size={15} className="animate-spin" /> : <XCircle size={15} />}
                {rejectLoading ? 'Rejecting...' : 'Reject Request'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Animations */}
      <style>{`
        @keyframes livePulse {
          0%, 100% { opacity: 1; transform: scale(1); }
          50% { opacity: 0.5; transform: scale(1.3); }
        }
        @keyframes fadeInUp {
          from { opacity: 0; transform: translateY(10px); }
          to { opacity: 1; transform: translateY(0); }
        }
        @keyframes slideUp {
          from { opacity: 0; transform: translateY(20px) scale(0.97); }
          to { opacity: 1; transform: translateY(0) scale(1); }
        }
      `}</style>
    </div>
  )
}