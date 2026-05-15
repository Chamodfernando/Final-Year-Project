import React from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import { AnimatePresence, motion as Motion } from 'framer-motion';
import Sidebar from './Sidebar';
import Navbar from './Navbar';

const pageTransition = {
  initial: { opacity: 0, y: 16, filter: 'blur(4px)' },
  animate: {
    opacity: 1,
    y: 0,
    filter: 'blur(0px)',
    transition: { duration: 0.38, ease: [0.16, 1, 0.3, 1] },
  },
  exit: {
    opacity: 0,
    y: -10,
    filter: 'blur(3px)',
    transition: { duration: 0.22, ease: [0.4, 0, 1, 1] },
  },
};

const Layout = () => {
  const location = useLocation();

  const getNavbar = () => {
    const path = location.pathname;
    if (path === '/') {
      return {
        title: 'Performance intelligence',
        breadcrumb: ['Console', 'Analytics'],
      };
    }
    if (path === '/users') {
      return { title: 'User management', breadcrumb: ['Console', 'Users'] };
    }
    if (path === '/locations') {
      return { title: 'Location management', breadcrumb: ['Console', 'Locations'] };
    }
    if (path === '/artifacts') {
      return { title: 'Artifacts', breadcrumb: ['Console', 'Artifacts'] };
    }
    return { title: 'Admin panel', breadcrumb: ['Console'] };
  };

  return (
    <div className="layout">
      <div className="layout-bg-orb layout-bg-orb--1" aria-hidden />
      <div className="layout-bg-orb layout-bg-orb--2" aria-hidden />
      <Sidebar />
      <div className="main-content">
        <Navbar {...getNavbar()} />
        <main className="content-area">
          <AnimatePresence mode="wait">
            <Motion.div
              key={location.pathname}
              className="page-motion"
              variants={pageTransition}
              initial="initial"
              animate="animate"
              exit="exit"
            >
              <Outlet />
            </Motion.div>
          </AnimatePresence>
        </main>
      </div>

      <style>{`
        .layout {
          display: flex;
          min-height: 100vh;
          position: relative;
          overflow-x: hidden;
        }

        .layout-bg-orb {
          position: fixed;
          border-radius: 50%;
          filter: blur(80px);
          opacity: 0.55;
          pointer-events: none;
          z-index: 0;
        }
        .layout-bg-orb--1 {
          width: 420px;
          height: 420px;
          top: -120px;
          right: -80px;
          background: radial-gradient(circle, rgba(13, 159, 92, 0.35) 0%, transparent 70%);
          animation: orbFloat1 18s ease-in-out infinite;
        }
        .layout-bg-orb--2 {
          width: 360px;
          height: 360px;
          bottom: -100px;
          left: 10%;
          background: radial-gradient(circle, rgba(99, 102, 241, 0.22) 0%, transparent 70%);
          animation: orbFloat2 22s ease-in-out infinite;
        }

        @keyframes orbFloat1 {
          0%, 100% { transform: translate(0, 0) scale(1); }
          50% { transform: translate(-30px, 24px) scale(1.05); }
        }
        @keyframes orbFloat2 {
          0%, 100% { transform: translate(0, 0); }
          50% { transform: translate(40px, -20px); }
        }

        .main-content {
          flex: 1;
          margin-left: 268px;
          display: flex;
          flex-direction: column;
          position: relative;
          z-index: 1;
        }

        .content-area {
          padding: 28px 32px 48px;
          max-width: 1440px;
          width: 100%;
          margin: 0 auto;
          flex: 1;
        }

        .page-motion {
          min-height: 100%;
        }
      `}</style>
    </div>
  );
};

export default Layout;
