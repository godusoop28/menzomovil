import type { Badge } from '@/types';

export const badges: Badge[] = [
  { id: 'fundador', name: 'Fundador', description: 'Estuvo aquí desde el primer día.', icon: 'flame', gradient: 'fire' },
  { id: 'recien-llegado', name: 'Recién llegado', description: 'Se acaba de unir a Menzo.', icon: 'sparkles', gradient: 'community' },
  { id: 'narrador', name: 'Narrador', description: 'Sus historias siempre encuentran lectores.', icon: 'book', gradient: 'creative' },
  { id: 'artista', name: 'Alma artista', description: 'Comparte lo que otros no se atreven.', icon: 'color-palette', gradient: 'midnight' },
  { id: 'conector', name: 'Conector', description: 'Une a personas con intereses en común.', icon: 'link', gradient: 'connection' },
  { id: 'veterano', name: 'Veterano', description: 'Lleva mucho tiempo activo en Menzo.', icon: 'medal', gradient: 'fire' },
  { id: 'noctambulo', name: 'Noctámbulo', description: 'Siempre presente después de medianoche.', icon: 'moon', gradient: 'midnight' },
  { id: 'guardian', name: 'Guardián del muro', description: 'Deja huellas que otros recuerdan.', icon: 'shield', gradient: 'community' },
];

export const badgeById = (id: string) => badges.find((b) => b.id === id);
