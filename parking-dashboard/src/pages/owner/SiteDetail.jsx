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
              <span>Rate</span>
            </div>
            <p className="text-2xl font-bold text-green-600">Variable per slot</p>
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
