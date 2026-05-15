import React, { useState, useEffect, useCallback, useRef } from 'react';
import { serverTimestamp } from 'firebase/firestore';
import { dbService } from '../services/dbService';
import { Mail, Calendar, Edit, Trash2, RefreshCw, X, Shield } from 'lucide-react';
import { AnimatedModal } from '../components/AnimatedModal';

const ROLES = ['User', 'Guest', 'Admin'];

function formatFirestoreDate(value) {
  if (value == null) return '—';
  if (typeof value?.toDate === 'function') {
    try {
      return value.toDate().toLocaleString();
    } catch {
      return '—';
    }
  }
  if (typeof value === 'string') return value;
  return String(value);
}

const Users = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [editing, setEditing] = useState(null);
  const editingSnapshotRef = useRef(null);
  if (editing) editingSnapshotRef.current = editing;
  const displayEditing = editing ?? editingSnapshotRef.current;
  const [editRole, setEditRole] = useState('User');
  const [saving, setSaving] = useState(false);
  const [deletingId, setDeletingId] = useState(null);

  const fetchUsers = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      let data;
      try {
        data = await dbService.getAll('users', {
          orderByField: 'updatedAt',
          orderDirection: 'desc',
          limitCount: 500,
        });
      } catch (e) {
        if (e?.code === 'failed-precondition' || String(e?.message || '').includes('index')) {
          data = await dbService.getAll('users');
        } else {
          throw e;
        }
      }
      setUsers(data || []);
    } catch (err) {
      console.error('Error fetching users:', err);
      setError(
        err?.message ||
          'Could not load users. Check Firestore rules allow read on `users`, and that the app syncs profiles (see README).'
      );
      setUsers([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  const openEdit = (user) => {
    setEditing(user);
    setEditRole(ROLES.includes(user.role) ? user.role : 'User');
  };

  const saveRole = async () => {
    if (!editing) return;
    setSaving(true);
    try {
      await dbService.update('users', editing.id, {
        role: editRole,
        updatedAt: serverTimestamp(),
      });
      setEditing(null);
      await fetchUsers();
    } catch (err) {
      console.error(err);
      alert('Could not update role: ' + (err?.message || err));
    } finally {
      setSaving(false);
    }
  };

  const confirmDelete = async (user) => {
    const ok = window.confirm(
      `Remove Firestore profile for "${user.name || user.email || user.id}"?\n\n` +
        'This does not delete the Firebase Authentication account. To fully remove a user, also delete them in Firebase Console → Authentication.'
    );
    if (!ok) return;
    setDeletingId(user.id);
    try {
      await dbService.delete('users', user.id);
      await fetchUsers();
    } catch (err) {
      console.error(err);
      alert('Could not delete: ' + (err?.message || err));
    } finally {
      setDeletingId(null);
    }
  };

  return (
    <div className="users-page">
      <div className="page-header">
        <div className="header-row">
          <p className="page-desc">
            Profiles come from the mobile app (<code>users</code> in Firestore). Each sign-in,
            sign-up, or guest session updates <code>lastSeenAt</code>. Ensure Firestore rules
            allow clients to write their own document and allow this admin app to read{' '}
            <code>users</code>.
          </p>
          <button type="button" className="btn-refresh" onClick={fetchUsers} disabled={loading}>
            <RefreshCw size={16} className={loading ? 'spin' : ''} />
            Refresh
          </button>
        </div>
      </div>

      {error && (
        <div className="alert alert-error" role="alert">
          {error}
        </div>
      )}

      {loading ? (
        <div className="loading-state">Loading users…</div>
      ) : users.length === 0 ? (
        <div className="empty-state card">
          <Shield size={40} strokeWidth={1.5} />
          <p>No user profiles yet.</p>
          <p className="muted">
            Open the Ceylon Trails app, sign in or continue as guest, then refresh. The app writes
            one document per Firebase user under <code>users/&lt;uid&gt;</code>.
          </p>
          <p className="muted backfill">
            <strong>Already have users in Authentication only?</strong> The admin panel reads{' '}
            <strong>Firestore</strong>, not Auth. Either have each user sign in once on the updated
            app, or run a one-time backfill from your machine: in <code>admin_panel</code>, set{' '}
            <code>GOOGLE_APPLICATION_CREDENTIALS</code> to a service-account JSON with Auth list +
            Firestore write, then <code>npm run sync-auth-to-firestore</code> (see{' '}
            <code>admin_panel/README.md</code>).
          </p>
        </div>
      ) : (
        <div className="table-container card">
          <table>
            <thead>
              <tr>
                <th>User</th>
                <th>Email</th>
                <th>Role</th>
                <th>Last seen</th>
                <th>Joined</th>
                <th>User ID</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => (
                <tr key={user.id}>
                  <td>
                    <div className="user-info-cell">
                      <div className="user-avatar">
                        {(user.name && user.name[0]) || (user.email && user.email[0]) || 'U'}
                      </div>
                      <span className="user-name">{user.name || '—'}</span>
                    </div>
                  </td>
                  <td>
                    <div className="icon-text">
                      <Mail size={14} />
                      <span>{user.email || (user.isAnonymous ? '(anonymous)' : '—')}</span>
                    </div>
                  </td>
                  <td>
                    <span className={`role-badge ${(user.role || 'User').toLowerCase()}`}>
                      {user.role || 'User'}
                    </span>
                  </td>
                  <td>
                    <div className="icon-text">
                      <Calendar size={14} />
                      <span>{formatFirestoreDate(user.lastSeenAt)}</span>
                    </div>
                  </td>
                  <td>
                    <span className="mono-sm">{formatFirestoreDate(user.joined)}</span>
                  </td>
                  <td>
                    <span className="mono-sm" title={user.id}>
                      {user.id.length > 12 ? `${user.id.slice(0, 8)}…` : user.id}
                    </span>
                  </td>
                  <td>
                    <div className="actions">
                      <button
                        type="button"
                        className="icon-btn-small"
                        title="Edit role"
                        onClick={() => openEdit(user)}
                      >
                        <Edit size={16} />
                      </button>
                      <button
                        type="button"
                        className="icon-btn-small delete"
                        title="Delete profile doc"
                        disabled={deletingId === user.id}
                        onClick={() => confirmDelete(user)}
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <AnimatedModal
        open={Boolean(editing)}
        onClose={() => setEditing(null)}
        onExitComplete={() => {
          editingSnapshotRef.current = null;
        }}
        panelClassName="modal card"
        ariaLabel="Edit user role"
      >
        {displayEditing ? (
          <>
            <div className="modal-head">
              <h3>Edit role</h3>
              <button type="button" className="icon-btn-small" onClick={() => setEditing(null)}>
                <X size={18} />
              </button>
            </div>
            <p className="modal-user">
              {displayEditing.name || displayEditing.email || displayEditing.id}
            </p>
            <label className="field-label">Role</label>
            <select
              className="role-select"
              value={editRole}
              onChange={(e) => setEditRole(e.target.value)}
            >
              {ROLES.map((r) => (
                <option key={r} value={r}>
                  {r}
                </option>
              ))}
            </select>
            <div className="modal-actions">
              <button type="button" className="btn-secondary" onClick={() => setEditing(null)}>
                Cancel
              </button>
              <button type="button" className="btn-primary" disabled={saving} onClick={saveRole}>
                {saving ? 'Saving…' : 'Save'}
              </button>
            </div>
          </>
        ) : null}
      </AnimatedModal>

      <style>{`
        .page-header { margin-bottom: 20px; }
        .header-row {
          display: flex;
          align-items: flex-start;
          justify-content: space-between;
          gap: 16px;
          flex-wrap: wrap;
        }
        .page-desc {
          color: var(--text-muted);
          font-size: 14px;
          line-height: 1.5;
          max-width: 720px;
          margin: 0;
        }
        .page-desc code {
          font-size: 12px;
          background: #f1f5f9;
          padding: 2px 6px;
          border-radius: 4px;
        }
        .btn-refresh {
          display: inline-flex;
          align-items: center;
          gap: 8px;
          padding: 8px 14px;
          border-radius: 8px;
          border: 1px solid #e2e8f0;
          background: #fff;
          cursor: pointer;
          font-size: 13px;
          font-weight: 600;
          color: var(--text-main, #0f172a);
        }
        .btn-refresh:hover:not(:disabled) {
          background: #f8fafc;
        }
        .btn-refresh:disabled { opacity: 0.6; cursor: not-allowed; }
        .spin { animation: spin 0.9s linear infinite; }
        @keyframes spin { to { transform: rotate(360deg); } }

        .alert {
          padding: 12px 16px;
          border-radius: 10px;
          margin-bottom: 16px;
          font-size: 14px;
        }
        .alert-error {
          background: #fef2f2;
          color: #b91c1c;
          border: 1px solid #fecaca;
        }
        .loading-state, .empty-state {
          padding: 40px 24px;
          text-align: center;
          color: var(--text-muted);
        }
        .empty-state svg { margin: 0 auto 12px; color: #94a3b8; }
        .empty-state .muted { font-size: 13px; margin-top: 8px; max-width: 560px; margin-left: auto; margin-right: auto; }
        .empty-state .muted.backfill { margin-top: 16px; text-align: left; }
        .empty-state code { font-size: 12px; background: #f1f5f9; padding: 2px 6px; border-radius: 4px; }

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
        .user-name { font-weight: 600; }
        .icon-text {
          display: flex;
          align-items: center;
          gap: 8px;
          color: var(--text-muted);
          font-size: 13px;
        }
        .mono-sm {
          font-family: ui-monospace, monospace;
          font-size: 11px;
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
        .role-badge.guest {
          background: #f0fdf4;
          color: #15803d;
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
          transition: background 0.2s;
        }
        .icon-btn-small:hover:not(:disabled) {
          background: #f1f5f9;
        }
        .icon-btn-small.delete:hover:not(:disabled) {
          background: #fef2f2;
          color: var(--danger, #dc2626);
        }
        .icon-btn-small:disabled { opacity: 0.5; cursor: not-allowed; }

        .modal {
          width: 100%;
          max-width: 400px;
          padding: 20px;
        }
        .modal-head {
          display: flex;
          justify-content: space-between;
          align-items: center;
          margin-bottom: 8px;
        }
        .modal-head h3 { margin: 0; font-size: 18px; }
        .modal-user {
          font-size: 14px;
          color: var(--text-muted);
          margin: 0 0 16px;
        }
        .field-label {
          display: block;
          font-size: 12px;
          font-weight: 600;
          margin-bottom: 6px;
          color: var(--text-muted);
        }
        .role-select {
          width: 100%;
          padding: 10px 12px;
          border-radius: 8px;
          border: 1px solid #e2e8f0;
          font-size: 14px;
          margin-bottom: 20px;
        }
        .modal-actions {
          display: flex;
          justify-content: flex-end;
          gap: 10px;
        }
        .btn-secondary {
          padding: 8px 16px;
          border-radius: 8px;
          border: 1px solid #e2e8f0;
          background: #fff;
          cursor: pointer;
          font-weight: 600;
        }
        .btn-primary {
          padding: 8px 16px;
          border-radius: 8px;
          border: none;
          background: #0c3b2e;
          color: #fff;
          cursor: pointer;
          font-weight: 600;
        }
        .btn-primary:disabled { opacity: 0.6; cursor: not-allowed; }
      `}</style>
    </div>
  );
};

export default Users;
