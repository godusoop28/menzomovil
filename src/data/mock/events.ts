import type { CommunityEvent } from '@/types';

export const demoEvents: CommunityEvent[] = [
  {
    id: 'ev1',
    title: 'Noche de openings y recuerdos',
    description: 'Una maratón de openings viejos para recordar viejos tiempos, con chat en vivo en Hangout.',
    date: '2026-07-19',
    time: '21:00',
    kind: 'Encuentro',
    attendees: ['u1', 'u2', 'u5', 'u7'],
  },
  {
    id: 'ev2',
    title: 'Torneo amistoso',
    description: 'Torneo casual sin presión, todos los niveles son bienvenidos.',
    date: '2026-07-25',
    time: '17:00',
    kind: 'Torneo',
    attendees: ['u5', 'u6', 'u10'],
  },
  {
    id: 'ev3',
    title: 'Reto de dibujo',
    description: 'Tema de la semana: "el lugar al que quieres volver". Comparte tu resultado en Galería.',
    date: '2026-07-21',
    time: '19:00',
    kind: 'Reto creativo',
    attendees: ['u1', 'u3', 'u7', 'u8', 'u9'],
  },
  {
    id: 'ev4',
    title: 'Historias de nuestra primera comunidad',
    description: 'Una ronda para compartir cómo llegaron aquí por primera vez.',
    date: '2026-07-05',
    time: '20:00',
    kind: 'Encuentro',
    attendees: ['u2', 'u9', 'u10'],
  },
];
