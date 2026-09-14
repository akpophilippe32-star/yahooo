import { useEffect, useMemo, useState } from 'react';
import {
  PlayCircle,
  Search,
  Send,
  Trash2,
  CheckCircle2,
  Clock,
} from 'lucide-react';
import {
  getAllRecipes,
  setRecipeStatus,
  deleteRecipe,
  type AdminRecipe,
} from '../lib/adminApi';
import SkeletonRows from '../components/SkeletonRows';
import RecipeThumb from '../components/RecipeThumb';
import Avatar from '../components/Avatar';
import { useToast } from '../contexts/ToastContext';
import { useConfirm } from '../contexts/ConfirmContext';
import { getErrorMessage } from '../lib/errors';

function StatusBadge({ status }: { status: string }) {
  const map: Record<string, { label: string; className: string }> = {
    published: { label: 'Publiée', className: 'badge-green' },
    draft: { label: 'Brouillon', className: 'badge-amber' },
    archived: { label: 'Archivée', className: 'badge-gray' },
  };
  const info = map[status] ?? { label: status, className: 'badge-gray' };
  return <span className={`badge ${info.className}`}>{info.label}</span>;
}

function MiniStat({
  label,
  value,
  Icon,
  color,
  bg,
}: {
  label: string;
  value: number;
  Icon: typeof PlayCircle;
  color: string;
  bg: string;
}) {
  return (
    <div className="stat-card" style={{ padding: 14 }}>
      <div
        className="stat-icon"
        style={{ background: bg, color, width: 32, height: 32, marginBottom: 8 }}
      >
        <Icon size={16} />
      </div>
      <div className="stat-label" style={{ marginBottom: 2 }}>
        {label}
      </div>
      <div className="stat-value" style={{ fontSize: 20 }}>
        {value}
      </div>
    </div>
  );
}

export default function VideosPage() {
  const { showSuccess, showError } = useToast();
  const confirm = useConfirm();
  const [recipes, setRecipes] = useState<AdminRecipe[]>([]);
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [busyId, setBusyId] = useState<number | null>(null);

  async function load() {
    setIsLoading(true);
    try {
      const data = await getAllRecipes();
      setRecipes(data.filter((r) => r.source_type === 'video'));
    } catch (err) {
      showError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase();
    if (!term) return recipes;
    return recipes.filter(
      (r) =>
        r.title.toLowerCase().includes(term) ||
        r.profiles?.full_name?.toLowerCase().includes(term) ||
        r.profiles?.username?.toLowerCase().includes(term),
    );
  }, [recipes, search]);

  const counts = useMemo(
    () => ({
      total: recipes.length,
      published: recipes.filter((r) => r.status === 'published').length,
      draft: recipes.filter((r) => r.status === 'draft').length,
    }),
    [recipes],
  );

  async function handleSetStatus(recipeId: number, status: string) {
    setBusyId(recipeId);
    try {
      await setRecipeStatus(recipeId, status);
      showSuccess('Statut mis à jour.');
      await load();
    } catch (err) {
      showError(getErrorMessage(err));
    } finally {
      setBusyId(null);
    }
  }

  async function handleDelete(recipeId: number, title: string) {
    const ok = await confirm({
      title: 'Supprimer cette vidéo ?',
      message: `« ${title} » sera supprimée définitivement.`,
      confirmLabel: 'Supprimer',
      danger: true,
    });
    if (!ok) return;

    setBusyId(recipeId);
    try {
      await deleteRecipe(recipeId);
      showSuccess('Vidéo supprimée.');
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
        <h1>Vidéos</h1>
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
          gap: 12,
          marginBottom: 20,
        }}
      >
        <MiniStat
          label="Total"
          value={counts.total}
          Icon={PlayCircle}
          color="var(--color-purple)"
          bg="var(--color-purple-bg)"
        />
        <MiniStat
          label="Publiées"
          value={counts.published}
          Icon={CheckCircle2}
          color="var(--color-green)"
          bg="var(--color-green-bg)"
        />
        <MiniStat
          label="En attente"
          value={counts.draft}
          Icon={Clock}
          color="var(--color-orange)"
          bg="var(--color-orange-bg)"
        />
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
          placeholder="Rechercher par titre ou créateur..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ width: '100%', paddingLeft: 34 }}
        />
      </div>

      {isLoading ? (
        <SkeletonRows count={5} />
      ) : filtered.length === 0 ? (
        <div className="empty-state">
          <PlayCircle size={32} />
          Aucune vidéo pour l’instant.
        </div>
      ) : (
        <table className="data-table">
          <thead>
            <tr>
              <th></th>
              <th>Titre</th>
              <th>Créateur</th>
              <th>Statut</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((recipe) => (
              <tr key={recipe.id}>
                <td>
                  <RecipeThumb imageUrl={null} isVideo />
                </td>
                <td style={{ fontWeight: 600 }}>{recipe.title}</td>
                <td>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <Avatar path={null} size={24} />
                    <span style={{ fontSize: 13 }}>
                      {recipe.profiles?.full_name ||
                        recipe.profiles?.username ||
                        '—'}
                    </span>
                  </div>
                </td>
                <td>
                  <StatusBadge status={recipe.status} />
                </td>
                <td>
                  <div style={{ display: 'flex', gap: 6 }}>
                    {recipe.status !== 'published' && (
                      <button
                        className="btn btn-outline btn-sm"
                        disabled={busyId === recipe.id}
                        onClick={() => handleSetStatus(recipe.id, 'published')}
                        title="Publier"
                      >
                        <Send size={13} />
                      </button>
                    )}
                    <button
                      className="btn btn-danger btn-sm"
                      disabled={busyId === recipe.id}
                      onClick={() => handleDelete(recipe.id, recipe.title)}
                      title="Supprimer"
                    >
                      <Trash2 size={13} />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}