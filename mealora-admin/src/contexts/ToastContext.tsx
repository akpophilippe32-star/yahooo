import {
  createContext,
  useCallback,
  useContext,
  useState,
  type ReactNode,
} from 'react';
import { CheckCircle2, XCircle, X } from 'lucide-react';

interface Toast {
  id: number;
  message: string;
  type: 'success' | 'error';
}

interface ToastContextValue {
  showSuccess: (message: string) => void;
  showError: (message: string) => void;
}

const ToastContext = createContext<ToastContextValue | undefined>(undefined);

let nextId = 1;

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const dismiss = useCallback((id: number) => {
    setToasts((current) => current.filter((t) => t.id !== id));
  }, []);

  const push = useCallback(
    (message: string, type: Toast['type']) => {
      const id = nextId++;
      setToasts((current) => [...current, { id, message, type }]);
      setTimeout(() => dismiss(id), 5000);
    },
    [dismiss],
  );

  const showSuccess = useCallback((m: string) => push(m, 'success'), [push]);
  const showError = useCallback((m: string) => push(m, 'error'), [push]);

  return (
    <ToastContext.Provider value={{ showSuccess, showError }}>
      {children}
      <div className="toast-stack">
        {toasts.map((toast) => (
          <div key={toast.id} className={`toast toast-${toast.type}`}>
            {toast.type === 'success' ? (
              <CheckCircle2 size={18} />
            ) : (
              <XCircle size={18} />
            )}
            <span>{toast.message}</span>
            <button
              className="toast-close"
              onClick={() => dismiss(toast.id)}
              aria-label="Fermer"
            >
              <X size={14} />
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast() {
  const context = useContext(ToastContext);

  if (!context) {
    throw new Error('useToast doit être utilisé dans un <ToastProvider>.');
  }

  return context;
}
