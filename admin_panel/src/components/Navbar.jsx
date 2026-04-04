import React from 'react';
import { Bell, Search, User } from 'lucide-react';

const Navbar = ({ title }) => {
    return (
        <div className="navbar">
            <div className="navbar-left">
                <h1 className="page-title">{title}</h1>
            </div>

            <div className="navbar-right">
                <div className="search-box">
                    <Search size={18} className="search-icon" />
                    <input type="text" placeholder="Search..." className="search-input" />
                </div>

                <button className="icon-btn">
                    <Bell size={20} />
                </button>

                <div className="user-profile">
                    <div className="avatar">
                        <User size={20} />
                    </div>
                    <span className="username">Admin User</span>
                </div>
            </div>

            <style>{`
        .navbar {
          height: 70px;
          background: var(--white);
          border-bottom: 1px solid var(--border);
          padding: 0 32px;
          display: flex;
          align-items: center;
          justify-content: space-between;
          position: sticky;
          top: 0;
          z-index: 10;
        }

        .page-title {
          font-size: 20px;
          font-weight: 700;
          color: var(--text-main);
        }

        .navbar-right {
          display: flex;
          align-items: center;
          gap: 20px;
        }

        .search-box {
          position: relative;
          display: flex;
          align-items: center;
        }

        .search-icon {
          position: absolute;
          left: 12px;
          color: var(--text-muted);
        }

        .search-input {
          padding: 8px 12px 8px 40px;
          background: #f1f5f9;
          border: 1px solid transparent;
          border-radius: 999px;
          width: 240px;
          font-size: 14px;
          transition: all 0.2s;
        }

        .search-input:focus {
          background: white;
          border-color: var(--primary);
          outline: none;
          box-shadow: 0 0 0 3px rgba(37, 198, 103, 0.1);
        }

        .icon-btn {
          background: none;
          border: none;
          color: var(--text-muted);
          cursor: pointer;
          padding: 8px;
          border-radius: 8px;
          transition: background 0.2s;
        }

        .icon-btn:hover {
          background: #f1f5f9;
        }

        .user-profile {
          display: flex;
          align-items: center;
          gap: 12px;
          padding: 4px 8px;
          border-radius: 999px;
          cursor: pointer;
          transition: background 0.2s;
        }

        .user-profile:hover {
          background: #f1f5f9;
        }

        .avatar {
          width: 36px;
          height: 36px;
          background: #e2e8f0;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          color: var(--text-muted);
        }

        .username {
          font-size: 14px;
          font-weight: 600;
          color: var(--text-main);
        }
      `}</style>
        </div>
    );
};

export default Navbar;
