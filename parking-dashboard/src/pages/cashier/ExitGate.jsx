import { useEffect, useState, useRef } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Camera, CheckCircle, XCircle, RefreshCw, PenLine, Keyboard, Banknote, Smartphone, Clock, Printer } from 'lucide-react'
import api from '../../api/axios'
import ManualEntryForm from '../../components/gate/ManualEntryForm'

const GRACE_MINUTES = 10   // must match backend setting

// ── Grace period countdown hook ────────────────────────────────
function useGraceCountdown(entryTime, isOverstay) {
  const [secondsLeft, setSecondsLeft] = useState(null)

  useEffect(() => {
    if (!entryTime || isOverstay) { setSecondsLeft(null); return }

    function calc() {
      const elapsed = (Date.now() - new Date(entryTime).getTime()) / 1000
      const graceSeconds = GRACE_MINUTES * 60
      const left = Math.max(0, graceSeconds - elapsed)
      setSecondsLeft(Math.floor(left))
    }

    calc()
    const id = setInterval(calc, 1000)
    return () => clearInterval(id)
  }, [entryTime, isOverstay])

  return secondsLeft
}

// ── Receipt printer ────────────────────────────────────────────
function printReceipt({ plate, slot, amount, baseAmount, overstayCharge, alreadyPaid, entryTime, method, receiptNo }) {
  const win = window.open('', '_blank', 'width=340,height=560')
  const now   = new Date().toLocaleString('en-PK', { dateStyle: 'medium', timeStyle: 'short' })
  const entry = entryTime ? new Date(entryTime).toLocaleString('en-PK', { dateStyle: 'medium', timeStyle: 'short' }) : '—'
  win.document.write(`
    <html><head><title>Exit Receipt</title>
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
      .total  { font-size: 18px; font-weight: bold; text-align: center; background: #f0f0f0; padding: 8px; border-radius: 4px; margin: 8px 0; }
      .warn   { color: #b45309; }
      .footer { font-size: 10px; color: #888; text-align: center; margin-top: 14px; }
    </style></head>
    <body>
      <div class="center">
        <div class="title">Parkroo</div>
        <div class="sub">Smart Parking Management System</div>
      </div>
      <hr/>
      <div class="center" style="font-size:11px;color:#555;margin-bottom:6px;">EXIT RECEIPT</div>
      <div class="plate">${plate ?? '—'}</div>
      <hr/>
      <div class="row"><span class="label">Slot</span><span>${slot ?? '—'}</span></div>
      <div class="row"><span class="label">Entry time</span><span>${entry}</span></div>
      <div class="row"><span class="label">Exit time</span><span>${now}</span></div>
      <div class="row"><span class="label">Payment</span><span>${method === 'cash' ? 'Cash' : 'Online'}</span></div>
      <hr/>
      ${baseAmount ? `<div class="row"><span class="label">Base amount</span><span>Rs. ${baseAmount}</span></div>` : ''}
      ${overstayCharge > 0 ? `<div class="row warn"><span class="label">Overstay charge</span><span>Rs. ${overstayCharge}</span></div>` : ''}
      ${alreadyPaid > 0 ? `<div class="row" style="color:#047857"><span class="label" style="color:#047857">Paid online</span><span>− Rs. ${alreadyPaid}</span></div>` : ''}
      <div class="total">${(amount ?? 0) > 0 ? `Collected now: Rs. ${amount}` : 'Nothing due — prepaid'}</div>
      ${receiptNo ? `<div class="row" style="margin-top:6px"><span class="label">Receipt #</span><span>${receiptNo}</span></div>` : ''}
      <hr/>
      <div class="footer">Thank you for using Parkroo.<br/>Drive safely!</div>
    </body></html>
  `)
  win.document.close()
  win.focus()
  setTimeout(() => { win.print(); win.close() }, 400)
}

// ── Grace timer badge ──────────────────────────────────────────
function GraceTimer({ entryTime, isOverstay }) {
  const secondsLeft = useGraceCountdown(entryTime, isOverstay)

  if (isOverstay || secondsLeft === null) return null

  const mins = Math.floor(secondsLeft / 60)
  const secs = secondsLeft % 60
  const pct  = (secondsLeft / (GRACE_MINUTES * 60)) * 100
  const urgent = secondsLeft <= 60

  return (
    <div className={`flex items-center gap-3 rounded-xl border px-4 py-3 ${
      urgent ? 'bg-red-50 border-red-200' : 'bg-amber-50 border-amber-200'
    }`}>
      <Clock className={`w-4 h-4 flex-shrink-0 ${urgent ? 'text-red-600' : 'text-amber-600'}`} />
      <div className="flex-1">
        <div className="flex items-center justify-between mb-1">
          <span className={`text-xs font-medium ${urgent ? 'text-red-700' : 'text-amber-700'}`}>
            Grace period — no charge yet
          </span>
          <span className={`text-sm font-bold font-mono ${urgent ? 'text-red-700' : 'text-amber-800'}`}>
            {String(mins).padStart(2, '0')}:{String(secs).padStart(2, '0')}
          </span>
        </div>
        <div className="w-full h-1.5 rounded-full bg-white/60 overflow-hidden">
          <div
            className={`h-full rounded-full transition-all ${urgent ? 'bg-red-500' : 'bg-amber-400'}`}
            style={{ width: `${pct}%` }}
          />
        </div>
      </div>
    </div>
  )
}

export default function ExitGate() {
  const [mode, setMode]               = useState('ai')
  const [pending, setPending]         = useState(null)
  const [plate, setPlate]             = useState('')
  const [editing, setEditing]         = useState(false)
  const [decision, setDecision]       = useState(null)
  const [loading, setLoading]         = useState(false)
  const [checkLoading, setCheckLoading] = useState(false)

  useEffect(() => {
    const token = localStorage.getItem('access_token')
    let ws = null
    let reconnectTimer = null

    function connect() {
      ws = new WebSocket('ws://127.0.0.1:8000/ws/parking/exit/')

      ws.onopen = () => {
        ws.send(JSON.stringify({ type: 'auth', token }))
      }

      ws.onmessage = (e) => {
        let data = null
        try { data = JSON.parse(e.data) } catch { return }

        if (data.type === 'auth_required') { ws.send(JSON.stringify({ type: 'auth', token })); return }
        if (data.type === 'auth_success')  { fetchPending(); return }
        if (data.type === 'auth_failed') {
          localStorage.removeItem('access_token')
          localStorage.removeItem('refresh_token')
          window.location.href = '/login'
          return
        }
        if (data.type === 'exit_detected') {
          setPending({
            id                   : data.ai_log_id,
            detected_plate_number: data.plate_number,
            confidence_score     : data.confidence,
            image_url            : data.image_url,
            cropped_plate        : data.cropped_plate || '',
            vehicle_type         : data.vehicle_type || 'car',
            vehicle_name         : data.vehicle_name || '',
            booking_info         : data.booking_info || null,
            slot                 : data.slot || '',
            amount               : data.amount ?? null,
            entry_time           : data.entry_time || '',
            is_extended          : data.is_extended || false,
            booking_id           : data.booking_id || '',
            entry_found          : data.entry_found || false,
          })
          setPlate(data.plate_number)
          setDecision(null)
          setEditing(false)
        }
      }

      ws.onclose = (e) => {
        if (e.code === 4004) return
        if ([4001, 4003, 4008].includes(e.code)) return
        reconnectTimer = setTimeout(connect, 3000)
      }

      ws.onerror = () => console.error('Exit WS error')
    }

    connect()
    return () => { clearTimeout(reconnectTimer); ws?.close() }
  }, [])

  async function fetchPending() {
    try {
      const res = await api.get('/ai/pending-exit/')
      if (res.data) {
        setPending(res.data)
        setPlate(res.data.detected_plate_number)
        setDecision(null)
        setEditing(false)
      } else {
        setPending(null)
      }
    } catch (err) {
      console.error('Error fetching pending exit:', err)
    }
  }

  async function handlePlateSave() {
    setEditing(false)
    if (!pending) return
    setCheckLoading(true)
    try {
      const res = await api.post('/ai/check-plate/', {
        plate_number: plate,
        ai_log_id   : pending.id,
      })
      const d = res.data
      setPending(prev => ({
        ...prev,
        detected_plate_number: d.plate_number,
        amount      : d.amount,
        vehicle_name: d.vehicle_name || '',
        vehicle_type: d.vehicle_type || 'car',
        slot        : d.slot || '',
        is_extended : d.is_extended || false,
        booking_id  : d.booking_id || '',
        booking_info: d.booking_info || null,
        entry_time  : d.entry_time || '',
        entry_found : d.entry_found || false,
      }))
    } catch (err) {
      console.error('Check plate error:', err)
    } finally {
      setCheckLoading(false)
    }
  }

  async function handleExit(paymentMethod) {
    if (!pending) return
    setLoading(true)
    try {
      const res = await api.post('/ai/approve-exit/', {
        ai_log_id     : pending.id,
        plate_number  : plate,
        payment_method: paymentMethod,
      })
      setDecision({
        type  : 'exited',
        method: paymentMethod,
        data  : res.data,
        // carry for receipt
        plate,
        entryTime     : pending.entry_time || pending.booking_info?.entry_time,
        slot          : res.data?.slot || pending.booking_info?.slot || pending.slot,
        baseAmount    : pending.booking_info?.base_amount,
        overstayCharge: pending.booking_info?.overstay_charge ?? 0,
        alreadyPaid   : pending.booking_info?.already_paid ?? 0,
      })
      setPending(null)
    } catch (err) {
      console.error('Exit error:', err)
    } finally {
      setLoading(false)
    }
  }

  async function handleReject() {
    if (!pending) return
    setLoading(true)
    try {
      await api.post('/ai/reject-exit/', { ai_log_id: pending.id })
      setDecision({ type: 'rejected' })
      setPending(null)
    } catch (err) {
      console.error('Reject error:', err)
    } finally {
      setLoading(false)
    }
  }

  function handleReset() {
    setDecision(null)
    setPending(null)
    fetchPending()
  }

  const displayAmount = pending?.amount ?? null
  const entryTimeForTimer = pending?.entry_time || pending?.booking_info?.entry_time
  const isOverstay        = pending?.booking_info?.is_overstay ?? false

  // Prepaid booking awareness — backend ab already_paid / amount_due bhejta hai.
  const alreadyPaid = pending?.booking_info?.already_paid ?? 0
  const amountDue   = pending?.booking_info?.amount_due ?? displayAmount
  const isPrepaid   = alreadyPaid > 0 || pending?.booking_info?.payment_status === 'paid'
  const nothingDue  = Boolean(pending?.entry_found && isPrepaid && Number(amountDue) === 0)

  return (
    <div className="space-y-5">

      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-foreground">Exit Gate</h2>
          <p className="text-sm text-muted-foreground mt-1">Process vehicle exit and collect payment</p>
        </div>
        <div className="flex gap-2">
          <button onClick={() => setMode('ai')}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium border transition-colors ${
              mode === 'ai' ? 'bg-primary text-primary-foreground border-primary'
                           : 'bg-card text-muted-foreground border-border hover:bg-secondary'}`}>
            <Camera className="w-4 h-4" /> AI Detection
          </button>
          <button onClick={() => setMode('manual')}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium border transition-colors ${
              mode === 'manual' ? 'bg-primary text-primary-foreground border-primary'
                               : 'bg-card text-muted-foreground border-border hover:bg-secondary'}`}>
            <Keyboard className="w-4 h-4" /> Manual Exit
          </button>
        </div>
      </div>

      {/* ── Grace period countdown banner ───────────────────── */}
      {pending && entryTimeForTimer && (
        <GraceTimer entryTime={entryTimeForTimer} isOverstay={isOverstay} />
      )}

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
                <span className="text-xs text-muted-foreground">Exit Camera</span>
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

          {/* Col 2 — Plate + Info */}
          <div className="space-y-4">

            {/* Plate Verification */}
            <div className="bg-card border border-border rounded-xl p-4">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm font-medium text-foreground">Plate Verification</span>
                {pending && (
                  <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                    pending.confidence_score >= 0.85 ? 'bg-green-50 text-green-600' : 'bg-amber-50 text-amber-600'}`}>
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
                      />
                      <button onClick={handlePlateSave} disabled={checkLoading}
                        className="px-3 py-2 bg-primary text-primary-foreground rounded-lg text-sm disabled:opacity-50">
                        {checkLoading ? '...' : 'Save'}
                      </button>
                    </div>
                  ) : (
                    <div className="px-3 py-2 bg-secondary rounded-lg font-mono text-sm tracking-widest">{plate}</div>
                  )}
                  <div className={`mt-3 text-xs px-2 py-1 rounded-md font-medium ${
                    pending.entry_found ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-600'
                  }`}>
                    {pending.entry_found ? '✓ Entry record found' : '✗ No entry record — edit plate to search again'}
                  </div>
                </>
              ) : (
                <p className="text-sm text-muted-foreground">No vehicle detected yet</p>
              )}
            </div>

            {/* Booking Info */}
            <div className="bg-card border border-border rounded-xl p-4">
              <div className="flex items-center justify-between mb-3">
                <span className="text-sm font-medium text-foreground">Booking Info</span>
                {pending?.booking_info && (
                  <div className="flex items-center gap-1.5">
                    {isPrepaid && (
                      <span className="text-xs px-2 py-0.5 rounded-full font-medium bg-emerald-50 text-emerald-600">
                        Paid online
                      </span>
                    )}
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                      pending.booking_info.is_overstay ? 'bg-amber-50 text-amber-600' : 'bg-green-50 text-green-600'}`}>
                      {pending.booking_info.is_overstay ? 'Overstay' : 'On time'}
                    </span>
                  </div>
                )}
              </div>
              {pending?.booking_info ? (
                <div className="space-y-2">
                  {[
                    { label: 'User',        value: pending.booking_info.user },
                    { label: 'Slot',        value: pending.booking_info.slot },
                    { label: 'Entry time',  value: pending.booking_info.entry_time ? new Date(pending.booking_info.entry_time).toLocaleTimeString() : '—' },
                    { label: 'Booked exit', value: pending.booking_info.booked_exit ? new Date(pending.booking_info.booked_exit).toLocaleTimeString() : '—' },
                  ].map(({ label, value }) => (
                    <div key={label} className="flex justify-between text-sm border-b border-border pb-2 last:border-0 last:pb-0">
                      <span className="text-muted-foreground">{label}</span>
                      <span className="font-medium text-foreground">{value}</span>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-muted-foreground">
                  {checkLoading ? 'Checking booking records...'
                    : pending
                    ? pending.entry_found ? 'Walk-in vehicle' : 'Edit plate to fetch details'
                    : 'Waiting for vehicle...'}
                </p>
              )}
            </div>

            {/* Payment Summary */}
            {pending && displayAmount !== null && (
              <div className="bg-card border border-border rounded-xl p-4">
                <p className="text-sm font-medium text-foreground mb-3">Payment Summary</p>
                <div className="space-y-2">
                  {pending.booking_info ? (
                    <>
                      <div className="flex justify-between text-sm pb-2 border-b border-border">
                        <span className="text-muted-foreground">Base amount</span>
                        <span className="font-medium">Rs. {pending.booking_info.base_amount}</span>
                      </div>
                      {pending.booking_info.overstay_charge > 0 && (
                        <div className="flex justify-between text-sm pb-2 border-b border-border">
                          <span className="text-amber-600">Overstay charge</span>
                          <span className="font-medium text-amber-600">Rs. {pending.booking_info.overstay_charge}</span>
                        </div>
                      )}
                      {alreadyPaid > 0 && (
                        <div className="flex justify-between text-sm pb-2 border-b border-border">
                          <span className="text-emerald-600">Paid online ✓</span>
                          <span className="font-medium text-emerald-600">− Rs. {alreadyPaid}</span>
                        </div>
                      )}
                    </>
                  ) : null}
                  <div className="flex justify-between text-sm font-semibold pt-1">
                    <span className="text-foreground">Total due</span>
                    <span className={nothingDue ? 'text-emerald-600' : 'text-foreground'}>
                      {nothingDue ? 'Rs. 0 — Already paid' : `Rs. ${amountDue ?? displayAmount}`}
                    </span>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Col 3 — Actions */}
          <div className="space-y-4">
            <div className="bg-card border border-border rounded-xl p-4">
              <p className="text-sm font-medium text-foreground mb-3">Gate Decision</p>
              <AnimatePresence mode="wait">
                {!decision ? (
                  <motion.div key="buttons" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="space-y-3">
                    {nothingDue ? (
                      <button
                        onClick={() => handleExit('online')}
                        disabled={!pending || !pending.entry_found || loading}
                        className="w-full flex items-center justify-center gap-2 py-3 bg-emerald-600 text-white rounded-lg text-sm font-medium disabled:opacity-40 hover:bg-emerald-700 transition-colors"
                      >
                        <CheckCircle className="w-4 h-4" />
                        {loading ? 'Processing...' : 'Allow Exit — Already Paid'}
                      </button>
                    ) : (
                      <>
                        <button
                          onClick={() => handleExit('cash')}
                          disabled={!pending || !pending.entry_found || loading}
                          className="w-full flex items-center justify-center gap-2 py-3 bg-green-600 text-white rounded-lg text-sm font-medium disabled:opacity-40 hover:bg-green-700 transition-colors"
                        >
                          <Banknote className="w-4 h-4" />
                          {loading ? 'Processing...' : 'Collect Cash + Allow Exit'}
                        </button>
                        <button
                          onClick={() => handleExit('online')}
                          disabled={!pending || !pending.entry_found || loading}
                          className="w-full flex items-center justify-center gap-2 py-3 bg-primary text-primary-foreground rounded-lg text-sm font-medium disabled:opacity-40 hover:bg-primary/90 transition-colors"
                        >
                          <Smartphone className="w-4 h-4" />
                          Online Paid + Allow Exit
                        </button>
                      </>
                    )}
                    <button
                      onClick={handleReject}
                      disabled={!pending || loading}
                      className="w-full flex items-center justify-center gap-2 py-3 bg-card text-destructive border border-destructive/30 rounded-lg text-sm font-medium disabled:opacity-40 hover:bg-destructive/5 transition-colors"
                    >
                      <XCircle className="w-4 h-4" /> Reject
                    </button>
                    {pending && !pending.entry_found && (
                      <p className="text-xs text-center text-amber-600 mt-2">Edit plate number to find entry record</p>
                    )}
                    {!pending && (
                      <p className="text-xs text-center text-muted-foreground mt-2">Waiting for AI detection...</p>
                    )}
                  </motion.div>
                ) : (
                  <motion.div key="result" initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }}
                    className={`rounded-xl p-5 text-center ${decision.type === 'exited' ? 'bg-green-50 border border-green-200' : 'bg-red-50 border border-red-200'}`}>
                    {decision.type === 'exited' ? (
                      <>
                        <CheckCircle className="w-10 h-10 text-green-600 mx-auto mb-2" />
                        <p className="font-semibold text-foreground">Exit Allowed</p>
                        <p className="text-xs text-muted-foreground mt-1">
                          {Number(decision.data?.amount) > 0
                            ? `Rs. ${decision.data?.amount} — ${decision.method === 'cash' ? 'Cash' : 'Online'}`
                            : 'Nothing due — paid online in advance'}
                        </p>
                        <p className="text-xs text-muted-foreground">Slot {decision.slot} freed</p>
                        {/* ── Print Receipt button — only for cash ── */}
                        {decision.method === 'cash' && (
                          <button
                            onClick={() => printReceipt({
                              plate         : decision.plate,
                              slot          : decision.slot,
                              amount        : decision.data?.amount,
                              baseAmount    : decision.baseAmount,
                              overstayCharge: decision.overstayCharge,
                              alreadyPaid   : decision.alreadyPaid ?? 0,
                              entryTime     : decision.entryTime,
                              method        : 'cash',
                              receiptNo     : decision.data?.receipt_number,
                            })}
                            className="mt-3 w-full flex items-center justify-center gap-2 py-2 bg-white border border-green-300 rounded-lg text-xs font-medium text-green-700 hover:bg-green-50 transition-colors"
                          >
                            <Printer className="w-3.5 h-3.5" /> Print Receipt
                          </button>
                        )}
                      </>
                    ) : (
                      <>
                        <XCircle className="w-10 h-10 text-red-600 mx-auto mb-2" />
                        <p className="font-semibold text-foreground">Exit Rejected</p>
                      </>
                    )}
                    <button onClick={handleReset} className="mt-3 flex items-center gap-1 text-xs text-primary mx-auto hover:underline">
                      <RefreshCw className="w-3 h-3" /> Next Vehicle
                    </button>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>

            <div className="bg-card border border-border rounded-xl p-4">
              <p className="text-sm font-medium text-foreground mb-3">Camera Status</p>
              <div className="flex items-center gap-2">
                <div className={`w-2 h-2 rounded-full ${pending ? 'bg-green-500 animate-pulse' : 'bg-muted-foreground'}`} />
                <span className="text-sm text-muted-foreground">
                  {pending ? 'Vehicle detected — review required' : 'Monitoring — no vehicle'}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}

      {mode === 'manual' && <ManualEntryForm type="exit" />}
    </div>
  )
}