export const NAME_MIN = 2;
export const NAME_MAX = 20;

export function collapseSpaces(value: string) {
  return value.replace(/\s+/g, ' ');
}

export function isValidDisplayName(value: string) {
  const trimmed = collapseSpaces(value).trim();
  return trimmed.length >= NAME_MIN && trimmed.length <= NAME_MAX;
}
