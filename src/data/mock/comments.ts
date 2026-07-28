import type { Comment } from '@/types';

function hoursAgo(h: number) {
  return new Date(Date.now() - h * 60 * 60 * 1000).toISOString();
}

export const demoComments: Comment[] = [
  { id: 'c1', postId: 'p1', authorId: 'u1', body: 'Presente. Nunca me fui del todo.', createdAt: hoursAgo(1.5) },
  { id: 'c2', postId: 'p1', authorId: 'u5', body: 'Yo volví hace un mes, se siente raro y lindo a la vez.', createdAt: hoursAgo(1.2) },
  { id: 'c3', postId: 'p1', authorId: 'u10', body: 'Aquí desde la primera versión de todo esto.', createdAt: hoursAgo(1) },
  { id: 'c4', postId: 'p2', authorId: 'u2', body: 'Esto lo escribí yo mil veces en mi cabeza y nunca lo publiqué.', createdAt: hoursAgo(4) },
  { id: 'c5', postId: 'p2', authorId: 'u8', body: 'Qué manera de resumir exactamente lo que siento.', createdAt: hoursAgo(3.5) },
  { id: 'c6', postId: 'p3', authorId: 'u9', body: 'Publícalos todos, en serio.', createdAt: hoursAgo(7) },
  { id: 'c7', postId: 'p4', authorId: 'u2', body: 'La mía empezó insultándonos en un chat de sala. Ahora es mi mejor amiga.', createdAt: hoursAgo(10) },
  { id: 'c8', postId: 'p5', authorId: 'u10', body: 'Esa lista necesita una segunda parte.', createdAt: hoursAgo(13) },
  { id: 'c9', postId: 'p6', authorId: 'u3', body: 'Sentí exactamente lo mismo cuando volví.', createdAt: hoursAgo(17) },
  { id: 'c10', postId: 'p6', authorId: 'u9', body: 'Este comentario lo firmo con los ojos llorosos.', createdAt: hoursAgo(16.5) },
  { id: 'c11', postId: 'p7', authorId: 'u1', body: 'Una que me marcó fue la que sonaba en todos los foros de esa época.', createdAt: hoursAgo(20) },
  { id: 'c12', postId: 'p9', authorId: 'u3', body: 'El mío era ridículo, mejor no lo digo.', createdAt: hoursAgo(27) },
  { id: 'c13', postId: 'p13', authorId: 'u7', body: 'Me apunto, ya tengo boceto.', createdAt: hoursAgo(45) },
];
