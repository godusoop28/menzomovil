import { API_BASE_URL } from './config';
import { clearSession, getCachedSession, saveSession } from './session';
import type { AuthResponseDto, ErrorResponse } from './types';

export class ApiError extends Error {
  status: number;
  fieldErrors: Record<string, string> | null;
  /** Código estable del backend (p. ej. "YOUTUBE_QUOTA_EXCEEDED") — null si no vino uno o si la
   * falla fue de red/timeout local (nunca llegó a golpear al backend). */
  code: string | null;

  constructor(status: number, message: string, fieldErrors: Record<string, string> | null = null, code: string | null = null) {
    super(message);
    this.status = status;
    this.fieldErrors = fieldErrors;
    this.code = code;
  }
}

type RequestOptions = {
  method?: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  body?: unknown;
  formData?: FormData;
  /** No adjunta el Bearer aunque haya sesión (solo auth/register, auth/login, auth/refresh). */
  skipAuth?: boolean;
};

const SLOW_REQUEST_THRESHOLD_MS = 6000;
const HARD_TIMEOUT_MS = 4 * 60 * 1000;

type SlowRequestListener = (active: boolean) => void;
const slowRequestListeners = new Set<SlowRequestListener>();
let activeSlowRequests = 0;

/** Se activa cuando una petición lleva varios segundos sin responder (p. ej. el backend gratuito de Render se estaba despertando). */
export function onSlowRequestChange(listener: SlowRequestListener): () => void {
  slowRequestListeners.add(listener);
  return () => {
    slowRequestListeners.delete(listener);
  };
}

function setSlowRequestActive(active: boolean) {
  slowRequestListeners.forEach((listener) => listener(active));
}

function beginSlowWatch(): () => void {
  activeSlowRequests += 1;
  let finished = false;
  const timer = setTimeout(() => {
    if (!finished) setSlowRequestActive(true);
  }, SLOW_REQUEST_THRESHOLD_MS);

  return () => {
    if (finished) return;
    finished = true;
    clearTimeout(timer);
    activeSlowRequests = Math.max(0, activeSlowRequests - 1);
    if (activeSlowRequests === 0) setSlowRequestActive(false);
  };
}

type SessionExpiredListener = () => void;
const sessionExpiredListeners = new Set<SessionExpiredListener>();

/** Se activa cuando el refresh token ya no sirve (expiró/fue revocado) y no queda más remedio que volver a iniciar sesión. */
export function onSessionExpired(listener: SessionExpiredListener): () => void {
  sessionExpiredListeners.add(listener);
  return () => {
    sessionExpiredListeners.delete(listener);
  };
}

// El backend gratuito de Render puede tardar hasta uno o dos minutos en levantar cuando
// estaba dormido, y durante ese arranque el fetch no queda "colgado" (lo que cubriría
// HARD_TIMEOUT_MS) sino que la conexión es rechazada de entrada — eso lanza un error de red
// inmediato. Antes solo se reintentaba ~4s en total (1s + 3s), muy por debajo de lo que
// tarda un cold start real, así que un login legítimo terminaba mostrando "revisa tu
// conexión" incluso con wifi perfecto. Se reintenta cada 3s hasta cubrir ese margen.
const NETWORK_RETRY_DELAY_MS = 3000;
const NETWORK_RETRY_BUDGET_MS = 75_000;

function isNetworkError(e: unknown): boolean {
  return e instanceof Error && e.name !== 'AbortError';
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

let refreshPromise: Promise<boolean> | null = null;

async function doRefresh(): Promise<boolean> {
  const session = getCachedSession();
  if (!session) return false;
  try {
    // Pasa por apiFetch (no por fetch crudo) para heredar los reintentos de red y el margen de
    // 4 minutos que ya usan el resto de las peticiones: sin esto, un backend de Render que
    // recién está despertando podía hacer fallar este refresh puntual y desloguear a alguien
    // con una sesión perfectamente válida.
    const data = await apiFetch<AuthResponseDto>('/api/auth/refresh', {
      method: 'POST',
      body: { refreshToken: session.refreshToken },
      skipAuth: true,
    });
    await saveSession({ accessToken: data.accessToken, refreshToken: data.refreshToken, userId: data.profile.id });
    return true;
  } catch {
    return false;
  }
}

function refreshOnce(): Promise<boolean> {
  if (!refreshPromise) {
    refreshPromise = doRefresh().finally(() => {
      refreshPromise = null;
    });
  }
  return refreshPromise;
}

export async function apiFetch<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = 'GET', body, formData, skipAuth } = options;

  async function attempt(): Promise<Response> {
    const session = getCachedSession();
    const headers: Record<string, string> = {};
    if (!formData) headers['Content-Type'] = 'application/json';
    if (!skipAuth && session?.accessToken) headers.Authorization = `Bearer ${session.accessToken}`;

    const controller = new AbortController();
    const hardTimeout = setTimeout(() => controller.abort(), HARD_TIMEOUT_MS);
    try {
      const response = await fetch(`${API_BASE_URL}${path}`, {
        method,
        headers,
        body: formData ?? (body !== undefined ? JSON.stringify(body) : undefined),
        signal: controller.signal,
      });
      // Render acepta la conexión en su proxy de entrada apenas el host está despierto, pero la
      // app puede tardar un poco más en estar lista — durante esa ventana el proxy responde con
      // una página de error de gateway (no JSON) en vez de esperar. Desde afuera "la API ya
      // respondía", pero la petición real igual fallaba. Tratarlo como error de red hace que el
      // mismo reintento de más arriba lo cubra en vez de reventar al parsear el body como JSON.
      if (response.status === 502 || response.status === 503 || response.status === 504) {
        throw new Error(`Gateway no listo (${response.status})`);
      }
      return response;
    } finally {
      clearTimeout(hardTimeout);
    }
  }

  async function attemptWithRetries(): Promise<Response> {
    const endSlowWatch = beginSlowWatch();
    const deadline = Date.now() + NETWORK_RETRY_BUDGET_MS;
    try {
      let lastError: unknown;
      try {
        return await attempt();
      } catch (e) {
        lastError = e;
      }
      while (isNetworkError(lastError) && Date.now() < deadline) {
        await sleep(NETWORK_RETRY_DELAY_MS);
        try {
          return await attempt();
        } catch (retryError) {
          lastError = retryError;
        }
      }
      if (lastError instanceof Error && lastError.name === 'AbortError') {
        throw new ApiError(
          0,
          'Menzo tardó demasiado en responder. El servidor puede estar iniciando — inténtalo de nuevo en un minuto.'
        );
      }
      throw new ApiError(0, 'No se pudo conectar con el servidor. Revisa tu conexión.');
    } finally {
      endSlowWatch();
    }
  }

  let response = await attemptWithRetries();

  if (response.status === 401 && !skipAuth && getCachedSession()) {
    const refreshed = await refreshOnce();
    if (refreshed) {
      response = await attemptWithRetries();
    } else {
      await clearSession();
      sessionExpiredListeners.forEach((listener) => listener());
    }
  }

  if (response.status === 204) {
    return undefined as T;
  }

  const text = await response.text();
  let data: unknown;
  try {
    data = text ? JSON.parse(text) : undefined;
  } catch {
    throw new ApiError(
      response.status,
      response.ok
        ? 'Menzo devolvió una respuesta inesperada. Inténtalo de nuevo en un momento.'
        : `Error ${response.status}`
    );
  }

  if (!response.ok) {
    const err = data as ErrorResponse | undefined;
    throw new ApiError(response.status, err?.message ?? `Error ${response.status}`, err?.fieldErrors ?? null, err?.code ?? null);
  }

  return data as T;
}
