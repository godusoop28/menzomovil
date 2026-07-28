import type { Notification } from '@/types';

function hoursAgo(h: number) {
  return new Date(Date.now() - h * 60 * 60 * 1000).toISOString();
}

export const demoNotifications: Notification[] = [
  {
    id: 'n1',
    category: 'comentarios',
    title: 'Dais comentó tu publicación',
    body: '"Esto lo escribí yo mil veces en mi cabeza y nunca lo publiqué."',
    createdAt: hoursAgo(3),
    read: false,
    relatedPostId: 'p2',
    relatedUserId: 'u2',
  },
  {
    id: 'n2',
    category: 'likes',
    title: 'A 5 personas les gustó tu publicación',
    body: 'Volvimos después de tantos años sigue reuniendo reacciones.',
    createdAt: hoursAgo(6),
    read: false,
    relatedPostId: 'p6',
  },
  {
    id: 'n3',
    category: 'mensajes',
    title: 'Nuevo mensaje en La sala del reencuentro',
    body: 'La conversación sigue activa, entra cuando quieras.',
    createdAt: hoursAgo(9),
    read: true,
    relatedRoomId: 'r1',
  },
  {
    id: 'n4',
    category: 'eventos',
    title: 'Reto de dibujo esta semana',
    body: 'Tema: "el lugar al que quieres volver".',
    createdAt: hoursAgo(20),
    read: false,
    relatedEventId: 'ev3',
  },
  {
    id: 'n5',
    category: 'seguimientos',
    title: 'Ren empezó a seguirte',
    body: 'Aquí desde la primera versión de todo esto.',
    createdAt: hoursAgo(30),
    read: true,
    relatedUserId: 'u10',
  },
  {
    id: 'n6',
    category: 'mensajes',
    title: 'Estás viendo una demostración local de MENZO',
    body: 'Los mensajes y notificaciones simulan actividad, pero no hay red ni servidores.',
    createdAt: hoursAgo(48),
    read: true,
  },
];
