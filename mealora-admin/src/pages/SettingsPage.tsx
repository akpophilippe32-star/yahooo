import { Settings } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';

/**
 * Écran minimal pour l'instant — juste les infos du compte
 * connecté. À étoffer (gestion des admins, préférences globales
 * de la plateforme...) dans un prochain passage.
 */
export default function SettingsPage() {
  const { session, role } = useAuth();

  return (
    <div>
      <div className="admin-page-header">
        <h1>Paramètres</h1>
      </div>

      <div className="card" style={{ maxWidth: 420 }}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            marginBottom: 16,
          }}
        >
          <div className="stat-icon" style={{ background: 'var(--color-surface-muted)', color: 'var(--color-text-muted)', margin: 0 }}>
            <Settings size={18} />
          </div>
          <div>
            <div style={{ fontWeight: 700, fontSize: 14 }}>Mon compte</div>
            <div style={{ fontSize: 12, color: 'var(--color-text-muted)' }}>
              Informations de connexion
            </div>
          </div>
        </div>

        <table className="data-table">
          <tbody>
            <tr>
              <td style={{ color: 'var(--color-text-muted)' }}>Email</td>
              <td>{session?.user.email}</td>
            </tr>
            <tr>
              <td style={{ color: 'var(--color-text-muted)' }}>Rôle</td>
              <td>{role}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div className="empty-state" style={{ maxWidth: 420, textAlign: 'left' }}>
        D'autres réglages (gestion des comptes administrateurs,
        préférences de la plateforme) arriveront ici prochainement.
      </div>
    </div>
  );
}
