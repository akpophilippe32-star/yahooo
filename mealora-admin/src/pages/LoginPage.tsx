import { useState, type FormEvent } from 'react';
import { AlertCircle } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';

export default function LoginPage() {
  const { signIn } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setIsLoading(true);

    try {
      await signIn(email, password);
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : 'Impossible de se connecter.',
      );
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <div className="login-screen">
      <form className="login-card" onSubmit={handleSubmit}>
        <div className="logo" />
        <h1>Mealora — Admin</h1>
        <p>Réservé aux comptes administrateur.</p>

        {error && (
          <div className="login-error">
            <AlertCircle size={16} />
            {error}
          </div>
        )}

        <div className="login-field">
          <label htmlFor="email">Adresse e-mail</label>
          <input
            id="email"
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="email"
          />
        </div>

        <div className="login-field">
          <label htmlFor="password">Mot de passe</label>
          <input
            id="password"
            type="password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
          />
        </div>

        <button
          type="submit"
          className="btn btn-primary"
          style={{ width: '100%', justifyContent: 'center' }}
          disabled={isLoading}
        >
          {isLoading ? 'Connexion...' : 'Se connecter'}
        </button>
      </form>
    </div>
  );
}
