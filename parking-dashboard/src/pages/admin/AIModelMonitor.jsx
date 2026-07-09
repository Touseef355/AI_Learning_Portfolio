import { useState, useEffect } from 'react'
import {
  Bot, Search, Download, AlertTriangle,
  CheckCircle, XCircle, RefreshCw, Camera,
  ScanLine, TrendingUp, TrendingDown
} from 'lucide-react'
import api from '../../api/axios'

function pct(success, total) {
  if (!total) return '—'
  return ((success / total) * 100).toFixed(1) + '%'
}

function accColor(val) {
  const n = parseFloat(val)
  if (isNaN(n)) return 'text-gray-400'
  if (n >= 90) return 'text-green-600'
  if (n >= 75) return 'text-yellow-600'
  return 'text-red-600'
}

function accBar(val) {
  const n = parseFloat(val)
  if (isNaN(n)) return 'bg-gray-200'
  if (n >= 90) return 'bg-green-500'
  if (n >= 75) return 'bg-yellow-400'
  return 'bg-red-500'
}

export default function AIModelMonitor() {
  const [logs,       setLogs]       = useState([])
  const [siteStats,  setSiteStats]  = useState([])
  const [sites,      setSites]      = useState([])
  const [loading,    setLoading]    = useState(true)
  const [search,     setSearch]     = useState('')
  const [filterSite, setFilterSite] = useState('All Sites')
  const [filterStatus, setFilterStatus] = useState('all')

  const fetchData = async () => {
    setLoading(true)
    try {
      const [logsRes, sitesRes] = await Promise.all([
        api.get('/ai/admin/logs/'),
        api.get('/parking/sites/')
      ])

      const aiLogs = logsRes.data || []
      const sitesData = sitesRes.data || []

      setSites(sitesData)

      if (aiLogs && aiLogs.length > 0) {
        setLogs(aiLogs.map(l => ({
          id:         l.id,
          time:       l.time || l.created_at,
          site:       l.site || '—',
          plate:      l.plate || '???',
          model:      (l.model || 'LPD').toUpperCase(),
          confidence: Math.round((l.confidence || 0) * (l.confidence <= 1 ? 100 : 1)),
          status:     (l.status || '').toLowerCase() === 'success' || l.status === 'approved' ? 'success' : 'failed',
          note:       l.note || '',
        })))

        const statsMap = {}
        aiLogs.forEach(l => {
          const sName = l.site || 'Unknown'
          if (!statsMap[sName]) statsMap[sName] = { site: sName, lpd_total: 0, lpd_success: 0, ocr_total: 0, ocr_success: 0, manual: 0 }
          const model = (l.model || 'LPD').toUpperCase()
          const ok = (l.status || '').toLowerCase() === 'success' || l.status === 'approved'
          if (model === 'LPD') {
            statsMap[sName].lpd_total++
            if (ok) statsMap[sName].lpd_success++
          } else if (model === 'OCR') {
            statsMap[sName].ocr_total++
            if (ok) statsMap[sName].ocr_success++
          }
          if (l.method && l.method.toLowerCase() === 'manual') statsMap[sName].manual++
        })
        setSiteStats(Object.values(statsMap))
      } else {
        setLogs([])
        setSiteStats(sitesData.map(s => ({
          site: s.name, lpd_total: 0, lpd_success: 0, ocr_total: 0, ocr_success: 0, manual: 0
        })))
      }
    } catch (err) {
      console.error('AI Monitor fetch error:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchData()
  }, [])

  const allSites = ['All Sites', ...sites.map(s => s.name)]

  // Global stats
  const totalLPD       = siteStats.reduce((s, x) => s + x.lpd_total, 0)
  const successLPD     = siteStats.reduce((s, x) => s + x.lpd_success, 0)
  const totalOCR       = siteStats.reduce((s, x) => s + x.ocr_total, 0)
  const successOCR     = siteStats.reduce((s, x) => s + x.ocr_success, 0)
  const totalManual    = siteStats.reduce((s, x) => s + x.manual, 0)
  const totalDetect    = totalLPD + totalOCR
  const totalSuccess   = successLPD + successOCR
  const globalAcc      = pct(totalSuccess, totalDetect)

  // 7-day trend from logs (last 7 days LPD accuracy per day)
  const DAYS = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
  const weeklyLPD = DAYS.map((_, i) => {
    const target = new Date()
    target.setDate(target.getDate() - (6 - i))
    const dayLogs = logs.filter(l => {
      const d = new Date(l.time)
      return d.getDate() === target.getDate() && d.getMonth() === target.getMonth() && l.model === 'LPD'
    })
    if (dayLogs.length === 0) return 0
    return Math.round((dayLogs.filter(l => l.status === 'success').length / dayLogs.length) * 100)
  })
  const weeklyOCR = DAYS.map((_, i) => {
    const target = new Date()
    target.setDate(target.getDate() - (6 - i))
    const dayLogs = logs.filter(l => {
      const d = new Date(l.time)
      return d.getDate() === target.getDate() && d.getMonth() === target.getMonth() && l.model === 'OCR'
    })
    if (dayLogs.length === 0) return 0
    return Math.round((dayLogs.filter(l => l.status === 'success').length / dayLogs.length) * 100)
  })
  const maxBar = Math.max(...weeklyLPD, ...weeklyOCR, 1)

  // Filter
  const filtered = logs.filter(l => {
    const matchSearch =
      (l.plate || '').toLowerCase().includes(search.toLowerCase()) ||
      (l.site  || '').toLowerCase().includes(search.toLowerCase()) ||
      (l.note  || '').toLowerCase().includes(search.toLowerCase())
    const matchSite   = filterSite === 'All Sites' || l.site === filterSite
    const matchStatus = filterStatus === 'all' || l.status === filterStatus
    return matchSearch && matchSite && matchStatus
  })

  const exportCSV = () => {
    const headers = ['Time','Site','Plate','Model','Confidence','Status','Note']
    const rows = filtered.map(l => [
      new Date(l.time).toLocaleString(),
      l.site, l.plate, l.model,
      `${l.confidence}%`, l.status, l.note
    ])
    const csv  = [headers, ...rows].map(r => r.map(v => `"${String(v).replace(/"/g,'""')}"`).join(',')).join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const a = document.createElement('a'); a.href = URL.createObjectURL(blob)
    a.download = `ai_logs_${Date.now()}.csv`; a.click()
  }

  return (
    <div className="p-6 space-y-6 bg-gray-50 min-h-screen">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">AI Model Monitor</h1>
          <p className="text-gray-500 mt-1 text-sm">YOLOv8 LPD & EasyOCR accuracy tracking across all sites.</p>
        </div>
        <div className="flex gap-3">
          <button onClick={fetchData} className="flex items-center gap-2 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg text-sm hover:bg-gray-50 transition-colors">
            <RefreshCw className="w-4 h-4" /> Refresh
          </button>
          <button onClick={exportCSV} className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors">
            <Download className="w-4 h-4" /> Export CSV
          </button>
        </div>
      </div>

      {/* Global KPI cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[
          { label: 'Global Accuracy', val: globalAcc,          icon: Bot,        iconBg: 'bg-blue-100',   iconColor: 'text-blue-600'   },
          { label: 'LPD Accuracy',   val: pct(successLPD,totalLPD), icon: Camera,iconBg: 'bg-violet-100', iconColor: 'text-violet-600' },
          { label: 'OCR Accuracy',   val: pct(successOCR,totalOCR), icon: ScanLine,iconBg:'bg-green-100', iconColor: 'text-green-600'  },
          { label: 'Manual Overrides',val: totalManual,         icon: AlertTriangle,iconBg:'bg-orange-100',iconColor:'text-orange-600' },
        ].map(s => {
          const IconComp = s.icon
          return (
            <div key={s.label} className="bg-white rounded-xl p-6 border border-gray-200">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-500">{s.label}</p>
                  <p className={`text-2xl font-bold mt-1 ${s.label.includes('Accuracy') ? accColor(s.val) : 'text-gray-900'}`}>
                    {loading ? '...' : s.val}
                  </p>
                </div>
                <div className={`p-3 rounded-lg ${s.iconBg}`}>
                  <IconComp className={`w-5 h-5 ${s.iconColor}`} />
                </div>
              </div>
            </div>
          )
        })}
      </div>

      {/* 7-day trend chart */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="text-lg font-semibold text-gray-900">7-Day Accuracy Trend</h3>
            <p className="text-sm text-gray-500 mt-0.5">LPD (blue) vs OCR (green) daily accuracy %</p>
          </div>
          <TrendingUp className="w-5 h-5 text-gray-400" />
        </div>
        <div className="flex items-end gap-3 h-28 mb-2">
          {DAYS.map((day, i) => (
            <div key={day} className="flex-1 flex flex-col gap-1 items-center">
              <div className="w-full flex gap-1 items-end h-24">
                <div className="flex-1 group relative">
                  <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-gray-900 text-white text-[10px] px-1.5 py-0.5 rounded opacity-0 group-hover:opacity-100 whitespace-nowrap pointer-events-none z-10">
                    LPD: {weeklyLPD[i]}%
                  </div>
                  <div
                    className="w-full bg-blue-500 hover:bg-blue-600 rounded-t transition-colors"
                    style={{ height: `${maxBar > 0 ? (weeklyLPD[i] / maxBar) * 96 : 0}%`, minHeight: weeklyLPD[i] > 0 ? '4px' : '0' }}
                  />
                </div>
                <div className="flex-1 group relative">
                  <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-gray-900 text-white text-[10px] px-1.5 py-0.5 rounded opacity-0 group-hover:opacity-100 whitespace-nowrap pointer-events-none z-10">
                    OCR: {weeklyOCR[i]}%
                  </div>
                  <div
                    className="w-full bg-green-500 hover:bg-green-600 rounded-t transition-colors"
                    style={{ height: `${maxBar > 0 ? (weeklyOCR[i] / maxBar) * 96 : 0}%`, minHeight: weeklyOCR[i] > 0 ? '4px' : '0' }}
                  />
                </div>
              </div>
              <p className="text-[10px] text-gray-400">{day}</p>
            </div>
          ))}
        </div>
        <div className="flex gap-4 text-xs text-gray-500">
          <span className="flex items-center gap-1.5"><span className="w-3 h-3 rounded bg-blue-500 inline-block" />LPD (YOLOv8)</span>
          <span className="flex items-center gap-1.5"><span className="w-3 h-3 rounded bg-green-500 inline-block" />OCR (EasyOCR)</span>
        </div>
      </div>

      {/* Per-Site Stats */}
      <div className="bg-white rounded-xl border border-gray-200">
        <div className="p-6 border-b border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900">Per-Site Breakdown</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Site</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">LPD Total</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">LPD Acc.</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">OCR Total</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">OCR Acc.</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Manual</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {loading ? (
                <tr><td colSpan={6} className="text-center py-10"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600 mx-auto" /></td></tr>
              ) : siteStats.length === 0 ? (
                <tr><td colSpan={6} className="text-center py-10 text-gray-400 text-sm">No AI log data yet.</td></tr>
              ) : siteStats.map((s, i) => {
                const lpdAcc = pct(s.lpd_success, s.lpd_total)
                const ocrAcc = pct(s.ocr_success, s.ocr_total)
                return (
                  <tr key={i} className="hover:bg-gray-50 transition-colors">
                    <td className="px-6 py-4 text-sm font-medium text-gray-900">{s.site}</td>
                    <td className="px-6 py-4 text-sm text-gray-600">{s.lpd_total}</td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        <div className="w-16 bg-gray-100 rounded-full h-1.5">
                          <div className={`${accBar(lpdAcc)} h-1.5 rounded-full`} style={{ width: lpdAcc !== '—' ? lpdAcc : '0%' }} />
                        </div>
                        <span className={`text-sm font-semibold ${accColor(lpdAcc)}`}>{lpdAcc}</span>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-sm text-gray-600">{s.ocr_total}</td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-2">
                        <div className="w-16 bg-gray-100 rounded-full h-1.5">
                          <div className={`${accBar(ocrAcc)} h-1.5 rounded-full`} style={{ width: ocrAcc !== '—' ? ocrAcc : '0%' }} />
                        </div>
                        <span className={`text-sm font-semibold ${accColor(ocrAcc)}`}>{ocrAcc}</span>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <span className={`text-sm font-semibold ${s.manual > 5 ? 'text-orange-600' : 'text-gray-700'}`}>{s.manual}</span>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Detection Log */}
      <div className="bg-white rounded-xl border border-gray-200">
        <div className="p-6 border-b border-gray-200 flex flex-wrap items-center gap-3">
          <div className="flex-1">
            <h3 className="text-lg font-semibold text-gray-900">Detection Log</h3>
            <p className="text-sm text-gray-500 mt-0.5">Recent AI detection events</p>
          </div>
          <div className="flex gap-2">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search plate or site..."
                value={search}
                onChange={e => setSearch(e.target.value)}
                className="pl-9 pr-4 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 w-48"
              />
            </div>
            <select
              value={filterSite}
              onChange={e => setFilterSite(e.target.value)}
              className="text-sm border border-gray-300 rounded-lg px-3 py-2 text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              {allSites.map(s => <option key={s}>{s}</option>)}
            </select>
            {['all','success','failed'].map(s => (
              <button
                key={s}
                onClick={() => setFilterStatus(s)}
                className={`text-xs px-3 py-2 rounded-lg font-medium transition-colors capitalize ${
                  filterStatus === s ? 'bg-blue-600 text-white' : 'border border-gray-300 text-gray-600 hover:bg-gray-50'
                }`}
              >
                {s}
              </button>
            ))}
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Time</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Site</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Plate</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Model</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Confidence</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Status</th>
                <th className="text-left text-xs font-medium text-gray-500 uppercase px-6 py-3">Note</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {loading ? (
                <tr><td colSpan={7} className="text-center py-10"><div className="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600 mx-auto" /></td></tr>
              ) : filtered.length === 0 ? (
                <tr><td colSpan={7} className="text-center py-10 text-gray-400 text-sm">No detection events found.</td></tr>
              ) : filtered.slice(0, 50).map((l, i) => (
                <tr key={`${l.id}-${i}`} className="hover:bg-gray-50 transition-colors">
                  <td className="px-6 py-3 text-xs text-gray-400 whitespace-nowrap">
                    {l.time ? new Date(l.time).toLocaleString('en-GB', { day:'2-digit', month:'short', hour:'2-digit', minute:'2-digit' }) : '—'}
                  </td>
                  <td className="px-6 py-3 text-sm text-gray-600">{l.site}</td>
                  <td className="px-6 py-3 text-sm font-mono font-semibold text-gray-900">{l.plate}</td>
                  <td className="px-6 py-3">
                    <span className={`text-xs px-2 py-1 rounded-full font-medium ${
                      l.model === 'LPD' ? 'bg-blue-100 text-blue-700' : 'bg-green-100 text-green-700'
                    }`}>{l.model}</span>
                  </td>
                  <td className="px-6 py-3">
                    <div className="flex items-center gap-2">
                      <div className="w-12 bg-gray-100 rounded-full h-1.5">
                        <div
                          className={`${l.confidence >= 90 ? 'bg-green-500' : l.confidence >= 70 ? 'bg-yellow-400' : 'bg-red-500'} h-1.5 rounded-full`}
                          style={{ width: `${l.confidence}%` }}
                        />
                      </div>
                      <span className={`text-sm font-semibold ${l.confidence >= 90 ? 'text-green-700' : l.confidence >= 70 ? 'text-yellow-700' : 'text-red-700'}`}>
                        {l.confidence}%
                      </span>
                    </div>
                  </td>
                  <td className="px-6 py-3">
                    {l.status === 'success'
                      ? <span className="flex items-center gap-1 text-xs text-green-700"><CheckCircle className="w-3.5 h-3.5" /> Success</span>
                      : <span className="flex items-center gap-1 text-xs text-red-700"><XCircle className="w-3.5 h-3.5" /> Failed</span>
                    }
                  </td>
                  <td className="px-6 py-3 text-xs text-gray-500 max-w-xs truncate">{l.note || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!loading && filtered.length > 0 && (
          <div className="px-6 py-3 border-t border-gray-100">
            <p className="text-xs text-gray-400">Showing {Math.min(50, filtered.length)} of {filtered.length} events</p>
          </div>
        )}
      </div>
    </div>
  )
}