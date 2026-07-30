# MENZO (móvil)

App móvil de MENZO — comunidad, chats, LIVE con voz (Agora) y Menzi DJ (música sincronizada vía
YouTube). Migrada de Expo/React Native a **Flutter**, con el mismo diseño y estructura que
[menzoweb](../menzoweb) (Next.js) y hablando contra el mismo backend, [menzoapi](../menzoapi)
(Spring Boot).

## Stack

- **Flutter 3.44** / Dart 3.12
- **Riverpod** (`flutter_riverpod`) para estado — reemplaza los Context+reducer de la versión RN
- **go_router** para navegación (rutas con guard de auth/onboarding)
- **dio** para HTTP, con reintentos/timeout adaptados a que el backend (Render free-tier) puede
  tardar en despertar
- **stomp_dart_client** para WebSocket/STOMP (mensajes, LIVE, Menzi DJ, muro — mismos tópicos que
  el backend)
- **agora_rtc_engine** para la voz de las salas LIVE
- **webview_flutter** + el reproductor oficial de YouTube (IFrame Player API) para Menzi DJ —
  nunca se extrae audio ni se usan streams no oficiales
- **flutter_secure_storage** para el par de tokens de sesión (Keychain/Keystore, no texto plano)
- **google_fonts** (Space Grotesk + Inter, mismas fuentes que la web)

## Estructura

```
lib/
├── core/           # tema, red (ApiClient/Stomp), storage, router
├── data/           # modelos (DTOs 1:1 con menzoapi) y repositorios por dominio
└── features/       # una carpeta por área: auth, onboarding, home, chat, live, music,
                     # profile, members, notifications, events, post, settings, shared
```

## Correr el proyecto

```bash
flutter pub get
flutter run                 # dispositivo/emulador conectado
flutter run -d chrome        # navegador (Agora/WebView de YouTube no aplican en web)
```

`API_BASE_URL` apunta por defecto a `https://menzoapi.onrender.com` — para apuntar a otro backend:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

## Verificación

```bash
flutter analyze
dart format --output=none --set-exit-if-changed .
flutter test
```

## Permisos nativos

- **Android** (`android/app/src/main/AndroidManifest.xml`): `RECORD_AUDIO`,
  `MODIFY_AUDIO_SETTINGS`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`,
  `POST_NOTIFICATIONS`, `READ_MEDIA_IMAGES`.
- **iOS** (`ios/Runner/Info.plist`): `NSMicrophoneUsageDescription`,
  `NSPhotoLibraryUsageDescription`, `UIBackgroundModes: audio`.

## Pendiente conocido

- No se probó en un dispositivo/emulador real (Agora, WebView de YouTube, permisos en runtime) —
  solo se verificó que compila (`flutter analyze` + `flutter build web`). Antes de publicar,
  probar el flujo de LIVE y Menzi DJ en un dispositivo físico.
- El servicio en foreground de Android para mantener la llamada de voz viva en segundo plano
  (que existía como módulo nativo custom en la versión Expo) todavía no se portó — hoy la
  reproducción de voz puede cortarse si el sistema mata la app en background.
