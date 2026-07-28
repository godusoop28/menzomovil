import { createContext, useCallback, useContext, useMemo, useState } from 'react';

import { Toast } from '@/components/Toast';

const ToastContext = createContext<((message: string) => void) | null>(null);

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [message, setMessage] = useState<string | null>(null);

  const showToast = useCallback((next: string) => setMessage(next), []);
  const hideToast = useCallback(() => setMessage(null), []);

  const value = useMemo(() => showToast, [showToast]);

  return (
    <ToastContext.Provider value={value}>
      {children}
      <Toast message={message} onHide={hideToast} />
    </ToastContext.Provider>
  );
}

export function useToast() {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error('useToast must be used within a ToastProvider');
  return ctx;
}
