import { useEffect, useState } from 'react'
import { motion } from 'framer-motion'
import api from '../../api/axios'
import { getUser } from '../../utils/auth'

const statusConfig = {
  available: { bg: 'bg-green-50 border-green-200',   text: 'text-green-700'  },
  occupied:  { bg: 'bg-blue-50 border-blue-200',     text: 'text-blue-700'   },
  reserved:  { bg: 'bg-amber-50 border-amber-200',   text: 'text-amber-700'  },
  overstay:  { bg: 'bg-red-50 border-red-200',       text: 'text-red-700'    },
}

export default function SlotGrid() {
  const [slots, setSlots] = useState([])
  const [loading, setLoading] = useState(true)
  const [selectedSlot, setSelectedSlot] = useState(null)

  useEffect(() => {
    async function fetchSlots() {
      try {
        const { site_id } = getUser()
        
        if (!site_id) {
          console.error('No site assigned')
          setLoading(false)
          return
        }
    
        const slotsRes = await api.get(`/parking/sites/${site_id}/slots/`)
        setSlots(slotsRes.data)
      } catch (error) {
        console.error('Error fetching slots:', error)
      } finally {
        setLoading(false)
      }
    }
    fetchSlots()
  }, [])

  // Slot ka status determine karna
  function getStatus(slot) {
    if (slot.is_occupied) return 'occupied'
    if (slot.is_reserved) return 'reserved'
    return 'available'
  }

  const statusCounts = {
    available: slots.filter(s => !s.is_occupied && !s.is_reserved).length,
    occupied:  slots.filter(s => s.is_occupied).length,
    reserved:  slots.filter(s => s.is_reserved).length,
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.2 }}
      className="bg-card border border-border rounded-2xl p-5"
    >
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-sm font-semibold text-foreground">Slot Overview</h3>
        <div className="flex items-center gap-4 text-xs text-muted-foreground">
          <span className="flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-full bg-green-500 inline-block"></span>
            Available ({statusCounts.available})
          </span>
          <span className="flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-full bg-blue-500 inline-block"></span>
            Occupied ({statusCounts.occupied})
          </span>
          <span className="flex items-center gap-1.5">
            <span className="w-2.5 h-2.5 rounded-full bg-amber-500 inline-block"></span>
            Reserved ({statusCounts.reserved})
          </span>
        </div>
      </div>

      {loading ? (
        <div className="py-8 text-center text-sm text-muted-foreground">
          Loading slots...
        </div>
      ) : slots.length === 0 ? (
        <div className="py-8 text-center text-sm text-muted-foreground">
          No slots found
        </div>
      ) : (
        <>
          {/* Grid */}
          <div className="grid grid-cols-6 sm:grid-cols-8 md:grid-cols-10 gap-2 mb-4">
            {slots.map((slot, i) => {
              const status = getStatus(slot)
              const cfg = statusConfig[status]
              const isSelected = selectedSlot?.id === slot.id
              return (
                <motion.button
                  key={slot.id}
                  initial={{ opacity: 0, scale: 0.8 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: i * 0.01 }}
                  onClick={() => setSelectedSlot(isSelected ? null : slot)}
                  className={`border-2 rounded-xl p-2.5 text-center cursor-pointer hover:scale-105 transition-all ${cfg.bg} ${
                    isSelected ? 'ring-2 ring-primary ring-offset-1' : ''
                  }`}
                >
                  <p className={`text-xs font-bold ${cfg.text}`}>{slot.slot_number}</p>
                  <p className="text-[9px] text-muted-foreground mt-0.5">{slot.slot_type}</p>
                </motion.button>
              )
            })}
          </div>

          {/* Selected slot detail */}
          {selectedSlot && (
            <motion.div
              initial={{ opacity: 0, y: 5 }}
              animate={{ opacity: 1, y: 0 }}
              className="bg-secondary rounded-xl p-4 max-w-xs"
            >
              <p className="text-sm font-semibold text-foreground mb-2">
                Slot {selectedSlot.slot_number}
              </p>
              <div className="space-y-1.5 text-xs">
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Type</span>
                  <span className="font-medium text-foreground capitalize">{selectedSlot.slot_type}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Status</span>
                  <span className="font-medium text-foreground capitalize">{getStatus(selectedSlot)}</span>
                </div>
                {selectedSlot.price_per_hour && (
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Price</span>
                    <span className="font-medium text-foreground">Rs. {selectedSlot.price_per_hour}</span>
                  </div>
                )}
              </div>
            </motion.div>
          )}
        </>
      )}
    </motion.div>
  )
}