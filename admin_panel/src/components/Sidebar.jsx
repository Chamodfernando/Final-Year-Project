import React from 'react';
import { BarChart3, Users, MapPin, Box, LogOut, Sparkles } from 'lucide-react';
import { NavLink } from 'react-router-dom';
import { motion as Motion } from 'framer-motion';

const menuItems = [
  { icon: BarChart3, label: 'Analytics', path: '/' },
  { icon: Users, label: 'Users', path: '/users' },
  { icon: MapPin, label: 'Locations', path: '/locations' },
  { icon: Box, label: 'Artifacts', path: '/artifacts' },
];

const Sidebar = () => {
  return (
    <Motion.aside
      className="sidebar"
      initial={{ x: -24, opacity: 0 }}
      animate={{ x: 0, opacity: 1 }}
      transition={{ duration: 0.45, ease: [0.16, 1, 0.3, 1] }}
    >
      <div className="sidebar-glow" aria-hidden />
      <div className="sidebar-header">
        <Motion.div
          className="logo-row"
          initial={{ scale: 0.92, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ delay: 0.12, type: 'spring', stiffness: 260, damping: 20 }}
        >
          <Motion.span
            className="logo-mark"
            whileHover={{ scale: 1.06, rotate: [-2, 2, 0] }}
            transition={{ duration: 0.35 }}
          >
            <Sparkles size={22} strokeWidth={2.2} />
          </Motion.span>
          <div>
            <h2 className="logo-text">Ceylon Admin</h2>
            <p className="logo-tag">Enterprise console</p>
          </div>
        </Motion.div>
      </div>
      <nav className="sidebar-nav">
        {menuItems.map((item, index) => (
          <Motion.div
            key={item.path}
            initial={{ opacity: 0, x: -14 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.08 + index * 0.06, duration: 0.35, ease: [0.16, 1, 0.3, 1] }}
          >
            <NavLink to={item.path} end={item.path === '/'} className="nav-link-wrap">
              {({ isActive }) => (
                <span className={`nav-item ${isActive ? 'active' : ''}`}>
                  {isActive && (
                    <Motion.span
                      layoutId="sidebar-active-pill"
                      className="nav-active-pill"
                      transition={{ type: 'spring', stiffness: 400, damping: 34 }}
                    />
                  )}
                  <span className="nav-item-content">
                    <item.icon size={20} strokeWidth={isActive ? 2.25 : 2} />
                    <span>{item.label}</span>
                  </span>
                </span>
              )}
            </NavLink>
          </Motion.div>
        ))}
      </nav>
      <div className="sidebar-footer">
        <Motion.button
          type="button"
          className="nav-item logout-btn"
          whileHover={{ scale: 1.02, backgroundColor: 'rgba(254, 242, 242, 0.95)' }}
          whileTap={{ scale: 0.98 }}
        >
          <span className="nav-item-content">
            <LogOut size={20} />
            <span>Logout</span>
          </span>
        </Motion.button>
      </div>

      <style>{`
        .sidebar {
          width: 268px;
          height: 100vh;
          background: var(--sidebar-bg);
          backdrop-filter: blur(20px) saturate(1.4);
          -webkit-backdrop-filter: blur(20px) saturate(1.4);
          border-right: 1px solid var(--border);
          display: flex;
          flex-direction: column;
          position: fixed;
          left: 0;
          top: 0;
          z-index: 40;
          box-shadow: 4px 0 40px rgba(15, 23, 42, 0.06);
        }

        .sidebar-glow {
          position: absolute;
          top: 0;
          left: 0;
          right: 0;
          height: 160px;
          background: linear-gradient(180deg, rgba(13, 159, 92, 0.08) 0%, transparent 100%);
          pointer-events: none;
        }

        .sidebar-header {
          padding: 22px 20px 20px;
          border-bottom: 1px solid var(--border);
          position: relative;
        }

        .logo-row {
          display: flex;
          align-items: center;
          gap: 12px;
        }

        .logo-mark {
          width: 44px;
          height: 44px;
          border-radius: 12px;
          background: linear-gradient(135deg, var(--primary) 0%, var(--primary-dark) 100%);
          color: white;
          display: flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 8px 24px var(--primary-glow);
          cursor: default;
        }

        .logo-text {
          color: var(--text-main);
          font-size: 1.15rem;
          font-weight: 800;
          letter-spacing: -0.03em;
          font-family: var(--font-display, inherit);
          line-height: 1.2;
        }

        .logo-tag {
          font-size: 11px;
          color: var(--text-muted);
          font-weight: 600;
          text-transform: uppercase;
          letter-spacing: 0.08em;
          margin-top: 2px;
        }

        .sidebar-nav {
          flex: 1;
          padding: 14px 12px;
          display: flex;
          flex-direction: column;
          gap: 6px;
          position: relative;
        }

        .nav-link-wrap {
          text-decoration: none;
          display: block;
        }

        .nav-item {
          position: relative;
          display: flex;
          align-items: center;
          border-radius: 12px;
          font-weight: 600;
          font-size: 14px;
          color: var(--text-muted);
          overflow: hidden;
          transition: color 0.2s ease;
        }

        .nav-active-pill {
          position: absolute;
          inset: 0;
          border-radius: 12px;
          background: linear-gradient(135deg, rgba(13, 159, 92, 0.14) 0%, rgba(13, 159, 92, 0.06) 100%);
          border: 1px solid rgba(13, 159, 92, 0.22);
          box-shadow: 0 4px 16px rgba(13, 159, 92, 0.12);
        }

        .nav-item-content {
          position: relative;
          z-index: 1;
          display: flex;
          align-items: center;
          gap: 12px;
          padding: 12px 14px;
          width: 100%;
        }

        .nav-item:hover:not(.active) {
          color: var(--text-main);
        }

        .nav-item:hover:not(.active) .nav-item-content {
          background: rgba(241, 245, 249, 0.85);
          border-radius: 12px;
        }

        .nav-item.active {
          color: var(--primary-dark);
        }

        .sidebar-footer {
          padding: 14px 12px 20px;
          border-top: 1px solid var(--border);
        }

        .logout-btn {
          width: 100%;
          border: none;
          background: transparent;
          cursor: pointer;
          color: var(--danger);
          border-radius: 12px;
        }
      `}</style>
    </Motion.aside>
  );
};

export default Sidebar;
