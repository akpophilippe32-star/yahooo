import { useEffect, useState } from 'react';
import { Carrot, Plus } from 'lucide-react';
import {
  getAllIngredients,
  createIngredient,
  updateIngredient,
  deleteIngredient,
  type AdminIngredient,
} from '../lib/adminApi';
import { useToast } from '../contexts/ToastContext';
import { useConfirm } from '../contexts/ConfirmContext';
import SkeletonRows from '../components/SkeletonRows';
import { getErrorMessage } from '../lib/errors';

export default function IngredientsPage() {
  const { showSuccess, showError } = useToast();
  const confirm = useConfirm();

  const [ingredients, setIngredients] = useState<AdminIngredient[]>([]);
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  const [editingId, setEditingId] = useState<number | 'new' | null>(null);
  const [formName, setFormName] = useState('');
  const [isSaving, setIsSaving] = useState(false);

  async function load() {
    setIsLoading(true);
    try {
      const data = await getAllIngredients();
      setIngredients(data);
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

  const filtered = ingredients.filter((i) =>
    i.name.toLowerCase().includes(search.trim().toLowerCase()),
  );

  function startCreate() {
    setEditingId('new');
    setFormName('');
  }

  function startEdit(ingredient: AdminIngredient) {
    setEditingId(ingredient.id);
    setFormName(ingredient.name);
  }

  async function handleSave() {
    if (!formName.trim()) return;
    setIsSaving(true);

    try {
      if (editingId === 'new') {
        await createIngredient(formName.trim());
        showSuccess('Ingrédient ajouté.');
      } else if (typeof editingId === 'number') {
        await updateIngredient(editingId, formName.trim());
        showSuccess('Ingrédient modifié.');
      }
      setEditingId(null);
      await load();
    } catch (err) {
      showError(getErrorMessage(err));
    } finally {
      setIsSaving(false);
    }
  }

  async function handleDelete(ingredient: AdminIngredient) {
    const ok = await confirm({
      title: 'Supprimer cet ingrédient ?',
      message: `« ${ingredient.name} » sera retiré du catalogue.`,
      danger: true,
    });
    if (!ok) return;

    try {
      await deleteIngredient(ingredient.id);
      showSuccess('Ingrédient supprimé.');
      await load();
    } catch (err) {
      showError(getErrorMessage(err));
    }
  }

  return (
    <div>
      <div className="admin-page-header">
        <h1>Ingrédients</h1>
        <button className="btn btn-primary btn-sm" onClick={startCreate}>
          <Plus size={14} /> Nouvel ingrédient
        </button>
      </div>

      {editingId !== null && (
        <div className="card">
          <div className="login-field">
            <label>Nom</label>
            <input
              value={formName}
              onChange={(e) => setFormName(e.target.value)}
              placeholder="Ex. Tomate"
              autoFocus
            />
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button
              className="btn btn-primary btn-sm"
              disabled={isSaving || !formName.trim()}
              onClick={handleSave}
            >
              {isSaving ? 'Enregistrement...' : 'Enregistrer'}
            </button>
            <button
              className="btn btn-outline btn-sm"
              onClick={() => setEditingId(null)}
            >
              Annuler
            </button>
          </div>
        </div>
      )}

      <input
        placeholder="Rechercher un ingrédient..."
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{ width: '100%', maxWidth: 360, marginBottom: 16 }}
      />

      {isLoading ? (
        <SkeletonRows count={6} />
      ) : filtered.length === 0 ? (
        <div className="empty-state">
          <Carrot size={32} />
          Aucun ingrédient pour l’instant.
        </div>
      ) : (
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))',
            gap: 10,
          }}
        >
          {filtered.map((ingredient) => (
            <div
              key={ingredient.id}
              className="card"
              style={{
                margin: 0,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: 12,
              }}
            >
              <span style={{ fontSize: 13, fontWeight: 600 }}>
                {ingredient.name}
              </span>
              <div style={{ display: 'flex', gap: 4 }}>
                <button
                  className="btn btn-outline btn-sm"
                  onClick={() => startEdit(ingredient)}
                >
                  Modifier
                </button>
                <button
                  className="btn btn-danger btn-sm"
                  onClick={() => handleDelete(ingredient)}
                >
                  Suppr.
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
