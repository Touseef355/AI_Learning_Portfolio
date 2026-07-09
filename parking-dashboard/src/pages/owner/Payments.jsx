import React, { useState, useEffect, useMemo } from 'react'
import api from '../../api/axios'
import { Wallet, TrendingUp, Download, Search, Clock, DollarSign } from 'lucide-react'

const Payments = () => {
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState('All')
  const [dateFilter, setDateFilter] = useState('All Time')
  const [payments, setPayments] = useState([])

  useEffect(() => {
    fetchPayments()
  }, [])

  async function fetchPayments() {
    try {
      const res = await api.get('/payments/owner/')
      const d = res.data
      const mapped = (d.payments || []).map((p) => ({
        id: p.id,
        bookingId: p.id,
        customer: p.plate_number || 'Guest',
        vehicle: p.plate_number || '-',
        amount: parseFloat(p.amount) || 0,
        method: p.payment_method || 'Cash',
        date: p.paid_at ? p.paid_at.split('T')[0] : '-',
        time: p.paid_at ? new Date(p.paid_at).toLocaleTimeString([], { hour:'2-digit', minute:'2-digit' }) : '-',
        status: p.status === 'success' ? 'Completed' : 'Pending',
      }))
      setPayments(mapped)
    } catch (err) {
      console.error(err)
    }
  }

  const isDateInRange = (date, filter) => {
    const today = new Date()
    const d = new Date(date)
    if (filter === 'Today') return d.toDateString() === today.toDateString()
    if (filter === 'This Week') { const w = new Date(); w.setDate(today.getDate()-7); return d >= w }
    if (filter === 'This Month') return d.getMonth() === today.getMonth() && d.getFullYear() === today.getFullYear()
    return true
  }

  const filteredPayments = useMemo(() => {
    return payments.filter(p => {
      const s = searchTerm.toLowerCase()
      const matchSearch = p.customer.toLowerCase().includes(s) || p.vehicle.toLowerCase().includes(s) || p.id.toLowerCase().includes(s)
      const matchStatus = statusFilter === 'All' || p.status === statusFilter
      const matchDate = isDateInRange(p.date, dateFilter)
      return matchSearch && matchStatus && matchDate
    })
  }, [payments, searchTerm, statusFilter, dateFilter])

  const stats = useMemo(() => {
    const completed = payments.filter(p => p.status === 'Completed')
    const today = new Date().toISOString().split('T')[0]
    return {
      totalRevenue: completed.reduce((s,p) => s + p.amount, 0),
      todayRevenue: completed.filter(p => p.date === today).reduce((s,p) => s + p.amount, 0),
      pendingAmount: payments.filter(p => p.status === 'Pending').reduce((s,p) => s + p.amount, 0),
      totalTransactions: payments.length
    }
  }, [payments])

  const handleExport = () => {
    const headers = ['Payment ID','Customer','Vehicle','Amount','Method','Date','Time','Status']
    const rows = filteredPayments.map(p => [p.id, p.customer, p.vehicle, p.amount, p.method, p.date, p.time, p.status])
    const csv = [headers,...rows].map(r => r.join(',')).join('\n')
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.setAttribute('download', `payments_${new Date().toISOString().split('T')[0]}.csv`)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
  }

  const getStatusColor = (s) => s === 'Completed' ? 'bg-green-100 text-green-700' : s === 'Pending' ? 'bg-yellow-100 text-yellow-700' : 'bg-red-100 text-red-700'
  const getMethodColor = (m) => m === 'Cash' ? 'bg-blue-100 text-blue-700' : m === 'Card' ? 'bg-purple-100 text-purple-700' : 'bg-gray-100 text-gray-700'

  return (
    <div className="p-6 space-y-6 bg-gray-50 min-h-screen">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Payments</h1>
          <p className="text-gray-600 mt-1">Track and manage all payment transactions</p>
        </div>
        <button onClick={handleExport} className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
          <Download className="w-4 h-4" /> Export CSV
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div className="bg-white rounded-xl p-6 border border-gray-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">Total Revenue</p>
              <p className="text-2xl font-bold text-gray-900 mt-1">Rs. {stats.totalRevenue.toLocaleString()}</p>
              <p className="text-xs text-gray-500 mt-1">All time</p>
            </div>
            <div className="p-3 bg-green-100 rounded-lg"><DollarSign className="w-5 h-5 text-green-600" /></div>
          </div>
        </div>

        <div className="bg-white rounded-xl p-6 border border-gray-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">Today's Revenue</p>
              <p className="text-2xl font-bold text-green-600 mt-1">Rs. {stats.todayRevenue.toLocaleString()}</p>
              <p className="text-xs text-gray-500 mt-1">From completed payments</p>
            </div>
            <div className="p-3 bg-green-100 rounded-lg"><TrendingUp className="w-5 h-5 text-green-600" /></div>
          </div>
        </div>

        <div className="bg-white rounded-xl p-6 border border-gray-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">Pending Amount</p>
              <p className="text-2xl font-bold text-yellow-600 mt-1">Rs. {stats.pendingAmount.toLocaleString()}</p>
              <p className="text-xs text-gray-500 mt-1">Awaiting payment</p>
            </div>
            <div className="p-3 bg-yellow-100 rounded-lg"><Clock className="w-5 h-5 text-yellow-600" /></div>
          </div>
        </div>

        <div className="bg-white rounded-xl p-6 border border-gray-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm text-gray-500">Total Transactions</p>
              <p className="text-2xl font-bold text-gray-900 mt-1">{stats.totalTransactions}</p>
              <p className="text-xs text-gray-500 mt-1">All payments</p>
            </div>
            <div className="p-3 bg-blue-100 rounded-lg"><Wallet className="w-5 h-5 text-blue-600" /></div>
          </div>
        </div>
      </div>

      <div className="bg-white rounded-xl p-4 border border-gray-200">
        <div className="flex flex-col md:flex-row gap-4">
          <div className="flex-1 relative">
            <Search className="w-5 h-5 text-gray-400 absolute left-3 top-1/2 transform -translate-y-1/2" />
            <input type="text" placeholder="Search by customer, vehicle, or payment ID..." value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)} className="w-full pl-10 pr-4 py-2 bg-gray-50 border border-gray-300 rounded-lg text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div className="flex gap-2">
            <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} className="px-4 py-2 bg-gray-50 border border-gray-300 rounded-lg text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500">
              <option>All</option><option>Completed</option><option>Pending</option>
            </select>
            <select value={dateFilter} onChange={(e) => setDateFilter(e.target.value)} className="px-4 py-2 bg-gray-50 border border-gray-300 rounded-lg text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500">
              <option>All Time</option><option>Today</option><option>This Week</option><option>This Month</option>
            </select>
          </div>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left text-xs font-medium text-gray-500 px-6 py-3">PAYMENT ID</th>
                <th className="text-left text-xs font-medium text-gray-500 px-6 py-3">CUSTOMER</th>
                <th className="text-left text-xs font-medium text-gray-500 px-6 py-3">VEHICLE</th>
                <th className="text-left text-xs font-medium text-gray-500 px-6 py-3">AMOUNT</th>
                <th className="text-left text-xs font-medium text-gray-500 px-6 py-3">METHOD</th>
                <th className="text-left text-xs font-medium text-gray-500 px-6 py-3">DATE & TIME</th>
                <th className="text-left text-xs font-medium text-gray-500 px-6 py-3">STATUS</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {filteredPayments.length === 0 ? (
                <tr><td colSpan="7" className="px-6 py-8 text-center text-gray-500">No payments found</td></tr>
              ) : filteredPayments.map((p) => (
                <tr key={p.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-6 py-4 text-sm font-medium text-gray-900 font-mono">{String(p.id).slice(-8)}</td>
                  <td className="px-6 py-4"><p className="text-sm font-medium text-gray-900">{p.customer}</p></td>
                  <td className="px-6 py-4 text-sm text-gray-900 font-mono">{p.vehicle}</td>
                  <td className="px-6 py-4"><span className="text-sm font-bold text-green-600">Rs. {p.amount.toLocaleString()}</span></td>
                  <td className="px-6 py-4"><span className={`px-2 py-1 text-xs font-medium rounded-full ${getMethodColor(p.method)}`}>{p.method}</span></td>
                  <td className="px-6 py-4"><p className="text-sm text-gray-900">{p.date}</p><p className="text-xs text-gray-500">{p.time}</p></td>
                  <td className="px-6 py-4"><span className={`px-2 py-1 text-xs font-medium rounded-full ${getStatusColor(p.status)}`}>{p.status}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}

export default Payments
