import * as FileSystem from 'expo-file-system/legacy';
import * as ImagePicker from 'expo-image-picker';
import { router } from 'expo-router';
import { useState } from 'react';
import { Alert, StyleSheet, Text, View } from 'react-native';

import { GradientButton } from '@/components/GradientButton';
import { IconButton } from '@/components/IconButton';
import { ScreenContainer } from '@/components/ScreenContainer';
import { SecondaryButton } from '@/components/SecondaryButton';
import { UserAvatar } from '@/components/UserAvatar';
import { menzoAssets } from '@/constants/assets';
import { useOnboardingDraft } from '@/features/onboarding/OnboardingDraftContext';
import { useHaptics } from '@/hooks/useHaptics';
import { Colors, Spacing, Typography } from '@/theme';

export default function OnboardingAvatar() {
  const { draft, setAvatarUri } = useOnboardingDraft();
  const { light } = useHaptics();
  const [busy, setBusy] = useState(false);

  async function pickImage() {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) {
      Alert.alert(
        'Permiso necesario',
        'Puedes continuar con un avatar de iniciales si prefieres no compartir tus fotos.'
      );
      return;
    }

    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.85,
    });

    if (result.canceled || !result.assets?.[0]) return;

    setBusy(true);
    try {
      const asset = result.assets[0];
      const dir = `${FileSystem.documentDirectory}menzo-avatars/`;
      await FileSystem.makeDirectoryAsync(dir, { intermediates: true }).catch(() => {});
      const dest = `${dir}avatar-${Date.now()}.jpg`;
      await FileSystem.copyAsync({ from: asset.uri, to: dest });
      light();
      setAvatarUri(dest);
    } catch (error) {
      console.warn('[menzo/onboarding] avatar copy failed', error);
      setAvatarUri(result.assets[0].uri);
    } finally {
      setBusy(false);
    }
  }

  return (
    <ScreenContainer backgroundImage={menzoAssets.backgrounds.onboarding} backgroundImageOverlay={0.66}>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
      </View>
      <View style={styles.content}>
        <Text style={styles.title}>Elige tu avatar</Text>
        <Text style={styles.subtitle}>
          Puedes usar una imagen o quedarte con tu inicial y tu aura. Ambas se ven bien.
        </Text>

        <View style={styles.avatarWrap}>
          <UserAvatar
            name={draft.displayName || '?'}
            avatarUri={draft.avatarUri}
            gradient={draft.avatarGradient}
            size={140}
          />
        </View>

        <View style={styles.actions}>
          <SecondaryButton
            label={busy ? 'Preparando imagen…' : 'Elegir desde la galería'}
            onPress={pickImage}
            disabled={busy}
          />
          {!!draft.avatarUri && (
            <SecondaryButton label="Usar inicial en su lugar" onPress={() => setAvatarUri(undefined)} />
          )}
        </View>
      </View>
      <View style={styles.footer}>
        <GradientButton label="Continuar" onPress={() => router.push('/onboarding/interests')} />
      </View>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: { paddingHorizontal: Spacing.md, paddingTop: Spacing.xs },
  content: { flex: 1, paddingHorizontal: Spacing.xl, gap: Spacing.md, alignItems: 'center' },
  title: { ...Typography.h1, color: Colors.textPrimary, alignSelf: 'flex-start', marginTop: Spacing.sm },
  subtitle: { ...Typography.body, color: Colors.textSecondary, alignSelf: 'flex-start' },
  avatarWrap: { marginVertical: Spacing.xxl },
  actions: { width: '100%', gap: Spacing.sm },
  footer: { paddingHorizontal: Spacing.xl, paddingBottom: Spacing.xl },
});
