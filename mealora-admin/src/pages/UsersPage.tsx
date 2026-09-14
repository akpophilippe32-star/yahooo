import { useEffect, useMemo, useState } from 'react';
import {
  getAllUsers,
  setUserRole,
  getUserRecipeCount,
  type AdminUser,
} from '../lib/adminApi';
import { useAuth } from '../contexts/AuthContext';
import Modal from '../components/Modal';
import Avatar from '../components/Avatar';
import { RefreshCw } from 'lucide-react';
import { getErrorMessage } from '../lib/errors';

function RoleBadge({ role }: { role: string }) {
  const map: Record<string, string> = {
    admin: 'badge-red',
    creator: 'badge-green',
    user: 'badge-gray',
  };

  const label: Record<string, string> = {
    admin: 'Admin',
    creator: 'Créateur',
    user: 'Utilisateur',
  };

  return (
    <span className={`badge ${map[role] ?? 'badge-gray'}`}>
      {label[role] ?? role}
    </span>
  );
}

function formatDate(iso: string): string {
  const date = new Date(iso);
  return date.toLocaleDateString('fr-FR', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
}

function UserDetailModal({
  user,
  onClose,
}: {
  user: AdminUser;
  onClose: () => void;
}) {
  const [recipeCount, setRecipeCount] = useState<number | null>(null);

  useEffect(() => {
    getUserRecipeCount(user.id)
      .then(setRecipeCount)
      .catch(() => setRecipeCount(null));
  }, [user.id]);

  return (
    <Modal title="Détail de l’utilisateur" onClose={onClose}>
      <div className="card-row" style={{ marginBottom: 16 }}>
        <Avatar path={user.avatar_url} size={44} />
        <div>
          <div style={{ fontWeight: 700 }}>{user.full_name || 'Sans nom'}</div>
          <div style={{ fontSize: 12, color: 'var(--color-text-muted)' }}>
            @{user.username}
          </div>
        </div>
      </div>

      <table className="data-table">
        <tbody>
          <tr>
            <td style={{ color: 'var(--color-text-muted)' }}>Email</td>
            <td>{user.email ?? '—'}</td>
          </tr>
          <tr>
            <td style={{ color: 'var(--color-text-muted)' }}>Rôle</td>
            <td>
              <RoleBadge role={user.role} />
            </td>
          </tr>
          <tr>
            <td style={{ color: 'var(--color-text-muted)' }}>
              Statut créateur
            </td>
            <td>{user.creator_status ?? '—'}</td>
          </tr>
          <tr>
            <td style={{ color: 'var(--color-text-muted)' }}>Membre depuis</td>
            <td>{formatDate(user.created_at)}</td>
          </tr>
          <tr>
            <td style={{ color: 'var(--color-text-muted)' }}>
              Recettes publiées
            </td>
            <td>{recipeCount ?? '...'}</td>
          </tr>
        </tbody>
      </table>
    </Modal>
  );
}

export default function UsersPage() {
  const { session } = useAuth();
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [detailUser, setDetailUser] = useState<AdminUser | null>(null);

  async function load() {
    setIsLoading(true);
    setError(null);

    try {
      const data = await getAllUsers();
      setUsers(data);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  const filteredUsers = useMemo(() => {
    const term = search.trim().toLowerCase();
    if (!term) return users;

    return users.filter(
      (u) =>
        u.full_name?.toLowerCase().includes(term) ||
        u.username?.toLowerCase().includes(term) ||
        u.email?.toLowerCase().includes(term),
    );
  }, [users, search]);

  async function handleRoleChange(userId: string, role: string) {
    setBusyId(userId);
    try {
      await setUserRole(userId, role);
      await load();
    } catch (err) {
      alert(`Erreur : ${getErrorMessage(err)}`);
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div>
      <div className="admin-page-header">
        <h1>Utilisateurs</h1>
        <button className="btn btn-outline btn-sm" onClick={load}>
          <RefreshCw size={14} /> Actualiser
        </button>
      </div>

      <input
        placeholder="Rechercher par nom, username ou email..."
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{ width: '100%', maxWidth: 360, marginBottom: 16 }}
      />

      {isLoading && <div className="empty-state">Chargement...</div>}
      {error && (
        <div className="empty-state" style={{ color: 'var(--color-danger)' }}>
          Erreur : {error}
        </div>
      )}

      {!isLoading && !error && (
        <table className="data-table">
          <thead>
            <tr>
              <th>Nom</th>
              <th>Email</th>
              <th>Rôle</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {filteredUsers.map((user) => {
              const isSelf = user.id === session?.user.id;

              return (
                <tr key={user.id}>
                  <td
                    style={{ cursor: 'pointer' }}
                    onClick={() => setDetailUser(user)}
                  >
                    <div
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 10,
                      }}
                    >
                      <Avatar path={user.avatar_url} size={32} />
                      <div>
                        <div>{user.full_name || 'Sans nom'}</div>
                        <div
                          style={{
                            fontSize: 12,
                            color: 'var(--color-text-muted)',
                          }}
                        >
                          @{user.username}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td
                    style={{
                      fontSize: 13,
                      color: 'var(--color-text-muted)',
                    }}
                  >
                    {user.email ?? '—'}
                  </td>
                  <td>
                    <RoleBadge role={user.role} />
                  </td>
                  <td>
                    <select
                      value={user.role}
                      disabled={busyId === user.id || isSelf}
                      onChange={(e) =>
                        handleRoleChange(user.id, e.target.value)
                      }
                      title={
                        isSelf
                          ? 'Tu ne peux pas changer ton propre rôle ici'
                          : undefined
                      }
                    >
                      <option value="user">Utilisateur</option>
                      <option value="creator">Créateur</option>
                      <option value="admin">Admin</option>
                    </select>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}

      {detailUser && (
        <UserDetailModal
          user={detailUser}
          onClose={() => setDetailUser(null)}
        />
      )}
    </div>
  );
}
