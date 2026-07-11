import React, { useState, useEffect, useCallback } from 'react'
import api from '../../api/axios'
import {
  Grid3x3, Plus, Edit2, Trash2, Save, X, Car, Zap, Accessibility,
  RefreshCw, AlertTriangle, Check, ChevronDown, DollarSign, Layers
} from 'lucide-react'

const SlotConfig = () => {
  // ── State ──────────────────────────────────────────────────────────
  const [sites, setSites] = useState([])
  const [siteId, setSiteId] = useState(null)
  const [selectedSite, setSelectedSite] = useState(null)
  const [slots, setSlots] = useState([])
  const [loading, setLoading] = useState(false)
  const [generating, setGenerating] = useState(false)

  // Bulk generate form
  const [showBulkPanel, setShowBulkPanel] = useState(false)
  const [bulkForm, setBulkForm] = useState({
    normal: 0, vip: 0, disabled: 0,
    normal_rate: 100, vip_rate: 250, disabled_rate: 80
  })

  // Individual edit
  const [editingSlot, setEditingSlot] = useState(null)

  // Add single slot
  const [showAddSlot, setShowAddSlot] = useState(false)
  const [newSlot, setNewSlot] = useState({ slotNumber: '', type: 'normal', rate: 100 })

  // Bulk rate update
  const [showRatePanel, setShowRatePanel] = useState(false)
  const [rateForm, setRateForm] = useState({ type: 'normal', rate: 100 })

  // Confirmation modal
  const [confirmModal, setConfirmModal] = useState(null)

  // Toast notification
  const [toast, setToast] = useState(null)

  // Filter
  const [filter, setFilter] = useState('all') // all, normal, vip, disabled
  const [statusFilter, setStatusFilter] = useState('all') // all, available, occupied, reserved

  // ── Helpers ─────────────────────────────────────────────────────────
  const showToast = (message, type = 'success') => {
    setToast({ message, type })
    setTimeout(() => setToast(null), 3000)
  }

  // ── Fetch Data ─────────────────────────────────────────────────────
  const fetchSites = async () => {
    try {
      const res = await api.get('/parking/sites/')
      setSites(res.data || [])
      if (res.data?.length) {
        const first = res.data[0]
        setSiteId(first.id)
        setSelectedSite(first)
        await fetchSlots(first.id)
      }
    } catch (err) {
      console.error('Error fetching sites:', err)
    }
  }

  const fetchSlots = useCallback(async (id = siteId) => {
    if (!id) return
    setLoading(true)
    try {
      const res = await api.get(`/parking/sites/${id}/slots/`)
      const mapped = (res.data || []).map(s => ({
        id: s.id,
        slotNumber: s.slot_number,
        type: s.slot_type || 'normal',
        status: s.is_occupied ? 'Occupied' : s.is_reserved ? 'Reserved' : 'Available',
        rate: parseFloat(s.price_per_hour) || 50,
        is_occupied: s.is_occupied,
        is_reserved: s.is_reserved
      }))
      mapped.sort((a, b) => a.slotNumber.localeCompare(b.slotNumber, undefined, { numeric: true, sensitivity: 'base' }))
      setSlots(mapped)
    } catch (err) {
      console.error('Error fetching slots:', err)
    } finally {
      setLoading(false)
    }
  }, [siteId])

  useEffect(() => { fetchSites() }, [])

  // ── Site Change ────────────────────────────────────────────────────
  const handleSiteChange = async (id) => {
    setSiteId(id)
    const site = sites.find(s => s.id === id)
    setSelectedSite(site)
    await fetchSlots(id)
  }

  // ── Computed Stats ─────────────────────────────────────────────────
  const stats = {
    total: slots.length,
    capacity: selectedSite?.capacity || 0,
    normal: slots.filter(s => s.type === 'normal').length,
    vip: slots.filter(s => s.type === 'vip').length,
    disabled: slots.filter(s => s.type === 'disabled').length,
    available: slots.filter(s => s.status === 'Available').length,
    occupied: slots.filter(s => s.status === 'Occupied').length,
    reserved: slots.filter(s => s.status === 'Reserved').length,
  }
  const capacityPercent = stats.capacity > 0 ? Math.round((stats.total / stats.capacity) * 100) : 0

  // ── Pricing mode (per-slot pricing) ────────────────────────────────
  // Site ka pricing_type decide karta hai slot price ka matlab:
  //   "hourly" -> slot price = Rate/Hour
  //   "flat"   -> slot price = Base Price (first N hours ke liye total)
  const isHourly = selectedSite?.pricing_type === 'hourly'
  const flatHours = selectedSite?.flat_hours ?? 4
  const priceLabel = isHourly ? 'Rate/Hour (Rs.)' : 'Base Price (Rs.)'
  const priceSuffix = isHourly ? '/hr' : ' base' 

  // ── Bulk Generate ──────────────────────────────────────────────────
  const handleBulkGenerate = async () => {
    if (!siteId) return showToast('No site selected', 'error')
    const total = bulkForm.normal + bulkForm.vip + bulkForm.disabled
    if (total === 0) return showToast('Enter at least one slot count', 'error')

    setGenerating(true)
    try {
      const res = await api.post(`/parking/sites/${siteId}/slots/bulk-generate/`, bulkForm)
      showToast(`✅ ${res.data.created} slots generated successfully!`)
      setShowBulkPanel(false)
      setBulkForm({ normal: 0, vip: 0, disabled: 0, normal_rate: 100, vip_rate: 250, disabled_rate: 80 })
      await fetchSlots()
    } catch (err) {
      const msg = err.response?.data?.error || err.message
      showToast(`❌ ${msg}`, 'error')
    } finally {
      setGenerating(false)
    }
  }

  // ── Bulk Delete ────────────────────────────────────────────────────
  const handleBulkDelete = async (type = null) => {
    setConfirmModal(null)
    try {
      const body = type ? { type } : {}
      const res = await api.post(`/parking/sites/${siteId}/slots/bulk-delete/`, body)
      showToast(`🗑️ ${res.data.deleted} slots deleted`)
      await fetchSlots()
    } catch (err) {
      showToast(`❌ ${err.response?.data?.error || err.message}`, 'error')
    }
  }

  // ── Bulk Rate Update ───────────────────────────────────────────────
  const handleBulkRateUpdate = async () => {
    try {
      const res = await api.post(`/parking/sites/${siteId}/slots/bulk-update-rate/`, rateForm)
      showToast(`💰 ${res.data.updated} ${rateForm.type} slots updated to Rs. ${rateForm.rate}${priceSuffix}`)
      setShowRatePanel(false)
      await fetchSlots()
    } catch (err) {
      showToast(`❌ ${err.response?.data?.error || err.message}`, 'error')
    }
  }

  // ── Single Slot CRUD ───────────────────────────────────────────────
  const handleAddSlot = async () => {
    if (!newSlot.slotNumber.trim()) return showToast('Enter slot number', 'error')
    try {
      await api.post(`/parking/sites/${siteId}/slots/`, {
        slot_number: newSlot.slotNumber.trim().toUpperCase(),
        slot_type: newSlot.type,
        is_occupied: false, is_reserved: false,
        price_per_hour: parseFloat(newSlot.rate) || 50
      })
      showToast('✅ Slot added')
      setShowAddSlot(false)
      setNewSlot({ slotNumber: '', type: 'normal', rate: 100 })
      await fetchSlots()
    } catch (err) {
      showToast(`❌ ${err.response?.data?.error || err.message}`, 'error')
    }
  }

  const handleSaveEdit = async () => {
    try {
      const res = await api.put(`/parking/slots/${editingSlot.id}/`, {
        slot_number: editingSlot.slotNumber.trim().toUpperCase(),
        slot_type: editingSlot.type,
        is_occupied: editingSlot.status === 'Occupied',
        is_reserved: editingSlot.status === 'Reserved',
        price_per_hour: parseFloat(editingSlot.rate) || 50
      })
      // Backend batata hai agar slot free karne se bookings cancel+refund huin
      showToast(res.data?.message ? `✅ ${res.data.message}` : '✅ Slot updated')
      setEditingSlot(null)
      await fetchSlots()
    } catch (err) {
      showToast(`❌ ${err.response?.data?.error || err.message}`, 'error')
    }
  }

  const handleDeleteSlot = async (id) => {
    setConfirmModal(null)
    try {
      const res = await api.delete(`/parking/slots/${id}/`)
      showToast(`🗑️ ${res.data?.message || 'Slot deleted'}`)
      await fetchSlots()
    } catch (err) {
      showToast(`❌ ${err.response?.data?.error || err.message}`, 'error')
    }
  }

  // ── Filtered Slots ─────────────────────────────────────────────────
  const filteredSlots = slots.filter(s => {
    if (filter !== 'all' && s.type !== filter) return false
    if (statusFilter !== 'all' && s.status.toLowerCase() !== statusFilter) return false
    return true
  })

  // ── Slot Card Colors ───────────────────────────────────────────────
  const getSlotStyle = (slot) => {
    const base = {
      normal: { bg: 'bg-emerald-50', border: 'border-emerald-200', badge: 'bg-emerald-500', text: 'text-emerald-700' },
      vip: { bg: 'bg-purple-50', border: 'border-purple-200', badge: 'bg-purple-500', text: 'text-purple-700' },
      disabled: { bg: 'bg-amber-50', border: 'border-amber-200', badge: 'bg-amber-500', text: 'text-amber-700' },
    }
    const statusOverlay = {
      Occupied: 'ring-2 ring-red-400 ring-offset-1',
      Reserved: 'ring-2 ring-blue-400 ring-offset-1',
      Available: ''
    }
    const s = base[slot.type] || base.normal
    return { ...s, ring: statusOverlay[slot.status] || '' }
  }

  const getTypeIcon = (type) => {
    switch (type) {
      case 'vip': return <Zap className="w-4 h-4 text-purple-500" />
      case 'disabled': return <Accessibility className="w-4 h-4 text-amber-600" />
      default: return <Car className="w-4 h-4 text-emerald-600" />
    }
  }

  const getStatusDot = (status) => {
    switch (status) {
      case 'Occupied': return 'bg-red-500'
      case 'Reserved': return 'bg-blue-500'
      default: return 'bg-green-500'
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // RENDER
  // ══════════════════════════════════════════════════════════════════════
  return (
    <div className="p-6 space-y-6 bg-gray-50 min-h-screen">

      {/* ── Toast ──────────────────────────────────────────────────── */}
      {toast && (
        <div className={`fixed top-6 right-6 z-50 px-5 py-3 rounded-xl shadow-2xl text-white text-sm font-medium
          transition-all duration-300 animate-slide-in
          ${toast.type === 'error' ? 'bg-red-600' : 'bg-gradient-to-r from-emerald-500 to-teal-600'}`}>
          {toast.message}
        </div>
      )}

      {/* ── Confirm Modal ─────────────────────────────────────────── */}
      {confirmModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl p-6 max-w-md w-full space-y-4">
            <div className="flex items-center gap-3">
              <div className="w-12 h-12 rounded-full bg-red-100 flex items-center justify-center">
                <AlertTriangle className="w-6 h-6 text-red-600" />
              </div>
              <div>
                <h3 className="font-bold text-gray-900 text-lg">{confirmModal.title}</h3>
                <p className="text-gray-500 text-sm">{confirmModal.message}</p>
              </div>
            </div>
            <div className="flex gap-3 justify-end">
              <button onClick={() => setConfirmModal(null)}
                className="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors font-medium">
                Cancel
              </button>
              <button onClick={confirmModal.onConfirm}
                className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors font-medium">
                {confirmModal.confirmText || 'Delete'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Header ────────────────────────────────────────────────── */}
      <div className="bg-gradient-to-r from-blue-600 via-indigo-600 to-purple-600 rounded-2xl p-6 text-white shadow-xl">
        <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold flex items-center gap-2">
              <Grid3x3 className="w-7 h-7" /> Slot Configuration
            </h1>
            <p className="text-blue-100 mt-1">Manage and generate parking slots for your sites</p>
          </div>
          <div className="flex flex-wrap gap-2">
            <button onClick={() => setShowBulkPanel(!showBulkPanel)}
              className="flex items-center gap-2 px-4 py-2.5 bg-white/20 hover:bg-white/30 backdrop-blur rounded-xl transition-all font-medium text-sm">
              <Layers className="w-4 h-4" /> Bulk Generate
            </button>
            <button onClick={() => setShowAddSlot(!showAddSlot)}
              className="flex items-center gap-2 px-4 py-2.5 bg-white/20 hover:bg-white/30 backdrop-blur rounded-xl transition-all font-medium text-sm">
              <Plus className="w-4 h-4" /> Add Single
            </button>
            <button onClick={() => setShowRatePanel(!showRatePanel)}
              className="flex items-center gap-2 px-4 py-2.5 bg-white/20 hover:bg-white/30 backdrop-blur rounded-xl transition-all font-medium text-sm">
              <DollarSign className="w-4 h-4" /> Bulk Rate
            </button>
          </div>
        </div>
      </div>

      {/* ── Site Selector ─────────────────────────────────────────── */}
      {sites.length > 0 && (
        <div className="bg-white rounded-xl p-4 border border-gray-200 flex flex-col sm:flex-row items-start sm:items-center gap-4 shadow-sm">
          <span className="text-sm font-semibold text-gray-700">Select Site:</span>
          <select
            value={siteId || ''}
            onChange={(e) => handleSiteChange(e.target.value)}
            className="flex-1 px-4 py-2.5 bg-gray-50 border border-gray-300 rounded-xl text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500 font-medium"
          >
            {sites.map(s => (
              <option key={s.id} value={s.id}>{s.name} {s.capacity ? `(Capacity: ${s.capacity})` : ''}</option>
            ))}
          </select>
          <button onClick={() => fetchSlots()} className="p-2.5 bg-gray-100 hover:bg-gray-200 rounded-xl transition-colors" title="Refresh">
            <RefreshCw className={`w-4 h-4 text-gray-600 ${loading ? 'animate-spin' : ''}`} />
          </button>
        </div>
      )}

      {/* ── Stats Dashboard ───────────────────────────────────────── */}
      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {/* Capacity usage */}
        <div className="col-span-2 bg-white rounded-xl p-4 border border-gray-200 shadow-sm">
          <p className="text-xs text-gray-500 font-medium uppercase tracking-wide">Capacity Usage</p>
          <div className="flex items-end gap-2 mt-2">
            <p className="text-2xl font-bold text-gray-900">{stats.total}</p>
            <p className="text-sm text-gray-400 mb-0.5">/ {stats.capacity || '∞'}</p>
          </div>
          <div className="mt-2 w-full bg-gray-200 rounded-full h-2">
            <div className="bg-gradient-to-r from-blue-500 to-indigo-500 h-2 rounded-full transition-all duration-500"
              style={{ width: `${Math.min(capacityPercent, 100)}%` }} />
          </div>
          <p className="text-xs text-gray-400 mt-1">{capacityPercent}% used</p>
        </div>
        {/* Type counts */}
        <div className="bg-emerald-50 rounded-xl p-4 border border-emerald-100 shadow-sm">
          <p className="text-xs text-emerald-600 font-medium">Normal</p>
          <p className="text-2xl font-bold text-emerald-700 mt-1">{stats.normal}</p>
        </div>
        <div className="bg-purple-50 rounded-xl p-4 border border-purple-100 shadow-sm">
          <p className="text-xs text-purple-600 font-medium">VIP</p>
          <p className="text-2xl font-bold text-purple-700 mt-1">{stats.vip}</p>
        </div>
        <div className="bg-amber-50 rounded-xl p-4 border border-amber-100 shadow-sm">
          <p className="text-xs text-amber-600 font-medium">Disabled</p>
          <p className="text-2xl font-bold text-amber-700 mt-1">{stats.disabled}</p>
        </div>
        {/* Status counts */}
        <div className="bg-white rounded-xl p-4 border border-gray-200 shadow-sm">
          <p className="text-xs text-green-600 font-medium">Available</p>
          <p className="text-2xl font-bold text-green-700 mt-1">{stats.available}</p>
        </div>
        <div className="bg-white rounded-xl p-4 border border-gray-200 shadow-sm">
          <p className="text-xs text-red-600 font-medium">Occupied</p>
          <p className="text-2xl font-bold text-red-700 mt-1">{stats.occupied}</p>
        </div>
        <div className="bg-white rounded-xl p-4 border border-gray-200 shadow-sm">
          <p className="text-xs text-blue-600 font-medium">Reserved</p>
          <p className="text-2xl font-bold text-blue-700 mt-1">{stats.reserved}</p>
        </div>
      </div>

      {/* ── Bulk Generate Panel ───────────────────────────────────── */}
      {showBulkPanel && (
        <div className="bg-white rounded-2xl p-6 border border-blue-200 shadow-lg">
          <div className="flex items-center justify-between mb-5">
            <h3 className="text-lg font-bold text-gray-900 flex items-center gap-2">
              <Layers className="w-5 h-5 text-blue-600" /> Bulk Generate Slots
            </h3>
            <button onClick={() => setShowBulkPanel(false)} className="p-1.5 hover:bg-gray-100 rounded-lg">
              <X className="w-5 h-5 text-gray-400" />
            </button>
          </div>

          <div className="bg-blue-50 border border-blue-100 rounded-lg px-3 py-2 mb-5">
            <p className="text-xs text-blue-700">
              {isHourly
                ? 'This site uses per-hour pricing — the price you set here is each slot\'s hourly rate.'
                : `This site uses flat pricing — the price you set here is each slot's base price for the first ${flatHours} hours (extra hours charged at the site's extra-hour rate).`}
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
            {/* Normal */}
            <div className="bg-emerald-50 rounded-xl p-4 border border-emerald-200">
              <div className="flex items-center gap-2 mb-3">
                <Car className="w-5 h-5 text-emerald-600" />
                <span className="font-semibold text-emerald-800">Normal Slots</span>
              </div>
              <div className="space-y-3">
                <div>
                  <label className="text-xs text-emerald-600 font-medium">Count</label>
                  <input type="number" min="0" value={bulkForm.normal}
                    onChange={e => setBulkForm({ ...bulkForm, normal: parseInt(e.target.value) || 0 })}
                    className="w-full mt-1 px-3 py-2 bg-white border border-emerald-200 rounded-lg focus:ring-2 focus:ring-emerald-400 focus:outline-none" />
                </div>
                <div>
                  <label className="text-xs text-emerald-600 font-medium">{priceLabel}</label>
                  <input type="number" min="0" value={bulkForm.normal_rate}
                    onChange={e => setBulkForm({ ...bulkForm, normal_rate: parseInt(e.target.value) || 0 })}
                    className="w-full mt-1 px-3 py-2 bg-white border border-emerald-200 rounded-lg focus:ring-2 focus:ring-emerald-400 focus:outline-none" />
                </div>
              </div>
            </div>

            {/* VIP */}
            <div className="bg-purple-50 rounded-xl p-4 border border-purple-200">
              <div className="flex items-center gap-2 mb-3">
                <Zap className="w-5 h-5 text-purple-600" />
                <span className="font-semibold text-purple-800">VIP Slots</span>
              </div>
              <div className="space-y-3">
                <div>
                  <label className="text-xs text-purple-600 font-medium">Count</label>
                  <input type="number" min="0" value={bulkForm.vip}
                    onChange={e => setBulkForm({ ...bulkForm, vip: parseInt(e.target.value) || 0 })}
                    className="w-full mt-1 px-3 py-2 bg-white border border-purple-200 rounded-lg focus:ring-2 focus:ring-purple-400 focus:outline-none" />
                </div>
                <div>
                  <label className="text-xs text-purple-600 font-medium">{priceLabel}</label>
                  <input type="number" min="0" value={bulkForm.vip_rate}
                    onChange={e => setBulkForm({ ...bulkForm, vip_rate: parseInt(e.target.value) || 0 })}
                    className="w-full mt-1 px-3 py-2 bg-white border border-purple-200 rounded-lg focus:ring-2 focus:ring-purple-400 focus:outline-none" />
                </div>
              </div>
            </div>

            {/* Disabled */}
            <div className="bg-amber-50 rounded-xl p-4 border border-amber-200">
              <div className="flex items-center gap-2 mb-3">
                <Accessibility className="w-5 h-5 text-amber-600" />
                <span className="font-semibold text-amber-800">Disabled Slots</span>
              </div>
              <div className="space-y-3">
                <div>
                  <label className="text-xs text-amber-600 font-medium">Count</label>
                  <input type="number" min="0" value={bulkForm.disabled}
                    onChange={e => setBulkForm({ ...bulkForm, disabled: parseInt(e.target.value) || 0 })}
                    className="w-full mt-1 px-3 py-2 bg-white border border-amber-200 rounded-lg focus:ring-2 focus:ring-amber-400 focus:outline-none" />
                </div>
                <div>
                  <label className="text-xs text-amber-600 font-medium">{priceLabel}</label>
                  <input type="number" min="0" value={bulkForm.disabled_rate}
                    onChange={e => setBulkForm({ ...bulkForm, disabled_rate: parseInt(e.target.value) || 0 })}
                    className="w-full mt-1 px-3 py-2 bg-white border border-amber-200 rounded-lg focus:ring-2 focus:ring-amber-400 focus:outline-none" />
                </div>
              </div>
            </div>
          </div>

          {/* Summary & Actions */}
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 bg-gray-50 rounded-xl p-4">
            <div className="text-sm text-gray-600">
              <span className="font-semibold text-gray-900">
                Total: {bulkForm.normal + bulkForm.vip + bulkForm.disabled} slots
              </span>
              {stats.capacity > 0 && (
                <span className="ml-2">
                  (Remaining capacity: {Math.max(0, stats.capacity - stats.total - bulkForm.normal - bulkForm.vip - bulkForm.disabled)})
                </span>
              )}
            </div>
            <div className="flex gap-2">
              <button onClick={() => setConfirmModal({
                title: 'Clear All Unoccupied Slots?',
                message: 'This will delete all unoccupied slots. Occupied slots will remain.',
                confirmText: 'Clear All',
                onConfirm: () => handleBulkDelete()
              })}
                className="px-4 py-2 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition-colors font-medium text-sm">
                Clear All
              </button>
              <button onClick={handleBulkGenerate} disabled={generating}
                className="px-6 py-2 bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-lg hover:from-blue-700 hover:to-indigo-700 transition-all font-medium text-sm disabled:opacity-50 flex items-center gap-2">
                {generating ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Check className="w-4 h-4" />}
                {generating ? 'Generating...' : 'Generate Slots'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Bulk Rate Update Panel ────────────────────────────────── */}
      {showRatePanel && (
        <div className="bg-white rounded-2xl p-6 border border-indigo-200 shadow-lg">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-bold text-gray-900 flex items-center gap-2">
              <DollarSign className="w-5 h-5 text-indigo-600" /> Bulk Rate Update
            </h3>
            <button onClick={() => setShowRatePanel(false)} className="p-1.5 hover:bg-gray-100 rounded-lg">
              <X className="w-5 h-5 text-gray-400" />
            </button>
          </div>
          <div className="flex flex-col sm:flex-row gap-4 items-end">
            <div className="flex-1">
              <label className="text-sm text-gray-600 font-medium">Slot Type</label>
              <select value={rateForm.type} onChange={e => setRateForm({ ...rateForm, type: e.target.value })}
                className="w-full mt-1 px-3 py-2.5 bg-gray-50 border border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-400 focus:outline-none font-medium">
                <option value="normal">Normal ({stats.normal} slots)</option>
                <option value="vip">VIP ({stats.vip} slots)</option>
                <option value="disabled">Disabled ({stats.disabled} slots)</option>
              </select>
            </div>
            <div className="flex-1">
              <label className="text-sm text-gray-600 font-medium">New {priceLabel}</label>
              <input type="number" min="0" value={rateForm.rate}
                onChange={e => setRateForm({ ...rateForm, rate: parseInt(e.target.value) || 0 })}
                className="w-full mt-1 px-3 py-2.5 bg-gray-50 border border-gray-300 rounded-xl focus:ring-2 focus:ring-indigo-400 focus:outline-none" />
            </div>
            <button onClick={handleBulkRateUpdate}
              className="px-6 py-2.5 bg-gradient-to-r from-indigo-600 to-purple-600 text-white rounded-xl hover:from-indigo-700 hover:to-purple-700 transition-all font-medium text-sm whitespace-nowrap">
              Update All
            </button>
          </div>
        </div>
      )}

      {/* ── Add Single Slot Panel ─────────────────────────────────── */}
      {showAddSlot && (
        <div className="bg-white rounded-2xl p-6 border border-gray-200 shadow-lg">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-bold text-gray-900">Add Single Slot</h3>
            <button onClick={() => setShowAddSlot(false)} className="p-1.5 hover:bg-gray-100 rounded-lg">
              <X className="w-5 h-5 text-gray-400" />
            </button>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="text-sm text-gray-500 font-medium">Slot Number</label>
              <input type="text" placeholder="e.g. A5" value={newSlot.slotNumber}
                onChange={e => setNewSlot({ ...newSlot, slotNumber: e.target.value })}
                className="w-full mt-1 px-3 py-2 bg-gray-50 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none" />
            </div>
            <div>
              <label className="text-sm text-gray-500 font-medium">Type</label>
              <select value={newSlot.type} onChange={e => setNewSlot({ ...newSlot, type: e.target.value })}
                className="w-full mt-1 px-3 py-2 bg-gray-50 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none">
                <option value="normal">Normal</option>
                <option value="vip">VIP</option>
                <option value="disabled">Disabled</option>
              </select>
            </div>
            <div>
              <label className="text-sm text-gray-500 font-medium">{priceLabel}</label>
              <input type="number" value={newSlot.rate}
                onChange={e => setNewSlot({ ...newSlot, rate: parseInt(e.target.value) })}
                className="w-full mt-1 px-3 py-2 bg-gray-50 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none" />
            </div>
          </div>
          <div className="flex gap-2 mt-4">
            <button onClick={handleAddSlot}
              className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium text-sm">
              <Save className="w-4 h-4" /> Add Slot
            </button>
          </div>
        </div>
      )}

      {/* ── Filter Bar ────────────────────────────────────────────── */}
      <div className="bg-white rounded-xl p-4 border border-gray-200 shadow-sm flex flex-col sm:flex-row gap-4 items-start sm:items-center">
        <span className="text-sm font-semibold text-gray-700">Filter:</span>
        <div className="flex flex-wrap gap-2">
          {[
            { value: 'all', label: 'All Types', count: stats.total },
            { value: 'normal', label: 'Normal', count: stats.normal },
            { value: 'vip', label: 'VIP', count: stats.vip },
            { value: 'disabled', label: 'Disabled', count: stats.disabled },
          ].map(f => (
            <button key={f.value} onClick={() => setFilter(f.value)}
              className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-all
                ${filter === f.value ? 'bg-blue-600 text-white shadow-md' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}>
              {f.label} ({f.count})
            </button>
          ))}
        </div>
        <div className="sm:ml-auto flex gap-2">
          {[
            { value: 'all', label: 'All Status' },
            { value: 'available', label: 'Available' },
            { value: 'occupied', label: 'Occupied' },
            { value: 'reserved', label: 'Reserved' },
          ].map(f => (
            <button key={f.value} onClick={() => setStatusFilter(f.value)}
              className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-all
                ${statusFilter === f.value ? 'bg-indigo-600 text-white shadow-md' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}>
              {f.label}
            </button>
          ))}
        </div>
      </div>

      {/* ── Slot Grid ─────────────────────────────────────────────── */}
      <div className="bg-white rounded-2xl p-6 border border-gray-200 shadow-sm">
        <div className="flex items-center justify-between mb-5">
          <h3 className="text-lg font-bold text-gray-900">
            Parking Slots <span className="text-sm font-normal text-gray-400 ml-2">({filteredSlots.length} shown)</span>
          </h3>
          {/* Legend */}
          <div className="hidden md:flex items-center gap-4 text-xs text-gray-500">
            <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded-full bg-green-500 inline-block" /> Available</span>
            <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded-full bg-red-500 inline-block" /> Occupied</span>
            <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded-full bg-blue-500 inline-block" /> Reserved</span>
          </div>
        </div>

        {loading ? (
          <div className="text-center py-20">
            <RefreshCw className="w-8 h-8 text-gray-300 animate-spin mx-auto" />
            <p className="text-gray-400 mt-3">Loading slots...</p>
          </div>
        ) : filteredSlots.length === 0 ? (
          <div className="text-center py-20 text-gray-400">
            <Grid3x3 className="w-16 h-16 mx-auto mb-4 opacity-30" />
            <p className="text-lg font-medium">No slots found</p>
            <p className="text-sm mt-1">Use "Bulk Generate" to create slots for this site</p>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 xl:grid-cols-8 gap-3">
            {filteredSlots.map(slot => {
              const style = getSlotStyle(slot)
              const isEditing = editingSlot?.id === slot.id

              return (
                <div key={slot.id}
                  className={`relative p-3 rounded-xl border-2 ${style.bg} ${style.border} ${style.ring}
                    hover:shadow-lg hover:-translate-y-0.5 transition-all duration-200 cursor-pointer group`}>

                  {isEditing ? (
                    /* ── Edit Mode ────────────────────────── */
                    <div className="space-y-2">
                      <input type="text" value={editingSlot.slotNumber}
                        onChange={e => setEditingSlot({ ...editingSlot, slotNumber: e.target.value })}
                        className="w-full px-2 py-1 text-xs border rounded-lg bg-white" />
                      <select value={editingSlot.type}
                        onChange={e => setEditingSlot({ ...editingSlot, type: e.target.value })}
                        className="w-full px-2 py-1 text-xs border rounded-lg bg-white">
                        <option value="normal">Normal</option>
                        <option value="vip">VIP</option>
                        <option value="disabled">Disabled</option>
                      </select>
                      <select value={editingSlot.status}
                        onChange={e => setEditingSlot({ ...editingSlot, status: e.target.value })}
                        className="w-full px-2 py-1 text-xs border rounded-lg bg-white">
                        <option>Available</option>
                        <option>Occupied</option>
                        <option>Reserved</option>
                      </select>
                      <input type="number" value={editingSlot.rate}
                        onChange={e => setEditingSlot({ ...editingSlot, rate: parseInt(e.target.value) })}
                        className="w-full px-2 py-1 text-xs border rounded-lg bg-white" placeholder="Rate" />
                      <div className="flex gap-1">
                        <button onClick={handleSaveEdit}
                          className="flex-1 px-2 py-1 bg-green-600 text-white text-xs rounded-lg font-medium">
                          Save
                        </button>
                        <button onClick={() => setEditingSlot(null)}
                          className="flex-1 px-2 py-1 bg-gray-400 text-white text-xs rounded-lg font-medium">
                          Cancel
                        </button>
                      </div>
                    </div>
                  ) : (
                    /* ── Display Mode ─────────────────────── */
                    <>
                      {/* Status dot */}
                      <div className={`absolute top-2 right-2 w-2.5 h-2.5 rounded-full ${getStatusDot(slot.status)}`}
                        title={slot.status} />

                      {/* Slot Number */}
                      <div className="flex items-center gap-1.5 mb-1">
                        {getTypeIcon(slot.type)}
                        <span className="font-bold text-sm text-gray-900">{slot.slotNumber}</span>
                      </div>

                      {/* Type badge */}
                      <span className={`inline-block px-2 py-0.5 rounded-md text-[10px] font-semibold text-white ${style.badge} uppercase tracking-wide`}>
                        {slot.type}
                      </span>

                      {/* Rate */}
                      <p className="text-xs text-gray-500 mt-1.5">Rs. {slot.rate}{priceSuffix}</p>

                      {/* Status text */}
                      <p className={`text-xs font-medium mt-1 ${style.text}`}>{slot.status}</p>

                      {/* Action buttons (show on hover) */}
                      <div className="flex gap-1 mt-2 opacity-0 group-hover:opacity-100 transition-opacity">
                        <button onClick={() => setEditingSlot(slot)}
                          className="flex-1 p-1.5 bg-white/70 hover:bg-white rounded-lg transition-colors border border-gray-200">
                          <Edit2 className="w-3 h-3 mx-auto text-blue-600" />
                        </button>
                        <button onClick={() => setConfirmModal({
                          title: `Delete Slot ${slot.slotNumber}?`,
                          message: 'This action cannot be undone.',
                          onConfirm: () => handleDeleteSlot(slot.id)
                        })}
                          className="flex-1 p-1.5 bg-white/70 hover:bg-white rounded-lg transition-colors border border-gray-200">
                          <Trash2 className="w-3 h-3 mx-auto text-red-600" />
                        </button>
                      </div>
                    </>
                  )}
                </div>
              )
            })}
          </div>
        )}
      </div>

      {/* ── Custom Animation Style ────────────────────────────────── */}
      <style>{`
        @keyframes slideIn {
          from { transform: translateX(100px); opacity: 0; }
          to { transform: translateX(0); opacity: 1; }
        }
        .animate-slide-in { animation: slideIn 0.3s ease-out; }
      `}</style>
    </div>
  )
}

export default SlotConfig