import { NavLink, Outlet } from 'react-router-dom';
import {
  LayoutDashboard,
  UserCheck,
  BookOpen,
  MessageSquare,
  Tag,
  Users,
  Carrot,
  Video,
  Bell,
  Settings,
  LogOut,
  Search,
  ChefHat,
  Sun,
  Moon,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useTheme } from '../contexts/ThemeContext';
import Avatar from './Avatar';
import { getPendingCreatorApplicationsCount } from '../lib/adminApi';

const navItems = [
  { to: '/', label: 'Tableau de bord', Icon: LayoutDashboard, end: true },
  { to: '/recipes', label: 'Recettes', Icon: BookOpen },
  { to: '/videos', label: 'Vidéos', Icon: Video },
  { to: '/creator-applications', label: 'Demandes créateur', Icon: UserCheck },
  { to: '/users', label: 'Utilisateurs', Icon: Users },
  { to: '/categories', label: 'Catégories', Icon: Tag },
  { to: '/ingredients', label: 'Ingrédients', Icon: Carrot },
  { to: '/comments', label: 'Commentaires', Icon: MessageSquare },
  { to: '/notifications', label: 'Notifications', Icon: Bell },
  { to: '/settings', label: 'Paramètres', Icon: Settings },
];

export default function AdminLayout() {
  const { session, role, signOut } = useAuth();
  const { theme, toggleTheme } = useTheme();
  const email = session?.user.email ?? '';
  const displayName = email.split('@')[0] || 'Admin';
  const [pendingCount, setPendingCount] = useState(0);

  useEffect(() => {
    getPendingCreatorApplicationsCount()
      .then(setPendingCount)
      .catch(() => setPendingCount(0));
  }, []);

  return (
    <div className="admin-layout">
      <aside className="admin-sidebar">
        <div className="admin-sidebar-brand">
          <div className="logo">
            <ChefHat size={18} />
          </div>
          <div className="brand-text">
            <strong>Mealora</strong>
            <span>Bien manger, mieux vivre</span>
          </div>
        </div>

        <nav className="admin-nav">
          {navItems.map(({ to, label, Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                `admin-nav-item${isActive ? ' active' : ''}`
              }
            >
              <Icon size={18} />
              {label}
            </NavLink>
          ))}
        </nav>

        <div className="admin-sidebar-promo">
          <div className="promo-icon">
            <ChefHat size={16} />
          </div>
          <strong>Mealora Admin</strong>
          <p>Gérez votre plateforme de recettes en toute simplicité</p>
        </div>

        <div className="admin-sidebar-footer">
          <button
            className="btn btn-outline btn-sm"
            style={{ width: '100%', justifyContent: 'center' }}
            onClick={() => signOut()}
          >
            <LogOut size={14} />
            Se déconnecter
          </button>
        </div>
      </aside>

      <div className="admin-shell">
        <header className="admin-topbar">
          <div className="admin-topbar-search">
            <Search size={16} />
            <input placeholder="Rechercher une recette, un utilisateur..." />
          </div>

          <div className="admin-topbar-right">
            <button
              className="theme-toggle-btn"
              onClick={toggleTheme}
              title={
                theme === 'dark' ? 'Passer en thème clair' : 'Passer en thème sombre'
              }
              aria-label="Changer de thème"
            >
              {theme === 'dark' ? <Sun size={18} /> : <Moon size={18} />}
            </button>

            <NavLink to="/notifications" className="admin-topbar-bell">
              <Bell size={20} />
              {pendingCount > 0 && (
                <span className="badge-dot">{pendingCount}</span>
              )}
            </NavLink>

            <div className="admin-topbar-user">
              <Avatar path={null} size={36} />
              <div className="user-text">
                <strong style={{ textTransform: 'capitalize' }}>
                  {displayName}
                </strong>
                <span>{role === 'admin' ? 'Administrateur' : role}</span>
              </div>
            </div>
          </div>
        </header>

        <main className="admin-content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}