import { supabase } from './supabase';

/**
 * Centralise toutes les actions réservées aux administrateurs :
 * demandes créateur, modération des recettes/commentaires, gestion
 * des catégories et des utilisateurs.
 *
 * Chaque appel est revérifié côté base (les fonctions RPC
 * vérifient elles-mêmes que l'appelant est bien admin) — ce
 * module ne fait qu'exposer ces actions côté React. Calque exact
 * du repository Flutter équivalent (même RPC, mêmes tables), pour
 * que les deux interfaces restent cohérentes entre elles.
 */

// ============================================================
// AVATARS (bucket privé — URL signée à la demande, comme côté
// mobile)
// ============================================================

const avatarUrlCache = new Map<string, string>();

export async function getAvatarUrl(
  path: string | null | undefined,
): Promise<string | null> {
  if (!path) return null;

  const cached = avatarUrlCache.get(path);
  if (cached) return cached;

  const { data, error } = await supabase.storage
    .from('avatars')
    .createSignedUrl(path, 60 * 60);

  if (error || !data) return null;

  avatarUrlCache.set(path, data.signedUrl);
  return data.signedUrl;
}

const recipeImageUrlCache = new Map<string, string>();

export async function getRecipeImageUrl(
  path: string | null | undefined,
): Promise<string | null> {
  if (!path) return null;

  const cached = recipeImageUrlCache.get(path);
  if (cached) return cached;

  const { data, error } = await supabase.storage
    .from('recipe-images')
    .createSignedUrl(path, 60 * 60);

  if (error || !data) return null;

  recipeImageUrlCache.set(path, data.signedUrl);
  return data.signedUrl;
}

// ============================================================
// TABLEAU DE BORD
// ============================================================

export interface DashboardStats {
  totalUsers: number;
  totalCreators: number;
  totalRecipes: number;
  publishedRecipes: number;
  draftRecipes: number;
  pendingApplications: number;
  totalComments: number;
  hiddenComments: number;
  totalVideos: number;
}

async function countRows(
  table: string,
  filters?: Record<string, unknown>,
): Promise<number> {
  let query = supabase.from(table).select('*', { count: 'exact', head: true });

  if (filters) {
    for (const [key, value] of Object.entries(filters)) {
      query = query.eq(key, value);
    }
  }

  const { count, error } = await query;
  if (error) throw error;
  return count ?? 0;
}

export async function getDashboardStats(): Promise<DashboardStats> {
  const [
    totalUsers,
    totalCreators,
    totalRecipes,
    publishedRecipes,
    draftRecipes,
    pendingApplications,
    totalComments,
    hiddenComments,
    totalVideos,
  ] = await Promise.all([
    countRows('profiles'),
    countRows('profiles', { role: 'creator' }),
    countRows('recipes'),
    countRows('recipes', { status: 'published' }),
    countRows('recipes', { status: 'draft' }),
    countRows('profiles', { creator_status: 'pending' }),
    countRows('recipe_comments'),
    countRows('recipe_comments', { is_hidden: true }),
    countRows('recipes', { source_type: 'video' }),
  ]);

  return {
    totalUsers,
    totalCreators,
    totalRecipes,
    publishedRecipes,
    draftRecipes,
    pendingApplications,
    totalComments,
    hiddenComments,
    totalVideos,
  };
}

export async function getPendingCreatorApplicationsCount(): Promise<number> {
  return countRows('profiles', { creator_status: 'pending' });
}

/**
 * Compte les lignes créées après une date donnée. Sert à calculer
 * un vrai pourcentage d'évolution (période actuelle vs période
 * précédente), à partir de `created_at` — pas de données inventées.
 */
async function countCreatedSince(table: string, since: Date): Promise<number> {
  const { count, error } = await supabase
    .from(table)
    .select('*', { count: 'exact', head: true })
    .gte('created_at', since.toISOString());

  if (error) throw error;
  return count ?? 0;
}

export interface MonthlyChange {
  currentPeriod: number;
  previousPeriod: number;
  percent: number | null;
}

/**
 * Compare les 30 derniers jours aux 30 jours précédents pour une
 * table donnée. `percent` est `null` s'il n'y a rien à comparer
 * (évite d'afficher un faux "+100 %" trompeur).
 */
export async function getMonthlyChange(table: string): Promise<MonthlyChange> {
  const now = new Date();
  const start30 = new Date(now);
  start30.setDate(start30.getDate() - 30);
  const start60 = new Date(now);
  start60.setDate(start60.getDate() - 60);

  const [last30, last60] = await Promise.all([
    countCreatedSince(table, start30),
    countCreatedSince(table, start60),
  ]);

  const previousPeriod = last60 - last30;
  const percent =
    previousPeriod > 0
      ? Math.round(((last30 - previousPeriod) / previousPeriod) * 100)
      : null;

  return { currentPeriod: last30, previousPeriod, percent };
}

export interface SignupTrendPoint {
  date: string;
  label: string;
  count: number;
}

/** Nombre d'inscriptions par jour sur les 7 derniers jours. */
export async function getSignupTrend(): Promise<SignupTrendPoint[]> {
  const days: SignupTrendPoint[] = [];
  const now = new Date();

  for (let i = 6; i >= 0; i--) {
    const day = new Date(now);
    day.setDate(day.getDate() - i);
    days.push({
      date: day.toISOString().slice(0, 10),
      label: day.toLocaleDateString('fr-FR', {
        day: 'numeric',
        month: 'short',
      }),
      count: 0,
    });
  }

  const start = new Date(now);
  start.setDate(start.getDate() - 6);
  start.setHours(0, 0, 0, 0);

  const { data, error } = await supabase
    .from('profiles')
    .select('created_at')
    .gte('created_at', start.toISOString());

  if (error) throw error;

  for (const row of data ?? []) {
    const day = (row.created_at as string).slice(0, 10);
    const match = days.find((d) => d.date === day);
    if (match) match.count += 1;
  }

  return days;
}

export interface CategoryDistributionSlice {
  name: string;
  count: number;
}

/** Répartition des recettes publiées par catégorie. */
export async function getRecipeCategoryDistribution(): Promise<
  CategoryDistributionSlice[]
> {
  const { data, error } = await supabase
    .from('recipes')
    .select('categories ( name )')
    .eq('status', 'published');

  if (error) throw error;

  const counts = new Map<string, number>();

  for (const row of (data ?? []) as unknown as {
    categories: { name: string } | null;
  }[]) {
    const name = row.categories?.name ?? 'Sans catégorie';
    counts.set(name, (counts.get(name) ?? 0) + 1);
  }

  return Array.from(counts.entries())
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count);
}

export interface RecentRecipeRow {
  id: number;
  title: string;
  status: string;
  image_url: string | null;
  source_type: string;
  created_at: string;
  profiles: { full_name: string | null; username: string | null } | null;
  categories: { name: string } | null;
}

export async function getRecentRecipes(limit = 5): Promise<RecentRecipeRow[]> {
  const { data, error } = await supabase
    .from('recipes')
    .select(
      `
        id, title, status, image_url, source_type, created_at,
        profiles ( full_name, username ),
        categories ( name )
      `,
    )
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) throw error;
  return (data as unknown as RecentRecipeRow[]) ?? [];
}

export interface RecentUserRow {
  id: string;
  full_name: string | null;
  email: string | null;
  avatar_url: string | null;
  created_at: string;
}

export async function getRecentUsers(limit = 5): Promise<RecentUserRow[]> {
  const { data, error } = await supabase.rpc('admin_get_users_with_email');

  if (error) throw error;

  return ((data as AdminUser[]) ?? [])
    .slice(0, limit)
    .map((u) => ({
      id: u.id,
      full_name: u.full_name,
      email: u.email,
      avatar_url: u.avatar_url,
      created_at: u.created_at,
    }));
}

export type ActivityType =
  | 'new_recipe'
  | 'new_comment'
  | 'new_user'
  | 'new_video'
  | 'creator_application';

export interface ActivityItem {
  type: ActivityType;
  title: string;
  subtitle: string;
  date: string;
}

/**
 * Combine plusieurs tables (recettes, commentaires, utilisateurs,
 * demandes créateur) triées par date pour simuler un fil
 * d'activité — il n'existe pas de table "journal d'activité"
 * dédiée, donc ceci est reconstruit à la volée à partir des
 * horodatages déjà existants plutôt qu'inventé.
 */
export async function getRecentActivity(limit = 6): Promise<ActivityItem[]> {
  const [recipesRes, commentsRes, usersRes, applicationsRes] =
    await Promise.all([
      supabase
        .from('recipes')
        .select('title, source_type, status, created_at')
        .eq('status', 'published')
        .order('created_at', { ascending: false })
        .limit(limit),
      supabase
        .from('recipe_comments')
        .select('content, created_at, recipes ( title )')
        .order('created_at', { ascending: false })
        .limit(limit),
      supabase
        .from('profiles')
        .select('full_name, username, created_at')
        .order('created_at', { ascending: false })
        .limit(limit),
      supabase
        .from('profiles')
        .select('full_name, username, created_at')
        .eq('creator_status', 'pending')
        .order('created_at', { ascending: false })
        .limit(limit),
    ]);

  const items: ActivityItem[] = [];

  for (const r of recipesRes.data ?? []) {
    items.push({
      type: r.source_type === 'video' ? 'new_video' : 'new_recipe',
      title:
        r.source_type === 'video'
          ? 'Nouvelle vidéo ajoutée'
          : 'Nouvelle recette publiée',
      subtitle: r.title,
      date: r.created_at,
    });
  }

  for (const c of (commentsRes.data ?? []) as unknown as {
    content: string;
    created_at: string;
    recipes: { title: string } | null;
  }[]) {
    items.push({
      type: 'new_comment',
      title: 'Nouveau commentaire',
      subtitle: `Sur la recette « ${c.recipes?.title ?? '—'} »`,
      date: c.created_at,
    });
  }

  for (const u of usersRes.data ?? []) {
    items.push({
      type: 'new_user',
      title: 'Utilisateur inscrit',
      subtitle: u.full_name || u.username || 'Nouvel utilisateur',
      date: u.created_at,
    });
  }

  for (const a of applicationsRes.data ?? []) {
    items.push({
      type: 'creator_application',
      title: 'Demande créateur',
      subtitle: a.full_name || a.username || 'Nouvelle demande',
      date: a.created_at,
    });
  }

  return items
    .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())
    .slice(0, limit);
}

// ============================================================
// DEMANDES CRÉATEUR
// ============================================================

export interface CreatorApplication {
  id: string;
  full_name: string | null;
  username: string | null;
  avatar_url: string | null;
  specialty: string | null;
  application_note: string | null;
  created_at: string;
}

export async function getPendingCreatorApplications(): Promise<
  CreatorApplication[]
> {
  const { data, error } = await supabase
    .from('profiles')
    .select(
      'id, full_name, username, avatar_url, specialty, application_note, created_at',
    )
    .eq('creator_status', 'pending')
    .order('created_at', { ascending: true });

  if (error) throw error;
  return data ?? [];
}

export async function reviewCreatorApplication(
  userId: string,
  approve: boolean,
): Promise<void> {
  const { error } = await supabase.rpc('admin_review_creator_application', {
    p_user_id: userId,
    p_approve: approve,
  });

  if (error) throw error;
}

// ============================================================
// RECETTES (toutes, pas seulement celles de l'admin)
// ============================================================

export interface AdminRecipe {
  id: number;
  title: string;
  status: string;
  source_type: string;
  image_url: string | null;
  created_at: string;
  author_id: string;
  profiles: { full_name: string | null; username: string | null } | null;
}

export async function getAllRecipes(
  statusFilter?: string,
): Promise<AdminRecipe[]> {
  let query = supabase.from('recipes').select(
    `
      id,
      title,
      status,
      source_type,
      image_url,
      created_at,
      author_id,
      profiles ( full_name, username )
    `,
  );

  if (statusFilter) {
    query = query.eq('status', statusFilter);
  }

  const { data, error } = await query.order('created_at', {
    ascending: false,
  });

  if (error) throw error;
  return (data as unknown as AdminRecipe[]) ?? [];
}

export async function setRecipeStatus(
  recipeId: number,
  status: string,
): Promise<void> {
  const { error } = await supabase.rpc('admin_set_recipe_status', {
    p_recipe_id: recipeId,
    p_status: status,
  });

  if (error) throw error;
}

export async function deleteRecipe(recipeId: number): Promise<void> {
  const { error } = await supabase.rpc('admin_delete_recipe', {
    p_recipe_id: recipeId,
  });

  if (error) throw error;
}

export interface AdminRecipeDetail extends AdminRecipe {
  description: string | null;
  prep_time: number | null;
  cook_time: number | null;
  servings: number | null;
  difficulty: string | null;
  image_url: string | null;
  video_url: string | null;
  categories: { name: string } | null;
}

export interface RecipeIngredientRow {
  quantity: string | null;
  unit: string | null;
  ingredients: { name: string } | null;
}

export interface RecipeStepRow {
  step_number: number;
  instruction: string;
}

export async function getRecipeDetail(recipeId: number): Promise<{
  recipe: AdminRecipeDetail;
  ingredients: RecipeIngredientRow[];
  steps: RecipeStepRow[];
}> {
  const [{ data: recipe, error: recipeError }, ingredientsResult, stepsResult] =
    await Promise.all([
      supabase
        .from('recipes')
        .select(
          `
            id, title, status, source_type, created_at, author_id,
            description, prep_time, cook_time, servings, difficulty,
            image_url, video_url,
            profiles ( full_name, username ),
            categories ( name )
          `,
        )
        .eq('id', recipeId)
        .single(),
      supabase
        .from('recipe_ingredients')
        .select('quantity, unit, ingredients ( name )')
        .eq('recipe_id', recipeId),
      supabase
        .from('recipe_steps')
        .select('step_number, instruction')
        .eq('recipe_id', recipeId)
        .order('step_number', { ascending: true }),
    ]);

  if (recipeError) throw recipeError;
  if (ingredientsResult.error) throw ingredientsResult.error;
  if (stepsResult.error) throw stepsResult.error;

  return {
    recipe: recipe as unknown as AdminRecipeDetail,
    ingredients: (ingredientsResult.data as unknown as RecipeIngredientRow[]) ?? [],
    steps: (stepsResult.data as unknown as RecipeStepRow[]) ?? [],
  };
}

// ============================================================
// COMMENTAIRES
// ============================================================

export interface AdminComment {
  id: number;
  content: string;
  is_hidden: boolean;
  created_at: string;
  recipe_id: number;
  user_id: string;
  profiles: { full_name: string | null; username: string | null } | null;
  recipes: { title: string } | null;
}

export async function getAllComments(
  onlyHidden = false,
): Promise<AdminComment[]> {
  let query = supabase.from('recipe_comments').select(
    `
      id,
      content,
      is_hidden,
      created_at,
      recipe_id,
      user_id,
      profiles ( full_name, username ),
      recipes ( title )
    `,
  );

  if (onlyHidden) {
    query = query.eq('is_hidden', true);
  }

  const { data, error } = await query.order('created_at', {
    ascending: false,
  });

  if (error) throw error;
  return (data as unknown as AdminComment[]) ?? [];
}

export async function setCommentHidden(
  commentId: number,
  hidden: boolean,
): Promise<void> {
  const { error } = await supabase.rpc('admin_set_comment_hidden', {
    p_comment_id: commentId,
    p_hidden: hidden,
  });

  if (error) throw error;
}

// ============================================================
// CATÉGORIES
// ============================================================

export interface AdminCategory {
  id: number;
  name: string;
  image_url: string | null;
}

export async function getAllCategories(): Promise<AdminCategory[]> {
  const { data, error } = await supabase
    .from('categories')
    .select()
    .order('name', { ascending: true });

  if (error) throw error;
  return data ?? [];
}

export async function createCategory(
  name: string,
  imageUrl?: string,
): Promise<void> {
  const { error } = await supabase
    .from('categories')
    .insert({ name, image_url: imageUrl ?? null });

  if (error) throw error;
}

export async function updateCategory(
  categoryId: number,
  name: string,
  imageUrl?: string,
): Promise<void> {
  const payload: Record<string, unknown> = { name };
  if (imageUrl !== undefined) payload.image_url = imageUrl;

  const { error } = await supabase
    .from('categories')
    .update(payload)
    .eq('id', categoryId);

  if (error) throw error;
}

export async function deleteCategory(categoryId: number): Promise<void> {
  const { error } = await supabase
    .from('categories')
    .delete()
    .eq('id', categoryId);

  if (error) throw error;
}

// ============================================================
// INGRÉDIENTS
// ============================================================

export interface AdminIngredient {
  id: number;
  name: string;
}

export async function getAllIngredients(): Promise<AdminIngredient[]> {
  const { data, error } = await supabase
    .from('ingredients')
    .select('id, name')
    .order('name', { ascending: true });

  if (error) throw error;
  return data ?? [];
}

export async function createIngredient(name: string): Promise<void> {
  const { error } = await supabase.from('ingredients').insert({ name });
  if (error) throw error;
}

export async function updateIngredient(
  ingredientId: number,
  name: string,
): Promise<void> {
  const { error } = await supabase
    .from('ingredients')
    .update({ name })
    .eq('id', ingredientId);

  if (error) throw error;
}

export async function deleteIngredient(ingredientId: number): Promise<void> {
  const { error } = await supabase
    .from('ingredients')
    .delete()
    .eq('id', ingredientId);

  if (error) throw error;
}

// ============================================================
// UTILISATEURS
// ============================================================

export interface AdminUser {
  id: string;
  full_name: string | null;
  username: string | null;
  avatar_url: string | null;
  email: string | null;
  role: string;
  creator_status: string | null;
  created_at: string;
}

export async function getAllUsers(): Promise<AdminUser[]> {
  const { data, error } = await supabase.rpc('admin_get_users_with_email');

  if (error) throw error;
  return (data as AdminUser[]) ?? [];
}

export async function setUserRole(
  userId: string,
  role: string,
): Promise<void> {
  const { error } = await supabase.rpc('set_user_role', {
    target_user_id: userId,
    new_role: role,
  });

  if (error) throw error;
}

export async function getUserRecipeCount(userId: string): Promise<number> {
  const { count, error } = await supabase
    .from('recipes')
    .select('*', { count: 'exact', head: true })
    .eq('author_id', userId);

  if (error) throw error;
  return count ?? 0;
}