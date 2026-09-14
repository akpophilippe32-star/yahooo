import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import type { ReactNode } from 'react';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { ToastProvider } from './contexts/ToastContext';
import { ConfirmProvider } from './contexts/ConfirmContext';
import { ThemeProvider } from './contexts/ThemeContext';
import AdminLayout from './components/AdminLayout';
import LoginPage from './pages/LoginPage';
import CreatorApplicationsPage from './pages/CreatorApplicationsPage';
import DashboardPage from './pages/DashboardPage';
import VideosPage from './pages/VideosPage';
import IngredientsPage from './pages/IngredientsPage';
import NotificationsPage from './pages/NotificationsPage';
import SettingsPage from './pages/SettingsPage';
import RecipesPage from './pages/RecipesPage';
import CommentsPage from './pages/CommentsPage';
import CategoriesPage from './pages/CategoriesPage';
import UsersPage from './pages/UsersPage';

/**
 * Protège tout ce qu'il contient : redirige vers /login si pas
 * connecté, et refuse l'accès (avec message clair) si connecté
 * mais pas administrateur — la vérification de rôle est de toute
 * façon revérifiée côté base par chaque fonction RPC, ceci n'est
 * qu'un confort d'interface.
 */
function RequireAdmin({ children }: { children: ReactNode }) {
  const { session, role, isLoading } = useAuth();

  if (isLoading) {
    return <div className="centered-loader">Chargement...</div>;
  }

  if (!session) {
    return <Navigate to="/login" replace />;
  }

  if (role !== 'admin') {
    return (
      <div className="centered-loader">
        Ce compte n’a pas les droits administrateur.
      </div>
    );
  }

  return <>{children}</>;
}

function LoginRoute() {
  const { session, isLoading } = useAuth();

  if (isLoading) {
    return <div className="centered-loader">Chargement...</div>;
  }

  if (session) {
    return <Navigate to="/" replace />;
  }

  return <LoginPage />;
}

export default function App() {
  return (
    <ThemeProvider>
      <ToastProvider>
        <ConfirmProvider>
          <AuthProvider>
            <BrowserRouter>
              <Routes>
                <Route path="/login" element={<LoginRoute />} />
                <Route
                  element={
                    <RequireAdmin>
                      <AdminLayout />
                    </RequireAdmin>
                  }
                >
                  <Route path="/" element={<DashboardPage />} />
                  <Route
                    path="/creator-applications"
                    element={<CreatorApplicationsPage />}
                  />
                  <Route path="/recipes" element={<RecipesPage />} />
                  <Route path="/videos" element={<VideosPage />} />
                  <Route path="/comments" element={<CommentsPage />} />
                  <Route path="/categories" element={<CategoriesPage />} />
                  <Route path="/ingredients" element={<IngredientsPage />} />
                  <Route path="/users" element={<UsersPage />} />
                  <Route
                    path="/notifications"
                    element={<NotificationsPage />}
                  />
                  <Route path="/settings" element={<SettingsPage />} />
                </Route>
              </Routes>
            </BrowserRouter>
          </AuthProvider>
        </ConfirmProvider>
      </ToastProvider>
    </ThemeProvider>
  );
}