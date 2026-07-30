# MENZO — Guía de publicación en Google Play

> ⚠️ **Histórico de la era Expo/EAS.** El proyecto se migró a Flutter — ya no hay `eas.json`,
> `app.json` ni `eas build`. La build de Android/iOS ahora es directamente con Gradle/Xcode
> (`flutter build appbundle`, `flutter build ipa`). Se conserva este documento solo por el
> **package name definitivo** (`com.sega2028.menzomovil`, ya configurado igual en el proyecto
> Flutter) y el contexto de la cuenta de Google Play — el resto (EAS, `eas.json`, scripts npm)
> ya no aplica.

## Identidad de la app (no cambiar después de la primera subida)

| Campo | Valor |
|---|---|
| **Package Android definitivo** | `com.sega2028.menzomovil` |
| Nombre visible | Menzo |
| Versión visible (`version`) | `1.0.0` |
| VersionCode | Gestionado remotamente por EAS (`appVersionSource: "remote"` en `eas.json`) — empieza en 1 automáticamente en el primer build de `production` y se incrementa solo en cada build siguiente gracias a `autoIncrement: true`. No hay un `android.versionCode` fijo en `app.json` a propósito. |
| Cuenta / proyecto EAS | `@sega2028/menzomovil` — `947b8f42-65fc-4539-948a-fa8e774a3919` (ya vinculado) |

> ⚠️ **`com.sega2028.menzomovil` es el identificador definitivo de Google Play.** Una vez subas la primera versión (aunque sea a Prueba interna), este package **no se puede cambiar nunca más** para esta app — Google Play lo trata como el ID único permanente.

## Qué se configuró en esta sesión

- **`app.json`**: agregado el plugin `expo-status-bar` (`style: "light"`, para que la barra de estado se vea bien sobre el fondo oscuro incluso antes de que cargue el JS) y el plugin `expo-image-picker` con permiso de fotos en español y **cámara/micrófono explícitamente desactivados** (la app nunca los usa — solo selecciona imágenes de la galería).
- **`eas.json`**: perfil `production` ahora declara explícitamente `"buildType": "app-bundle"` (antes dependía del valor por defecto; ahora queda explícito para evitar ambigüedad).
- **`package.json`**: agregados los scripts `typecheck` y `doctor`; **eliminado** el script `reset-project` y su archivo (`scripts/reset-project.js`) — era el script de plantilla de Expo que borra `src/` y `scripts/`; en una app terminada era un riesgo real, no una utilidad.
- **`.gitignore`**: reforzado contra fugas de credenciales y binarios (`*.aab`, `*.apk`, `google-services.json`, `*-service-account.json`, `credentials.json`, `.env`).
- Iconos y splash: ya configurados en la sesión anterior con los assets reales de MENZO (`assets/branding/`, `assets/app-icons/`) — verificado de nuevo que no queda ningún recurso genérico de Expo/React referenciado.

## Validaciones ejecutadas (todas en verde)

| Comando | Resultado |
|---|---|
| `npx expo install --check` | Dependencias ya compatibles con SDK 57, sin cambios necesarios |
| `npx expo-doctor` | **20/20 checks pasados** |
| `npx tsc --noEmit` | Sin errores |
| `npm run lint` | Sin errores ni warnings |
| `npx expo config --type public` | Config resuelve sin errores |
| `npx expo export -p web` | Bundle de las 37 rutas sin errores |
| `npx eas-cli@latest whoami` | Sesión activa: `sega2028` |
| `npx eas-cli@latest project:info` | Proyecto vinculado correctamente: `@sega2028/menzomovil` |
| `npx eas-cli@latest config --platform android --profile production` | Resuelve `buildType: app-bundle`, `distribution: store`, `package: com.sega2028.menzomovil`, `autoIncrement: true` |

**Confirmación: la app funciona 100% sin API.** Búsqueda exhaustiva de `fetch(`, `axios`, `WebSocket`, `localhost`, `127.0.0.1`, `http://`, `https://`, `API_URL`, `BASE_URL` en todo `src/` — cero resultados. Todo el estado vive en `AsyncStorage` + datos de demostración locales (`src/data/mock/`).

No se pudo verificar el estado del **keystore de Android** (si EAS ya generó uno para este proyecto o no) sin abrir el menú interactivo de `eas credentials`, y evité tocarlo para no arriesgarme a disparar la generación de uno nuevo por accidente. Lo verá el propio `eas build` en el primer intento.

## Comandos que te faltan a ti

Ya tienes sesión iniciada (`sega2028`) y el proyecto ya está vinculado (`project:info` respondió bien), así que puedes saltarte `login` y `project:init` — pero los dejo documentados por si alguna vez cambias de cuenta o de máquina.

```bash
# Solo si alguna vez pierdes la sesión o cambias de PC:
npx eas-cli@latest login
npx eas-cli@latest whoami
npx eas-cli@latest project:init

# Verificar que todo sigue vinculado:
npx eas-cli@latest project:info

# Si necesitas reconfigurar Android para EAS:
npx eas-cli@latest build:configure --platform android

# APK instalable directo en tu teléfono (para probar antes de subir a Play):
npx eas-cli@latest build --platform android --profile preview

# AAB de producción — esto es lo que subes a Google Play:
npx eas-cli@latest build --platform android --profile production
```

No agregué `--non-interactive` al comando de producción a propósito: la primera vez que EAS construya esta app te va a preguntar cómo manejar las credenciales/keystore de Android — tienes que confirmarlo tú mismo.

### Dónde queda el archivo

Cuando termine el build de producción, la terminal imprime un link a `expo.dev` con el `.aab` descargable. También puedes verlo en cualquier momento con:

```bash
npx eas-cli@latest build:list --platform android --limit 5
```

### Subir a Google Play (Prueba interna)

1. Entra a [Google Play Console](https://play.google.com/console) → crea la app (si es la primera vez) usando exactamente el package `com.sega2028.menzomovil`.
2. Ve a **Pruebas → Prueba interna** → **Crear nueva versión**.
3. Sube el `.aab` descargado del build de `production`.
4. Completa la ficha de la tienda (descripción, capturas, ícono de 512×512 — puedes exportar `assets/branding/app-icon.png` a ese tamaño, política de privacidad).
5. Agrega los correos de los probadores internos.
6. Publica la versión de prueba interna y espera a que Google la procese (unos minutos).

### Cómo subir la siguiente versión

- Cambia `version` en `app.json` cuando sea un release visible para el usuario (ej. `1.0.1`, `1.1.0`).
- **No toques `android.package`, nunca.**
- No necesitas tocar el versionCode — `autoIncrement: true` + `appVersionSource: "remote"` en `eas.json` lo maneja solo en cada build de `production`.
- Vuelve a correr `npx eas-cli@latest build --platform android --profile production` y sube el nuevo `.aab` como una nueva versión en la misma pista (interna, cerrada, abierta o producción).

## Checklist antes de compilar producción

- [ ] `npx expo-doctor` sigue en verde
- [ ] `npx tsc --noEmit` sin errores
- [ ] Probaste el APK de `preview` en un teléfono Android real (no solo Expo Go)
- [ ] Onboarding completo funciona y no reaparece al reabrir la app
- [ ] Crear publicación, dar like, comentar, enviar mensaje — persisten tras cerrar y reabrir
- [ ] "Restablecer Menzo" en Configuración realmente regresa al onboarding
- [ ] El ícono en la pantalla de inicio y el splash se ven correctos (esto **solo se ve en un build real**, nunca en Expo Go)
- [ ] Selector de imágenes (avatar / publicaciones) pide permiso y funciona
- [ ] No hay ningún texto ni recurso en inglés que se haya colado
- [ ] Revisaste que no aparezca contenido de marcas protegidas en ningún dato de demostración

## Advertencia final

Esta build es completamente local: **no hay backend, no hay sincronización entre dispositivos, no hay Firebase ni Analytics ni publicidad.** Cada instalación tiene su propio estado. Si en el futuro agregas un backend real, la capa de repositorios en `src/data/repositories/` ya está preparada como punto de conexión sin tener que reescribir pantallas — pero eso queda fuera del alcance de esta primera versión.
