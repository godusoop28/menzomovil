# MENZO

> Un lugar para volver a encontrarnos.

MENZO es un prototipo de aplicación social inspirado emocionalmente en las viejas comunidades de
internet (anime, manga, videojuegos, arte, escritura, fútbol y cultura digital de finales de los
2000). Es una demostración **100% local**: no tiene backend, no llama a ninguna API externa y no
sincroniza nada entre dispositivos. Cada persona que instale la app crea su propio perfil local y
explora una comunidad simulada precargada (miembros, publicaciones, salas de chat, eventos…).

## Tecnologías

- [Expo](https://expo.dev) SDK 57 + [Expo Router](https://docs.expo.dev/router/introduction/) (file-based routing, en `src/app`)
- React Native 0.86 + React 19, TypeScript estricto
- `@react-native-async-storage/async-storage` para persistencia local
- `expo-linear-gradient`, `expo-blur`, `expo-haptics`, `expo-image-picker`, `expo-file-system`, `@expo/vector-icons`
- `react-native-reanimated` para animaciones
- Tipografías `Space Grotesk` (títulos) e `Inter` (cuerpo) vía `@expo-google-fonts/*`

Sin Redux, sin NativeWind, sin Firebase/Supabase, sin llamadas de red.

## Instalación y ejecución

```bash
npm install
npx expo start
```

Desde ahí puedes abrir la app en Expo Go, un simulador iOS/Android, o el navegador (`w` en la
terminal de Expo). Funciona en Android, iOS y web, y se adapta a distintos tamaños de pantalla.

## Estructura del proyecto

```
assets/branding/menzo-logo.png   Logotipo de MENZO (splash, onboarding, Acerca de)
src/app/                         Rutas de Expo Router
  onboarding/                    Splash animado + elección de nombre, aura, avatar e intereses
  (tabs)/                        Inicio, En línea, Chats, Perfil (con barra inferior personalizada)
  post/[id], member/[id], chat/[id]
  create/                        Publicación, pregunta, encuesta, galería, evento
  events/, notifications, search, settings, about, edit-profile, following, bookmarks, recent…
src/components/                  Biblioteca de componentes reutilizables (PostCard, ChatBubble…)
src/theme/                       Sistema de diseño centralizado (colores, tipografía, espaciado…)
src/store/                       Estado global (Context + useReducer) y persistencia AsyncStorage
src/data/mock/                   Datos de demostración (usuarios, publicaciones, salas, eventos…)
src/data/repositories/           Interfaces de repositorio + implementación local (ver más abajo)
src/config/community.ts          Textos y configuración editable de la comunidad
```

## Persistencia local

Todo el estado (perfil, publicaciones creadas, likes, guardados, comentarios, mensajes, muro,
configuración y onboarding completado) se guarda en `AsyncStorage` a través de
`src/store/AppStateContext.tsx` y `src/store/storage.ts`. Al reabrir la app, el estado se hidrata
automáticamente y el onboarding no vuelve a aparecer.

**Esta versión no sincroniza datos entre dispositivos** — cada instalación tiene su propio estado
local. Los demás miembros, publicaciones y salas que ves son datos de demostración precargados
(`src/data/mock/`); solo tu perfil y tu actividad son reales y persistentes en tu dispositivo.

## Restablecer la demostración

En **Perfil → Configuración → Restablecer Menzo** (pide confirmación antes de borrar). Esto limpia
todo `AsyncStorage` y te regresa al onboarding para volver a crear tu perfil.

## Cambiar el nombre de la comunidad

Edita `src/config/community.ts` (nombre, subtítulo, descripción, lema, número de miembros, tags).

## Reemplazar el logotipo

Sustituye `assets/branding/menzo-logo.png` por otro archivo con el mismo nombre. Se usa a través
del componente `src/components/MenzoLogo.tsx` en el splash, el onboarding, el menú lateral y la
pantalla "Acerca de Menzo".

## Funcionalidades simuladas vs. reales

**Reales y persistentes:** perfil propio, publicaciones/preguntas/encuestas/galería/eventos que
creas, likes, guardados, comentarios, mensajes de chat y de muro, seguir/dejar de seguir,
confirmar asistencia a eventos, configuración, historial de búsqueda y de vistos recientemente.

**Simulados (datos precargados, no reales):** los 10 miembros de ejemplo, sus publicaciones,
salas de Hangout, mensajes iniciales, notificaciones y eventos de ejemplo. Nadie te responde
automáticamente — es una demostración local, no una red social conectada.

## Conectar un backend en el futuro

`src/data/repositories/` define interfaces (`ProfileRepository`, `PostRepository`,
`ChatRepository`, `CommunityRepository`) con una implementación local en
`src/data/repositories/local/`, pensadas como el punto de conexión para una futura API HTTP sin
tener que reescribir las pantallas. Hoy en día las pantallas leen y escriben directamente a través
de `AppStateContext`, que usa el mismo almacenamiento local — ese es el siguiente punto natural
para introducir llamadas de red si algún día se agrega un backend real.

## Limitaciones conocidas

- No hay selector de imágenes múltiple (una imagen por publicación).
- Fecha y hora de eventos se ingresan como texto validado (`AAAA-MM-DD` / `HH:MM`), sin selector
  nativo de calendario.
- Los mensajes directos (`/chat/dm-<usuario>`) se generan al vuelo la primera vez que escribes a
  alguien; no aparecen como una "sala" formal en `Hangout`.
"# menzomovil" 
