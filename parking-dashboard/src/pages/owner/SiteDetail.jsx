import { useState, useEffect, useCallback } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import api from '../../api/axios'
import { Pencil, Building2, Clock, MapPin, DollarSign, X, Plus } from 'lucide-react'

export default function SiteDetail() {
  const navigate = useNavigate()
  const [site, setSite] = useState(null)
  const [loading, setLoading] = useState(true)
  const [showModal, setShowModal] = useState(false)
  const [isEditing, setIsEditing] = useState(false)
  const [formData, setFormData] = useState({
    name: '',
    location: '',
    capacity: '',
    pricing_type: 'flat',
    flat_hours: 4,
    flat_price: '',
    extra_hour_rate: '',
    price_per_hour: '',
  })

  const { id } = useParams()

  const fetchSiteDetails = useCallback(async () => {
    try {
      if (!id) return
      const res = await api.get(`/parking/sites/${id}/`)
      setSite(res.data)
    } catch (error) {
      console.error('Error fetching site details:', error)
    } finally {
      setLoading(false)
    }
  }, [id])

  useEffect(() => {
    fetchSiteDetails()
  }, [fetchSiteDetails])

  const handleEdit = () => {
    setIsEditing(true)
    setFormData({
      name: site.name || '',
      location: site.location || '',
      capacity: site.capacity || '',
      pricing_type: site.pricing_type || 'flat',
      flat_hours: site.flat_hours ?? 4,
      flat_price: site.flat_price ?? '',
      extra_hour_rate: site.extra_hour_rate ?? '',
      price_per_hour: site.price_per_hour ?? '',
    })
    setShowModal(true)
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    try {
      const payload = {
        name: formData.name,
        location: formData.location,
        capacity: parseInt(formData.capacity) || 0,
        pricing_type: formData.pricing_type,
      }

      if (formData.pricing_type === 'flat') {
        payload.flat_hours = parseInt(formData.flat_hours) || 4
        payload.extra_hour_rate = formData.extra_hour_rate === '' ? null : parseFloat(formData.extra_hour_rate)
        // Base price ab har slot pe set hoti hai (Slot Config) — site-level
        // flat_price ko null kar do taake koi stale value fallback na bane.
        payload.flat_price = null
      } else {
        // Hourly rate bhi per-slot hai — site-level rate null.
        payload.price_per_hour = null
      }

      if (isEditing) {
        await api.put(`/parking/sites/${site.id}/`, payload)
        alert('Site updated successfully!')
      }

      setShowModal(false)
      fetchSiteDetails()
    } catch (error) {
      alert('Error saving site: ' + (error.response?.data?.detail || error.message))
    }
  }

  if (loading) return <div className="p-6">Loading...</div>
  if (!site) return (
    <div className="p-6">
      <div className="text-center py-12">
        <p className="text-gray-500 text-lg mb-4">No site found</p>
        <button
          onClick={() => navigate('/owner/site')}
          className="bg-blue-600 text-white px-6 py-2 rounded-lg flex items-center gap-2 hover:bg-blue-700 mx-auto"
        >
          <Plus size={20} />
          Go to Site Management
        </button>
      </div>
    </div>
  )

  return (
    <div className="p-6">
      <div className="flex justify-between items-start mb-6">
        <div>
          <h1 className="text-3xl font-bold">Site Management</h1>
          <p className="text-gray-600 mt-1">Manage your parking site details and configuration</p>
          <div className="flex items-center gap-2 mt-3">
            <div className="w-6 h-6 bg-green-100 rounded-full flex items-center justify-center">
              <span className="text-green-600 text-xs">✓</span>
            </div>
            <span className="text-green-600 font-medium">Active</span>
          </div>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => navigate('/owner/site')}
            className="bg-green-600 text-white px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-green-700"
          >
            <Plus size={18} />
            All Sites
          </button>
          <button
            onClick={handleEdit}
            className="bg-blue-600 text-white px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-blue-700"
          >
            <Pencil size={18} />
            Edit Details
          </button>
        </div>
      </div>

      <div className="grid md:grid-cols-2 gap-6 mb-6">
        <div className="bg-white border rounded-lg p-6">
          <div className="flex items-center gap-2 mb-4">
            <Building2 className="text-blue-600" size={20} />
            <h2 className="text-lg font-semibold">Basic Information</h2>
          </div>

          <div className="space-y-4">
            <div>
              <p className="text-sm text-gray-500">Site Name</p>
              <p className="text-lg font-semibold">{site.name}</p>
            </div>

            <div>
              <div className="flex items-center gap-2 text-sm text-gray-500">
                <MapPin size={16} />
                <span>Location</span>
              </div>
              <p className="mt-1">{site.location || 'N/A'}</p>
            </div>

            <div>
              <div className="flex items-center gap-2 text-sm text-gray-500">
                <Building2 size={16} />
                <span>Owner</span>
              </div>
              <p className="mt-1">{site.owner || 'N/A'}</p>
            </div>

            <div>
              <p className="text-sm text-gray-500">Created</p>
              <p className="mt-1">{site.created_at ? new Date(site.created_at).toLocaleDateString() : 'N/A'}</p>
            </div>
          </div>
        </div>

        <div className="bg-white border rounded-lg p-6">
          <div className="flex items-center gap-2 mb-4">
            <Clock className="text-blue-600" size={20} />
            <h2 className="text-lg font-semibold">Operational Details</h2>
          </div>

          <div className="grid grid-cols-2 gap-4 mb-4">
            <div className="bg-gray-50 p-4 rounded-lg">
              <p className="text-sm text-gray-500">Total Capacity</p>
              <p className="text-2xl font-bold">{site.capacity || 0}</p>
            </div>
            <div className="bg-green-50 p-4 rounded-lg">
              <p className="text-sm text-gray-500">Status</p>
              <p className="text-2xl font-bold text-green-600">Active</p>
            </div>
          </div>

          <div className="bg-green-50 p-4 rounded-lg">
            <div className="flex items-center gap-2 text-sm text-gray-500 mb-1">
              <DollarSign size={16} />
              <span>Pricing</span>
            </div>
            {site.pricing_type === 'hourly' ? (
              <>
                <p className="text-2xl font-bold text-green-600">
                  Per-slot hourly rates
                </p>
                <p className="text-xs text-gray-500 mt-1">Each slot's rate is set in Slot Config</p>
              </>
            ) : (
              <>
                <p className="text-2xl font-bold text-green-600">
                  Slot base price / first {site.flat_hours ?? 4} hrs
                </p>
                <p className="text-xs text-gray-500 mt-1">
                  Base price per slot (Slot Config) · Then Rs. {site.extra_hour_rate ?? '—'}/hr after
                </p>
              </>
            )}
          </div>
        </div>
      </div>

      {showModal && (
        <div className="fixed inset-0 bg-black/30 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl w-full max-w-lg shadow-2xl">
            <div className="flex justify-between items-center p-5 border-b">
              <h2 className="text-xl font-bold">Edit Site Details</h2>
              <button
                onClick={() => setShowModal(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="p-5 space-y-3 max-h- overflow-y-auto">
              <div className="grid grid-cols-2 gap-3">
                <div className="col-span-2">
                  <label className="block text-sm font-medium mb-1">Site Name *</label>
                  <input
                    type="text"
                    value={formData.name}
                    onChange={(e) => setFormData({...formData, name: e.target.value})}
                    required
                    className="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                    placeholder="SmartPark Downtown"
                  />
                </div>

                <div className="col-span-2">
                  <label className="block text-sm font-medium mb-1">Location *</label>
                  <input
                    type="text"
                    value={formData.location}
                    onChange={(e) => setFormData({...formData, location: e.target.value})}
                    required
                    className="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                    placeholder="123 Main Street"
                  />
                </div>

                <div className="col-span-2">
                  <label className="block text-sm font-medium mb-1">Capacity (Total Slots) *</label>
                  <input
                    type="number"
                    value={formData.capacity}
                    onChange={(e) => setFormData({...formData, capacity: e.target.value})}
                    required
                    min="1"
                    className="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                    placeholder="85"
                  />
                </div>

                <div className="col-span-2 pt-2 border-t">
                  <label className="block text-sm font-medium mb-2">Pricing Model *</label>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={() => setFormData({ ...formData, pricing_type: 'flat' })}
                      className={`flex-1 py-2 rounded-lg text-sm font-medium border transition-colors
                        ${formData.pricing_type === 'flat'
                          ? 'bg-blue-600 text-white border-blue-600'
                          : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'}`}
                    >
                      Flat rate (first N hours)
                    </button>
                    <button
                      type="button"
                      onClick={() => setFormData({ ...formData, pricing_type: 'hourly' })}
                      className={`flex-1 py-2 rounded-lg text-sm font-medium border transition-colors
                        ${formData.pricing_type === 'hourly'
                          ? 'bg-blue-600 text-white border-blue-600'
                          : 'bg-white text-gray-700 border-gray-300 hover:bg-gray-50'}`}
                    >
                      Per hour
                    </button>
                  </div>
                </div>

                {formData.pricing_type === 'flat' ? (
                  <>
                    <div>
                      <label className="block text-sm font-medium mb-1">Flat Hours *</label>
                      <input
                        type="number"
                        value={formData.flat_hours}
                        onChange={(e) => setFormData({ ...formData, flat_hours: e.target.value })}
                        required
                        min="1"
                        className="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                        placeholder="4"
                      />
                      <p className="text-xs text-gray-400 mt-1">Hours covered by each slot's base price.</p>
                    </div>
                    <div>
                      <label className="block text-sm font-medium mb-1">Extra Hour Rate (Rs./hr) *</label>
                      <input
                        type="number"
                        value={formData.extra_hour_rate}
                        onChange={(e) => setFormData({ ...formData, extra_hour_rate: e.target.value })}
                        required
                        min="0"
                        className="w-full border rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
                        placeholder="50"
                      />
                      <p className="text-xs text-gray-400 mt-1">Charged per hour (or partial slab) after the flat window.</p>
                    </div>
                    <div className="col-span-2 bg-blue-50 border border-blue-100 rounded-lg px-3 py-2">
                      <p className="text-xs text-blue-700">
                        Base price is set <span className="font-semibold">per slot</span> — configure it in Slot Config when creating slots.
                      </p>
                    </div>
                  </>
                ) : (
                  <div className="col-span-2 bg-blue-50 border border-blue-100 rounded-lg px-3 py-2">
                    <p className="text-xs text-blue-700">
                      Hourly rate is set <span className="font-semibold">per slot</span> — configure each slot's Rate/Hour in Slot Config.
                    </p>
                  </div>
                )}
              </div>

              <div className="flex gap-3 pt-3">
                <button
                  type="submit"
                  className="flex-1 bg-blue-600 text-white py-2.5 rounded-lg hover:bg-blue-700 font-medium text-sm"
                >
                  Update Site
                </button>
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="flex-1 bg-gray-100 text-gray-700 py-2.5 rounded-lg hover:bg-gray-200 font-medium text-sm"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}