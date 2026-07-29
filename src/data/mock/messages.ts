import type { Message } from '@/types';

function minutesAgo(m: number) {
  return new Date(Date.now() - m * 60 * 1000).toISOString();
}

export const demoMessages: Message[] = [
  { id: 'm1', roomId: 'r1', authorId: 'u1', body: 'Bienvenidos a quienes acaban de volver.', createdAt: minutesAgo(240), type: 'text', receivedAt: Date.now() },
  { id: 'm2', roomId: 'r1', authorId: 'u10', body: 'Esta sala existe desde el primer día, se siente bien verla llena otra vez.', createdAt: minutesAgo(228), type: 'text', receivedAt: Date.now() },
  { id: 'm3', roomId: 'r1', authorId: 'u2', body: 'Yo entré hace una semana y ya se siente como antes.', createdAt: minutesAgo(210), type: 'text', receivedAt: Date.now() },
  { id: 'm4', roomId: 'r1', authorId: 'u5', body: '¿Alguien más tiene ganas de organizar algo este fin de semana?', createdAt: minutesAgo(180), type: 'text', receivedAt: Date.now() },
  { id: 'm5', roomId: 'r1', authorId: 'u7', body: 'Yo me apunto a lo que sea.', createdAt: minutesAgo(175), type: 'text', receivedAt: Date.now() },
  { id: 'm6', roomId: 'r1', authorId: 'system', body: 'Estás viendo una demostración local de MENZO.', createdAt: minutesAgo(1440), type: 'system', receivedAt: Date.now() },
  { id: 'm7', roomId: 'r2', authorId: 'u1', body: 'Puse una lista entera de openings viejos hoy.', createdAt: minutesAgo(320), type: 'text', receivedAt: Date.now() },
  { id: 'm8', roomId: 'r2', authorId: 'u9', body: 'Mándala, necesito llorar un rato.', createdAt: minutesAgo(310), type: 'text', receivedAt: Date.now() },
  { id: 'm9', roomId: 'r2', authorId: 'u3', body: '¿Alguien vio el capítulo nuevo? Sin spoilers todavía.', createdAt: minutesAgo(260), type: 'text', receivedAt: Date.now() },
  { id: 'm10', roomId: 'r2', authorId: 'u8', body: 'Yo voy a medias, cuidado con lo que dicen.', createdAt: minutesAgo(255), type: 'text', receivedAt: Date.now() },
  { id: 'm11', roomId: 'r2', authorId: 'u1', body: 'Prometido, nada de spoilers por aquí.', createdAt: minutesAgo(250), type: 'text', receivedAt: Date.now() },
  { id: 'm12', roomId: 'r3', authorId: 'u3', body: 'Subí un boceto nuevo al feed, cualquier feedback es bienvenido.', createdAt: minutesAgo(400), type: 'text', receivedAt: Date.now() },
  { id: 'm13', roomId: 'r3', authorId: 'u7', body: 'Me encantó el trazo, se nota que practicaste.', createdAt: minutesAgo(390), type: 'text', receivedAt: Date.now() },
  { id: 'm14', roomId: 'r3', authorId: 'u8', body: 'Deberíamos hacer un reto grupal esta semana.', createdAt: minutesAgo(120), type: 'text', receivedAt: Date.now() },
  { id: 'm15', roomId: 'r4', authorId: 'u6', body: 'El torneo del sábado ya tiene lista de inscritos, avisen si quieren entrar.', createdAt: minutesAgo(500), type: 'text', receivedAt: Date.now() },
  { id: 'm16', roomId: 'r4', authorId: 'u10', body: 'Yo me anoto sin dudarlo.', createdAt: minutesAgo(480), type: 'text', receivedAt: Date.now() },
  { id: 'm17', roomId: 'r4', authorId: 'u5', body: '¿Va a haber revancha del año pasado?', createdAt: minutesAgo(150), type: 'text', receivedAt: Date.now() },
  { id: 'm18', roomId: 'r5', authorId: 'u2', body: 'Reabrimos el rincón, dejen sus textos cuando quieran.', createdAt: minutesAgo(600), type: 'text', receivedAt: Date.now() },
  { id: 'm19', roomId: 'r5', authorId: 'u9', body: 'Tenía un borrador guardado hace años, creo que por fin lo voy a publicar.', createdAt: minutesAgo(90), type: 'text', receivedAt: Date.now() },
  { id: 'm20', roomId: 'r5', authorId: 'u7', body: 'Ese es justo el espíritu de esta sala.', createdAt: minutesAgo(80), type: 'text', receivedAt: Date.now() },
];
