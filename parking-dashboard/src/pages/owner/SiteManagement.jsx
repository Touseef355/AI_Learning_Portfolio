import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import api from '../../api/axios'
import { Pencil, Trash2, Plus, X, Building2, MapPin, Eye } from 'lucide-react'

export default function SiteManagement() {
  const navigate = useNavigate()
  const [sites, setSites] = useState([])
  const [loading, setLoading] = useState(true)
  const [showModal, setShowModal] = useState(false)
  const [isEditing, setIsEditing] = useState(false)
  const [selectedSite, setSelectedSite] = useState(null)
  const [formData, setFormData] = useState({
    name: '',
    location: '',
    capacity: '',
  })

  useEffect(() => {
    fetchSites()
  }, [])

  const fetchSites = async () => {
    try {
      setLoading(true)
      const res = await api.get('/parking/sites/')
      const mapped = (res.data || []).map(s => ({
        id: s.id,
        name: s.name,
        location: s.location || '',
        capacity: s.capacity || 0,
      }))
      setSites(mapped)
    } catch (error) {
      console.error('Error fetching sites:', error)
      alert('Error fetching sites: ' + (error.response?.data?.detail || error.message))
    } finally {
      setLoading(false)
    }
  }

  const handleAddNew = () => {
    setIsEditing(false)
    setSelectedSite(null)
    setFormData({ name: '', location: '', capacity: '' })
    setShowModal(true)
  }

  const handleEdit = (site) => {
    setIsEditing(true)
    setSelectedSite(site)
    setFormData({
      name: site.name || '',
      location: site.location || '',
      capacity: site.capacity || '',
    })
    setShowModal(true)
  }

  const handleDelete = async (id) => {
    if (!confirm('Are you sure you want to delete this site?')) return

    try {
      await api.delete(`/parking/sites/${id}/`)
      alert('Site deleted successfully!')
      fetchSites()
    } catch (error) {
      alert('Error deleting site: ' + (error.response?.data?.detail || error.message))
    }
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    try {
      const sitePayload = {
        name: formData.name,
        location: formData.location,
        capacity: parseInt(formData.capacity) || 0,
      }

      if (isEditing) {
        await api.put(`/parking/sites/${selectedSite.id}/`, sitePayload)
        alert('Site updated successfully!')
      } else {
        await api.post('/parking/sites/', sitePayload)
        alert('New site added successfully!')
      }

      setShowModal(false)
      fetchSites()
    } catch (error) {
      alert('Error saving site: ' + (error.response?.data?.detail || error.message))
    }
  }

  const getStats = () => {
    const total = sites.length
    return { total }
  }

  const stats = getStats()

  if (loading) return <div className="p-6">Loading...</div>

  return (
    <div className="p-6">
      <div className="flex justify-between items-start mb-6">
        <div>
          <h1 className="text-3xl font-bold">Site Management</h1>
          <p className="text-gray-600 mt-1">Manage all your parking sites</p>
        </div>
        <button
          onClick={handleAddNew}
          className="bg-blue-600 text-white px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-blue-700"
        >
          <Plus size={20} />
          Add New Site
        </button>
      </div>

      {/* STATS CARDS */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
        <div className="bg-white border rounded-lg p-4">
          <p className="text-sm text-gray-500">Total Sites</p>
          <p className="text-3xl font-bold">{stats.total}</p>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <p className="text-sm text-gray-500">Total Capacity</p>
          <p className="text-3xl font-bold text-blue-600">{sites.reduce((s, site) => s + site.capacity, 0)}</p>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <p className="text-sm text-gray-500">Avg Capacity</p>
          <p className="text-3xl font-bold text-green-600">{stats.total ? Math.round(sites.reduce((s, site) => s + site.capacity, 0) / stats.total) : 0}</p>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <p className="text-sm text-gray-500">Status</p>
          <p className="text-3xl font-bold text-green-600">Active</p>
        </div>
      </div>

      {/* TABLE - Cashiers jaisa */}
      {sites.length === 0? (
        <div className="bg-white border rounded-lg p-12 text-center">
          <p className="text-gray-500 text-lg mb-4">No parking sites found</p>
          <button
            onClick={handleAddNew}
            className="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700"
          >
            Add Your First Site
          </button>
        </div>
      ) : (
        <div className="bg-white border rounded-lg overflow-hidden">
          <table className="w-full">
            <thead className="bg-gray-50 border-b">
              <tr>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">SITE</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">LOCATION</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">CAPACITY</th>
                <th className="text-left px-6 py-3 text-xs font-medium text-gray-500 uppercase">ACTIONS</th>
              </tr>
            </thead>
            <tbody className="divide-y">
              {sites.map((site) => (
                <tr key={site.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4">
                    <div className="flex items-center gap-3">
                      <div className="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
                        <Building2 className="text-blue-600" size={20} />
                      </div>
                      <div>
                        <p className="font-semibold text-gray-900">{site.name}</p>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <p className="text-sm text-gray-600 flex items-center gap-1">
                      <MapPin size={14} />
                      {site.location?.substring(0, 40) || 'N/A'}
                    </p>
                  </td>
                  <td className="px-6 py-4">
                    <span className="bg-blue-50 text-blue-700 px-3 py-1 rounded-full text-sm font-medium">
                      {site.capacity} Slots
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex gap-2">
                      <button
                        onClick={() => navigate(`/owner/site/${site.id}`)}
                        className="text-blue-600 hover:bg-blue-50 p-2 rounded"
                        title="View Details"
                      >
                        <Eye size={18} />
                      </button>
                      <button
                        onClick={() => handleEdit(site)}
                        className="text-blue-600 hover:bg-blue-50 p-2 rounded"
                        title="Edit"
                      >
                        <Pencil size={18} />
                      </button>
                      <button
                        onClick={() => handleDelete(site.id)}
                        className="text-red-600 hover:bg-red-50 p-2 rounded"
                        title="Delete"
                      >
                        <Trash2 size={18} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* MODAL - Chota + Blur */}
      {showModal && (
        <div className="fixed inset-0 bg-black/30 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-xl w-full max-w-lg shadow-2xl">
            <div className="flex justify-between items-center p-5 border-b">
              <h2 className="text-xl font-bold">
                {isEditing? 'Edit Site Details' : 'Add New Site'}
              </h2>
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
                    placeholder="123 Main Street, Islamabad"
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
                  {isEditing? 'Update Site' : 'Add Site'}
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