import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  Users,
  MapPin,
  Landmark,
  Timer,
  Download,
  Filter,
  Pencil,
  Shield,
  Plus,
  ChevronRight,
  Activity,
} from 'lucide-react';
import { Link } from 'react-router-dom';
import { motion as Motion } from 'framer-motion';
import { dbService } from '../services/dbService';

function toDate(val) {
  if (val == null) return null;
  if (typeof val?.toDate === 'function') {
    try {
      return val.toDate();
    } catch {
      return null;
    }
  }
  if (typeof val === 'string') {
    const d = new Date(val);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

function startOfDay(d) {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
}

function daysAgo(n, from = new Date()) {
  const d = new Date(from);
  d.setDate(d.getDate() - n);
  return d;
}

function formatCount(n) {
  if (n === null || n === undefined) return '—';
  return Number(n).toLocaleString();
}

function formatShortDuration(ms) {
  if (ms == null || ms < 0 || !Number.isFinite(ms)) return '—';
  const m = Math.floor(ms / 60000);
  const s = Math.floor((ms % 60000) / 1000);
  if (m >= 60) {
    const h = Math.floor(m / 60);
    return `${h}h ${String(m % 60).padStart(2, '0')}m`;
  }
  return `${m}m ${String(s).padStart(2, '0')}s`;
}

function pctChange(current, previous) {
  if (previous <= 0) return current > 0 ? 100 : 0;
  return ((current - previous) / previous) * 100;
}

function formatDelta(p) {
  if (!Number.isFinite(p)) return '0%';
  const sign = p >= 0 ? '+' : '';
  return `${sign}${p.toFixed(1)}%`;
}

function isLoggedInUser(u) {
  if (u == null) return false;
  if (u.isAnonymous === true || u.isAnonymous === 'true' || u.isAnonymous === 1) {
    return false;
  }
  return true;
}

function bucketLastSeenByDay(users, days, end = new Date()) {
  const labels = [];
  const counts = [];
  for (let i = days - 1; i >= 0; i--) {
    const day = startOfDay(daysAgo(i, end));
    labels.push(day);
    const next = new Date(day);
    next.setDate(next.getDate() + 1);
    let c = 0;
    for (const u of users) {
      const t = toDate(u.lastSeenAt);
      if (t && t >= day && t < next) c += 1;
    }
    counts.push(c);
  }
  return { labels, counts };
}

function bucketJoinedByDay(users, days, end = new Date()) {
  const labels = [];
  const counts = [];
  for (let i = days - 1; i >= 0; i--) {
    const day = startOfDay(daysAgo(i, end));
    labels.push(day);
    const next = new Date(day);
    next.setDate(next.getDate() + 1);
    let c = 0;
    for (const u of users) {
      const t = toDate(u.joined);
      if (t && t >= day && t < next) c += 1;
    }
    counts.push(c);
  }
  return { labels, counts };
}

function countInRange(docs, field, start, end) {
  let n = 0;
  for (const d of docs) {
    const t = toDate(d[field]);
    if (t && t >= start && t < end) n += 1;
  }
  return n;
}

function AreaChart({ seriesA, seriesB, labels, mode }) {
  const w = 520;
  const h = 180;
  const pad = 12;
  const max = Math.max(1, ...seriesA, ...seriesB);
  const n = labels.length;
  const step = (w - pad * 2) / Math.max(1, n - 1);

  const line = (arr) =>
    arr
      .map((v, i) => {
        const x = pad + i * step;
        const y = pad + (h - pad * 2) * (1 - v / max);
        return `${i === 0 ? 'M' : 'L'}${x},${y}`;
      })
      .join(' ');

  const dA = line(seriesA);
  const dB = line(seriesB);
  const fillA = `${dA} L ${pad + (n - 1) * step},${h - pad} L ${pad},${h - pad} Z`;
  const fillB = `${dB} L ${pad + (n - 1) * step},${h - pad} L ${pad},${h - pad} Z`;

  const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  return (
    <svg width="100%" height={h} viewBox={`0 0 ${w} ${h}`} className="area-chart" preserveAspectRatio="xMidYMid meet">
      <defs>
        <linearGradient id="gradA" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#0d9f5c" stopOpacity="0.35" />
          <stop offset="100%" stopColor="#0d9f5c" stopOpacity="0" />
        </linearGradient>
        <linearGradient id="gradB" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#6366f1" stopOpacity="0.28" />
          <stop offset="100%" stopColor="#6366f1" stopOpacity="0" />
        </linearGradient>
      </defs>
      {mode === 'visits' ? (
        <>
          <path d={fillA} fill="url(#gradA)" />
          <path d={dA} fill="none" stroke="#0d9f5c" strokeWidth="2.5" strokeLinecap="round" />
        </>
      ) : (
        <>
          <path d={fillB} fill="url(#gradB)" />
          <path d={dB} fill="none" stroke="#6366f1" strokeWidth="2.5" strokeLinecap="round" />
        </>
      )}
      {labels.map((dt, i) => (
        <text
          key={i}
          x={pad + i * step}
          y={h - 2}
          textAnchor="middle"
          className="area-chart-label"
          fontSize="10"
          fill="var(--text-muted)"
        >
          {dayNames[new Date(dt).getDay()]}
        </text>
      ))}
    </svg>
  );
}

function artifactStatus(art) {
  const hasImg = Boolean(art.imagePath);
  const hasModel = Boolean(art.modelPath || art.modelPathAr);
  if (hasImg && hasModel) return { label: 'Published', tone: 'pub' };
  if (hasImg || hasModel) return { label: 'In review', tone: 'review' };
  return { label: 'Draft', tone: 'draft' };
}

const container = {
  hidden: { opacity: 0 },
  show: { opacity: 1, transition: { staggerChildren: 0.06, delayChildren: 0.08 } },
};
const fadeUp = {
  hidden: { opacity: 0, y: 16 },
  show: { opacity: 1, y: 0, transition: { duration: 0.4, ease: [0.16, 1, 0.3, 1] } },
};

const Dashboard = () => {
  const [rangeDays, setRangeDays] = useState(30);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [users, setUsers] = useState([]);
  const [locations, setLocations] = useState([]);
  const [artifacts, setArtifacts] = useState([]);
  const [chartMode, setChartMode] = useState('visits');
  const [liveTick, setLiveTick] = useState(0);
  const [lastSyncAt, setLastSyncAt] = useState(null);
  const primedRef = useRef({ users: false, locations: false, artifacts: false });

  useEffect(() => {
    const id = setInterval(() => setLiveTick((t) => t + 1), 15000);
    return () => clearInterval(id);
  }, []);

  useEffect(() => {
    primedRef.current = { users: false, locations: false, artifacts: false };

    const tryDone = () => {
      const p = primedRef.current;
      if (p.users && p.locations && p.artifacts) {
        setLoading(false);
      }
    };

    const onErr = (e) => {
      console.error(e);
      setError(e?.message || 'Firestore listener error');
      setLoading(false);
    };

    const unsubUsers = dbService.subscribeCollectionDocs(
      'users',
      (rows) => {
        setUsers(rows);
        setLastSyncAt(new Date());
        primedRef.current.users = true;
        tryDone();
      },
      onErr
    );

    const unsubLocations = dbService.subscribeCollectionDocs(
      'locations',
      (rows) => {
        setLocations(rows);
        setLastSyncAt(new Date());
        primedRef.current.locations = true;
        tryDone();
      },
      onErr
    );

    const unsubArtifacts = dbService.subscribeCollectionDocs(
      'artifacts',
      (rows) => {
        setArtifacts(rows);
        setLastSyncAt(new Date());
        primedRef.current.artifacts = true;
        tryDone();
      },
      onErr
    );

    return () => {
      unsubUsers();
      unsubLocations();
      unsubArtifacts();
    };
  }, []);

  const windowBounds = useMemo(() => {
    void liveTick;
    const now = new Date();
    const windowEnd = now;
    const windowStart = daysAgo(rangeDays, now);
    const prevWindowEnd = windowStart;
    const prevWindowStart = daysAgo(rangeDays * 2, now);
    return { now, windowEnd, windowStart, prevWindowEnd, prevWindowStart };
  }, [rangeDays, liveTick]);

  const { now, windowEnd, windowStart, prevWindowEnd, prevWindowStart } = windowBounds;

  const chartDays = 7;
  const visitsSeries = useMemo(() => bucketLastSeenByDay(users, chartDays, windowEnd).counts, [users, windowEnd]);
  const loginsSeries = useMemo(() => bucketJoinedByDay(users, chartDays, windowEnd).counts, [users, windowEnd]);
  const chartLabels = useMemo(() => bucketLastSeenByDay(users, chartDays, windowEnd).labels, [users, windowEnd]);

  const kpis = useMemo(() => {
    const uCur = countInRange(users, 'joined', windowStart, windowEnd);
    const uPrev = countInRange(users, 'joined', prevWindowStart, prevWindowEnd);
    const locTotal = locations.length;
    const artCur = artifacts.filter((a) => {
      const t = toDate(a.createdAt) || toDate(a.updatedAt);
      return t && t >= windowStart && t < windowEnd;
    }).length;
    const artPrev = artifacts.filter((a) => {
      const t = toDate(a.createdAt) || toDate(a.updatedAt);
      return t && t >= prevWindowStart && t < prevWindowEnd;
    }).length;

    const loggedInUsers = users.filter(isLoggedInUser);
    const perUserSessionAvgs = [];
    for (const u of loggedInUsers) {
      const sessions = Number(u.foregroundSessionCount) || 0;
      const totalMs = Number(u.totalForegroundMs) || 0;
      if (sessions > 0 && totalMs > 0) {
        perUserSessionAvgs.push(totalMs / sessions);
      }
    }
    const avgSessionMs =
      perUserSessionAvgs.length > 0
        ? perUserSessionAvgs.reduce((a, b) => a + b, 0) / perUserSessionAvgs.length
        : null;

    return [
      {
        key: 'users',
        label: 'Total users',
        value: formatCount(users.length),
        delta: pctChange(uCur, uPrev),
        color: '#0d9f5c',
        icon: Users,
      },
      {
        key: 'locs',
        label: 'Active locations',
        value: formatCount(locTotal),
        delta: pctChange(
          countInRange(locations, 'updatedAt', windowStart, windowEnd),
          countInRange(locations, 'updatedAt', prevWindowStart, prevWindowEnd)
        ),
        color: '#0d9f5c',
        icon: MapPin,
      },
      {
        key: 'art',
        label: 'Artifacts cataloged',
        value: formatCount(artifacts.length),
        delta: pctChange(artCur, artPrev),
        color: '#0d9f5c',
        icon: Landmark,
      },
      {
        key: 'eng',
        label: 'Avg. screen time',
        value: avgSessionMs != null ? formatShortDuration(avgSessionMs) : '—',
        sub: 'Mean session length (signed-in users; app foreground until background)',
        color: '#0d9f5c',
        icon: Timer,
      },
    ];
  }, [users, locations, artifacts, windowStart, windowEnd, prevWindowStart, prevWindowEnd]);

  const locationLoad = useMemo(() => {
    const byLoc = new Map();
    for (const loc of locations) {
      byLoc.set(loc.id, { id: loc.id, title: loc.title || loc.city || 'Untitled', count: 0 });
    }
    for (const a of artifacts) {
      const id = a.locationId;
      if (id && byLoc.has(id)) {
        byLoc.get(id).count += 1;
      }
    }
    const rows = [...byLoc.values()]
      .sort((a, b) => b.count - a.count)
      .slice(0, 5);
    const max = Math.max(1, ...rows.map((r) => r.count));
    return rows.map((r) => ({ ...r, pct: Math.round((r.count / max) * 100) }));
  }, [locations, artifacts]);

  const recentArtifacts = useMemo(() => {
    return [...artifacts]
      .sort((a, b) => {
        const tb = toDate(b.updatedAt) || toDate(b.createdAt) || new Date(0);
        const ta = toDate(a.updatedAt) || toDate(a.createdAt) || new Date(0);
        return tb - ta;
      })
      .slice(0, 6);
  }, [artifacts]);

  const modelsCount = useMemo(
    () => artifacts.filter((a) => a.modelPath || a.modelPathAr).length,
    [artifacts]
  );

  const exportCsv = () => {
    const lines = [
      ['metric', 'value'].join(','),
      ['users', users.length].join(','),
      ['locations', locations.length].join(','),
      ['artifacts', artifacts.length].join(','),
      [],
      ['artifact', 'site', 'status', 'updated'].join(','),
      ...recentArtifacts.map((a) => {
        const st = artifactStatus(a);
        const t = toDate(a.updatedAt) || toDate(a.createdAt);
        return [JSON.stringify(a.title || ''), JSON.stringify(a.siteName || ''), st.label, t ? t.toISOString() : ''].join(
          ','
        );
      }),
    ];
    const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `ceylon-analytics-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  if (loading) {
    return (
      <div className="analytics analytics--loading">
        <p>Loading analytics…</p>
        <style>{`
          .analytics--loading { padding: 48px; color: var(--text-muted); font-weight: 600; }
        `}</style>
      </div>
    );
  }

  return (
    <div className="analytics">
      <Motion.div className="analytics-head" variants={container} initial="hidden" animate="show">
        <Motion.div variants={fadeUp} className="head-row">
          <div className="range-wrap">
            <span className="range-label">Reporting period</span>
            <div className="range-pills">
              {[7, 30].map((d) => (
                <button
                  key={d}
                  type="button"
                  className={`range-pill ${rangeDays === d ? 'on' : ''}`}
                  onClick={() => setRangeDays(d)}
                >
                  Last {d} days
                </button>
              ))}
            </div>
            <span className="range-dates muted">
              {startOfDay(daysAgo(rangeDays - 1, now)).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })} —{' '}
              {now.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' })}
            </span>
            <span className="live-pill" title="Firestore listeners on users, locations, and artifacts">
              <span className="live-dot" aria-hidden />
              Live updates
            </span>
          </div>
          <Motion.button
            type="button"
            className="btn-export"
            onClick={exportCsv}
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
          >
            <Download size={18} />
            Export report
          </Motion.button>
        </Motion.div>

        {error && (
          <div className="alert-error" role="alert">
            {error}
          </div>
        )}

        <Motion.div className="kpi-grid" variants={container} initial="hidden" animate="show">
          {kpis.map((k) => (
            <Motion.div key={k.key} className="card kpi-card" variants={fadeUp} whileHover={{ y: -3 }}>
              <div className="kpi-top">
                <span className="kpi-icon" style={{ color: k.color, background: `${k.color}18` }}>
                  <k.icon size={22} strokeWidth={2.1} />
                </span>
                {typeof k.delta === 'number' && Number.isFinite(k.delta) ? (
                  <span className={`kpi-delta ${k.delta >= 0 ? 'up' : 'down'}`}>{formatDelta(k.delta)}</span>
                ) : (
                  <span className="kpi-delta-spacer" aria-hidden />
                )}
              </div>
              <p className="kpi-label">{k.label}</p>
              <p className="kpi-value">{k.value}</p>
              {k.sub && <p className="kpi-sub muted">{k.sub}</p>}
            </Motion.div>
          ))}
        </Motion.div>
      </Motion.div>

      <Motion.div className="grid-2" variants={container} initial="hidden" animate="show">
        <Motion.div className="card chart-card" variants={fadeUp}>
          <div className="card-head">
            <h3>User activity</h3>
            <div className="toggle" role="tablist">
              <Motion.div
                className="toggle-glider"
                aria-hidden
                initial={false}
                animate={{ x: chartMode === 'visits' ? 0 : '100%' }}
                transition={{ type: 'spring', stiffness: 420, damping: 34 }}
              />
              <button
                type="button"
                role="tab"
                aria-selected={chartMode === 'visits'}
                className={chartMode === 'visits' ? 'on' : ''}
                onClick={() => setChartMode('visits')}
              >
                Last seen
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={chartMode === 'logins'}
                className={chartMode === 'logins' ? 'on' : ''}
                onClick={() => setChartMode('logins')}
              >
                New profiles
              </button>
            </div>
          </div>
          <p className="muted chart-caption">
            Daily counts from Firestore timestamps (last 7 days). Updates live when documents change.
          </p>
          <div className="chart-body">
            <AreaChart
              mode={chartMode}
              seriesA={visitsSeries}
              seriesB={loginsSeries}
              labels={chartLabels}
            />
          </div>
        </Motion.div>

        <Motion.div className="card loc-card" variants={fadeUp}>
          <div className="card-head">
            <h3>Location load</h3>
            <Activity size={18} className="muted" />
          </div>
          <p className="muted chart-caption">
            Artifacts linked per location (top sites). Updates live from Firestore.
          </p>
          <ul className="loc-list">
            {locationLoad.length === 0 ? (
              <li className="muted">No locations yet.</li>
            ) : (
              locationLoad.map((row) => (
                <li key={row.id}>
                  <div className="loc-row-top">
                    <span>{row.title}</span>
                    <span className="loc-pct">{row.pct}%</span>
                  </div>
                  <div className="bar-track">
                    <Motion.div
                      className="bar-fill"
                      initial={{ width: 0 }}
                      animate={{ width: `${row.pct}%` }}
                      transition={{ type: 'spring', stiffness: 120, damping: 20, delay: 0.05 }}
                    />
                  </div>
                </li>
              ))
            )}
          </ul>
          <Link to="/locations" className="link-metrics">
            View detailed metrics <ChevronRight size={16} />
          </Link>
        </Motion.div>
      </Motion.div>

      <Motion.div className="grid-2 bottom" variants={container} initial="hidden" animate="show">
        <Motion.div className="card table-card" variants={fadeUp}>
          <div className="card-head">
            <h3>Recent artifact additions</h3>
            <span className="icon-filter" aria-hidden>
              <Filter size={18} />
            </span>
          </div>
          <p className="muted chart-caption table-card-caption">Latest rows from the live artifacts listener.</p>
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Artifact</th>
                  <th>Category</th>
                  <th>Date</th>
                  <th>Status</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {recentArtifacts.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="muted">
                      No artifacts yet.
                    </td>
                  </tr>
                ) : (
                  recentArtifacts.map((a) => {
                    const st = artifactStatus(a);
                    const t = toDate(a.updatedAt) || toDate(a.createdAt);
                    return (
                      <tr key={a.id}>
                        <td>
                          <div className="artifact-cell">
                            <span className="thumb" />
                            <span>{a.title || 'Untitled'}</span>
                          </div>
                        </td>
                        <td>{a.timePeriod || a.material || '—'}</td>
                        <td className="mono-sm">{t ? t.toLocaleDateString() : '—'}</td>
                        <td>
                          <span className={`pill pill--${st.tone}`}>{st.label}</span>
                        </td>
                        <td>
                          <Link to="/artifacts" className="icon-edit" aria-label="Edit in Artifacts">
                            <Pencil size={16} />
                          </Link>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </Motion.div>

        <Motion.div className="card health-card" variants={fadeUp}>
          <div className="card-head">
            <h3>System health</h3>
          </div>
          <p className="muted chart-caption">
            Live snapshot from this browser (not Firebase billing). Counts reflect the same Firestore
            listeners as the rest of this page.
          </p>

          <div className="health-block">
            <div className="health-title">
              <span className="dot ok" /> Firestore
            </div>
            <div className="health-metrics">
              <span>Indexed collections</span>
              <span className="mono-sm">{users.length + locations.length + artifacts.length} docs loaded</span>
            </div>
            <div className="bar-track subtle">
              <Motion.div
                className="bar-fill soft"
                initial={{ width: 0 }}
                animate={{ width: `${Math.min(100, Math.round(((users.length + locations.length + artifacts.length) / 500) * 100))}%` }}
                transition={{ type: 'spring', stiffness: 100, damping: 22 }}
              />
            </div>
          </div>

          <div className="health-block">
            <div className="health-title">
              <span className="dot ok" /> Storage
            </div>
            <div className="health-metrics">
              <span>3D models tracked</span>
              <span className="mono-sm">
                {modelsCount} / {artifacts.length || 1} artifacts
              </span>
            </div>
            <div className="bar-track subtle">
              <Motion.div
                className="bar-fill soft indigo"
                initial={{ width: 0 }}
                animate={{
                  width: `${artifacts.length ? Math.round((modelsCount / artifacts.length) * 100) : 0}%`,
                }}
                transition={{ type: 'spring', stiffness: 100, damping: 22, delay: 0.08 }}
              />
            </div>
          </div>

          <div className="health-block">
            <div className="health-title">
              <span className="dot warn" /> Admin client
            </div>
            <div className="health-metrics">
              <span>UI session</span>
              <span className="mono-sm">Live</span>
            </div>
          </div>

          <div className="health-audit">
            <Shield size={16} />
            <span>
              Rules: verify Firestore access in Firebase Console.
              {lastSyncAt
                ? ` Last Firestore update: ${lastSyncAt.toLocaleTimeString()}.`
                : ''}{' '}
              Clock refresh every 15s for time-based metrics.
            </span>
          </div>

          <Link to="/locations" className="fab-add" title="Add location">
            <Motion.span whileHover={{ scale: 1.06 }} whileTap={{ scale: 0.94 }}>
              <Plus size={22} strokeWidth={2.5} />
            </Motion.span>
          </Link>
        </Motion.div>
      </Motion.div>

      <style>{`
        .analytics {
          max-width: 1400px;
          margin: 0 auto;
        }
        .analytics-head { margin-bottom: 22px; }
        .head-row {
          display: flex;
          flex-wrap: wrap;
          align-items: flex-end;
          justify-content: space-between;
          gap: 16px;
          margin-bottom: 22px;
        }
        .range-wrap { display: flex; flex-wrap: wrap; align-items: center; gap: 12px 18px; }
        .range-label {
          font-size: 11px;
          font-weight: 700;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          color: var(--text-muted);
          width: 100%;
        }
        .range-pills { display: flex; gap: 8px; }
        .range-pill {
          padding: 8px 14px;
          border-radius: 999px;
          border: 1px solid var(--border);
          background: rgba(255,255,255,0.7);
          font-size: 13px;
          font-weight: 600;
          color: var(--text-muted);
          cursor: pointer;
          transition: background 0.2s, border-color 0.2s, color 0.2s;
        }
        .range-pill.on {
          background: rgba(13, 159, 92, 0.12);
          border-color: rgba(13, 159, 92, 0.35);
          color: var(--primary-dark);
        }
        .range-dates { font-size: 13px; }
        .live-pill {
          display: inline-flex;
          align-items: center;
          gap: 8px;
          font-size: 12px;
          font-weight: 700;
          color: var(--primary-dark);
          background: rgba(13, 159, 92, 0.12);
          padding: 6px 12px;
          border-radius: 999px;
          border: 1px solid rgba(13, 159, 92, 0.22);
        }
        .live-dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
          background: var(--primary);
          box-shadow: 0 0 0 0 rgba(13, 159, 92, 0.45);
          animation: livePulse 1.6s ease-out infinite;
        }
        @keyframes livePulse {
          0% { box-shadow: 0 0 0 0 rgba(13, 159, 92, 0.45); }
          70% { box-shadow: 0 0 0 8px rgba(13, 159, 92, 0); }
          100% { box-shadow: 0 0 0 0 rgba(13, 159, 92, 0); }
        }
        .muted { color: var(--text-muted); }
        .btn-export {
          display: inline-flex;
          align-items: center;
          gap: 10px;
          padding: 11px 20px;
          border-radius: 12px;
          border: none;
          cursor: pointer;
          font-weight: 700;
          font-size: 14px;
          color: #fff;
          background: linear-gradient(135deg, #0b7a4a 0%, #0d9f5c 100%);
          box-shadow: 0 8px 24px rgba(13, 159, 92, 0.35);
        }
        .btn-export:hover { filter: brightness(1.05); }
        .alert-error {
          background: #fef2f2;
          color: #b91c1c;
          border: 1px solid #fecaca;
          padding: 12px 14px;
          border-radius: 12px;
          margin-bottom: 16px;
          font-size: 14px;
        }
        .kpi-grid {
          display: grid;
          grid-template-columns: repeat(4, minmax(0, 1fr));
          gap: 18px;
        }
        @media (max-width: 1100px) {
          .kpi-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        }
        @media (max-width: 640px) {
          .kpi-grid { grid-template-columns: 1fr; }
        }
        .kpi-card {
          padding: 20px 20px 16px;
          position: relative;
          overflow: hidden;
        }
        .kpi-top { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 10px; }
        .kpi-icon {
          width: 44px; height: 44px;
          border-radius: 12px;
          display: flex; align-items: center; justify-content: center;
        }
        .kpi-delta-spacer {
          min-width: 56px;
          height: 24px;
        }
        .kpi-delta {
          font-size: 12px;
          font-weight: 800;
          padding: 4px 8px;
          border-radius: 999px;
        }
        .kpi-delta.up { background: rgba(13, 159, 92, 0.12); color: #0b7a4a; }
        .kpi-delta.down { background: rgba(239, 68, 68, 0.1); color: #b91c1c; }
        .kpi-label {
          font-size: 11px;
          font-weight: 700;
          text-transform: uppercase;
          letter-spacing: 0.06em;
          color: var(--text-muted);
          margin: 0 0 6px;
        }
        .kpi-value {
          font-size: 1.65rem;
          font-weight: 800;
          letter-spacing: -0.03em;
          margin: 0 0 4px;
          font-family: var(--font-display, inherit);
          color: var(--text-main);
        }
        .kpi-sub { font-size: 11px; margin: 0; line-height: 1.35; }

        .grid-2 {
          display: grid;
          grid-template-columns: 1.35fr 0.85fr;
          gap: 20px;
          margin-top: 22px;
        }
        .grid-2.bottom { margin-top: 20px; }
        @media (max-width: 1024px) {
          .grid-2 { grid-template-columns: 1fr; }
        }
        .card-head {
          display: flex;
          align-items: center;
          justify-content: space-between;
          margin-bottom: 8px;
        }
        .card-head h3 {
          margin: 0;
          font-size: 1rem;
          font-weight: 800;
          letter-spacing: -0.02em;
        }
        .chart-caption { font-size: 12px; margin: 0 0 12px; }
        .chart-card { padding: 20px 22px 18px; }
        .chart-body { min-height: 180px; }
        .area-chart { width: 100%; display: block; }
        .area-chart-label { font-family: var(--font-sans, inherit); }

        .toggle {
          position: relative;
          display: flex;
          background: rgba(241, 245, 249, 0.9);
          border-radius: 10px;
          padding: 4px;
        }
        .toggle button {
          position: relative;
          z-index: 1;
          flex: 1;
          border: none;
          background: transparent;
          padding: 8px 14px;
          font-size: 12px;
          font-weight: 700;
          color: var(--text-muted);
          cursor: pointer;
          border-radius: 8px;
          transition: color 0.2s;
        }
        .toggle button.on { color: var(--primary-dark); }
        .toggle-glider {
          position: absolute;
          left: 4px;
          top: 4px;
          bottom: 4px;
          width: calc(50% - 4px);
          background: #fff;
          border-radius: 8px;
          box-shadow: 0 2px 8px rgba(15, 23, 42, 0.08);
          pointer-events: none;
          z-index: 0;
        }

        .loc-card { padding: 20px 22px 18px; position: relative; }
        .loc-list { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 14px; }
        .loc-row-top { display: flex; justify-content: space-between; font-size: 13px; font-weight: 600; margin-bottom: 6px; }
        .loc-pct { color: var(--text-muted); font-variant-numeric: tabular-nums; }
        .bar-track {
          height: 8px;
          border-radius: 999px;
          background: rgba(15, 23, 42, 0.06);
          overflow: hidden;
        }
        .bar-track.subtle { height: 6px; }
        .bar-fill {
          height: 100%;
          border-radius: 999px;
          background: linear-gradient(90deg, #0b7a4a, #0d9f5c);
        }
        .bar-fill.soft { background: linear-gradient(90deg, #0d9f5caa, #0d9f5c); }
        .bar-fill.indigo { background: linear-gradient(90deg, #6366f1aa, #6366f1); }
        .link-metrics {
          display: inline-flex;
          align-items: center;
          gap: 4px;
          margin-top: 16px;
          font-size: 13px;
          font-weight: 700;
          color: var(--primary-dark);
          text-decoration: none;
        }
        .link-metrics:hover { text-decoration: underline; }

        .table-card { padding: 0; overflow: hidden; }
        .table-card .card-head { padding: 18px 20px 0; }
        .table-card-caption { padding: 0 20px 10px; margin: 0; font-size: 12px; }
        .icon-filter { color: var(--text-muted); }
        .table-scroll { overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; font-size: 13px; }
        th {
          text-align: left;
          padding: 10px 20px;
          font-size: 11px;
          text-transform: uppercase;
          letter-spacing: 0.06em;
          color: var(--text-muted);
          border-bottom: 1px solid var(--border);
          background: rgba(248, 250, 252, 0.9);
        }
        td { padding: 14px 20px; border-bottom: 1px solid var(--border); vertical-align: middle; }
        tr:hover td { background: rgba(13, 159, 92, 0.04); }
        .artifact-cell { display: flex; align-items: center; gap: 10px; font-weight: 600; }
        .thumb {
          width: 32px; height: 32px;
          border-radius: 8px;
          background: linear-gradient(135deg, #e2e8f0, #f1f5f9);
          flex-shrink: 0;
        }
        .mono-sm { font-variant-numeric: tabular-nums; font-size: 12px; color: var(--text-muted); }
        .pill {
          display: inline-block;
          padding: 4px 10px;
          border-radius: 999px;
          font-size: 11px;
          font-weight: 700;
        }
        .pill--pub { background: rgba(13, 159, 92, 0.14); color: #0b7a4a; }
        .pill--review { background: rgba(245, 158, 11, 0.18); color: #b45309; }
        .pill--draft { background: rgba(148, 163, 184, 0.25); color: #475569; }
        .icon-edit {
          display: flex;
          color: var(--text-muted);
          padding: 6px;
          border-radius: 8px;
        }
        .icon-edit:hover { background: rgba(241, 245, 249, 0.95); color: var(--text-main); }

        .health-card { padding: 20px 22px 22px; position: relative; }
        .health-block { margin-bottom: 18px; }
        .health-title { display: flex; align-items: center; gap: 8px; font-weight: 700; font-size: 13px; margin-bottom: 8px; }
        .dot { width: 8px; height: 8px; border-radius: 50%; }
        .dot.ok { background: #0d9f5c; box-shadow: 0 0 0 3px rgba(13, 159, 92, 0.25); }
        .dot.warn { background: #f59e0b; box-shadow: 0 0 0 3px rgba(245, 158, 11, 0.25); }
        .health-metrics {
          display: flex;
          justify-content: space-between;
          font-size: 12px;
          color: var(--text-muted);
          margin-bottom: 8px;
        }
        .health-audit {
          display: flex;
          align-items: flex-start;
          gap: 10px;
          margin-top: 8px;
          padding: 12px 14px;
          border-radius: 12px;
          background: rgba(241, 245, 249, 0.85);
          font-size: 12px;
          color: var(--text-muted);
          line-height: 1.45;
        }
        .health-audit svg { flex-shrink: 0; margin-top: 2px; color: var(--primary); }
        .fab-add {
          position: absolute;
          right: 18px;
          bottom: 18px;
          width: 48px;
          height: 48px;
          border-radius: 50%;
          background: linear-gradient(135deg, #0b7a4a 0%, #0d9f5c 100%);
          color: #fff;
          display: flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 10px 28px rgba(13, 159, 92, 0.4);
          text-decoration: none;
        }
        .fab-add:hover { filter: brightness(1.06); }
      `}</style>
    </div>
  );
};

export default Dashboard;
