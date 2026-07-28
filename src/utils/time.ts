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
