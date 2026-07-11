import { useState, useEffect } from 'react'
import {
  MapPin,
  Plus,
  Search,
  Edit2,
  Trash2,
  X,
  Building2,
  Mail,
  Phone,
  RefreshCw
} from 'lucide-react'

import api from '../../api/axios'

// ─────────────────────────────────────────────
// Status Badge
// ─────────────────────────────────────────────
function StatusBadge({ status }) {
  const styles = {
    active: 'bg-green-100 text-green-700',
    pending: 'bg-yellow-100 text-yellow-700',
    blocked: 'bg-red-100 text-red-600',
  }

  return (
    <span
      className={`text-xs px-2.5 py-1 rounded-full font-medium ${styles[status] || 'bg-gray-100 text-gray-700'}`}
    >
      {status ? (status.charAt(0).toUpperCase() + status.slice(1)) : 'Unknown'}
    </span>
  )
}

// ─────────────────────────────────────────────
// Confirm Delete Modal
// ─────────────────────────────────────────────
function ConfirmDeleteModal({ site, onConfirm, onCancel }) {
  return (
    <div className="fixed inset-0 bg-black/40 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-card border border-border rounded-2xl w-full max-w-sm p-6 shadow-xl animate-in fade-in zoom-in duration-200">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-base font-semibold text-foreground">
            Remove Site
          </h2>
          <button
            onClick={onCancel}
            className="text-muted-foreground hover:text-foreground transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <p className="text-sm text-muted-foreground mb-1">
          Are you sure you want to remove:
        </p>
        <p className="text-sm font-semibold text-foreground mb-4">
          "{site.name}"
        </p>

        <p className="text-xs text-red-500 bg-red-50 dark:bg-red-950/20 px-3 py-2 rounded-lg mb-5">
          This action cannot be undone and will delete all associated slots.
        </p>

        <div className="flex justify-end gap-3">
          <button
            onClick={onCancel}
            className="text-sm px-4 py-2 border border-border rounded-lg hover:bg-secondary transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            className="text-sm px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
          >
            Delete
          </button>
        </div>
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────
// Add / Edit Modal
// ─────────────────────────────────────────────
function SiteModal({ site, onClose, onSave }) {
  const isEdit = !!site

  const [form, setForm] = useState({
    name: site?.name || '',
    address: site?.address || '',
    total_slots: site?.total_slots || '',
    total_floors: site?.total_floors || '2',
    opening_time: site?.opening_time || '06:00',
    closing_time: site?.closing_time || '23:00',
    contact_number: site?.contact_number || '',
    email: site?.email || '',
    status: site?.status || 'active',
  })

  const handleChange = (e) => {
    setForm(prev => ({
      ...prev,
      [e.target.name]: e.target.value
    }))
  }

  const handleSubmit = () => {
    if (!form.name || !form.address || !form.total_slots) {
      alert('Please fill all required fields: Name, Address, Total Slots')
      return
    }

    onSave({
      ...site,
      name: form.name,
      address: form.address,
      total_slots: Number(form.total_slots),
      total_floors: Number(form.total_floors) || 2,
      opening_time: form.opening_time,
      closing_time: form.closing_time,
      contact_number: form.contact_number,
      email: form.email,
      status: form.status,
    })

    onClose()
  }

  return (
    <div className="fixed inset-0 bg-black/40 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-card border border-border rounded-2xl w-full max-w-lg p-6 shadow-xl max-h-[90vh] overflow-y-auto animate-in fade-in zoom-in duration-200">
        {/* HEADER */}
        <div className="flex items-center justify-between mb-5 border-b border-border pb-3">
          <div>
            <h2 className="text-base font-semibold text-foreground">
              {isEdit ? 'Edit Parking Site' : 'Add Parking Site'}
            </h2>
            <p className="text-xs text-muted-foreground mt-1">
              {isEdit ? 'Update the site details below' : 'Fill in the site details below'}
            </p>
          </div>
          <button
            onClick={onClose}
            className="text-muted-foreground hover:text-foreground transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* FORM */}
        <div className="grid grid-cols-2 gap-4">
          <div className="col-span-2">
            <label className="text-xs font-semibold text-muted-foreground block mb-1">Site Name *</label>
            <input
              name="name"
              value={form.name}
              onChange={handleChange}
              placeholder="Downtown Premium Parking"
              className="w-full border border-border rounded-lg px-3 py-2 text-sm bg-background text-foreground focus:outline-none focus:border-primary"
            />
          </div>

          <div className="col-span-2">
            <label className="text-xs font-semibold text-muted-foreground block mb-1">Address *</label>
            <input
              name="address"
              value={form.address}
              onChange={handleChange}
              placeholder="Sector G-11, Islamabad"
              className="w-full border border-border rounded-lg px-3 py-2 text-sm bg-background text-foreground focus:outline-none focus:border-primary"
            />
          </div>

          <div>
            <label className="text-xs font-semibold text-muted-foreground block mb-1">Total Slots *</label>
            <input
              type="number"
              name="total_slots"
              value={form.total_slots}
              onChange={handleChange}
              placeholder="100"
              className="w-full border border-border rounded-lg px-3 py-2 text-sm bg-background text-foreground focus:outline-none focus:border-primary"
            />
          </div>

          <div>
            <label className="text-xs font-semibold text-muted-foreground block mb-1">Pricing</label>
            <div className="w-full border border-border rounded-lg px-3 py-2 text-xs bg-background text-muted-foreground">
              Prices are set per slot in the owner's Slot Config.
            </div>
          </div>

          <div>
            <label className="text-xs font-semibold text-muted-foreground block mb-1">Total Floors</label>
            <input
              type="number"
              name="total_floors"
              value={form.total_floors}
              onChange={handleChange}
              placeholder="2"
              className="w-full border border-border rounded-lg px-3 py-2 text-sm bg-background text-foreground focus:outline-none focus:border-primary"
            />
          </div>

          <div>
            <label className="text-xs font-semibold text-muted-foreground block mb-1">Status</label>
            <select
              name="status"
              value={form.status}
              onChange={handleChange}
              className="w-full border border-border rounded-lg px-3 py-2 text-sm bg-background text-foreground focus:outline-none focus:border-primary"
            >
              <option value="active">Active</option>
              <option value="pending">Pending</option>
              <option value="blocked">Blocked</option>
            </select>
          </div>

          <div>
            <label className="text-xs font-semibold text-muted-foreground block mb-1">Opening Time</label>
            <input
              type="time"
              name="opening_time"
              value={form.opening_time}
              onChange={handleChange}
              className="w-full border border-border rounded-lg px-3 py-2 text-sm bg-background text-foreground focus:outline-none focus:border-primary"
            />
          </div>

          <div>
            <label className="text-xs font-semibold text-muted-foreground block mb-1">Closing Time</label>
            <input
              type="time"
              name="closing_time"
              value={form.closing_time}
              onChange={handleChange}
              className="w-full border border-border rounded-lg px-3 py-2 text-sm bg-background text-foreground focus:outline-none focus:border-primary"
            />
          </div>

          <div>
            <label className="text-xs font-semibold text-muted-foreground block mb-1">Contact Number</label>
            <input
              name="contact_number"
              value={form.contact_number}
              onChange={handleChange}
              placeholder="+92 300 1234567"
              className="w-full border border-border rounded-lg px-3 py-2 text-sm bg-background text-foreground focus:outline-none focus:border-primary"
            />
          </div>

          <div>
            <label className="text-xs font-semibold text-muted-foreground block mb-1">Email</label>
            <input
              type="email"
              name="email"
              value={form.email}
              onChange={handleChange}
              placeholder="downtown@smartpark.com"
              className="w-full border border-border rounded-lg px-3 py-2 text-sm bg-background text-foreground focus:outline-none focus:border-primary"
            />
          </div>
        </div>

        {/* FOOTER */}
        <div className="flex justify-end gap-3 mt-6 border-t border-border pt-4">
          <button
            onClick={onClose}
            className="text-sm px-4 py-2 border border-border rounded-lg hover:bg-secondary transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            className="text-sm px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:opacity-90 transition-opacity font-semibold"
          >
            {isEdit ? 'Save Changes' : 'Add Site'}
          </button>
        </div>
      </div>
    </div>
  )
}

// ─────────────────────────────────────────────
// MAIN PAGE
// ─────────────────────────────────────────────
export default function ParkingSites() {
  const [sites, setSites] = useState([])
  const [loading, setLoading] = useState(true)

  const [search, setSearch] = useState('')
  const [filterStatus, setFilterStatus] = useState('all')

  const [showModal, setShowModal] = useState(false)
  const [editSite, setEditSite] = useState(null)
  const [deleteSite, setDeleteSite] = useState(null)

  // ─────────────────────────────────────────
  // FETCH SITES
  // ─────────────────────────────────────────
  useEffect(() => {
    fetchSites()
  }, [])

  const fetchSites = async () => {
    setLoading(true)
    try {
      const { data } = await api.get('/parking/sites/')
      setSites(data || [])
    } catch (error) {
      console.error('Error fetching sites:', error)
    } finally {
      setLoading(false)
    }
  }

  // ─────────────────────────────────────────
  // SAVE SITE
  // ─────────────────────────────────────────
  const handleSave = async (site) => {
    try {
      const sitePayload = {
        name: site.name,
        address: site.address,
        total_slots: site.total_slots,
        // price_per_hour intentionally not sent — pricing is per slot now
        // (Slot Config); site-level price is only a legacy fallback.
        total_floors: site.total_floors,
        opening_time: site.opening_time,
        closing_time: site.closing_time,
        contact_number: site.contact_number,
        email: site.email,
        status: site.status,
      }

      if (site.id) {
        // EDIT
        await api.put(`/parking/sites/${site.id}/`, sitePayload)
      } else {
        // ADD
        await api.post('/parking/sites/', sitePayload)
      }

      fetchSites()
    } catch (error) {
      console.error('Save Error:', error)
      alert('Error saving site: ' + error.message)
    }
  }

  // ─────────────────────────────────────────
  // DELETE SITE
  // ─────────────────────────────────────────
  const handleDelete = async () => {
    if (!deleteSite) return
    try {
      await api.delete(`/parking/sites/${deleteSite.id}/`)

      if (deleteSite.email) {
        try {
          await api.delete('/auth/admin/owner-cleanup/', {
            data: { email: deleteSite.email }
          })
        } catch (apiErr) {
          console.error('Owner cleanup error:', apiErr)
        }
      }

      setDeleteSite(null)
      fetchSites()
    } catch (error) {
      console.error('Delete Error:', error)
      alert('Error deleting site: ' + error.message)
    }
  }

  // ─────────────────────────────────────────
  // UPDATE STATUS
  // ─────────────────────────────────────────
  const updateStatus = async (id, status) => {
    try {
      await api.put(`/parking/sites/${id}/`, { status })
      fetchSites()
    } catch (error) {
      console.error('Status Update Error:', error)
    }
  }

  // ─────────────────────────────────────────
  // FILTER
  // ─────────────────────────────────────────
  const filtered = sites.filter(site => {
    const matchSearch =
      site.name?.toLowerCase().includes(search.toLowerCase()) ||
      site.address?.toLowerCase().includes(search.toLowerCase()) ||
      site.email?.toLowerCase().includes(search.toLowerCase()) ||
      site.contact_number?.toLowerCase().includes(search.toLowerCase())

    const matchStatus =
      filterStatus === 'all' ||
      site.status === filterStatus

    return matchSearch && matchStatus
  })

  // ─────────────────────────────────────────
  // COUNTS
  // ─────────────────────────────────────────
  const counts = {
    total: sites.length,
    active: sites.filter(s => s.status === 'active').length,
    pending: sites.filter(s => s.status === 'pending').length,
    blocked: sites.filter(s => s.status === 'blocked').length,
  }

  return (
    <div className="pb-8 space-y-6">
      {/* HEADER */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-border pb-5">
        <div>
          <h1 className="text-2xl font-bold text-foreground flex items-center gap-2">
            <Building2 className="w-6 h-6 text-primary" />
            Parking Sites
          </h1>
          <p className="text-sm text-muted-foreground mt-1">
            Add, edit, or manage status rules for all parking locations.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={fetchSites}
            className="flex items-center gap-2 text-sm px-4 py-2 border border-border rounded-lg text-muted-foreground hover:bg-secondary transition-colors"
          >
            <RefreshCw className="w-4 h-4" />
            Refresh
          </button>
          <button
            onClick={() => {
              setEditSite(null)
              setShowModal(true)
            }}
            className="flex items-center gap-2 text-sm px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:opacity-90 transition-opacity font-semibold shadow-sm"
          >
            <Plus className="w-4 h-4" />
            Add Site
          </button>
        </div>
      </div>

      {/* STATS */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {[
          { label: 'Total Sites', value: counts.total, color: 'text-foreground' },
          { label: 'Active', value: counts.active, color: 'text-green-600' },
          { label: 'Pending', value: counts.pending, color: 'text-yellow-600' },
          { label: 'Blocked', value: counts.blocked, color: 'text-red-500' },
        ].map(s => (
          <div
            key={s.label}
            className="bg-card/60 backdrop-blur-md border border-border rounded-xl p-5 hover:shadow-md transition-shadow"
          >
            <p className="text-xs text-muted-foreground uppercase tracking-wide font-semibold mb-1">
              {s.label}
            </p>
            <p className={`text-2xl font-bold ${s.color}`}>
              {s.value}
            </p>
          </div>
        ))}
      </div>

      {/* TABLE SECTION */}
      <div className="bg-card border border-border rounded-xl p-5">
        {/* CONTROLS */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-5 pb-4 border-b border-border">
          {/* Search bar */}
          <div className="flex items-center gap-2 flex-1 border border-border rounded-lg px-3 py-2 bg-background">
            <Search className="w-4 h-4 text-muted-foreground" />
            <input
              type="text"
              placeholder="Search by site name, address, or contact details..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="flex-1 bg-transparent outline-none text-sm text-foreground"
            />
          </div>

          {/* Status filter tabs */}
          <div className="flex items-center gap-1.5 overflow-x-auto self-start md:self-auto">
            {['all', 'active', 'pending', 'blocked'].map(statusTab => (
              <button
                key={statusTab}
                onClick={() => setFilterStatus(statusTab)}
                className={`text-xs px-3 py-1.5 rounded-lg font-medium transition-colors capitalize ${filterStatus === statusTab
                    ? 'bg-primary text-primary-foreground'
                    : 'border border-border text-muted-foreground hover:bg-secondary'
                  }`}
              >
                {statusTab}
              </button>
            ))}
          </div>
        </div>

        {/* DATA GRID */}
        <div className="overflow-x-auto">
          <div className="min-w-[900px]">
            {/* Headers */}
            <div className="grid grid-cols-12 gap-4 px-3 py-2.5 text-xs font-semibold text-muted-foreground uppercase tracking-wide border-b border-border bg-secondary/30 rounded-t-lg items-center">
              <div className="col-span-3">Site Details</div>
              <div className="col-span-3">Contact Info</div>
              <div className="col-span-2 text-center">Slots & Floors</div>
              <div className="col-span-1 text-center">Rate / Hr</div>
              <div className="col-span-1 text-center">Timings</div>
              <div className="col-span-1 text-center">Status</div>
              <div className="col-span-1 text-right">Actions</div>
            </div>

            {/* List */}
            {loading ? (
              <div className="text-center py-12 text-muted-foreground flex flex-col items-center justify-center">
                <div className="w-8 h-8 border-3 border-primary border-t-transparent rounded-full animate-spin mb-3"></div>
                Loading sites list...
              </div>
            ) : filtered.length === 0 ? (
              <div className="text-center py-12 text-muted-foreground text-sm">
                No parking sites found matching current filters.
              </div>
            ) : (
              filtered.map(site => (
                <div
                  key={site.id}
                  className="grid grid-cols-12 gap-4 px-3 py-4 border-b border-border items-center hover:bg-secondary/10 transition-colors"
                >
                  {/* SITE INFO */}
                  <div className="col-span-3 flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0">
                      <MapPin className="w-4 h-4 text-primary" />
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-foreground">
                        {site.name}
                      </p>
                      <p className="text-xs text-muted-foreground truncate max-w-[200px]" title={site.address}>
                        {site.address || 'No Address'}
                      </p>
                    </div>
                  </div>

                  {/* CONTACT INFO */}
                  <div className="col-span-3 space-y-0.5">
                    {site.email && (
                      <p className="text-xs text-foreground flex items-center gap-1">
                        <Mail className="w-3 h-3 text-muted-foreground" />
                        {site.email}
                      </p>
                    )}
                    {site.contact_number && (
                      <p className="text-xs text-muted-foreground flex items-center gap-1">
                        <Phone className="w-3 h-3 text-muted-foreground" />
                        {site.contact_number}
                      </p>
                    )}
                    {!site.email && !site.contact_number && (
                      <p className="text-xs text-muted-foreground">No contact details</p>
                    )}
                  </div>

                  {/* SLOTS & FLOORS */}
                  <div className="col-span-2 text-center">
                    <p className="text-sm font-semibold text-foreground">
                      {site.total_slots} Slots
                    </p>
                    <p className="text-xs text-muted-foreground">
                      {site.total_floors || '1'} {site.total_floors === 1 ? 'Floor' : 'Floors'}
                    </p>
                  </div>

                  {/* RATE */}
                  <div className="col-span-1 text-center font-medium text-sm text-green-600">
                    {site.rate_per_hour ? `From Rs. ${site.rate_per_hour}` : '—'}
                  </div>

                  {/* TIMINGS */}
                  <div className="col-span-1 text-center text-xs text-foreground font-medium">
                    {site.opening_time || '00:00'} - {site.closing_time || '23:59'}
                  </div>

                  {/* STATUS */}
                  <div className="col-span-1 flex justify-center">
                    <StatusBadge status={site.status} />
                  </div>

                  {/* ACTIONS */}
                  <div className="col-span-1 flex justify-end gap-1.5">
                    <button
                      onClick={() => {
                        setEditSite(site)
                        setShowModal(true)
                      }}
                      className="p-1.5 border border-border rounded-lg hover:bg-secondary hover:text-foreground transition-all"
                      title="Edit site details"
                    >
                      <Edit2 className="w-3.5 h-3.5" />
                    </button>
                    <button
                      onClick={() => setDeleteSite(site)}
                      className="p-1.5 border border-red-200 text-red-500 rounded-lg hover:bg-red-50 hover:text-red-600 transition-all"
                      title="Remove site"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>

                    {/* Inline Status Actions */}
                    {site.status === 'pending' && (
                      <button
                        onClick={() => updateStatus(site.id, 'active')}
                        className="text-[10px] px-2 py-1 bg-primary text-primary-foreground rounded-lg hover:opacity-90 transition-opacity"
                      >
                        Approve
                      </button>
                    )}
                    {site.status === 'active' && (
                      <button
                        onClick={() => updateStatus(site.id, 'blocked')}
                        className="text-[10px] px-2 py-1 border border-red-200 text-red-600 rounded-lg hover:bg-red-50 transition-colors"
                      >
                        Block
                      </button>
                    )}
                    {site.status === 'blocked' && (
                      <button
                        onClick={() => updateStatus(site.id, 'active')}
                        className="text-[10px] px-2 py-1 border border-green-200 text-green-600 rounded-lg hover:bg-green-50 transition-colors"
                      >
                        Activate
                      </button>
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>

      {/* MODAL */}
      {showModal && (
        <SiteModal
          site={editSite}
          onClose={() => {
            setShowModal(false)
            setEditSite(null)
          }}
          onSave={handleSave}
        />
      )}

      {/* DELETE MODAL */}
      {deleteSite && (
        <ConfirmDeleteModal
          site={deleteSite}
          onConfirm={handleDelete}
          onCancel={() => setDeleteSite(null)}
        />
      )}
    </div>
  )
}