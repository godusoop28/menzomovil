import { requireOptionalNativeModule } from 'expo';

type VoiceForegroundServiceNativeModule = {
  start(roomName: string): void;
  stop(): void;
};

const NativeModule = requireOptionalNativeModule<VoiceForegroundServiceNativeModule>('VoiceForegroundService');

/** Arranca el foreground service de Android (notificación persistente + `foregroundServiceType`
 * "microphone") para que el audio de la sala de voz sobreviva a que la app pase a segundo plano o
 * la pantalla se bloquee. No existe en iOS ni Android sin dev-client (el módulo nativo no está
 * linkeado ahí) — por eso `requireOptionalNativeModule` en vez de `requireNativeModule`, y por eso
 * esto es un no-op seguro en cualquier plataforma donde el módulo no esté presente. */
export function startVoiceForegroundService(roomName: string) {
  NativeModule?.start(roomName);
}

export function stopVoiceForegroundService() {
  NativeModule?.stop();
}
