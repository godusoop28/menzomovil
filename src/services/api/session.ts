import { getItem, removeItem, setItem, StorageKeys } from '@/store/storage';

export type StoredSession = {
  accessToken: string;
  refreshToken: string;
  /** UUID real del usuario autenticado, tal como lo devuelve la API (nunca se envía a la UI). */
  userId: string;
};

let cached: StoredSession | null | undefined; // undefined = todavía no se leyó de disco

export async function loadSession(): Promise<StoredSession | null> {
  if (cached !== undefined) return cached;
  cached = await getItem<StoredSession>(StorageKeys.auth);
  return cached;
}

export async function saveSession(session: StoredSession): Promise<void> {
  cached = session;
  await setItem(StorageKeys.auth, session);
}

export async function clearSession(): Promise<void> {
  cached = null;
  await removeItem(StorageKeys.auth);
}

/** Sincrónico: solo válido después de `loadSession()` o de un login/registro en esta misma sesión de app. */
export function getCachedSession(): StoredSession | null {
  return cached ?? null;
}

export function getMyRealId(): string | null {
  return cached?.userId ?? null;
}
