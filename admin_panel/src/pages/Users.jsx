import React, { useState, useEffect } from 'react';
import { dbService } from '../services/dbService';
import { Mail, Calendar, MoreVertical, Edit, Trash2 } from 'lucide-react';

const Users = () => {
    const [users, setUsers] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchUsers = async () => {
            try {
                const data = await dbService.getAll("users");
                setUsers(data);
            } catch (error) {
                console.error("Error fetching users:", error);
                // Fallback for demo if collection doesn't exist yet
                setUsers([
                    { id: '1', name: 'John Doe', email: 'john@example.com', role: 'User', joined: '2024-03-01' },
                    { id: '2', name: 'Jane Smith', email: 'jane@example.com', role: 'Admin', joined: '2024-02-15' },
                ]);
            } finally {
                setLoading(false);
            }
        };
        fetchUsers();
    }, []);

    return (
        <div className="users-page">
            <div className="page-header">
                <p className="page-desc">Manage all registered travelers and administrators.</p>
            </div>

            <div className="table-container card">
                <table>
                    <thead>
                        <tr>
                            <th>User</th>
                            <th>Email</th>
                            <th>Role</th>
                            <th>Joined Date</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {users.map((user) => (
                            <tr key={user.id}>
                                <td>
                                    <div className="user-info-cell">
                                        <div className="user-avatar">{user.name?.[0] || 'U'}</div>
                                        <span className="user-name">{user.name || 'Anonymous'}</span>
                                    </div>
                                </td>
                                <td>
                                    <div className="icon-text">
                                        <Mail size={14} />
                                        <span>{user.email}</span>
                                    </div>
                                </td>
                                <td>
                                    <span className={`role-badge ${user.role?.toLowerCase()}`}>
                                        {user.role || 'User'}
                                    </span>
                                </td>
                                <td>
                                    <div className="icon-text">
                                        <Calendar size={14} />
                                        <span>{user.joined || 'N/A'}</span>
                                    </div>
                                </td>
                                <td>
                                    <div className="actions">
                                        <button className="icon-btn-small"><Edit size={16} /></button>
                                        <button className="icon-btn-small delete"><Trash2 size={16} /></button>
                                    </div>
                                </td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>

            <style>{`
        .page-header {
          margin-bottom: 24px;
        }

        .page-desc {
          color: var(--text-muted);
          font-size: 14px;
        }

        .user-info-cell {
          display: flex;
          align-items: center;
          gap: 12px;
        }

        .user-avatar {
          width: 32px;
          height: 32px;
          background: #3b82f615;
          color: #3b82f6;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          font-weight: 700;
          font-size: 14px;
        }

        .user-name {
          font-weight: 600;
        }

        .icon-text {
          display: flex;
          align-items: center;
          gap: 8px;
          color: var(--text-muted);
        }

        .role-badge {
          padding: 4px 10px;
          border-radius: 999px;
          font-size: 11px;
          font-weight: 700;
          text-transform: uppercase;
        }

        .role-badge.admin {
          background: #fdf2f8;
          color: #db2777;
        }

        .role-badge.user {
          background: #eff6ff;
          color: #2563eb;
        }

        .actions {
          display: flex;
          gap: 8px;
        }

        .icon-btn-small {
          background: none;
          border: none;
          color: var(--text-muted);
          cursor: pointer;
          padding: 6px;
          border-radius: 6px;
          transition: background 0.20s;
        }

        .icon-btn-small:hover {
          background: #f1f5f9;
        }

        .icon-btn-small.delete:hover {
          background: #fef2f2;
          color: var(--danger);
        }
      `}</style>
        </div>
    );
};

export default Users;
