import React from 'react';
import { Bell, Search, User, ChevronRight } from 'lucide-react';
import { motion as Motion } from 'framer-motion';

const Navbar = ({ title, breadcrumb = [], userName = 'Admin User', userRole = 'Super administrator' }) => {
  return (
    <Motion.header
      className="navbar"
      initial={{ y: -12, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.4, ease: [0.16, 1, 0.3, 1] }}
    >
      <div className="navbar-left">
        {breadcrumb.length > 0 && (
          <nav className="breadcrumb" aria-label="Breadcrumb">
            {breadcrumb.map((crumb, i) => (
              <React.Fragment key={i}>
                {i > 0 && (
                  <ChevronRight size={14} className="bc-sep" aria-hidden />
                )}
                <span className={i === breadcrumb.length - 1 ? 'bc-current' : 'bc-link'}>{crumb}</span>
              </React.Fragment>
            ))}
          </nav>
        )}
        <Motion.h1
          className="page-title"
          key={title}
          initial={{ opacity: 0, x: -8 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ duration: 0.3, ease: [0.16, 1, 0.3, 1] }}
        >
          {title}
        </Motion.h1>
      </div>

      <div className="navbar-center">
        <label className="search-box">
          <Search size={18} className="search-icon" aria-hidden />
          <Motion.input
            type="search"
            placeholder="Search console…"
            className="search-input"
            whileFocus={{ scale: 1.01 }}
            transition={{ type: 'spring', stiffness: 400, damping: 28 }}
          />
        </label>
      </div>

      <div className="navbar-right">
        <Motion.button
          type="button"
          className="icon-btn"
          whileHover={{ scale: 1.08, backgroundColor: 'rgba(241, 245, 249, 0.95)' }}
          whileTap={{ scale: 0.94 }}
        >
          <Bell size={20} />
        </Motion.button>

        <Motion.div
          className="user-profile"
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
        >
          <div className="user-text">
            <span className="username">{userName}</span>
            <span className="user-role">{userRole}</span>
          </div>
          <Motion.div
            className="avatar"
            animate={{
              boxShadow: [
                '0 0 0 0 rgba(13, 159, 92, 0.35)',
                '0 0 0 8px rgba(13, 159, 92, 0)',
              ],
            }}
            transition={{ duration: 2.2, repeat: Infinity, repeatDelay: 1 }}
          >
            <User size={20} />
          </Motion.div>
        </Motion.div>
      </div>

      <style>{`
        .navbar {
          height: auto;
          min-height: 72px;
          background: rgba(255, 255, 255, 0.78);
          backdrop-filter: blur(16px) saturate(1.3);
          -webkit-backdrop-filter: blur(16px) saturate(1.3);
          border-bottom: 1px solid var(--border);
          padding: 14px 28px 14px 32px;
          display: grid;
          grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
          align-items: center;
          gap: 20px;
          position: sticky;
          top: 0;
          z-index: 30;
        }

        .navbar-left {
          min-width: 0;
        }

        .breadcrumb {
          display: flex;
          align-items: center;
          flex-wrap: wrap;
          gap: 4px;
          font-size: 12px;
          font-weight: 600;
          color: var(--text-muted);
          margin-bottom: 4px;
        }
        .bc-sep { color: var(--border); flex-shrink: 0; }
        .bc-current { color: var(--primary-dark); }
        .bc-link { color: var(--text-muted); }

        .page-title {
          font-size: 1.35rem;
          font-weight: 800;
          color: var(--text-main);
          font-family: var(--font-display, inherit);
          letter-spacing: -0.03em;
          margin: 0;
          line-height: 1.2;
        }

        .navbar-center {
          justify-self: center;
        }

        .navbar-right {
          display: flex;
          align-items: center;
          justify-content: flex-end;
          gap: 14px;
        }

        .search-box {
          position: relative;
          display: flex;
          align-items: center;
          cursor: text;
        }

        .search-icon {
          position: absolute;
          left: 14px;
          color: var(--text-muted);
          pointer-events: none;
        }

        .search-input {
          padding: 10px 14px 10px 44px;
          background: rgba(241, 245, 249, 0.85);
          border: 1px solid transparent;
          border-radius: 999px;
          width: min(320px, 36vw);
          font-size: 14px;
          transition: border-color 0.25s ease, box-shadow 0.3s ease, background 0.25s ease;
        }

        .search-input:focus {
          background: rgba(255, 255, 255, 0.95);
          border-color: rgba(13, 159, 92, 0.45);
          outline: none;
          box-shadow: 0 0 0 4px var(--primary-soft), 0 8px 28px rgba(15, 23, 42, 0.08);
        }

        .icon-btn {
          background: none;
          border: none;
          color: var(--text-muted);
          cursor: pointer;
          padding: 10px;
          border-radius: 12px;
          display: flex;
          align-items: center;
          justify-content: center;
        }

        .user-profile {
          display: flex;
          align-items: center;
          gap: 12px;
          padding: 6px 8px 6px 12px;
          border-radius: 999px;
          cursor: pointer;
          border: 1px solid transparent;
          transition: border-color 0.2s ease, background 0.2s ease;
        }

        .user-profile:hover {
          background: rgba(241, 245, 249, 0.9);
          border-color: var(--border);
        }

        .user-text {
          display: flex;
          flex-direction: column;
          align-items: flex-end;
          gap: 2px;
          min-width: 0;
        }

        .username {
          font-size: 13px;
          font-weight: 800;
          color: var(--text-main);
          line-height: 1.2;
        }

        .user-role {
          font-size: 10px;
          font-weight: 700;
          text-transform: uppercase;
          letter-spacing: 0.06em;
          color: var(--text-muted);
        }

        .avatar {
          width: 40px;
          height: 40px;
          background: linear-gradient(145deg, #e2e8f0 0%, #f1f5f9 100%);
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          color: var(--text-muted);
          flex-shrink: 0;
        }

        @media (max-width: 1024px) {
          .navbar {
            grid-template-columns: 1fr;
            gap: 14px;
          }
          .navbar-center { justify-self: stretch; }
          .search-input { width: 100%; }
          .navbar-right { justify-content: space-between; }
          .user-text { align-items: flex-start; }
        }
      `}</style>
    </Motion.header>
  );
};

export default Navbar;
