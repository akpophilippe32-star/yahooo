import { useEffect, useMemo, useState } from 'react';
import {
  RefreshCw,
  Search,
  BookOpen,
  Eye,
  Send,
  Archive,
  Trash2,
  FileEdit,
  CheckCircle2,
} from 'lucide-react';
import {
  getAllRecipes,
  setRecipeStatus,
  deleteRecipe,
  getRecipeDetail,
  type AdminRecipe,
  type AdminRecipeDetail,
  type RecipeIngredientRow,
  type RecipeStepRow,
} from '../lib/adminApi';
import Modal from '../components/Modal';
import SkeletonRows from '../components/SkeletonRows';
import RecipeThumb from '../components/RecipeThumb';
import Avatar from '../components/Avatar';
import { useToast } from '../contexts/ToastContext';
import { useConfirm } from '../contexts/ConfirmContext';
import { getErrorMessage } from '../lib/errors';

const statusFilters = [
  { value: undefined, label: 'Toutes' },
  { value: 'published', label: 'Publiées' },
  { value: 'draft', label: 'Brouillons' },
  { value: 'archived', label: 'Archivées' },
];

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
  Icon: typeof BookOpen;
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

function RecipeDetailModal({
  recipeId,
  onClose,
}: {
  recipeId: number;
  onClose: () => void;
}) {
  const [recipe, setRecipe] = useState<AdminRecipeDetail | null>(null);
  const [ingredients, setIngredients] = useState<RecipeIngredientRow[]>([]);
  const [steps, setSteps] = useState<RecipeStepRow[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getRecipeDetail(recipeId)
      .then((result) => {
        setRecipe(result.recipe);
        setIngredients(result.ingredients);
        setSteps(result.steps);
      })
      .catch((err) => setError(getErrorMessage(err)))
      .finally(() => setIsLoading(false));
  }, [recipeId]);

  return (
    <Modal title="Détail de la recette" onClose={onClose}>
      {isLoading && <SkeletonRows count={2} />}
      {error && (
        <div className="empty-state" style={{ color: 'var(--color-danger)' }}>
          Erreur : {error}
        </div>
      )}

      {recipe && (
        <div>
          <div style={{ display: 'flex', gap: 14, marginBottom: 14 }}>
            <RecipeThumb
              imageUrl={recipe.image_url}
              isVideo={recipe.source_type === 'video'}
              size={64}
            />
            <div>
              <h3 style={{ margin: '0 0 4px' }}>{recipe.title}</h3>
              <div
                style={{
                  fontSize: 12,
                  color: 'var(--color-text-muted)',
                  marginBottom: 6,
                }}
              >
                Par{' '}
                {recipe.profiles?.full_name || recipe.profiles?.username || '—'}
                {' · '}
                {recipe.categories?.name ?? 'Sans catégorie'}
              </div>
              <StatusBadge status={recipe.status} />
            </div>
          </div>

          {recipe.description && (
            <p style={{ fontSize: 14, marginBottom: 12 }}>{recipe.description}</p>
          )}

          <div style={{ display: 'flex', gap: 16, fontSize: 13, marginBottom: 16, color: 'var(--color-text-muted)' }}>
            {recipe.prep_time != null && <span>Préparation : {recipe.prep_time} min</span>}
            {recipe.cook_time != null && <span>Cuisson : {recipe.cook_time} min</span>}
            {recipe.servings != null && <span>{recipe.servings} portions</span>}
            {recipe.difficulty && <span>Difficulté : {recipe.difficulty}</span>}
          </div>

          {ingredients.length > 0 && (
            <>
              <h4 style={{ fontSize: 13, marginBottom: 6 }}>Ingrédients</h4>
              <ul style={{ margin: '0 0 16px', paddingLeft: 20, fontSize: 13 }}>
                {ingredients.map((item, index) => (
                  <li key={index}>
                    {item.ingredients?.name ?? 'Ingrédient'}
                    {item.quantity ? ` — ${item.quantity}` : ''}
                    {item.unit ? ` ${item.unit}` : ''}
                  </li>
                ))}
              </ul>
            </>
          )}

          {steps.length > 0 && (
            <>
              <h4 style={{ fontSize: 13, marginBottom: 6 }}>Étapes</h4>
              <ol style={{ margin: 0, paddingLeft: 20, fontSize: 13 }}>
                {steps.map((step) => (
                  <li key={step.step_number} style={{ marginBottom: 4 }}>
                    {step.instruction}
                  </li>
                ))}
              </ol>
            </>
          )}
        </div>
      )}
    </Modal>
  );
}

export default function RecipesPage() {
  const { showSuccess, showError } = useToast();
  const confirm = useConfirm();
  const [recipes, setRecipes] = useState<AdminRecipe[]>([]);
  const [filter, setFilter] = useState<string | undefined>(undefined);
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<number | null>(null);
  const [detailId, setDetailId] = useState<number | null>(null);

  async function load(statusFilter?: string) {
    setIsLoading(true);
    setError(null);

    try {
      const data = await getAllRecipes(statusFilter);
      setRecipes(data);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load(filter);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filter]);

  const filteredRecipes = useMemo(() => {
    const term = search.trim().toLowerCase();
    if (!term) return recipes;

    return recipes.filter((r) => {
      const author =
        r.profiles?.full_name?.toLowerCase() ??
        r.profiles?.username?.toLowerCase() ??
        '';
      return r.title.toLowerCase().includes(term) || author.includes(term);
    });
  }, [recipes, search]);

  const counts = useMemo(() => {
    return {
      total: recipes.length,
      published: recipes.filter((r) => r.status === 'published').length,
      draft: recipes.filter((r) => r.status === 'draft').length,
      archived: recipes.filter((r) => r.status === 'archived').length,
    };
  }, [recipes]);

  async function handleSetStatus(recipeId: number, status: string) {
    setBusyId(recipeId);
    try {
      await setRecipeStatus(recipeId, status);
      showSuccess('Statut mis à jour.');
      await load(filter);
    } catch (err) {
      showError(getErrorMessage(err));
    } finally {
      setBusyId(null);
    }
  }

  async function handleDelete(recipeId: number, title: string) {
    const ok = await confirm({
      title: 'Supprimer cette recette ?',
      message: `« ${title} » sera supprimée définitivement. Cette action est irréversible.`,
      confirmLabel: 'Supprimer',
      danger: true,
    });

    if (!ok) return;

    setBusyId(recipeId);
    try {
      await deleteRecipe(recipeId);
      showSuccess('Recette supprimée.');
      await load(filter);
    } catch (err) {
      showError(getErrorMessage(err));
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div>
      <div className="admin-page-header">
        <h1>Recettes</h1>
        <button className="btn btn-outline btn-sm" onClick={() => load(filter)}>
          <RefreshCw size={14} />
          Actualiser
        </button>
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
          Icon={BookOpen}
          color="var(--color-primary)"
          bg="#fdece3"
        />
        <MiniStat
          label="Publiées"
          value={counts.published}
          Icon={CheckCircle2}
          color="var(--color-green)"
          bg="var(--color-green-bg)"
        />
        <MiniStat
          label="Brouillons"
          value={counts.draft}
          Icon={FileEdit}
          color="var(--color-orange)"
          bg="var(--color-orange-bg)"
        />
        <MiniStat
          label="Archivées"
          value={counts.archived}
          Icon={Archive}
          color="var(--color-text-muted)"
          bg="var(--color-surface-muted)"
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

      <div className="filters-row">
        {statusFilters.map((f) => (
          <button
            key={f.label}
            className={`filter-chip${filter === f.value ? ' active' : ''}`}
            onClick={() => setFilter(f.value)}
          >
            {f.label}
          </button>
        ))}
      </div>

      {isLoading && <SkeletonRows count={5} />}
      {error && (
        <div className="empty-state" style={{ color: 'var(--color-danger)' }}>
          Erreur : {error}
        </div>
      )}
      {!isLoading && !error && filteredRecipes.length === 0 && (
        <div className="empty-state">
          <BookOpen size={32} />
          Aucune recette ici.
        </div>
      )}

      {!isLoading && !error && filteredRecipes.length > 0 && (
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
            {filteredRecipes.map((recipe) => (
              <tr key={recipe.id}>
                <td style={{ cursor: 'pointer' }} onClick={() => setDetailId(recipe.id)}>
                  <RecipeThumb
                    imageUrl={recipe.image_url ?? null}
                    isVideo={recipe.source_type === 'video'}
                  />
                </td>
                <td
                  style={{ cursor: 'pointer', fontWeight: 600 }}
                  onClick={() => setDetailId(recipe.id)}
                >
                  {recipe.title}
                </td>
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
                    <button
                      className="btn btn-outline btn-sm"
                      onClick={() => setDetailId(recipe.id)}
                      title="Voir le détail"
                    >
                      <Eye size={13} />
                    </button>
                    {recipe.status !== 'published' && (
                      <button
                        className="btn btn-outline btn-sm"
                        disabled={busyId === recipe.id}
                        onClick={() =>
                          handleSetStatus(recipe.id, 'published')
                        }
                        title="Publier"
                      >
                        <Send size={13} />
                      </button>
                    )}
                    {recipe.status !== 'archived' && (
                      <button
                        className="btn btn-outline btn-sm"
                        disabled={busyId === recipe.id}
                        onClick={() =>
                          handleSetStatus(recipe.id, 'archived')
                        }
                        title="Archiver"
                      >
                        <Archive size={13} />
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

      {detailId !== null && (
        <RecipeDetailModal
          recipeId={detailId}
          onClose={() => setDetailId(null)}
        />
      )}
    </div>
  );
}