import { useEffect, useState, useRef } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Camera, CheckCircle, XCircle, RefreshCw, PenLine, Keyboard, MapPin, Printer, AlertTriangle } from 'lucide-react'
import api from '../../api/axios'
import ManualEntryForm from './ManualEntryForm'

// ── Receipt printer ────────────────────────────────────────────
function printReceipt({ plate, slot, type, entryTime, method, receiptNo }) {
  const win = window.open('', '_blank', 'width=340,height=500')
  const time = new Date().toLocaleString('en-PK', { dateStyle: 'medium', timeStyle: 'short' })
  const entry = entryTime ? new Date(entryTime).toLocaleString('en-PK', { dateStyle: 'medium', timeStyle: 'short' }) : '—'
  win.document.write(`
    <html><head><title>Entry Receipt</title>
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      body { font-family: 'Courier New', monospace; font-size: 13px; padding: 20px; max-width: 300px; }
      .center { text-align: center; }
      .title  { font-size: 16px; font-weight: bold; margin-bottom: 2px; }
      .sub    { font-size: 11px; color: #555; margin-bottom: 14px; }
      hr      { border: none; border-top: 1px dashed #999; margin: 10px 0; }
      .row    { display: flex; justify-content: space-between; margin-bottom: 5px; }
      .label  { color: #555; }
      .plate  { font-size: 22px; font-weight: bold; letter-spacing: 3px; text-align: center; margin: 10px 0; }
      .slot   { font-size: 18px; font-weight: bold; text-align: center; background: #f0f0f0; padding: 6px; border-radius: 4px; margin: 8px 0; }
      .footer { font-size: 10px; color: #888; text-align: center; margin-top: 14px; }
    </style></head>
    <body>
      <div class="center">
        <div class="title">Parkroo</div>
        <div class="sub">Smart Parking Management System</div>
      </div>
      <hr/>
      <div class="center" style="font-size:11px;color:#555;margin-bottom:6px;">ENTRY RECEIPT</div>
      <div class="plate">${plate ?? '—'}</div>
      <div style="font-size:11px;text-align:center;color:#555;margin-bottom:10px;">Assigned slot</div>
      <div class="slot">${slot ?? '—'}</div>
      <hr/>
      <div class="row"><span class="label">Type</span><span>${type ?? 'Walk-in'}</span></div>
      <div class="row"><span class="label">Entry time</span><span>${entry}</span></div>
      <div class="row"><span class="label">Method</span><span>${method ?? 'Cash'}</span></div>
      <div class="row"><span class="label">Printed</span><span>${time}</span></div>
      ${receiptNo ? `<div class="row"><span class="label">Receipt #</span><span>${receiptNo}</span></div>` : ''}
      <hr/>
      <div class="footer">Thank you — Please keep this slip<br/>until you exit the parking area.</div>
    </body></html>
  `)
  win.document.close()
  win.focus()
  setTimeout(() => { win.print(); win.close() }, 400)
}

export default function EntryGate() {
  const [mode, setMode]         = useState('ai')
  const [pending, setPending]   = useState(null)
  const [plate, setPlate]       = useState('')
  const [editing, setEditing]   = useState(false)
  const [decision, setDecision] = useState(null)
  const [loading, setLoading]   = useState(false)
  const [rechecking, setRechecking] = useState(false)
  const [slotType, setSlotType]     = useState('normal') // walk-in slot type dropdown
  const [wsStatus, setWsStatus] = useState('disconnected')

  useEffect(() => {
    const token = localStorage.getItem('access_token')
    let ws = null
    let reconnectTimer = null

    function connect() {
      ws = new WebSocket('ws://127.0.0.1:8000/ws/parking/entry/')

      ws.onopen = () => {
        setWsStatus('connected')
        ws.send(JSON.stringify({ type: 'auth', token }))
      }

      ws.onmessage = (e) => {
        let data = null
        try { data = JSON.parse(e.data) } catch { return }

        if (data.type === 'auth_required') { ws.send(JSON.stringify({ type: 'auth', token })); return }
        if (data.type === 'auth_success')  { setWsStatus('authenticated'); fetchPending(); return }
        if (data.type === 'auth_failed') {
          localStorage.removeItem('access_token')
          localStorage.removeItem('refresh_token')
          window.location.href = '/login'
          return
        }
        if (data.type === 'entry_detected') {
          setPending({
            id                   : data.ai_log_id,
            detected_plate_number: data.plate_number,
            confidence_score     : data.confidence,
            image_url            : data.image_url,
            cropped_plate        : data.cropped_plate,
            has_booking          : data.has_booking,
            booking_info         : data.booking_info,
            vehicle_type         : data.vehicle_type,
            pre_assigned_slot    : data.pre_assigned_slot,
            entry_time           : data.entry_time,
            parking_full         : !data.has_booking && !data.pre_assigned_slot,
          })
          setSlotType(data.slot_type || 'normal')
          setPlate(data.plate_number)
          setDecision(null)
          setEditing(false)
        }
      }

      ws.onclose = (e) => {
        setWsStatus('disconnected')
        if (e.code === 4004) { localStorage.clear(); window.location.href = '/login'; return }
        if ([4001, 4003, 4008].includes(e.code)) return
        reconnectTimer = setTimeout(connect, 3000)
      }

      ws.onerror = () => setWsStatus('disconnected')
    }

    connect()
    return () => { clearTimeout(reconnectTimer); ws?.close() }
  }, [])

  async function fetchPending() {
    try {
      const res = await api.get('/ai/pending/')
      if (res.data) {
        setPending(res.data)
        setSlotType(res.data.slot_type || 'normal')
        setPlate(res.data.detected_plate_number)
        setDecision(null)
        setEditing(false)
      } else {
        setPending(null)
      }
    } catch (error) {
      console.error('Error fetching pending:', error)
    }
  }

  // FIX: plate edit hone par corrected plate ke against booking/pass/slot
  // dobara check karo — pehle ye API call hoti hi nahi thi, is liye edit
  // ke baad bhi purani (galat OCR) wali booking info hi dikhti rehti thi.
  async function recheckPlate(requestedSlotType) {
    if (!pending) return
    setRechecking(true)
    try {
      const res = await api.post('/ai/check-entry-plate/', {
        ai_log_id   : pending.id,
        plate_number: plate,
        slot_type   : requestedSlotType || slotType,
      })
      setPending(prev => ({
        ...prev,
        detected_plate_number: res.data.plate_number,
        has_booking          : res.data.has_booking,
        booking_info         : res.data.booking_info,
        pre_assigned_slot    : res.data.pre_assigned_slot,
        vehicle_type         : res.data.vehicle_type,
        // FIX: backend parking_full nahi bhejta — walk-in + no slot se derive karo
        parking_full         : !res.data.has_booking && !res.data.is_pass && !res.data.pre_assigned_slot,
        booking_other_site   : res.data.booking_other_site ?? null,
      }))
      // Backend jo type ka slot de paya wahi dropdown me dikhao
      if (res.data.slot_type) setSlotType(res.data.slot_type)
      setPlate(res.data.plate_number)
    } catch (error) {
      console.error('Recheck error:', error)
    } finally {
      setRechecking(false)
    }
  }

  async function handleSavePlate() {
    setEditing(false)
    await recheckPlate()
  }

  // Cashier ne walk-in ke liye slot type badla → us type ka slot dobara lo
  async function handleSlotTypeChange(newType) {
    setSlotType(newType)
    await recheckPlate(newType)
  }

  async function handleAllow() {
    if (!pending) return
    setLoading(true)
    try {
      const res = await api.post('/ai/approve/', {
        ai_log_id   : pending.id,
        plate_number: plate,
        slot_type   : slotType, // fallback slot pick ke liye (detect time pe slot na mila ho)
      })
      setDecision({
        type: 'allowed',
        data: res.data,
        // carry forward for receipt
        plate,
        entryTime  : pending.entry_time,
        bookingType: pending.has_booking ? 'Pre-booked' : 'Walk-in',
      })
      setPending(null)
    } catch (error) {
      console.error('Approve error:', error)
    } finally {
      setLoading(false)
    }
  }

  async function handleReject() {
    if (!pending) return
    setLoading(true)
    try {
      await api.post('/ai/reject/', { ai_log_id: pending.id })
      setDecision({ type: 'rejected' })
      setPending(null)
    } catch (error) {
      console.error('Reject error:', error)
    } finally {
      setLoading(false)
    }
  }

  function handleReset() {
    setDecision(null)
    setPending(null)
    fetchPending()
  }

  // Walk-in: slot assigned but not yet a booking_info slot
  const assignedSlot = pending?.booking_info?.slot ?? pending?.pre_assigned_slot ?? null
  const isWalkIn      = pending && !pending.has_booking
  const isParkingFull = isWalkIn && !assignedSlot

  return (
    <div className="space-y-5">

      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-foreground">Entry Gate</h2>
          <p className="text-sm text-muted-foreground mt-1">AI-powered vehicle entry control</p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setMode('ai')}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium border transition-colors ${
              mode === 'ai'
                ? 'bg-primary text-primary-foreground border-primary'
                : 'bg-card text-muted-foreground border-border hover:bg-secondary'
            }`}
          >
            <Camera className="w-4 h-4" /> AI Detection
          </button>
          <button
            onClick={() => setMode('manual')}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium border transition-colors ${
              mode === 'manual'
                ? 'bg-primary text-primary-foreground border-primary'
                : 'bg-card text-muted-foreground border-border hover:bg-secondary'
            }`}
          >
            <Keyboard className="w-4 h-4" /> Manual Entry
          </button>
        </div>
      </div>

      {/* ── Walk-in slot / parking-full banner ───────────────── */}
      <AnimatePresence>
        {isWalkIn && (
          assignedSlot ? (
            <motion.div
              key="slot-banner"
              initial={{ opacity: 0, y: -8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              className="flex items-center gap-3 bg-blue-50 border border-blue-200 rounded-xl px-5 py-3"
            >
              <MapPin className="w-5 h-5 text-blue-600 flex-shrink-0" />
              <div className="flex-1">
                <p className="text-sm font-semibold text-blue-800">Walk-in — Slot assigned</p>
                <p className="text-xs text-blue-600 mt-0.5">Direct the driver to slot <span className="font-bold">{assignedSlot}</span> after allowing entry</p>
              </div>
              <span className="text-2xl font-bold font-mono text-blue-700 bg-blue-100 px-4 py-1.5 rounded-lg">
                {assignedSlot}
              </span>
            </motion.div>
          ) : (
            <motion.div
              key="full-banner"
              initial={{ opacity: 0, y: -8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              className="flex items-center gap-3 bg-red-50 border border-red-200 rounded-xl px-5 py-3"
            >
              <AlertTriangle className="w-5 h-5 text-red-600 flex-shrink-0" />
              <div className="flex-1">
                <p className="text-sm font-semibold text-red-800">Parking Full</p>
                <p className="text-xs text-red-600 mt-0.5">No free {slotType} slot right now — try another slot type from the dropdown below, or wait for one to free up.</p>
              </div>
            </motion.div>
          )
        )}
      </AnimatePresence>

      {/* AI Mode */}
      {mode === 'ai' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">

          {/* Col 1 — Images */}
          <div className="space-y-4">
            <div className="bg-card border border-border rounded-xl overflow-hidden">
              <div className="px-4 py-3 border-b border-border flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <div className={`w-2 h-2 rounded-full ${pending ? 'bg-green-500 animate-pulse' : 'bg-muted-foreground'}`} />
                  <span className="text-sm font-medium text-foreground">Vehicle Image</span>
                </div>
                <span className="text-xs text-muted-foreground">Entry Camera</span>
              </div>
              <div className="bg-secondary h-44 flex items-center justify-center">
                {pending?.image_url ? (
                  <img src={`http://127.0.0.1:8000${pending.image_url}`} alt="Vehicle" className="w-full h-full object-cover" />
                ) : (
                  <div className="text-center text-muted-foreground">
                    <Camera className="w-8 h-8 mx-auto mb-2 opacity-30" />
                    <p className="text-xs">Waiting for vehicle...</p>
                  </div>
                )}
              </div>
            </div>

            <div className="bg-card border border-border rounded-xl overflow-hidden">
              <div className="px-4 py-3 border-b border-border">
                <span className="text-sm font-medium text-foreground">Plate Crop</span>
                <span className="text-xs text-muted-foreground ml-2">YOLO detected region</span>
              </div>
              <div className="bg-secondary h-20 flex items-center justify-center overflow-hidden">
                {pending?.cropped_plate ? (
                  <img src={`http://127.0.0.1:8000${pending.cropped_plate}`} alt="Plate" className="h-full object-contain" />
                ) : (
                  <p className="text-xs text-muted-foreground">No plate detected</p>
                )}
              </div>
            </div>
          </div>

          {/* Col 2 — Plate + Booking */}
          <div className="space-y-4">

            {/* Plate Verification */}
            <div className="bg-card border border-border rounded-xl p-4">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm font-medium text-foreground">Plate Verification</span>
                {pending && (
                  <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                    pending.confidence_score >= 0.85 ? 'bg-green-50 text-green-600' : 'bg-amber-50 text-amber-600'
                  }`}>
                    {(pending.confidence_score * 100).toFixed(0)}% confident
                  </span>
                )}
              </div>
              {pending ? (
                <>
                  <p className="text-2xl font-bold font-mono tracking-widest text-foreground mb-3">{plate}</p>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs text-muted-foreground">Correct if OCR is wrong:</span>
                    {!editing && (
                      <button onClick={() => setEditing(true)} className="flex items-center gap-1 text-xs text-primary hover:underline">
                        <PenLine className="w-3 h-3" /> Edit
                      </button>
                    )}
                  </div>
                  {editing ? (
                    <div className="flex gap-2">
                      <input
                        value={plate}
                        onChange={(e) => setPlate(e.target.value.toUpperCase())}
                        className="flex-1 px-3 py-2 text-sm font-mono tracking-widest border border-border rounded-lg bg-background focus:outline-none focus:ring-1 focus:ring-primary"
                        autoFocus
                        onKeyDown={(e) => { if (e.key === 'Enter') handleSavePlate() }}
                      />
                      <button onClick={handleSavePlate} disabled={rechecking} className="px-3 py-2 bg-primary text-primary-foreground rounded-lg text-sm disabled:opacity-50">
                        {rechecking ? 'Checking...' : 'Save'}
                      </button>
                    </div>
                  ) : (
                    <div className="px-3 py-2 bg-secondary rounded-lg font-mono text-sm tracking-widest text-foreground">
                      {plate} {rechecking && <span className="text-xs text-muted-foreground ml-2">(rechecking...)</span>}
                    </div>
                  )}
                </>
              ) : (
                <p className="text-sm text-muted-foreground">No vehicle detected yet</p>
              )}
            </div>

            {/* Booking Info */}
            <div className="bg-card border border-border rounded-xl p-4">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm font-medium text-foreground">Booking Info</span>
                {pending && (
                  <div className="flex items-center gap-1.5">
                    {pending.has_booking && pending.booking_info?.payment_status === 'paid' && (
                      <span className="text-xs px-2 py-0.5 rounded-full font-medium bg-emerald-50 text-emerald-600">
                        Paid ✓
                      </span>
                    )}
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                      pending.has_booking ? 'bg-green-50 text-green-600' : 'bg-blue-50 text-blue-600'
                    }`}>
                      {pending.has_booking ? 'Booking found' : 'Walk-in'}
                    </span>
                  </div>
                )}
              </div>
              {pending ? (
                <div className="space-y-2">
                  {/* Walk-in: cashier slot type chune — us type se slot milta hai */}
                  {!pending.has_booking && !pending.is_pass && (
                    <div className="flex justify-between items-center text-sm border-b border-border pb-2">
                      <span className="text-muted-foreground">Slot type</span>
                      <select
                        value={slotType}
                        onChange={(e) => handleSlotTypeChange(e.target.value)}
                        disabled={rechecking || loading}
                        className="px-2 py-1 text-sm font-medium border border-border rounded-md bg-background focus:outline-none focus:ring-1 focus:ring-primary disabled:opacity-50"
                      >
                        <option value="normal">Normal</option>
                        <option value="vip">VIP</option>
                        <option value="disabled">Disabled</option>
                      </select>
                    </div>
                  )}
                  {[
                    { label: 'Type',       value: pending.has_booking ? 'Pre-booked' : 'Walk-in' },
                    { label: 'Slot',       value: rechecking ? 'Finding...' : (assignedSlot ?? (isParkingFull ? `No ${slotType} slot free` : 'Finding...')) },
                    { label: 'Entry time', value: pending.entry_time ? new Date(pending.entry_time).toLocaleTimeString() : new Date().toLocaleTimeString() },
                    ...(pending.booking_info ? [{
                      label: 'Exit time',
                      value: pending.booking_info.exit_time ? new Date(pending.booking_info.exit_time).toLocaleTimeString() : '—'
                    }] : []),
                    ...(!pending.has_booking && pending.booking_other_site ? [{
                      label: 'Note',
                      value: `Booking exists at "${pending.booking_other_site}" — not this site`
                    }] : [])
                  ].map(({ label, value }) => (
                    <div key={label} className="flex justify-between text-sm border-b border-border pb-2 last:border-0 last:pb-0">
                      <span className="text-muted-foreground">{label}</span>
                      <span className={`font-medium ${label === 'Slot' && isParkingFull ? 'text-red-600' : 'text-foreground'}`}>{value}</span>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-muted-foreground">Waiting for vehicle...</p>
              )}
            </div>
          </div>

          {/* Col 3 — Actions */}
          <div className="space-y-4">
            <div className="bg-card border border-border rounded-xl p-4">
              <p className="text-sm font-medium text-foreground mb-3">Gate Decision</p>

              <AnimatePresence mode="wait">
                {!decision ? (
                  <motion.div key="buttons" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="space-y-3">
                    <button
                      onClick={handleAllow}
                      disabled={!pending || loading}
                      className="w-full flex items-center justify-center gap-2 py-3 bg-primary text-primary-foreground rounded-lg text-sm font-medium disabled:opacity-40 disabled:cursor-not-allowed hover:bg-primary/90 transition-colors"
                    >
                      <CheckCircle className="w-4 h-4" />
                      {loading ? 'Processing...' : 'Allow Entry'}
                    </button>
                    <button
                      onClick={handleReject}
                      disabled={!pending || loading}
                      className="w-full flex items-center justify-center gap-2 py-3 bg-card text-destructive border border-destructive/30 rounded-lg text-sm font-medium disabled:opacity-40 disabled:cursor-not-allowed hover:bg-destructive/5 transition-colors"
                    >
                      <XCircle className="w-4 h-4" /> Reject
                    </button>
                    {!pending && (
                      <p className="text-xs text-center text-muted-foreground mt-2">
                        {wsStatus === 'authenticated' ? 'Waiting for AI detection...'
                          : wsStatus === 'connected' ? 'Authenticating...'
                          : 'Connecting to camera...'}
                      </p>
                    )}
                  </motion.div>
                ) : (
                  <motion.div
                    key="result"
                    initial={{ opacity: 0, scale: 0.95 }}
                    animate={{ opacity: 1, scale: 1 }}
                    className={`rounded-xl p-5 text-center ${
                      decision.type === 'allowed'
                        ? 'bg-green-50 border border-green-200'
                        : 'bg-red-50 border border-red-200'
                    }`}
                  >
                    {decision.type === 'allowed' ? (
                      <>
                        <CheckCircle className="w-10 h-10 text-green-600 mx-auto mb-2" />
                        <p className="font-semibold text-foreground">Entry Allowed</p>
                        <p className="text-xs text-muted-foreground mt-1">
                          Slot <span className="font-bold text-foreground">{decision.data?.slot}</span> assigned
                        </p>
                        {/* ── Print Receipt button ── */}
                        <button
                          onClick={() => printReceipt({
                            plate      : decision.plate,
                            slot       : decision.data?.slot,
                            type       : decision.bookingType,
                            entryTime  : decision.entryTime,
                            method     : 'Cash / Walk-in',
                            receiptNo  : decision.data?.receipt_number,
                          })}
                          className="mt-3 w-full flex items-center justify-center gap-2 py-2 bg-white border border-green-300 rounded-lg text-xs font-medium text-green-700 hover:bg-green-50 transition-colors"
                        >
                          <Printer className="w-3.5 h-3.5" /> Print Receipt
                        </button>
                      </>
                    ) : (
                      <>
                        <XCircle className="w-10 h-10 text-red-600 mx-auto mb-2" />
                        <p className="font-semibold text-foreground">Entry Rejected</p>
                      </>
                    )}
                    <button
                      onClick={handleReset}
                      className="mt-3 flex items-center gap-1 text-xs text-primary mx-auto hover:underline"
                    >
                      <RefreshCw className="w-3 h-3" /> Next Vehicle
                    </button>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>

            {/* Camera Status */}
            <div className="bg-card border border-border rounded-xl p-4">
              <p className="text-sm font-medium text-foreground mb-3">Camera Status</p>
              <div className="flex items-center gap-2">
                <div className={`w-2 h-2 rounded-full ${
                  wsStatus === 'authenticated'
                    ? pending ? 'bg-green-500 animate-pulse' : 'bg-green-500'
                    : wsStatus === 'connected' ? 'bg-amber-500 animate-pulse'
                    : 'bg-muted-foreground'
                }`} />
                <span className="text-sm text-muted-foreground">
                  {wsStatus === 'authenticated'
                    ? pending ? 'Vehicle detected — review required' : 'Monitoring — no vehicle'
                    : wsStatus === 'connected' ? 'Authenticating...'
                    : 'Disconnected'}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Manual Mode */}
      {mode === 'manual' && <ManualEntryForm type="entry" />}
    </div>
  )
}