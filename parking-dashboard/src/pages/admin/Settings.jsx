import { useState, useEffect } from 'react'
import { Settings, Clock, AlertTriangle, CreditCard, Save, RotateCcw, Shield, Eye } from 'lucide-react'
import api from '../../api/axios'

// ── Section Card ──────────────────────────────────
function SectionCard({ title, description, icon: Icon, children }) {
  return (
    <div className="bg-white border border-gray-200 rounded-xl p-5 mb-5 hover:shadow-lg transition-all duration-300">
      <div className="flex items-start gap-3 mb-5 pb-4 border-b border-gray-200">
        <div className="w-9 h-9 rounded-lg bg-blue-100 flex items-center justify-center flex-shrink-0">
          <Icon className="w-4 h-4 text-blue-600" />
        </div>
        <div>
          <p className="text-sm font-semibold text-gray-900">{title}</p>
          <p className="text-xs text-gray-500 mt-0.5">{description}</p>
        </div>
      </div>
      <div className="space-y-1">
        {children}
      </div>
    </div>
  )
}

// ── Field Row ─────────────────────────────────────
function FieldRow({ label, hint, children }) {
  return (
    <div className="flex items-start justify-between py-3 border-b border-gray-200 last:border-0 hover:bg-gray-50 px-2 rounded-lg transition-colors">
      <div className="flex-1 mr-8">
        <p className="text-sm font-medium text-gray-900">{label}</p>
        {hint && <p className="text-xs text-gray-500 mt-0.5">{hint}</p>}
      </div>
      <div className="flex-shrink-0">{children}</div>
    </div>
  )
}

// ── Toggle Switch ─────────────────────────────────
function Toggle({ value, onChange }) {
  return (
    <button
      onClick={() => onChange(!value)}
      className={`relative w-11 h-6 rounded-full transition-colors ${
        value ? 'bg-blue-600' : 'bg-gray-200'
      }`}
    >
      <span className={`absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform ${
        value ? 'translate-x-5' : 'translate-x-0'
      }`} />
    </button>
  )
}

// ── Number Input ──────────────────────────────────
function NumberInput({ value, onChange, min = 0, suffix }) {
  return (
    <div className="flex items-center gap-2">
      <input
        type="number"
        min={min}
        value={value}
        onChange={e => onChange(Number(e.target.value))}
        className="w-20 text-sm border border-gray-200 rounded-lg px-3 py-1.5 bg-gray-50 text-gray-900 outline-none focus:border-blue-600 text-center"
      />
      {suffix && (
        <span className="text-xs text-gray-500">{suffix}</span>
      )}
    </div>
  )
}

// ── Main Page ─────────────────────────────────────
export default function AdminSettings() {
  const [loading, setLoading] = useState(true)
  const [saved, setSaved] = useState(false)
  const [settings, setSettings] = useState({
    grace_period_minutes: 10,
    overstay_rate_per_hour: 20,
    reservation_lock_minutes: 10,
    max_booking_days: 7,
    cash_enabled: true,
    easypaisa_enabled: true,
    card_enabled: true,
    refund_100_before_start: true,
    refund_percent: 50,
    refund_window_minutes: 30,
    notify_new_owner: true,
    notify_overstay: true,
    notify_payment_received: true,
    notify_manual_override: false,
    require_phone_otp: true,
    session_timeout_minutes: 60,
    max_login_attempts: 5,
    show_confidence_score: true,
    show_owner_revenue: true
  })

  useEffect(() => {
    fetchSettings()
  }, [])

  const fetchSettings = async () => {
    setLoading(true)
    try {
      const res = await api.get('/parking/admin/settings/')
      const data = res.data
      if (data) {
        setSettings({
          grace_period_minutes:     data.grace_period_minutes ?? 10,
          overstay_rate_per_hour:   Number(data.overstay_rate_per_hour) ?? 20,
          reservation_lock_minutes: data.reservation_lock_minutes ?? 10,
          max_booking_days:         data.max_booking_days ?? 7,
          cash_enabled:             data.cash_enabled ?? true,
          easypaisa_enabled:        data.easypaisa_enabled ?? true,
          card_enabled:             data.card_enabled ?? true,
          refund_100_before_start:  data.refund_100_before_start ?? true,
          refund_percent:           data.refund_percent ?? 50,
          refund_window_minutes:    data.refund_window_minutes ?? 30,
          notify_new_owner:         data.notify_new_owner ?? true,
          notify_overstay:          data.notify_overstay ?? true,
          notify_payment_received:  data.notify_payment_received ?? true,
          notify_manual_override:   data.notify_manual_override ?? false,
          require_phone_otp:        data.require_phone_otp ?? true,
          session_timeout_minutes:  data.session_timeout_minutes ?? 60,
          max_login_attempts:       data.max_login_attempts ?? 5,
          show_confidence_score:    data.show_confidence_score ?? true,
          show_owner_revenue:       data.show_owner_revenue ?? true,
        })
      }
    } catch (err) {
      console.error('Error fetching settings from API:', err)
    } finally {
      setLoading(false)
    }
  }

  const updateField = (key, val) => {
    setSettings(prev => ({
      ...prev,
      [key]: val
    }))
  }

  const handleSave = async () => {
    try {
      await api.put('/parking/admin/settings/', settings)
      setSaved(true)
      setTimeout(() => setSaved(false), 3000)
    } catch (err) {
      alert('Error saving settings: ' + err.message)
    }
  }

  const handleReset = async () => {
    if (!confirm('Are you sure you want to reset settings to default values?')) return
    const defaults = {
      grace_period_minutes: 10,
      overstay_rate_per_hour: 20,
      reservation_lock_minutes: 10,
      max_booking_days: 7,
      cash_enabled: true,
      easypaisa_enabled: true,
      card_enabled: true,
      refund_100_before_start: true,
      refund_percent: 50,
      refund_window_minutes: 30,
      notify_new_owner: true,
      notify_overstay: true,
      notify_payment_received: true,
      notify_manual_override: false,
      require_phone_otp: true,
      session_timeout_minutes: 60,
      max_login_attempts: 5,
      show_confidence_score: true,
      show_owner_revenue: true
    }
    try {
      await api.put('/parking/admin/settings/', defaults)
      setSettings(defaults)
      setSaved(true)
      setTimeout(() => setSaved(false), 3000)
    } catch (err) {
      alert('Error resetting settings: ' + err.message)
    }
  }

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[400px]">
        <div className="w-12 h-12 border-4 border-blue-600 border-t-transparent rounded-full animate-spin"></div>
        <p className="text-gray-500 mt-4 text-sm animate-pulse">Loading system settings...</p>
      </div>
    )
  }

  return (
    <div className="pb-12">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6 border-b border-gray-200 pb-5">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <Settings className="w-6 h-6 text-blue-600" />
            System Settings
          </h1>
          <p className="text-sm text-gray-500 mt-1">
            Configure system-wide parking rules, payment methods, notifications, and security policies.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={handleReset}
            className="flex items-center gap-2 text-sm px-4 py-2 border border-gray-200 rounded-lg text-gray-600 hover:bg-gray-50 transition-colors"
          >
            <RotateCcw className="w-4 h-4" />
            Reset Defaults
          </button>
          <button
            onClick={handleSave}
            className="flex items-center gap-2 text-sm px-4 py-2 bg-blue-600 text-white rounded-lg hover:opacity-90 transition-opacity font-medium shadow-sm"
          >
            <Save className="w-4 h-4" />
            Save Changes
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* 1. Parking & Booking Rules */}
        <SectionCard
          title="Parking & Booking Rules"
          description="Grace period, overstay rates, and booking thresholds"
          icon={Clock}
        >
          <FieldRow
            label="Grace Period"
            hint="Free minutes allowed before parking billing begins"
          >
            <NumberInput
              value={settings.grace_period_minutes}
              onChange={v => updateField('grace_period_minutes', v)}
              min={0}
              suffix="min"
            />
          </FieldRow>

          <FieldRow
            label="Overstay Rate"
            hint="System-wide extra rate charged per hour after duration exceeds"
          >
            <NumberInput
              value={settings.overstay_rate_per_hour}
              onChange={v => updateField('overstay_rate_per_hour', v)}
              min={0}
              suffix="Rs./hr"
            />
          </FieldRow>

          <FieldRow
            label="Reservation Lock Time"
            hint="Duration in minutes a booking is held before expiring if no arrival"
          >
            <NumberInput
              value={settings.reservation_lock_minutes}
              onChange={v => updateField('reservation_lock_minutes', v)}
              min={1}
              suffix="min"
            />
          </FieldRow>

          <FieldRow
            label="Maximum Booking Scope"
            hint="Maximum consecutive days a customer can reserve a parking slot"
          >
            <NumberInput
              value={settings.max_booking_days}
              onChange={v => updateField('max_booking_days', v)}
              min={1}
              suffix="days"
            />
          </FieldRow>
        </SectionCard>

        {/* 2. Payment & Refund Policy */}
        <SectionCard
          title="Payment & Refund Policy"
          description="Accepted billing options and customer refund rules"
          icon={CreditCard}
        >
          <FieldRow label="Enable Cash Payments" hint="Accept cash handling at cashier terminal exit gates">
            <Toggle
              value={settings.cash_enabled}
              onChange={v => updateField('cash_enabled', v)}
            />
          </FieldRow>

          <FieldRow label="Enable EasyPaisa" hint="Enable direct payments via EasyPaisa mobile integration">
            <Toggle
              value={settings.easypaisa_enabled}
              onChange={v => updateField('easypaisa_enabled', v)}
            />
          </FieldRow>

          <FieldRow label="Enable Card / Online Payments" hint="Allow online checkout with debit/credit cards">
            <Toggle
              value={settings.card_enabled}
              onChange={v => updateField('card_enabled', v)}
            />
          </FieldRow>

          <FieldRow label="Full Refund Before Arrival" hint="Allow 100% refund if booking is cancelled before start time">
            <Toggle
              value={settings.refund_100_before_start}
              onChange={v => updateField('refund_100_before_start', v)}
            />
          </FieldRow>

          <FieldRow label="Standard Refund Percentage" hint="Percent returned to user for late booking cancellations">
            <NumberInput
              value={settings.refund_percent}
              onChange={v => updateField('refund_percent', v)}
              min={0}
              suffix="%"
            />
          </FieldRow>

          <FieldRow label="Refund Cancel Window" hint="Minutes allowed before arrival time to receive any refund">
            <NumberInput
              value={settings.refund_window_minutes}
              onChange={v => updateField('refund_window_minutes', v)}
              min={5}
              suffix="min"
            />
          </FieldRow>
        </SectionCard>

        {/* 3. Notification Alerts */}
        <SectionCard
          title="Notification Alerts"
          description="Configure system alert triggers sent to administrator dashboard"
          icon={AlertTriangle}
        >
          <FieldRow label="New Owner Registrations" hint="Alert when a new parking owner registers an account">
            <Toggle
              value={settings.notify_new_owner}
              onChange={v => updateField('notify_new_owner', v)}
            />
          </FieldRow>

          <FieldRow label="Overstay Detections" hint="Notify when parked vehicles exceed reservation durations">
            <Toggle
              value={settings.notify_overstay}
              onChange={v => updateField('notify_overstay', v)}
            />
          </FieldRow>

          <FieldRow label="Successful Payments" hint="Notify when exit gate payments are completed successfully">
            <Toggle
              value={settings.notify_payment_received}
              onChange={v => updateField('notify_payment_received', v)}
            />
          </FieldRow>

          <FieldRow label="Manual Plate Override Alert" hint="Alert when cashiers bypass AI scanner detection manually">
            <Toggle
              value={settings.notify_manual_override}
              onChange={v => updateField('notify_manual_override', v)}
            />
          </FieldRow>
        </SectionCard>

        {/* 4. System Security */}
        <SectionCard
          title="System Security"
          description="Password settings, multi-factor, and timeouts"
          icon={Shield}
        >
          <FieldRow label="Require Phone OTP Verification" hint="Require phone number SMS OTP validation on signup">
            <Toggle
              value={settings.require_phone_otp}
              onChange={v => updateField('require_phone_otp', v)}
            />
          </FieldRow>

          <FieldRow label="Session Timeout Duration" hint="Auto logout inactive admin/owner dashboards after period">
            <NumberInput
              value={settings.session_timeout_minutes}
              onChange={v => updateField('session_timeout_minutes', v)}
              min={5}
              suffix="min"
            />
          </FieldRow>

          <FieldRow label="Max Login Failures" hint="Number of failed passcode attempts before locking accounts">
            <NumberInput
              value={settings.max_login_attempts}
              onChange={v => updateField('max_login_attempts', v)}
              min={3}
              suffix="tries"
            />
          </FieldRow>
        </SectionCard>

        {/* 5. Dashboard Display Options */}
        <SectionCard
          title="Dashboard Display Settings"
          description="Control public-facing dashboard visualizations"
          icon={Eye}
        >
          <FieldRow label="Show AI Confidence Score" hint="Display recognition percentage next to scanned plates">
            <Toggle
              value={settings.show_confidence_score}
              onChange={v => updateField('show_confidence_score', v)}
            />
          </FieldRow>

          <FieldRow label="Show Owner Revenue Stats" hint="Show estimated daily/monthly revenue metrics on dashboard">
            <Toggle
              value={settings.show_owner_revenue}
              onChange={v => updateField('show_owner_revenue', v)}
            />
          </FieldRow>
        </SectionCard>
      </div>

      {/* Save banner */}
      {saved && (
        <div className="fixed bottom-6 right-6 bg-blue-600 text-white text-sm px-5 py-3 rounded-xl shadow-lg font-medium animate-bounce z-50">
          ✓ System settings saved successfully!
        </div>
      )}
    </div>
  )
}