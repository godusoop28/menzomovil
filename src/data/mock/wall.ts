import type { WallMessage } from '@/types';

function daysAgo(d: number) {
  return new Date(Date.now() - d * 24 * 60 * 60 * 1000).toISOString();
}

export const demoWallMessages: WallMessage[] = [
  { id: 'w1', profileId: 'u1', authorId: 'u2', body: 'Nunca voy a olvidar las noches de openings contigo.', createdAt: daysAgo(2), commentCount: 0 },
  { id: 'w2', profileId: 'u1', authorId: 'u10', body: 'Qué bueno tenerte de vuelta por aquí.', createdAt: daysAgo(5), commentCount: 0 },
  { id: 'w3', profileId: 'u2', authorId: 'u7', body: 'Tus textos siguen siendo lo mejor de esta comunidad.', createdAt: daysAgo(3), commentCount: 0 },
  { id: 'w4', profileId: 'u10', authorId: 'u5', body: 'El fundador que nunca se fue de verdad.', createdAt: daysAgo(9), commentCount: 0 },
  { id: 'w5', profileId: 'u3', authorId: 'u8', body: 'Sigues dibujando increíble, no cambies.', createdAt: daysAgo(6), commentCount: 0 },
  { id: 'w6', profileId: 'u9', authorId: 'u1', body: 'Bienvenida de vuelta, se siente raro sin ti por aquí.', createdAt: daysAgo(1), commentCount: 0 },
];
