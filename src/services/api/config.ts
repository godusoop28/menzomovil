// Configurable via variable de entorno de Expo (EXPO_PUBLIC_* se embebe en el build).
// En desarrollo con Expo Go/dev client, si no se define, cae a localhost (útil solo en
// emulador/web; en dispositivo físico hace falta EXPO_PUBLIC_API_URL apuntando a la API real).
export const API_BASE_URL = (process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:8080').replace(/\/+$/, '');
