import { BrowserRouter, Routes, Route, Navigate, Outlet } from 'react-router-dom'

// ── Admin pages ────────────────────────────────────────────────
import AdminDashboard from './pages/admin/AdminDashboard'
import OwnerAccounts from './pages/admin/OwnerAccounts'
import ParkingSites from './pages/admin/ParkingSites'
import AdminPayments from './pages/admin/Payments'
import Queries from './pages/admin/Queries'
import AdminReports from './pages/admin/Reports'
import AdminSettings from './pages/admin/Settings'

import SystemLogs from './pages/admin/SystemLogs'
import UserAccounts from './pages/admin/UserAccounts'
import AIModelMonitor from './pages/admin/AIModelMonitor'
import Refunds from './pages/admin/Refunds'
import PeakHourDashboard from './pages/admin/PeakHourDashboard'

// ── Layouts ────────────────────────────────────────────────────
import AdminLayout from './layouts/AdminLayout'
import CashierLayout from './layouts/CashierLayout'
import OwnerLayout from './layouts/OwnerLayout'

// ── Cashier pages ──────────────────────────────────────────────
import CashierDashboard from './pages/cashier/Dashboard'
import EntryGate from './pages/cashier/EntryGate'
import ExitGate from './pages/cashier/ExitGate'
import CashierBookings from './pages/cashier/Bookings'
import CashierPayments from './pages/cashier/Payments'
import CashierSlots from './pages/cashier/Slots'

// ── Owner pages ──────────────────────────────────────────────

import OwnerDashboard from './pages/owner/Dashboard'
import SiteManagement from './pages/owner/SiteManagement'
import SlotConfig from './pages/owner/SlotConfig'
import Cashiers from './pages/owner/Cashiers'
import Bookings from './pages/owner/Bookings'
import OwnerPayments from './pages/owner/Payments'
import OwnerReports from './pages/owner/Reports'
import Settings from './pages/owner/Settings'
import SiteDetail from './pages/owner/SiteDetail'

// ── Auth util ──────────────────────────────────────────────────
import { getToken, getUser, logout } from './utils/auth'
import { NotificationProvider } from './utils/NotificationContext'
import ToastContainer from './components/ToastContainer'
import Login from './pages/Login'

const LANDING_URL = 'http://127.0.0.1:8000/landing/index.html'

function RequireAuth({ allowedRoles, children }) {
  // Capture auth tokens from landing page redirect URL if present
  const urlParams = new URLSearchParams(window.location.search);
  const urlToken = urlParams.get('access_token');
  if (urlToken) {
    localStorage.setItem('access_token', urlToken);
    localStorage.setItem('refresh_token', urlParams.get('refresh_token') || '');
    localStorage.setItem('user_role', urlParams.get('user_role') || '');
    localStorage.setItem('user_name', urlParams.get('user_name') || '');
    localStorage.setItem('user_email', urlParams.get('user_email') || '');
    localStorage.setItem('site_id', urlParams.get('site_id') || '');
    localStorage.setItem('user_id', urlParams.get('user_id') || '');
    // Clean URL
    window.history.replaceState({}, document.title, window.location.pathname);
  }

  const token = getToken()
  const { role } = getUser()

  if (!token || !role) {
    return <Navigate to="/login" replace />
  }

  if (allowedRoles && !allowedRoles.includes(role)) {
    if (role === 'admin') return <Navigate to="/admin/dashboard" replace />
    if (role === 'entry_cashier') return <Navigate to="/cashier/entry" replace />
    if (role === 'exit_cashier') return <Navigate to="/cashier/exit" replace />
    if (role === 'parking_owner') return <Navigate to="/owner/dashboard" replace />
    return <Navigate to="/login" replace />
  }

  return children
}

function RootRedirect() {
  const token = getToken()
  const { role } = getUser()

  if (!token || !role) {
    return <Navigate to="/login" replace />
  }
  if (role === 'admin') return <Navigate to="/admin/dashboard" replace />
  if (role === 'entry_cashier') return <Navigate to="/cashier/entry" replace />
  if (role === 'exit_cashier') return <Navigate to="/cashier/exit" replace />
  if (role === 'parking_owner') return <Navigate to="/owner/dashboard" replace />
  return <Navigate to="/login" replace />
}

// Shorthand wrapper to keep route definitions clean
const CASHIER_ROLES = ['entry_cashier', 'exit_cashier']

function CashierRoute({ element }) {
  return (
    <RequireAuth allowedRoles={CASHIER_ROLES}>
      <CashierLayout>{element}</CashierLayout>
    </RequireAuth>
  )
}

function EntryCashierRoute({ element }) {
  return (
    <RequireAuth allowedRoles={['entry_cashier']}>
      <CashierLayout>{element}</CashierLayout>
    </RequireAuth>
  )
}

function ExitCashierRoute({ element }) {
  return (
    <RequireAuth allowedRoles={['exit_cashier']}>
      <CashierLayout>{element}</CashierLayout>
    </RequireAuth>
  )
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>

        {/* Root → smart redirect based on role */}
        <Route path="/" element={<RootRedirect />} />

        {/* ── Admin ── */}
        <Route element={
          <RequireAuth allowedRoles={['admin']}>
            <NotificationProvider>
              <AdminLayout />
              <ToastContainer />
            </NotificationProvider>
          </RequireAuth>
        }>
          <Route path="/admin/dashboard" element={<AdminDashboard />} />
          <Route path="/admin/dashboard/owner-accounts" element={<OwnerAccounts />} />
          <Route path="/admin/dashboard/parking-sites" element={<ParkingSites />} />
          <Route path="/admin/dashboard/payments" element={<AdminPayments />} />
          <Route path="/admin/dashboard/queries" element={<Queries />} />
          <Route path="/admin/dashboard/reports" element={<AdminReports />} />
          <Route path="/admin/dashboard/settings" element={<AdminSettings />} />
          <Route path="/admin/dashboard/system-logs" element={<SystemLogs />} />
          <Route path="/admin/dashboard/user-accounts" element={<UserAccounts />} />
          <Route path="/admin/dashboard/ai-monitor" element={<AIModelMonitor />} />
          <Route path="/admin/dashboard/refunds" element={<Refunds />} />
          <Route path="/admin/dashboard/peak-hours" element={<PeakHourDashboard />} />
        </Route>

        <Route path="/admin" element={<Navigate to="/admin/dashboard" replace />} />

        {/* ── Owner ── */}
        <Route
          path="/owner"
          element={
            <RequireAuth allowedRoles={['parking_owner', 'owner']}>
              <OwnerLayout />
            </RequireAuth>
          }
        >
          <Route index element={<Navigate to="/owner/dashboard" replace />} />
          <Route path="dashboard" element={<OwnerDashboard />} />
          <Route path="site" element={<SiteManagement />} />
          <Route path="site/:id" element={<SiteDetail />} />
          <Route path="slots" element={<SlotConfig />} />
          <Route path="cashiers" element={<Cashiers />} />
          <Route path="bookings" element={<Bookings />} />
          <Route path="payments" element={<OwnerPayments />} />
          <Route path="reports" element={<OwnerReports />} />
          <Route path="settings" element={<Settings />} />
        </Route>

        {/* ── Cashier ── */}
        <Route path="/cashier/entry" element={<EntryCashierRoute element={<EntryGate />} />} />
        <Route path="/cashier/exit" element={<ExitCashierRoute element={<ExitGate />} />} />
        <Route path="/cashier/dashboard" element={<CashierRoute element={<CashierDashboard />} />} />
        <Route path="/cashier/bookings" element={<CashierRoute element={<CashierBookings />} />} />
        <Route path="/cashier/payments" element={<CashierRoute element={<CashierPayments />} />} />
        <Route path="/cashier/slots" element={<CashierRoute element={<CashierSlots />} />} />

        {/* Catch-all */}
        <Route path="/login" element={<Login />} />
        <Route path="*" element={<RootRedirect />} />

      </Routes>
    </BrowserRouter>
  )
}