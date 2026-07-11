import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import {
  Keyboard, Search, CheckCircle, XCircle, MapPin, Banknote,
  Smartphone, Printer, RefreshCw, AlertTriangle,
} from 'lucide-react'
import api from '../../api/axios'

// Manual entry/exit — cashier plate type karta hai, camera ke bina.
// Backend ke wahi endpoints reuse hote hain jo AI flow use karta hai:
//   Entry: /ai/manual-entry/ → /ai/check-entry-plate/ → /ai/approve/ | /ai/reject/
//   Exit : /ai/manual-exit/  → /ai/check-plate/       → /ai/approve-exit/ | /ai/reject-exit/

// ── Compact receipt (entry + exit dono) ────────────────────────
function printManualReceipt({ kind, plate, slot, type, amount, baseAmount, overstayCharge, alreadyPaid, entryTime, method }) {
  const win = window.open('', '_blank', 'width=340,height=560')
  const now   = new Date().toLocaleString('en-PK', { dateStyle: 'medium', timeStyle: 'short' })
  const entry = entryTime ? new Date(entryTime).toLocaleString('en-PK', { dateStyle: 'medium', timeStyle: 'short' }) : '—'
  const isExit = kind === 'exit'
  win.document.write(`
    <html><head><title>${isExit ? 'Exit' : 'Entry'} Receipt</title>
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
      .total  { font-size: 18px; font-weight: bold; text-align: center; background: #f0f0f0; padding: 8px; border-radius: 4px; margin: 8px 0; }
      .warn   { color: #b45309; }
      .paid   { color: #047857; }
      .footer { font-size: 10px; color: #888; text-align: center; margin-top: 14px; }
    </style></head>
    <body>
      <div class="center">
        <div class="title">Parkroo</div>
        <div class="sub">Smart Parking Management System</div>
      </div>
      <hr/>
      <div class="center" style="font-size:11px;color:#555;margin-bottom:6px;">${isExit ? 'EXIT' : 'ENTRY'} RECEIPT (MANUAL)</div>
      <div class="plate">${plate ?? '—'}</div>
      ${!isExit ? `<div style="font-size:11px;text-align:center;color:#555;margin-bottom:10px;">Assigned slot</div><div class="slot">${slot ?? '—'}</div>` : ''}
      <hr/>
      ${isExit ? `<div class="row"><span class="label">Slot</span><span>${slot ?? '—'}</span></div>` : ''}
      ${type ? `<div class="row"><span class="label">Type</span><span>${type}</span></div>` : ''}
      <div class="row"><span class="label">Entry time</span><span>${entry}</span></div>
      ${isExit ? `<div class="row"><span class="label">Exit time</span><span>${now}</span></div>` : `<div class="row"><span class="label">Printed</span><span>${now}</span></div>`}
      ${method ? `<div class="row"><span class="label">Payment</span><span>${method}</span></div>` : ''}
      ${isExit ? '<hr/>' : ''}
      ${isExit && baseAmount ? `<div class="row"><span class="label">Base amount</span><span>Rs. ${baseAmount}</span></div>` : ''}
      ${isExit && overstayCharge > 0 ? `<div class="row warn"><span class="label">Overstay charge</span><span>Rs. ${overstayCharge}</span></div>` : ''}
      ${isExit && alreadyPaid > 0 ? `<div class="row paid"><span class="label" style="color:#047857">Paid online</span><span>− Rs. ${alreadyPaid}</span></div>` : ''}
      ${isExit ? `<div class="total">${Number(amount) > 0 ? `Collected now: Rs. ${amount}` : 'Nothing due — prepaid'}</div>` : ''}
      <hr/>
      <div class="footer">${isExit ? 'Thank you for using Parkroo.<br/>Drive safely!' : 'Thank you — Please keep this slip<br/>until you exit the parking area.'}</div>
    </body></html>
  `)
  win.document.close()
  win.focus()
  setTimeout(() => { win.print(); win.close() }, 400)
}

export default function ManualEntryForm({ type }) {
  const isExit = type === 'exit'

  const [plate, setPlate]         = useState('')
  const [vehicleType, setVehicleType] = useState('car')
  const [slotType, setSlotType]       = useState('normal') // walk-in slot type
  const [logId, setLogId]         = useState(null)
  const [info, setInfo]           = useState(null)   // check-* response
  const [phase, setPhase]         = useState('form') // form | review | done | rejected
  const [loading, setLoading]     = useState(false)
  const [error, setError]         = useState('')
  const [result, setResult]       = useState(null)   // approve response

  function reset() {
    setPlate(''); setLogId(null); setInfo(null); setResult(null)
    setError(''); setPhase('form'); setVehicleType('car'); setSlotType('normal')
  }

  // ── Step 1+2: pending log banao + plate check karo ────────────
  async function handleLookup() {
    const p = plate.trim().toUpperCase()
    if (!p) { setError('Plate number likhein'); return }
    setLoading(true); setError('')
    try {
      const create = await api.post(isExit ? '/ai/manual-exit/' : '/ai/manual-entry/', {
        plate_number: p,
        vehicle_type: vehicleType,
      })
      const id = create.data.ai_log_id
      setLogId(id)

      const check = await api.post(isExit ? '/ai/check-plate/' : '/ai/check-entry-plate/', {
        ai_log_id: id,
        plate_number: p,
        ...(isExit ? {} : { slot_type: slotType }),
      })
      setInfo(check.data)
      if (check.data.slot_type) setSlotType(check.data.slot_type)
      setPlate(check.data.plate_number || p)
      setPhase('review')
    } catch (err) {
      const msg = err.response?.data?.error || err.response?.data?.message || 'Lookup failed — dobara koshish karein'
      setError(msg)
      // already_inside jaisi hard-fail par form pe hi raho
    } finally {
      setLoading(false)
    }
  }

  // Review phase me plate correct karke dobara check
  async function handleRecheck(requestedSlotType) {
    if (!logId) return
    setLoading(true); setError('')
    try {
      const check = await api.post(isExit ? '/ai/check-plate/' : '/ai/check-entry-plate/', {
        ai_log_id: logId,
        plate_number: plate.trim().toUpperCase(),
        ...(isExit ? {} : { slot_type: requestedSlotType || slotType }),
      })
      setInfo(check.data)
      if (check.data.slot_type) setSlotType(check.data.slot_type)
      setPlate(check.data.plate_number || plate)
    } catch (err) {
      setError(err.response?.data?.error || 'Recheck failed')
    } finally {
      setLoading(false)
    }
  }

  // ── Step 3: approve ───────────────────────────────────────────
  async function handleApprove(paymentMethod) {
    if (!logId) return
    setLoading(true); setError('')
    try {
      const res = await api.post(isExit ? '/ai/approve-exit/' : '/ai/approve/', {
        ai_log_id   : logId,
        plate_number: plate.trim().toUpperCase(),
        ...(isExit ? { payment_method: paymentMethod } : { slot_type: slotType }),
      })
      setResult({ ...res.data, method: paymentMethod })
      setPhase('done')
    } catch (err) {
      setError(err.response?.data?.error || 'Approve failed')
    } finally {
      setLoading(false)
    }
  }

  async function handleCancel() {
    if (!logId) { reset(); return }
    setLoading(true)
    try {
      await api.post(isExit ? '/ai/reject-exit/' : '/ai/reject/', { ai_log_id: logId })
    } catch { /* pending log na bhi mile to reset hi karna hai */ }
    setLoading(false)
    setPhase('rejected')
  }

  // ── Derived (exit paid-awareness — AI panel jaisa) ────────────
  const bi          = info?.booking_info || null
  const alreadyPaid = bi?.already_paid ?? 0
  const amountDue   = bi?.amount_due ?? info?.amount ?? null
  const isPrepaid   = alreadyPaid > 0 || bi?.payment_status === 'paid'
  const nothingDue  = Boolean(isExit && info?.entry_found && isPrepaid && Number(amountDue) === 0)
  const entryFound  = !isExit || Boolean(info?.entry_found)

  const entrySlot     = bi?.slot ?? info?.pre_assigned_slot ?? null
  const entryIsWalkIn = !isExit && info && !info.has_booking && !info.is_pass
  const parkingFull   = entryIsWalkIn && !entrySlot

  return (
    <div className="bg-card border border-border rounded-xl p-5 max-w-2xl">
      <div className="flex items-center gap-2 mb-4">
        <Keyboard className="w-4 h-4 text-primary" />
        <h3 className="text-sm font-medium text-foreground">
          Manual {isExit ? 'Exit' : 'Entry'}
        </h3>
      </div>

      <AnimatePresence mode="wait">
        {/* ── PHASE: form ─────────────────────────────────────── */}
        {phase === 'form' && (
          <motion.div key="form" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="space-y-3">
            <div>
              <label className="text-xs text-muted-foreground block mb-1">Plate number</label>
              <input
                value={plate}
                onChange={(e) => setPlate(e.target.value.toUpperCase())}
                onKeyDown={(e) => { if (e.key === 'Enter') handleLookup() }}
                placeholder="e.g. LEB 4910"
                className="w-full px-3 py-2.5 text-sm font-mono tracking-widest border border-border rounded-lg bg-background focus:outline-none focus:ring-1 focus:ring-primary"
                autoFocus
              />
            </div>
            {!isExit && (
              <div>
                <label className="text-xs text-muted-foreground block mb-1">Vehicle type</label>
                <select
                  value={vehicleType}
                  onChange={(e) => setVehicleType(e.target.value)}
                  className="w-full px-3 py-2.5 text-sm border border-border rounded-lg bg-background focus:outline-none focus:ring-1 focus:ring-primary"
                >
                  <option value="car">Car</option>
                  <option value="bike">Bike</option>
                  <option value="truck">Truck</option>
                </select>
              </div>
            )}
            {error && (
              <p className="flex items-center gap-1.5 text-xs text-destructive">
                <AlertTriangle className="w-3.5 h-3.5" /> {error}
              </p>
            )}
            <button
              onClick={handleLookup}
              disabled={loading || !plate.trim()}
              className="w-full flex items-center justify-center gap-2 py-3 bg-primary text-primary-foreground rounded-lg text-sm font-medium disabled:opacity-40 hover:bg-primary/90 transition-colors"
            >
              <Search className="w-4 h-4" />
              {loading ? 'Checking...' : `Check ${isExit ? 'Exit' : 'Entry'} Details`}
            </button>
          </motion.div>
        )}

        {/* ── PHASE: review ───────────────────────────────────── */}
        {phase === 'review' && info && (
          <motion.div key="review" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="space-y-4">

            {/* Plate + correction */}
            <div className="flex gap-2">
              <input
                value={plate}
                onChange={(e) => setPlate(e.target.value.toUpperCase())}
                onKeyDown={(e) => { if (e.key === 'Enter') handleRecheck() }}
                className="flex-1 px-3 py-2 text-sm font-mono tracking-widest border border-border rounded-lg bg-background focus:outline-none focus:ring-1 focus:ring-primary"
              />
              <button onClick={() => handleRecheck()} disabled={loading}
                className="px-3 py-2 bg-secondary text-foreground rounded-lg text-sm disabled:opacity-50 flex items-center gap-1.5">
                <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} /> Recheck
              </button>
            </div>

            {/* Status badges */}
            <div className="flex flex-wrap gap-1.5">
              {!isExit && (
                <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                  info.has_booking || info.is_pass ? 'bg-green-50 text-green-600' : 'bg-blue-50 text-blue-600'}`}>
                  {info.is_pass ? 'Pass holder' : info.has_booking ? 'Booking found' : 'Walk-in'}
                </span>
              )}
              {!isExit && info.has_booking && bi?.payment_status === 'paid' && (
                <span className="text-xs px-2 py-0.5 rounded-full font-medium bg-emerald-50 text-emerald-600">Paid ✓</span>
              )}
              {isExit && (
                <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                  info.entry_found ? 'bg-green-50 text-green-600' : 'bg-red-50 text-red-600'}`}>
                  {info.entry_found ? '✓ Entry record found' : '✗ No entry record'}
                </span>
              )}
              {isExit && bi && (
                <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
                  bi.is_overstay ? 'bg-amber-50 text-amber-600' : 'bg-green-50 text-green-600'}`}>
                  {bi.is_overstay ? 'Overstay' : 'On time'}
                </span>
              )}
              {isExit && isPrepaid && (
                <span className="text-xs px-2 py-0.5 rounded-full font-medium bg-emerald-50 text-emerald-600">Paid online</span>
              )}
            </div>

            {/* Details */}
            <div className="space-y-2 text-sm">
              {entryIsWalkIn && (
                <div className="flex justify-between items-center border-b border-border pb-2">
                  <span className="text-muted-foreground">Slot type</span>
                  <select
                    value={slotType}
                    onChange={(e) => { setSlotType(e.target.value); handleRecheck(e.target.value) }}
                    disabled={loading}
                    className="px-2 py-1 text-sm font-medium border border-border rounded-md bg-background focus:outline-none focus:ring-1 focus:ring-primary disabled:opacity-50"
                  >
                    <option value="normal">Normal</option>
                    <option value="vip">VIP</option>
                    <option value="disabled">Disabled</option>
                  </select>
                </div>
              )}
              {!isExit && (
                <div className="flex justify-between border-b border-border pb-2">
                  <span className="text-muted-foreground">Slot</span>
                  <span className="font-medium text-foreground flex items-center gap-1">
                    <MapPin className="w-3.5 h-3.5 text-primary" />
                    {loading ? 'Finding...' : (entrySlot ?? (parkingFull ? `No ${slotType} slot free` : '—'))}
                  </span>
                </div>
              )}
              {bi?.user && (
                <div className="flex justify-between border-b border-border pb-2">
                  <span className="text-muted-foreground">User</span>
                  <span className="font-medium text-foreground">{bi.user}</span>
                </div>
              )}
              {isExit && bi?.slot && (
                <div className="flex justify-between border-b border-border pb-2">
                  <span className="text-muted-foreground">Slot</span>
                  <span className="font-medium text-foreground">{bi.slot}</span>
                </div>
              )}
              {isExit && (info.entry_time || bi?.entry_time) && (
                <div className="flex justify-between border-b border-border pb-2">
                  <span className="text-muted-foreground">Entry time</span>
                  <span className="font-medium text-foreground">
                    {new Date(bi?.entry_time || info.entry_time).toLocaleTimeString()}
                  </span>
                </div>
              )}
              {isExit && bi?.booked_exit && (
                <div className="flex justify-between border-b border-border pb-2">
                  <span className="text-muted-foreground">Booked exit</span>
                  <span className="font-medium text-foreground">{new Date(bi.booked_exit).toLocaleTimeString()}</span>
                </div>
              )}
              {!isExit && info.booking_other_site && (
                <p className="text-xs text-amber-600 flex items-center gap-1.5">
                  <AlertTriangle className="w-3.5 h-3.5" />
                  Booking exists at "{info.booking_other_site}" — not this site
                </p>
              )}
            </div>

            {/* Exit: payment summary */}
            {isExit && info.entry_found && amountDue !== null && (
              <div className="bg-secondary/50 rounded-lg p-3 space-y-1.5 text-sm">
                {bi && (
                  <>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Base amount</span>
                      <span className="font-medium">Rs. {bi.base_amount}</span>
                    </div>
                    {bi.overstay_charge > 0 && (
                      <div className="flex justify-between text-amber-600">
                        <span>Overstay charge</span><span className="font-medium">Rs. {bi.overstay_charge}</span>
                      </div>
                    )}
                    {alreadyPaid > 0 && (
                      <div className="flex justify-between text-emerald-600">
                        <span>Paid online ✓</span><span className="font-medium">− Rs. {alreadyPaid}</span>
                      </div>
                    )}
                  </>
                )}
                <div className="flex justify-between font-semibold pt-1 border-t border-border">
                  <span>Total due</span>
                  <span className={nothingDue ? 'text-emerald-600' : ''}>
                    {nothingDue ? 'Rs. 0 — Already paid' : `Rs. ${amountDue}`}
                  </span>
                </div>
              </div>
            )}

            {error && (
              <p className="flex items-center gap-1.5 text-xs text-destructive">
                <AlertTriangle className="w-3.5 h-3.5" /> {error}
              </p>
            )}

            {/* Actions */}
            <div className="space-y-2">
              {!isExit && (
                <button
                  onClick={() => handleApprove()}
                  disabled={loading || parkingFull}
                  className="w-full flex items-center justify-center gap-2 py-3 bg-green-600 text-white rounded-lg text-sm font-medium disabled:opacity-40 hover:bg-green-700 transition-colors"
                >
                  <CheckCircle className="w-4 h-4" />
                  {loading ? 'Processing...' : 'Allow Entry'}
                </button>
              )}
              {isExit && nothingDue && (
                <button
                  onClick={() => handleApprove('online')}
                  disabled={loading || !entryFound}
                  className="w-full flex items-center justify-center gap-2 py-3 bg-emerald-600 text-white rounded-lg text-sm font-medium disabled:opacity-40 hover:bg-emerald-700 transition-colors"
                >
                  <CheckCircle className="w-4 h-4" />
                  {loading ? 'Processing...' : 'Allow Exit — Already Paid'}
                </button>
              )}
              {isExit && !nothingDue && (
                <>
                  <button
                    onClick={() => handleApprove('cash')}
                    disabled={loading || !entryFound}
                    className="w-full flex items-center justify-center gap-2 py-3 bg-green-600 text-white rounded-lg text-sm font-medium disabled:opacity-40 hover:bg-green-700 transition-colors"
                  >
                    <Banknote className="w-4 h-4" />
                    {loading ? 'Processing...' : 'Collect Cash + Allow Exit'}
                  </button>
                  <button
                    onClick={() => handleApprove('online')}
                    disabled={loading || !entryFound}
                    className="w-full flex items-center justify-center gap-2 py-3 bg-primary text-primary-foreground rounded-lg text-sm font-medium disabled:opacity-40 hover:bg-primary/90 transition-colors"
                  >
                    <Smartphone className="w-4 h-4" />
                    Online Paid + Allow Exit
                  </button>
                </>
              )}
              <button
                onClick={handleCancel}
                disabled={loading}
                className="w-full flex items-center justify-center gap-2 py-3 bg-card text-destructive border border-destructive/30 rounded-lg text-sm font-medium disabled:opacity-40 hover:bg-destructive/5 transition-colors"
              >
                <XCircle className="w-4 h-4" /> Cancel
              </button>
              {parkingFull && (
                <p className="text-xs text-center text-amber-600">No free {slotType} slot right now — try another slot type or wait for one to free up.</p>
              )}
              {isExit && !entryFound && (
                <p className="text-xs text-center text-amber-600">Plate number correct karke Recheck karein</p>
              )}
            </div>
          </motion.div>
        )}

        {/* ── PHASE: done ─────────────────────────────────────── */}
        {phase === 'done' && result && (
          <motion.div key="done" initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }}
            className="rounded-xl p-5 text-center bg-green-50 border border-green-200 space-y-2">
            <CheckCircle className="w-10 h-10 text-green-600 mx-auto" />
            <p className="font-semibold text-foreground">{isExit ? 'Exit Allowed' : 'Entry Allowed'}</p>
            {isExit ? (
              <p className="text-xs text-muted-foreground">
                {Number(result.amount) > 0
                  ? `Rs. ${result.amount} — ${result.method === 'cash' ? 'Cash' : 'Online'}`
                  : 'Nothing due — paid online in advance'}
                {result.slot ? ` · Slot ${result.slot} freed` : ''}
              </p>
            ) : (
              <p className="text-xs text-muted-foreground">
                Slot {result.slot ?? '—'}{result.is_pass ? ' · Pass holder' : result.booking_id ? ' · Pre-booked' : ' · Walk-in'}
              </p>
            )}
            <div className="flex gap-2 justify-center pt-1">
              <button
                onClick={() => printManualReceipt({
                  kind          : isExit ? 'exit' : 'entry',
                  plate         : result.plate_number || plate,
                  slot          : result.slot,
                  type          : isExit ? undefined
                                  : result.is_pass ? 'Pass holder'
                                  : result.booking_id ? 'Pre-booked' : 'Walk-in',
                  amount        : result.amount,
                  baseAmount    : bi?.base_amount,
                  overstayCharge: bi?.overstay_charge ?? 0,
                  alreadyPaid   : bi?.already_paid ?? 0,
                  entryTime     : result.entry_time || bi?.entry_time,
                  method        : isExit ? (Number(result.amount) > 0 ? (result.method === 'cash' ? 'Cash' : 'Online') : 'Prepaid') : undefined,
                })}
                className="flex items-center gap-1.5 px-4 py-2 bg-card border border-border rounded-lg text-xs font-medium hover:bg-secondary transition-colors"
              >
                <Printer className="w-3.5 h-3.5" /> Print Receipt
              </button>
              <button onClick={reset}
                className="flex items-center gap-1.5 px-4 py-2 bg-primary text-primary-foreground rounded-lg text-xs font-medium hover:bg-primary/90 transition-colors">
                <RefreshCw className="w-3.5 h-3.5" /> Next Vehicle
              </button>
            </div>
          </motion.div>
        )}

        {/* ── PHASE: rejected/cancelled ───────────────────────── */}
        {phase === 'rejected' && (
          <motion.div key="rejected" initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }}
            className="rounded-xl p-5 text-center bg-red-50 border border-red-200 space-y-2">
            <XCircle className="w-10 h-10 text-red-500 mx-auto" />
            <p className="font-semibold text-foreground">Cancelled</p>
            <button onClick={reset}
              className="flex items-center gap-1.5 px-4 py-2 mx-auto bg-primary text-primary-foreground rounded-lg text-xs font-medium hover:bg-primary/90 transition-colors">
              <RefreshCw className="w-3.5 h-3.5" /> Next Vehicle
            </button>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}