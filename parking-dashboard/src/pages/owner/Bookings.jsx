import React, { useState, useEffect } from 'react'
import api from '../../api/axios'
import { Calendar, Clock, Car, Phone, Search, Filter, Eye, X } from 'lucide-react'

const Bookings = () => {
  const [searchTerm, setSearchTerm] = useState('')
  const [statusFilter, setStatusFilter] = useState('All')
  const [selectedBooking, setSelectedBooking] = useState(null)
  const [bookings, setBookings] = useState([])

  useEffect(() => {
    fetchBookings()
  }, [])

  async function fetchBookings() {
    try {
      const [bookRes, payRes] = await Promise.allSettled([
        api.get('/bookings/owner/'),
        api.get('/payments/owner/')
      ])

      const bookingMap = {}
      if (bookRes.status === 'fulfilled') {
        (bookRes.value.data || []).forEach(b => {
          const id = b.id || b.booking_id
          bookingMap[id] = {
            id,
            customerName: b.user || 'Guest',
            phone: b.user_phone || '-',
            vehicleNo: b.vehicle_plate || '-',
            slotNumber: b.slot_number || 'N/A',
            bookingDate: b.entry_time ? b.entry_time.split('T')[0] : '-',
            entryTime: b.entry_time ? new Date(b.entry_time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '-',
            exitTime: b.exit_time ? new Date(b.exit_time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '-',
            amount: parseFloat(b.estimated_amount) || 0,
            status: b.status ? b.status.charAt(0).toUpperCase() + b.status.slice(1) : 'Active',
            paymentStatus: b.payment_status === 'paid' || b.payment_status === 'Paid' ? 'Paid' : 'Pending',
          }
        })
      }

      if (payRes.status === 'fulfilled') {
        const d = payRes.value.data
        const payments = d.payments || []
        payments.forEach(p => {
          const id = p.id || p.booking_id
          if (!bookingMap[id]) {
            bookingMap[id] = {
              id,
              customerName: p.plate_number || 'Guest',
              phone: '-',
              vehicleNo: p.plate_number || '-',
              slotNumber: p.slot_number || 'N/A',
              bookingDate: p.paid_at ? p.paid_at.split('T')[0] : '-',
              entryTime: p.paid_at ? new Date(p.paid_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '-',
              exitTime: '-',
              amount: parseFloat(p.amount) || 0,
              status: p.status === 'success' ? 'Completed' : p.status === 'pending' ? 'Active' : p.status,
              paymentStatus: p.status === 'success' ? 'Paid' : 'Pending',
            }
          }
        })
      }

      setBookings(Object.values(bookingMap))
    } catch (err) {
      console.error(err)
    }
  }

  const filteredBookings = bookings.filter(booking => {
    const searchLow = searchTerm.toLowerCase()
    const matchesSearch = (booking.customerName || '').toLowerCase().includes(searchLow) ||
                         (booking.vehicleNo || '').toLowerCase().includes(searchLow) ||
                         String(booking.id || '').toLowerCase().includes(searchLow)
    const matchesStatus = statusFilter === 'All' || booking.status === statusFilter
    return matchesSearch && matchesStatus
  })

  const getStatusColor = (status) => {
    switch(status) {
      case 'Active': return 'bg-green-100 text-green-700 border-green-200'
      case 'Completed': return 'bg-blue-100 text-blue-700 border-blue-200'
      case 'Upcoming': return 'bg-yellow-100 text-yellow-700 border-yellow-200'
      case 'Cancelled': return 'bg-red-100 text-red-700 border-red-200'
      default: return 'bg-gray-100 text-gray-700 border-gray-200'
    }
  }

  const getPaymentColor = (status) => {
    switch(status) {
      case 'Paid': return 'bg-green-100 text-green-700'
      case 'Pending': return 'bg-orange-100 text-orange-700'
      case 'Refunded': return 'bg-gray-100 text-gray-700'
      default: return 'bg-gray-100 text-gray-700'
    }
  }

  const stats = {
    total: bookings.length,
    active: bookings.filter(b => b.status === 'Active').length,
    completed: bookings.filter(b => b.status === 'Completed').length,
    cancelled: bookings.filter(b => b.status === 'Cancelled').length,
    revenue: bookings.filter(b => b.paymentStatus === 'Paid').reduce((sum, b) => sum + b.amount, 0)
  }

  return (
    <div className="p-6 space-y-6 bg-gray-50 min-h-screen">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Bookings Management</h1>
        <p className="text-gray-600 mt-1">View and manage all parking bookings</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
        <div className="bg-white rounded-xl p-4 border border-gray-200"><p className="text-sm text-gray-500">Total Bookings</p><p className="text-2xl font-bold text-gray-900 mt-1">{stats.total}</p></div>
        <div className="bg-white rounded-xl p-4 border border-gray-200"><p className="text-sm text-gray-500">Active</p><p className="text-2xl font-bold text-green-600 mt-1">{stats.active}</p></div>
        <div className="bg-white rounded-xl p-4 border border-gray-200"><p className="text-sm text-gray-500">Completed</p><p className="text-2xl font-bold text-blue-600 mt-1">{stats.completed}</p></div>
        <div className="bg-white rounded-xl p-4 border border-gray-200"><p className="text-sm text-gray-500">Cancelled</p><p className="text-2xl font-bold text-yellow-600 mt-1">{stats.cancelled}</p></div>
        <div className="bg-white rounded-xl p-4 border border-gray-200"><p className="text-sm text-gray-500">Total Revenue</p><p className="text-2xl font-bold text-green-600 mt-1">Rs. {stats.revenue.toLocaleString()}</p></div>
      </div>

      <div className="bg-white rounded-xl p-4 border border-gray-200">
        <div className="flex flex-col md:flex-row gap-4">
          <div className="flex-1 relative">
            <Search className="w-5 h-5 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <input type="text" placeholder="Search by name, vehicle no, or booking ID..." value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)} className="w-full pl-10 pr-4 py-2 bg-gray-50 border border-gray-300 rounded-lg text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500" />
          </div>
          <div className="flex items-center gap-2">
            <Filter className="w-5 h-5 text-gray-400" />
            <select value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)} className="px-4 py-2 bg-gray-50 border border-gray-300 rounded-lg text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500">
              <option value="All">All Status</option>
              <option value="Active">Active</option>
              <option value="Completed">Completed</option>
              <option value="Cancelled">Cancelled</option>
            </select>
          </div>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-4 py-3">Booking ID</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-4 py-3">Customer</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-4 py-3">Vehicle</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-4 py-3">Slot</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-4 py-3">Date & Time</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-4 py-3">Amount</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-4 py-3">Status</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-4 py-3">Payment</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-4 py-3">View</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filteredBookings.length === 0 ? (
                <tr>
                  <td colSpan={9} className="px-4 py-8 text-center text-gray-400 text-sm">No bookings found</td>
                </tr>
              ) : filteredBookings.map((booking) => (
                <tr key={booking.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-4 py-3 text-sm font-medium text-gray-900 font-mono">{String(booking.id).slice(-8)}</td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-2">
                      <div className="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 text-xs font-semibold">
                        {(booking.customerName || '?').split(' ').map(n => n[0]).join('').slice(0,2)}
                      </div>
                      <div>
                        <p className="text-sm font-medium text-gray-900">{booking.customerName}</p>
                        <p className="text-xs text-gray-500 flex items-center gap-1"><Phone className="w-3 h-3" />{booking.phone}</p>
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-1 text-sm text-gray-900">
                      <Car className="w-4 h-4 text-gray-400" />
                      <span className="font-mono">{booking.vehicleNo}</span>
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <span className="px-2 py-1 bg-gray-100 text-gray-700 text-xs rounded font-medium">
                      {booking.slotNumber}
                    </span>
                  </td>
                  <td className="px-4 py-3">
                    <div className="text-sm">
                      <p className="text-gray-900 flex items-center gap-1"><Calendar className="w-3 h-3 text-gray-400" />{booking.bookingDate}</p>
                      <p className="text-xs text-gray-500 flex items-center gap-1 mt-1"><Clock className="w-3 h-3" />{booking.entryTime}{booking.exitTime !== '-' ? ` - ${booking.exitTime}` : ''}</p>
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <p className="text-sm font-semibold text-green-600">Rs. {booking.amount.toLocaleString()}</p>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-1 text-xs rounded-full border ${getStatusColor(booking.status)}`}>{booking.status}</span>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-1 text-xs rounded-full ${getPaymentColor(booking.paymentStatus)}`}>{booking.paymentStatus}</span>
                  </td>
                  <td className="px-4 py-3">
                    <button onClick={() => setSelectedBooking(booking)} className="p-2 hover:bg-gray-100 rounded-lg transition-colors">
                      <Eye className="w-4 h-4 text-gray-600" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {selectedBooking && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl p-6 max-w-2xl w-full max-h- overflow-y-auto">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-xl font-bold text-gray-900">Booking Details</h3>
              <button onClick={() => setSelectedBooking(null)} className="p-2 hover:bg-gray-100 rounded-lg"><X className="w-5 h-5" /></button>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div><p className="text-sm text-gray-500">Booking ID</p><p className="text-gray-900 font-medium font-mono">{String(selectedBooking.id).slice(-8)}</p></div>
              <div><p className="text-sm text-gray-500">Status</p><span className={`px-2 py-1 text-xs rounded-full border inline-block mt-1 ${getStatusColor(selectedBooking.status)}`}>{selectedBooking.status}</span></div>
              <div><p className="text-sm text-gray-500">Customer</p><p className="text-gray-900 font-medium">{selectedBooking.customerName}</p></div>
              <div><p className="text-sm text-gray-500">Phone</p><p className="text-gray-900 font-medium">{selectedBooking.phone}</p></div>
              <div><p className="text-sm text-gray-500">Vehicle</p><p className="text-gray-900 font-medium">{selectedBooking.vehicleNo}</p></div>
              <div><p className="text-sm text-gray-500">Slot</p><p className="text-gray-900 font-medium">{selectedBooking.slotNumber}</p></div>
              <div><p className="text-sm text-gray-500">Date</p><p className="text-gray-900 font-medium">{selectedBooking.bookingDate}</p></div>
              <div><p className="text-sm text-gray-500">Amount</p><p className="text-green-600 font-bold">Rs. {selectedBooking.amount.toLocaleString()}</p></div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default Bookings
