import React from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import Sidebar from './Sidebar';
import Navbar from './Navbar';

const Layout = () => {
  const location = useLocation();

  const getTitle = () => {
    const path = location.pathname;
    if (path === '/') return 'Dashboard';
    if (path === '/users') return 'User Management';
    if (path === '/locations') return 'Location Management';
    if (path === '/artifacts') return 'Artifacts';
    return 'Admin Panel';
  };

  return (
    <div className="layout">
      <Sidebar />
      <div className="main-content">
        <Navbar title={getTitle()} />
        <main className="content-area">
          <Outlet />
        </main>
      </div>

      <style>{`
        .layout {
          display: flex;
          min-height: 100vh;
        }

        .main-content {
          flex: 1;
          margin-left: 260px;
          display: flex;
          flex-direction: column;
        }

        .content-area {
          padding: 32px;
          max-width: 1200px;
          width: 100%;
          margin: 0 auto;
        }
      `}</style>
    </div>
  );
};

export default Layout;
