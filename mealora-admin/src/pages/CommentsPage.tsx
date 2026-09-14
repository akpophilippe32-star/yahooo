import { useEffect, useMemo, useState } from 'react';
import { RefreshCw, Search, MessageSquare, EyeOff, Eye } from 'lucide-react';
import {
  getAllComments,
  setCommentHidden,
  type AdminComment,
} from '../lib/adminApi';
import SkeletonRows from '../components/SkeletonRows';
import { useToast } from '../contexts/ToastContext';
import { getErrorMessage } from '../lib/errors';

export default function CommentsPage() {
  const { showSuccess, showError } = useToast();
  const [comments, setComments] = useState<AdminComment[]>([]);
  const [onlyHidden, setOnlyHidden] = useState(false);
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<number | null>(null);

  async function load() {
    setIsLoading(true);
    setError(null);

    try {
      const data = await getAllComments(onlyHidden);
      setComments(data);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [onlyHidden]);

  const filteredComments = useMemo(() => {
    const term = search.trim().toLowerCase();
    if (!term) return comments;

    return comments.filter((c) => {
      const author =
        c.profiles?.full_name?.toLowerCase() ??
        c.profiles?.username?.toLowerCase() ??
        '';
      const recipeTitle = c.recipes?.title?.toLowerCase() ?? '';
      return (
        c.content.toLowerCase().includes(term) ||
        author.includes(term) ||
        recipeTitle.includes(term)
      );
    });
  }, [comments, search]);

  async function toggleHidden(commentId: number, hidden: boolean) {
    setBusyId(commentId);
    try {
      await setCommentHidden(commentId, hidden);
      showSuccess(hidden ? 'Commentaire masqué.' : 'Commentaire réaffiché.');
      await load();
    } catch (err) {
      showError(getErrorMessage(err));
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div>
      <div className="admin-page-header">
        <h1>Commentaires</h1>
        <button className="btn btn-outline btn-sm" onClick={load}>
          <RefreshCw size={14} />
          Actualiser
        </button>
      </div>

      <div style={{ position: 'relative', maxWidth: 360, marginBottom: 16 }}>
        <Search
          size={15}
          style={{
            position: 'absolute',
            left: 12,
            top: '50%',
            transform: 'translateY(-50%)',
            color: 'var(--color-text-muted)',
          }}
        />
        <input
          placeholder="Rechercher par contenu, auteur ou recette..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ width: '100%', paddingLeft: 34 }}
        />
      </div>

      <div className="filters-row">
        <button
          className={`filter-chip${!onlyHidden ? ' active' : ''}`}
          onClick={() => setOnlyHidden(false)}
        >
          Tous
        </button>
        <button
          className={`filter-chip${onlyHidden ? ' active' : ''}`}
          onClick={() => setOnlyHidden(true)}
        >
          Masqués seulement
        </button>
      </div>

      {isLoading && <SkeletonRows count={4} />}
      {error && (
        <div className="empty-state" style={{ color: 'var(--color-danger)' }}>
          Erreur : {error}
        </div>
      )}
      {!isLoading && !error && filteredComments.length === 0 && (
        <div className="empty-state">
          <MessageSquare size={32} />
          Aucun commentaire ici.
        </div>
      )}

      {filteredComments.map((comment) => (
        <div className="card" key={comment.id}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 12, color: 'var(--color-text-muted)' }}>
                {comment.profiles?.full_name ||
                  comment.profiles?.username ||
                  'Utilisateur'}{' '}
                · sur « {comment.recipes?.title ?? 'recette supprimée'} »
              </div>
              <div style={{ marginTop: 6 }}>{comment.content}</div>
              {comment.is_hidden && (
                <span className="badge badge-gray" style={{ marginTop: 8 }}>
                  Masqué
                </span>
              )}
            </div>
            <button
              className={
                comment.is_hidden
                  ? 'btn btn-primary btn-sm'
                  : 'btn btn-danger btn-sm'
              }
              disabled={busyId === comment.id}
              onClick={() => toggleHidden(comment.id, !comment.is_hidden)}
            >
              {comment.is_hidden ? <Eye size={13} /> : <EyeOff size={13} />}
              {comment.is_hidden ? 'Réafficher' : 'Masquer'}
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}
