import type { Aura } from '@/types';

export const auras: Aura[] = [
  {
    id: 'fuego',
    name: 'Fuego',
    description: 'Impulso y energía.',
    gradient: 'fire',
  },
  {
    id: 'tormenta',
    name: 'Tormenta',
    description: 'Movimiento y conexión.',
    gradient: 'connection',
  },
  {
    id: 'eclipse',
    name: 'Eclipse',
    description: 'Misterio y creatividad.',
    gradient: 'midnight',
  },
  {
    id: 'renacer',
    name: 'Renacer',
    description: 'Calma y nuevos comienzos.',
    gradient: 'community',
  },
  {
    id: 'prisma',
    name: 'Prisma',
    description: 'Una mezcla que no necesita explicación.',
    gradient: 'creative',
  },
];

export const auraById = (id: string) => auras.find((a) => a.id === id) ?? auras[0];
