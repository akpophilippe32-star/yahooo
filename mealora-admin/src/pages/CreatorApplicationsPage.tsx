import { useEffect, useState } from 'react';
import { FileText, RefreshCw, UserPlus } from 'lucide-react';
import {
  getCreatorDocumentUrl,
  getPendingCreatorApplications,
  reviewCreatorApplication,
  type CreatorApplication,
} from '../lib/adminApi';
import { useToast } from '../contexts/ToastContext';
import SkeletonRows from '../components/SkeletonRows';
import Avatar from '../components/Avatar';
import { getErrorMessage } from '../lib/errors';

function specialtyLabel(specialty: string | null): string {
  switch (specialty) {
    case 'cuisine':
      return 'Cuisinier·ère';
    case 'nutrition':
      return 'Nutritionniste';
    default:
      return specialty ?? '—';
  }
}

/**
 * Bouton "Voir le document" : le lien signé n'est généré qu'au clic
 * (pas au chargement de la liste entière), pour éviter de faire un
 * aller-retour storage par candidature juste pour un affichage.
 */
function DocumentLink({ path }: { path: string | null }) {
  const [isLoading, setIsLoading] = useState(false);
  const { showError } = useToast();

  if (!path) {
    return (
      <span
        style={{
          fontSize: 12,
          color: 'var(--color-text-muted)',
          fontStyle: 'italic',
        }}
      >
        Aucun document fourni
      </span>
    );
  }

  async function handleClick() {
    setIsLoading(true);
    try {
      const url = await getCreatorDocumentUrl(path);
      if (!url) {
        showError('Impossible d’ouvrir le document.');
        return;
      }
      window.open(url, '_blank', 'noopener,noreferrer');
    } catch (err) {
      showError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <button
      className="btn btn-outline btn-sm"
      onClick={handleClick}
      disabled={isLoading}
    >
      <FileText size={14} />
      {isLoading ? 'Ouverture...' : 'Voir le document'}
    </button>
  );
}

export default function CreatorApplicationsPage() {
  const { showSuccess, showError } = useToast();
  const [applications, setApplications] = useState<CreatorApplication[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [reviewingId, setReviewingId] = useState<string | null>(null);

  async function load() {
    setIsLoading(true);
    setError(null);

    try {
      const data = await getPendingCreatorApplications();
      setApplications(data);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function handleReview(userId: string, approve: boolean) {
    setReviewingId(userId);

    try {
      await reviewCreatorApplication(userId, approve);
      showSuccess(approve ? 'Demande approuvée.' : 'Demande refusée.');
      await load();
    } catch (err) {
      showError(getErrorMessage(err));
    } finally {
      setReviewingId(null);
    }
  }

  return (
    <div>
      <div className="admin-page-header">
        <h1>Demandes créateur</h1>
        <button className="btn btn-outline btn-sm" onClick={load}>
          <RefreshCw size={14} />
          Actualiser
        </button>
      </div>

      {isLoading && <SkeletonRows count={3} />}

      {error && (
        <div className="empty-state" style={{ color: 'var(--color-danger)' }}>
          Erreur : {error}
        </div>
      )}

      {!isLoading && !error && applications.length === 0 && (
        <div className="empty-state">
          <UserPlus size={32} />
          Aucune demande en attente.
        </div>
      )}

      {applications.map((app) => (
        <div className="card" key={app.id}>
          <div className="card-row">
            <Avatar path={app.avatar_url} size={44} />
            <div style={{ flex: 1 }}>
              <div style={{ fontWeight: 700 }}>
                {app.full_name || 'Sans nom'}
              </div>
              <div
                style={{ fontSize: 12, color: 'var(--color-text-muted)' }}
              >
                @{app.username} · {specialtyLabel(app.specialty)}
              </div>
              {app.application_note && (
                <div style={{ fontSize: 13, marginTop: 6 }}>
                  {app.application_note}
                </div>
              )}
              <div style={{ marginTop: 8 }}>
                <DocumentLink path={app.creator_document_path} />
              </div>
            </div>
            <button
              className="btn btn-danger btn-sm"
              disabled={reviewingId === app.id}
              onClick={() => handleReview(app.id, false)}
            >
              Refuser
            </button>
            <button
              className="btn btn-primary btn-sm"
              disabled={reviewingId === app.id}
              onClick={() => handleReview(app.id, true)}
            >
              {reviewingId === app.id ? '...' : 'Approuver'}
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}