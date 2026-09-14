import { useEffect, useState } from 'react';
import { UserCheck } from 'lucide-react';
import {
  getPendingCreatorApplications,
  type CreatorApplication,
} from '../lib/adminApi';
import { Link } from 'react-router-dom';
import Avatar from '../components/Avatar';
import SkeletonRows from '../components/SkeletonRows';

/**
 * Il n'existe pas encore de vraie table de notifications
 * administrateur (signalements, alertes système...) — pour
 * l'instant, cet écran affiche la seule chose qui nécessite
 * vraiment ton attention : les demandes créateur en attente. À
 * étoffer plus tard si besoin (recettes signalées, etc.).
 */
export default function NotificationsPage() {
  const [applications, setApplications] = useState<CreatorApplication[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    getPendingCreatorApplications()
      .then(setApplications)
      .finally(() => setIsLoading(false));
  }, []);

  return (
    <div>
      <div className="admin-page-header">
        <h1>Notifications</h1>
      </div>

      {isLoading ? (
        <SkeletonRows count={3} />
      ) : applications.length === 0 ? (
        <div className="empty-state">
          Rien qui nécessite ton attention pour l’instant.
        </div>
      ) : (
        applications.map((app) => (
          <Link to="/creator-applications" key={app.id}>
            <div className="card card-row">
              <Avatar path={app.avatar_url} size={40} />
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 700, fontSize: 13 }}>
                  Nouvelle demande créateur
                </div>
                <div
                  style={{ fontSize: 12, color: 'var(--color-text-muted)' }}
                >
                  {app.full_name || app.username} souhaite devenir créateur
                </div>
              </div>
              <UserCheck size={18} color="var(--color-primary)" />
            </div>
          </Link>
        ))
      )}
    </div>
  );
}
