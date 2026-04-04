import React from 'react';
import { LayoutDashboard, Users, MapPin, Landmark, LogOut } from 'lucide-react';
import { NavLink } from 'react-router-dom';

const Sidebar = () => {
  const menuItems = [
    { icon: LayoutDashboard, label: 'Dashboard', path: '/' },
    { icon: Users, label: 'Users', path: '/users' },
    { icon: MapPin, label: 'Locations', path: '/locations' },
  ];

  return (
    <div className="sidebar">
      <div className="sidebar-header">
        <h2 className="logo-text">Ceylon Admin</h2>
      </div>
      <nav className="sidebar-nav">
        {menuItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
          >
            <item.icon size={20} />
            <span>{item.label}</span>
          </NavLink>
        ))}
      </nav>
      <div className="sidebar-footer">
        <button className="nav-item logout-btn">
          <LogOut size={20} />
          <span>Logout</span>
        </button>
      </div>

      <style>{`
        .sidebar {
          width: 260px;
          height: 100vh;
          background: var(--sidebar-bg);
          border-right: 1px solid var(--border);
          display: flex;
          flex-direction: column;
          position: fixed;
          left: 0;
          top: 0;
        }

        .sidebar-header {
          padding: 24px;
          border-bottom: 1px solid var(--border);
        }

        .logo-text {
          color: var(--primary);
          font-size: 20px;
          font-weight: 800;
          letter-spacing: -0.5px;
        }

        .sidebar-nav {
          flex: 1;
          padding: 16px 12px;
          display: flex;
          flex-direction: column;
          gap: 4px;
        }

        .nav-item {
          display: flex;
          align-items: center;
          gap: 12px;
          padding: 12px;
          text-decoration: none;
          color: var(--text-muted);
          border-radius: 8px;
          font-weight: 500;
          transition: all 0.2s;
        }

        .nav-item:hover {
          background: #f1f5f9;
          color: var(--text-main);
        }

        .nav-item.active {
          background: #ecfdf5;
          color: var(--primary);
        }

        .sidebar-footer {
          padding: 16px;
          border-top: 1px solid var(--border);
        }

        .logout-btn {
          width: 100%;
          border: none;
          background: none;
          cursor: pointer;
          color: var(--danger);
        }

        .logout-btn:hover {
          background: #fef2f2;
          color: var(--danger);
        }
      `}</style>
    </div>
  );
};

export default Sidebar;
