import { useEffect, useState } from 'react';
import { Plus, Tag, Pencil, Trash2 } from 'lucide-react';
import {
  getAllCategories,
  createCategory,
  updateCategory,
  deleteCategory,
  type AdminCategory,
} from '../lib/adminApi';
import SkeletonRows from '../components/SkeletonRows';
import { useToast } from '../contexts/ToastContext';
import { useConfirm } from '../contexts/ConfirmContext';
import { getErrorMessage } from '../lib/errors';

export default function CategoriesPage() {
  const { showSuccess, showError } = useToast();
  const confirm = useConfirm();
  const [categories, setCategories] = useState<AdminCategory[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [editingId, setEditingId] = useState<number | 'new' | null>(null);
  const [formName, setFormName] = useState('');
  const [formImageUrl, setFormImageUrl] = useState('');
  const [isSaving, setIsSaving] = useState(false);

  async function load() {
    setIsLoading(true);
    setError(null);

    try {
      const data = await getAllCategories();
      setCategories(data);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  function startCreate() {
    setEditingId('new');
    setFormName('');
    setFormImageUrl('');
  }

  function startEdit(category: AdminCategory) {
    setEditingId(category.id);
    setFormName(category.name);
    setFormImageUrl(category.image_url ?? '');
  }

  function cancelEdit() {
    setEditingId(null);
  }

  async function handleSave() {
    if (!formName.trim()) return;

    setIsSaving(true);
    try {
      if (editingId === 'new') {
        await createCategory(formName.trim(), formImageUrl.trim() || undefined);
        showSuccess('Catégorie créée.');
      } else if (typeof editingId === 'number') {
        await updateCategory(
          editingId,
          formName.trim(),
          formImageUrl.trim() || undefined,
        );
        showSuccess('Catégorie modifiée.');
      }

      setEditingId(null);
      await load();
    } catch (err) {
      showError(getErrorMessage(err));
    } finally {
      setIsSaving(false);
    }
  }

  async function handleDelete(category: AdminCategory) {
    const ok = await confirm({
      title: 'Supprimer cette catégorie ?',
      message: `« ${category.name} » sera supprimée définitivement.`,
      confirmLabel: 'Supprimer',
      danger: true,
    });

    if (!ok) return;

    try {
      await deleteCategory(category.id);
      showSuccess('Catégorie supprimée.');
      await load();
    } catch (err) {
      showError(getErrorMessage(err));
    }
  }

  return (
    <div>
      <div className="admin-page-header">
        <h1>Catégories</h1>
        <button className="btn btn-primary btn-sm" onClick={startCreate}>
          <Plus size={14} />
          Nouvelle catégorie
        </button>
      </div>

      {editingId !== null && (
        <div className="card">
          <div className="login-field">
            <label>Nom</label>
            <input
              value={formName}
              onChange={(e) => setFormName(e.target.value)}
              placeholder="Ex. Petit-déjeuner"
              autoFocus
            />
          </div>
          <div className="login-field">
            <label>URL de l’image (optionnel)</label>
            <input
              value={formImageUrl}
              onChange={(e) => setFormImageUrl(e.target.value)}
              placeholder="https://..."
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
            <button className="btn btn-outline btn-sm" onClick={cancelEdit}>
              Annuler
            </button>
          </div>
        </div>
      )}

      {isLoading && <SkeletonRows count={4} />}
      {error && (
        <div className="empty-state" style={{ color: 'var(--color-danger)' }}>
          Erreur : {error}
        </div>
      )}
      {!isLoading && !error && categories.length === 0 && (
        <div className="empty-state">
          <Tag size={32} />
          Aucune catégorie pour l’instant.
        </div>
      )}

      {!isLoading && !error && categories.length > 0 && (
        <table className="data-table">
          <thead>
            <tr>
              <th>Nom</th>
              <th>Image</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {categories.map((category) => (
              <tr key={category.id}>
                <td>{category.name}</td>
                <td
                  style={{
                    fontSize: 12,
                    color: 'var(--color-text-muted)',
                    maxWidth: 260,
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap',
                  }}
                >
                  {category.image_url ?? '—'}
                </td>
                <td>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button
                      className="btn btn-outline btn-sm"
                      onClick={() => startEdit(category)}
                    >
                      <Pencil size={13} />
                      Modifier
                    </button>
                    <button
                      className="btn btn-danger btn-sm"
                      onClick={() => handleDelete(category)}
                    >
                      <Trash2 size={13} />
                      Supprimer
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
