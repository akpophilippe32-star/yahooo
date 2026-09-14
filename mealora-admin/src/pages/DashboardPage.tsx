import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from 'recharts';
import {
  BookOpen,
  Users,
  MessageSquare,
  Video,
  TrendingUp,
  TrendingDown,
  Calendar,
  ArrowRight,
  Zap,
  UserPlus,
  ChevronRight,
  PlayCircle,
  Flag,
  UserCheck,
} from 'lucide-react';
import {
  getDashboardStats,
  getMonthlyChange,
  getSignupTrend,
  getRecipeCategoryDistribution,
  getRecentRecipes,
  getRecentUsers,
  getRecentActivity,
  getRecipeImageUrl,
  type DashboardStats,
  type MonthlyChange,
  type SignupTrendPoint,
  type CategoryDistributionSlice,
  type RecentRecipeRow,
  type RecentUserRow,
  type ActivityItem,
  type ActivityType,
} from '../lib/adminApi';
import Avatar from '../components/Avatar';
import SkeletonRows from '../components/SkeletonRows';
import { getErrorMessage } from '../lib/errors';

const DONUT_COLORS = [
  '#16a34a',
  '#2563eb',
  '#9333ea',
  '#ec4899',
  '#94a3b8',
  '#ea580c',
];

function StatusBadge({ status }: { status: string }) {
  const map: Record<string, { label: string; className: string }> = {
    published: { label: 'Publié', className: 'badge-green' },
    draft: { label: 'En attente', className: 'badge-amber' },
    archived: { label: 'Archivée', className: 'badge-gray' },
  };

  const info = map[status] ?? { label: status, className: 'badge-gray' };
  return <span className={`badge ${info.className}`}>{info.label}</span>;
}

function StatCard({
  label,
  value,
  change,
  Icon,
  color,
  bg,
}: {
  label: string;
  value: number;
  change: MonthlyChange | null;
  Icon: typeof BookOpen;
  color: string;
  bg: string;
}) {
  return (
    <div className="stat-card">
      <div className="stat-icon" style={{ background: bg, color }}>
        <Icon size={20} />
      </div>
      <div className="stat-label">{label}</div>
      <div className="stat-value">{value.toLocaleString('fr-FR')}</div>
      {change && change.percent !== null && (
        <div
          className={`stat-change ${change.percent >= 0 ? 'positive' : 'negative'}`}
        >
          {change.percent >= 0 ? (
            <TrendingUp size={13} />
          ) : (
            <TrendingDown size={13} />
          )}
          {change.percent >= 0 ? '+' : ''}
          {change.percent}% ce mois
        </div>
      )}
    </div>
  );
}

function RecipeThumb({
  imageUrl,
  isVideo,
}: {
  imageUrl: string | null;
  isVideo: boolean;
}) {
  const [url, setUrl] = useState<string | null>(null);

  useEffect(() => {
    if (isVideo || !imageUrl) return;
    getRecipeImageUrl(imageUrl).then(setUrl).catch(() => setUrl(null));
  }, [imageUrl, isVideo]);

  if (isVideo) {
    return (
      <div
        className="recipe-thumb"
        style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}
      >
        <PlayCircle size={18} color="var(--color-text-muted)" />
      </div>
    );
  }

  return url ? (
    <img src={url} alt="" className="recipe-thumb" />
  ) : (
    <div className="recipe-thumb skeleton" />
  );
}

const activityIconMap: Record<
  ActivityType,
  { Icon: typeof BookOpen; color: string; bg: string }
> = {
  new_recipe: { Icon: BookOpen, color: 'var(--color-green)', bg: 'var(--color-green-bg)' },
  new_video: { Icon: PlayCircle, color: 'var(--color-purple)', bg: 'var(--color-purple-bg)' },
  new_comment: { Icon: MessageSquare, color: 'var(--color-orange)', bg: 'var(--color-orange-bg)' },
  new_user: { Icon: UserPlus, color: 'var(--color-blue)', bg: 'var(--color-blue-bg)' },
  creator_application: { Icon: UserCheck, color: 'var(--color-primary)', bg: '#fdece3' },
};

function timeAgo(iso: string): string {
  const diffMs = Date.now() - new Date(iso).getTime();
  const minutes = Math.floor(diffMs / 60000);
  if (minutes < 1) return 'à l’instant';
  if (minutes < 60) return `il y a ${minutes} min`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `il y a ${hours} h`;
  const days = Math.floor(hours / 24);
  return `il y a ${days} j`;
}

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [recipesChange, setRecipesChange] = useState<MonthlyChange | null>(null);
  const [usersChange, setUsersChange] = useState<MonthlyChange | null>(null);
  const [commentsChange, setCommentsChange] = useState<MonthlyChange | null>(null);
  const [videosChange, setVideosChange] = useState<MonthlyChange | null>(null);
  const [trend, setTrend] = useState<SignupTrendPoint[]>([]);
  const [distribution, setDistribution] = useState<CategoryDistributionSlice[]>([]);
  const [recentRecipes, setRecentRecipes] = useState<RecentRecipeRow[]>([]);
  const [recentUsers, setRecentUsers] = useState<RecentUserRow[]>([]);
  const [activity, setActivity] = useState<ActivityItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    setIsLoading(true);
    setError(null);

    try {
      const [
        statsData,
        recipesChangeData,
        usersChangeData,
        commentsChangeData,
        videosChangeData,
        trendData,
        distributionData,
        recentRecipesData,
        recentUsersData,
        activityData,
      ] = await Promise.all([
        getDashboardStats(),
        getMonthlyChange('recipes'),
        getMonthlyChange('profiles'),
        getMonthlyChange('recipe_comments'),
        getMonthlyChange('recipes'),
        getSignupTrend(),
        getRecipeCategoryDistribution(),
        getRecentRecipes(5),
        getRecentUsers(4),
        getRecentActivity(5),
      ]);

      setStats(statsData);
      setRecipesChange(recipesChangeData);
      setUsersChange(usersChangeData);
      setCommentsChange(commentsChangeData);
      setVideosChange(videosChangeData);
      setTrend(trendData);
      setDistribution(distributionData);
      setRecentRecipes(recentRecipesData);
      setRecentUsers(recentUsersData);
      setActivity(activityData);
    } catch (err) {
      setError(getErrorMessage(err));
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  const today = new Date().toLocaleDateString('fr-FR', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });

  const totalForDistribution = distribution.reduce((sum, d) => sum + d.count, 0);

  if (error) {
    return (
      <div className="empty-state" style={{ color: 'var(--color-danger)' }}>
        Erreur : {error}
      </div>
    );
  }

  return (
    <div>
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'flex-start',
          marginBottom: 24,
        }}
      >
        <div className="dashboard-greeting">
          <h1>Bonjour ! 👋</h1>
          <p>Voici un aperçu de votre plateforme Mealora</p>
        </div>
        <div className="dashboard-date">
          <Calendar size={15} />
          {today}
        </div>
      </div>

      {isLoading ? (
        <SkeletonRows count={4} />
      ) : (
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))',
            gap: 14,
            marginBottom: 20,
          }}
        >
          <StatCard
            label="Recettes publiées"
            value={stats?.publishedRecipes ?? 0}
            change={recipesChange}
            Icon={BookOpen}
            color="var(--color-green)"
            bg="var(--color-green-bg)"
          />
          <StatCard
            label="Utilisateurs inscrits"
            value={stats?.totalUsers ?? 0}
            change={usersChange}
            Icon={Users}
            color="var(--color-blue)"
            bg="var(--color-blue-bg)"
          />
          <StatCard
            label="Commentaires"
            value={stats?.totalComments ?? 0}
            change={commentsChange}
            Icon={MessageSquare}
            color="var(--color-orange)"
            bg="var(--color-orange-bg)"
          />
          <StatCard
            label="Vidéos"
            value={stats?.totalVideos ?? 0}
            change={videosChange}
            Icon={Video}
            color="var(--color-purple)"
            bg="var(--color-purple-bg)"
          />
        </div>
      )}

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1.6fr 1fr',
          gap: 16,
          marginBottom: 16,
          alignItems: 'stretch',
        }}
      >
        <div className="card" style={{ margin: 0 }}>
          <h3 className="panel-title">
            <Users size={16} color="var(--color-green)" />
            Évolution des inscriptions
          </h3>
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={trend}>
              <defs>
                <linearGradient id="signupGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#16a34a" stopOpacity={0.35} />
                  <stop offset="100%" stopColor="#16a34a" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="var(--color-border)" />
              <XAxis
                dataKey="label"
                tick={{ fontSize: 11, fill: 'var(--color-text-muted)' }}
                axisLine={false}
                tickLine={false}
              />
              <YAxis
                tick={{ fontSize: 11, fill: 'var(--color-text-muted)' }}
                axisLine={false}
                tickLine={false}
                allowDecimals={false}
              />
              <Tooltip
                contentStyle={{
                  borderRadius: 10,
                  border: '1px solid var(--color-border)',
                  fontSize: 12,
                }}
              />
              <Area
                type="monotone"
                dataKey="count"
                stroke="#16a34a"
                strokeWidth={2}
                fill="url(#signupGradient)"
                name="Inscriptions"
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        <div className="card" style={{ margin: 0 }}>
          <h3 className="panel-title">
            <BookOpen size={16} color="var(--color-primary)" />
            Répartition des recettes
          </h3>
          {distribution.length === 0 ? (
            <div className="empty-state">Aucune recette publiée.</div>
          ) : (
            <>
              <ResponsiveContainer width="100%" height={160}>
                <PieChart>
                  <Pie
                    data={distribution}
                    dataKey="count"
                    nameKey="name"
                    innerRadius={45}
                    outerRadius={70}
                    paddingAngle={2}
                  >
                    {distribution.map((_, index) => (
                      <Cell
                        key={index}
                        fill={DONUT_COLORS[index % DONUT_COLORS.length]}
                      />
                    ))}
                  </Pie>
                  <Tooltip
                    contentStyle={{
                      borderRadius: 10,
                      border: '1px solid var(--color-border)',
                      fontSize: 12,
                    }}
                  />
                </PieChart>
              </ResponsiveContainer>
              <div style={{ marginTop: 8 }}>
                {distribution.slice(0, 6).map((slice, index) => (
                  <div
                    key={slice.name}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 8,
                      fontSize: 12,
                      padding: '4px 0',
                    }}
                  >
                    <span
                      style={{
                        width: 8,
                        height: 8,
                        borderRadius: '50%',
                        background: DONUT_COLORS[index % DONUT_COLORS.length],
                        flexShrink: 0,
                      }}
                    />
                    <span style={{ flex: 1, color: 'var(--color-text-muted)' }}>
                      {slice.name}
                    </span>
                    <strong>
                      {totalForDistribution > 0
                        ? Math.round((slice.count / totalForDistribution) * 100)
                        : 0}
                      %
                    </strong>
                  </div>
                ))}
              </div>
            </>
          )}
        </div>
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1.6fr 1fr',
          gap: 16,
          marginBottom: 16,
          alignItems: 'start',
        }}
      >
        <div className="card" style={{ margin: 0 }}>
          <div className="panel-header">
            <h3 className="panel-title">
              <BookOpen size={16} color="var(--color-primary)" />
              Recettes récentes
            </h3>
            <Link to="/recipes" className="see-all-link">
              Voir tout <ArrowRight size={13} />
            </Link>
          </div>

          {isLoading ? (
            <SkeletonRows count={5} />
          ) : recentRecipes.length === 0 ? (
            <div className="empty-state">Aucune recette pour l’instant.</div>
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th></th>
                  <th>Titre</th>
                  <th>Catégorie</th>
                  <th>Auteur</th>
                  <th>Statut</th>
                </tr>
              </thead>
              <tbody>
                {recentRecipes.map((recipe) => (
                  <tr key={recipe.id}>
                    <td>
                      <RecipeThumb
                        imageUrl={recipe.image_url}
                        isVideo={recipe.source_type === 'video'}
                      />
                    </td>
                    <td>{recipe.title}</td>
                    <td>
                      <span className="badge badge-gray">
                        {recipe.categories?.name ?? '—'}
                      </span>
                    </td>
                    <td style={{ fontSize: 13, color: 'var(--color-text-muted)' }}>
                      {recipe.profiles?.full_name ||
                        recipe.profiles?.username ||
                        '—'}
                    </td>
                    <td>
                      <StatusBadge status={recipe.status} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        <div className="card" style={{ margin: 0 }}>
          <h3 className="panel-title">
            <Zap size={16} color="var(--color-secondary)" />
            Activité récente
          </h3>

          {isLoading ? (
            <SkeletonRows count={5} />
          ) : activity.length === 0 ? (
            <div className="empty-state">Aucune activité récente.</div>
          ) : (
            activity.map((item, index) => {
              const meta = activityIconMap[item.type];
              return (
                <div className="activity-item" key={index}>
                  <div
                    className="activity-icon"
                    style={{ background: meta.bg, color: meta.color }}
                  >
                    <meta.Icon size={15} />
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div className="activity-title">{item.title}</div>
                    <div
                      className="activity-subtitle"
                      style={{
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        whiteSpace: 'nowrap',
                      }}
                    >
                      {item.subtitle}
                    </div>
                  </div>
                  <div className="activity-time">{timeAgo(item.date)}</div>
                </div>
              );
            })
          )}
        </div>
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1.6fr 1fr',
          gap: 16,
          alignItems: 'start',
        }}
      >
        <div className="card" style={{ margin: 0 }}>
          <div className="panel-header">
            <h3 className="panel-title">
              <Users size={16} color="var(--color-blue)" />
              Derniers utilisateurs
            </h3>
            <Link to="/users" className="see-all-link">
              Voir tout <ArrowRight size={13} />
            </Link>
          </div>

          {isLoading ? (
            <SkeletonRows count={4} />
          ) : recentUsers.length === 0 ? (
            <div className="empty-state">Aucun utilisateur pour l’instant.</div>
          ) : (
            <table className="data-table">
              <thead>
                <tr>
                  <th></th>
                  <th>Nom</th>
                  <th>Email</th>
                  <th>Inscription</th>
                </tr>
              </thead>
              <tbody>
                {recentUsers.map((user) => (
                  <tr key={user.id}>
                    <td>
                      <Avatar path={user.avatar_url} size={30} />
                    </td>
                    <td>{user.full_name || 'Sans nom'}</td>
                    <td
                      style={{ fontSize: 13, color: 'var(--color-text-muted)' }}
                    >
                      {user.email ?? '—'}
                    </td>
                    <td style={{ fontSize: 13, color: 'var(--color-text-muted)' }}>
                      {new Date(user.created_at).toLocaleDateString('fr-FR')}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        <div className="card" style={{ margin: 0 }}>
          <h3 className="panel-title">
            <Zap size={16} color="var(--color-secondary)" />
            Actions rapides
          </h3>
          <div className="quick-actions-grid">
            <Link
              to="/recipes"
              className="quick-action-btn"
              style={{ background: 'var(--color-green)' }}
            >
              <BookOpen size={16} /> Voir les recettes
            </Link>
            <Link
              to="/users"
              className="quick-action-btn"
              style={{ background: 'var(--color-blue)' }}
            >
              <Users size={16} /> Gérer les utilisateurs
            </Link>
            <Link
              to="/creator-applications"
              className="quick-action-btn"
              style={{ background: 'var(--color-primary)' }}
            >
              <ChevronRight size={16} /> Demandes créateur
            </Link>
            <Link
              to="/comments"
              className="quick-action-btn"
              style={{ background: 'var(--color-purple)' }}
            >
              <Flag size={16} /> Voir les commentaires
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
