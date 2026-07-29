export function relativeTime(iso: string) {
  const diffMs = Date.now() - new Date(iso).getTime();
  const minutes = Math.round(diffMs / 60000);

  if (minutes < 1) return 'ahora';
  if (minutes < 60) return `hace ${minutes} min`;

  const hours = Math.round(minutes / 60);
  if (hours < 24) return `hace ${hours} h`;

  const days = Math.round(hours / 24);
  if (days < 7) return `hace ${days} d`;

  const weeks = Math.round(days / 7);
  if (weeks < 5) return `hace ${weeks} sem`;

  const months = Math.round(days / 30);
  return `hace ${months} mes${months === 1 ? '' : 'es'}`;
}

export function formatJoinDate(iso: string) {
  const date = new Date(iso);
  return date.toLocaleDateString('es-ES', { month: 'long', year: 'numeric' });
}

export function isSameDay(isoA: string, isoB: string): boolean {
  const a = new Date(isoA);
  const b = new Date(isoB);
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

/** Separador de fecha para listas de mensajes tipo chat — "Hoy"/"Ayer" para los últimos dos días,
 * fecha completa para el resto. */
export function dateSeparatorLabel(iso: string): string {
  const date = new Date(iso);
  const today = new Date();
  const yesterday = new Date();
  yesterday.setDate(today.getDate() - 1);
  if (isSameDay(iso, today.toISOString())) return 'Hoy';
  if (isSameDay(iso, yesterday.toISOString())) return 'Ayer';
  return date.toLocaleDateString('es-ES', {
    day: 'numeric',
    month: 'long',
    year: date.getFullYear() !== today.getFullYear() ? 'numeric' : undefined,
  });
}
