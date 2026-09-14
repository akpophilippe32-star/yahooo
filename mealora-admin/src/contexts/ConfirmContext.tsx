import {
  createContext,
  useCallback,
  useContext,
  useState,
  type ReactNode,
} from 'react';
import { AlertTriangle } from 'lucide-react';

interface ConfirmOptions {
  title: string;
  message: string;
  confirmLabel?: string;
  danger?: boolean;
}

interface ConfirmContextValue {
  confirm: (options: ConfirmOptions) => Promise<boolean>;
}

const ConfirmContext = createContext<ConfirmContextValue | undefined>(
  undefined,
);

export function ConfirmProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<{
    options: ConfirmOptions;
    resolve: (value: boolean) => void;
  } | null>(null);

  const confirm = useCallback((options: ConfirmOptions) => {
    return new Promise<boolean>((resolve) => {
      setState({ options, resolve });
    });
  }, []);

  function handleChoice(value: boolean) {
    state?.resolve(value);
    setState(null);
  }

  return (
    <ConfirmContext.Provider value={{ confirm }}>
      {children}
      {state && (
        <div className="modal-backdrop" onClick={() => handleChoice(false)}>
          <div
            className="card confirm-card"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="confirm-icon">
              <AlertTriangle size={22} />
            </div>
            <h3 style={{ margin: '12px 0 4px' }}>{state.options.title}</h3>
            <p
              style={{
                color: 'var(--color-text-muted)',
                fontSize: 13,
                margin: '0 0 20px',
              }}
            >
              {state.options.message}
            </p>
            <div style={{ display: 'flex', gap: 8 }}>
              <button
                className="btn btn-outline"
                style={{ flex: 1, justifyContent: 'center' }}
                onClick={() => handleChoice(false)}
              >
                Annuler
              </button>
              <button
                className={
                  state.options.danger
                    ? 'btn btn-danger-solid'
                    : 'btn btn-primary'
                }
                style={{ flex: 1, justifyContent: 'center' }}
                onClick={() => handleChoice(true)}
              >
                {state.options.confirmLabel ?? 'Confirmer'}
              </button>
            </div>
          </div>
        </div>
      )}
    </ConfirmContext.Provider>
  );
}

export function useConfirm() {
  const context = useContext(ConfirmContext);

  if (!context) {
    throw new Error('useConfirm doit être utilisé dans un <ConfirmProvider>.');
  }

  return context.confirm;
}
