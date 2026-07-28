const DIACRITICS_RANGE_START = 0x0300;
const DIACRITICS_RANGE_END = 0x036f;

function stripDiacritics(value: string) {
  let result = '';
  for (const char of value) {
    const code = char.codePointAt(0) ?? 0;
    if (code < DIACRITICS_RANGE_START || code > DIACRITICS_RANGE_END) {
      result += char;
    }
  }
  return result;
}

export function normalizeText(value: string) {
  return stripDiacritics(value.toLowerCase().normalize('NFD')).trim();
}

export function matchesQuery(value: string, query: string) {
  if (!query.trim()) return false;
  return normalizeText(value).includes(normalizeText(query));
}
