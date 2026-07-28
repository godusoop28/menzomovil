import AsyncStorage from '@react-native-async-storage/async-storage';

export const StorageKeys = {
  profile: '@menzo/profile_v1',
  socialState: '@menzo/social_state_v1',
  settings: '@menzo/settings_v1',
  onboarding: '@menzo/onboarding_v1',
  storageVersion: '@menzo/storage_version',
  auth: '@menzo/auth_v1',
} as const;

export const CURRENT_STORAGE_VERSION = 1;

export async function getItem<T>(key: string): Promise<T | null> {
  try {
    const raw = await AsyncStorage.getItem(key);
    if (!raw) return null;
    return JSON.parse(raw) as T;
  } catch (error) {
    console.warn(`[menzo/storage] failed to read ${key}`, error);
    return null;
  }
}

export async function setItem<T>(key: string, value: T): Promise<boolean> {
  try {
    await AsyncStorage.setItem(key, JSON.stringify(value));
    return true;
  } catch (error) {
    console.warn(`[menzo/storage] failed to write ${key}`, error);
    return false;
  }
}

export async function removeItem(key: string): Promise<void> {
  try {
    await AsyncStorage.removeItem(key);
  } catch (error) {
    console.warn(`[menzo/storage] failed to remove ${key}`, error);
  }
}

export async function resetAllStorage(): Promise<void> {
  await Promise.all(Object.values(StorageKeys).map((key) => removeItem(key)));
}

export async function ensureStorageVersion(): Promise<void> {
  const version = await getItem<number>(StorageKeys.storageVersion);
  if (version !== CURRENT_STORAGE_VERSION) {
    // No destructive migration needed yet — this is the first schema version.
    await setItem(StorageKeys.storageVersion, CURRENT_STORAGE_VERSION);
  }
}
