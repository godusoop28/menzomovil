import type { Interest } from '@/types';

export const interests: Interest[] = [
  { id: 'anime', label: 'Anime', icon: 'sparkles', gradient: 'fire' },
  { id: 'manga', label: 'Manga', icon: 'book', gradient: 'creative' },
  { id: 'videojuegos', label: 'Videojuegos', icon: 'game-controller', gradient: 'connection' },
  { id: 'arte', label: 'Arte', icon: 'color-palette', gradient: 'midnight' },
  { id: 'escritura', label: 'Escritura', icon: 'pencil', gradient: 'community' },
  { id: 'futbol', label: 'Fútbol', icon: 'football', gradient: 'fire' },
  { id: 'musica', label: 'Música', icon: 'musical-notes', gradient: 'creative' },
  { id: 'nostalgia', label: 'Nostalgia', icon: 'time', gradient: 'midnight' },
];

export const interestById = (id: string) => interests.find((i) => i.id === id);
