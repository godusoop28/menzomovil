import * as FileSystem from 'expo-file-system/legacy';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { AuraCard } from '@/components/AuraCard';
import { ConfirmationModal } from '@/components/ConfirmationModal';
import { GradientButton } from '@/components/GradientButton';
import { IconButton } from '@/components/IconButton';
import { InterestChip } from '@/components/InterestChip';
import { ScreenContainer } from '@/components/ScreenContainer';
import { SecondaryButton } from '@/components/SecondaryButton';
import { UserAvatar } from '@/components/UserAvatar';
import { auraById, auras } from '@/data/mock/auras';
import { interests } from '@/data/mock/interests';
import { useAppState } from '@/hooks/useAppState';
import { useHaptics } from '@/hooks/useHaptics';
import { useKeyboardBehavior } from '@/hooks/useKeyboardOffset';
import { useToast } from '@/hooks/useToast';
import { Colors, Spacing, Typography } from '@/theme';
import type { AuraId, InterestId } from '@/types';
import { collapseSpaces, isValidDisplayName, NAME_MAX } from '@/utils/validation';

export default function EditProfileScreen() {
  const { state, actions } = useAppState();
  const { success } = useHaptics();
  const behavior = useKeyboardBehavior();
  const showToast = useToast();
  const profile = state.profile!;

  const [displayName, setDisplayName] = useState(profile.displayName);
  const [bio, setBio] = useState(profile.bio);
  const [statusText, setStatusText] = useState(profile.statusText);
  const [aura, setAura] = useState<AuraId>(profile.aura);
  const [avatarUri, setAvatarUri] = useState(profile.avatarUri);
  const [coverUri, setCoverUri] = useState(profile.coverUri);
  const [selectedInterests, setSelectedInterests] = useState<InterestId[]>(profile.interests);
  const [showDiscardConfirm, setShowDiscardConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [busyCover, setBusyCover] = useState(false);
  const [saving, setSaving] = useState(false);

  const dirty =
    displayName !== profile.displayName ||
    bio !== profile.bio ||
    statusText !== profile.statusText ||
    aura !== profile.aura ||
    avatarUri !== profile.avatarUri ||
    coverUri !== profile.coverUri ||
    JSON.stringify(selectedInterests) !== JSON.stringify(profile.interests);

  const valid = isValidDisplayName(displayName);

  function toggleInterest(id: InterestId) {
    setSelectedInterests((current) => {
      if (current.includes(id)) return current.filter((i) => i !== id);
      if (current.length >= 5) return current;
      return [...current, id];
    });
  }

  async function pickAvatar() {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) return;
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.85,
    });
    if (result.canceled || !result.assets?.[0]) return;

    setBusy(true);
    try {
      const dir = `${FileSystem.documentDirectory}menzo-avatars/`;
      await FileSystem.makeDirectoryAsync(dir, { intermediates: true }).catch(() => {});
      const dest = `${dir}avatar-${Date.now()}.jpg`;
      await FileSystem.copyAsync({ from: result.assets[0].uri, to: dest });
      setAvatarUri(dest);
    } catch {
      setAvatarUri(result.assets[0].uri);
    } finally {
      setBusy(false);
    }
  }

  async function pickCover() {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) return;
    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsEditing: true,
      aspect: [16, 9],
      quality: 0.85,
    });
    if (result.canceled || !result.assets?.[0]) return;

    setBusyCover(true);
    try {
      const dir = `${FileSystem.documentDirectory}menzo-covers/`;
      await FileSystem.makeDirectoryAsync(dir, { intermediates: true }).catch(() => {});
      const dest = `${dir}cover-${Date.now()}.jpg`;
      await FileSystem.copyAsync({ from: result.assets[0].uri, to: dest });
      setCoverUri(dest);
    } catch {
      setCoverUri(result.assets[0].uri);
    } finally {
      setBusyCover(false);
    }
  }

  async function handleSave() {
    if (!valid || saving) return;
    setSaving(true);
    try {
      await actions.updateProfile({
        displayName: collapseSpaces(displayName).trim(),
        bio,
        statusText,
        aura,
        avatarGradient: auraById(aura).gradient,
        avatarUri,
        coverUri,
        interests: selectedInterests,
      });
      success();
      router.back();
    } catch (error) {
      console.warn('[menzo/api] updateProfile failed', error);
      showToast('No pudimos guardar los cambios. Revisa tu conexión e inténtalo de nuevo.');
    } finally {
      setSaving(false);
    }
  }

  function handleBack() {
    if (dirty) setShowDiscardConfirm(true);
    else router.back();
  }

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="close" label="Cancelar" onPress={handleBack} variant="surface" />
        <Text style={styles.headerTitle}>Editar perfil</Text>
        <View style={{ width: 44 }} />
      </View>

      <KeyboardAvoidingView behavior={behavior} style={styles.flex}>
        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
          <View style={styles.coverSection}>
            {coverUri ? (
              <Image source={{ uri: coverUri }} style={styles.coverPreview} contentFit="cover" />
            ) : (
              <View style={[styles.coverPreview, styles.coverPlaceholder]} />
            )}
            <SecondaryButton
              label={busyCover ? 'Preparando…' : 'Cambiar portada'}
              onPress={pickCover}
              disabled={busyCover}
            />
          </View>

          <View style={styles.avatarSection}>
            <UserAvatar name={displayName} avatarUri={avatarUri} gradient={auraById(aura).gradient} size={110} />
            <SecondaryButton label={busy ? 'Preparando…' : 'Cambiar foto'} onPress={pickAvatar} disabled={busy} />
          </View>

          <View style={styles.field}>
            <Text style={styles.label}>Nombre visible</Text>
            <TextInput
              value={displayName}
              onChangeText={(v) => setDisplayName(v.slice(0, NAME_MAX))}
              style={styles.input}
              placeholderTextColor={Colors.textMuted}
            />
          </View>

          <View style={styles.field}>
            <Text style={styles.label}>Estado</Text>
            <TextInput
              value={statusText}
              onChangeText={(v) => setStatusText(v.slice(0, 40))}
              style={styles.input}
              placeholder="¿Qué estás haciendo?"
              placeholderTextColor={Colors.textMuted}
            />
          </View>

          <View style={styles.field}>
            <Text style={styles.label}>Biografía</Text>
            <TextInput
              value={bio}
              onChangeText={(v) => setBio(v.slice(0, 160))}
              style={[styles.input, styles.multiline]}
              multiline
              placeholderTextColor={Colors.textMuted}
            />
          </View>

          <View style={styles.field}>
            <Text style={styles.label}>Aura</Text>
            <View style={styles.auraList}>
              {auras.map((item) => (
                <AuraCard key={item.id} aura={item} selected={aura === item.id} onSelect={setAura} />
              ))}
            </View>
          </View>

          <View style={styles.field}>
            <Text style={styles.label}>Intereses</Text>
            <View style={styles.chipsRow}>
              {interests.map((interest) => (
                <InterestChip
                  key={interest.id}
                  interest={interest}
                  selected={selectedInterests.includes(interest.id)}
                  onToggle={toggleInterest}
                  disabled={selectedInterests.length >= 5}
                />
              ))}
            </View>
          </View>
        </ScrollView>

        <View style={styles.footer}>
          <GradientButton label="Guardar cambios" onPress={handleSave} disabled={!valid} loading={saving} />
        </View>
      </KeyboardAvoidingView>

      <ConfirmationModal
        visible={showDiscardConfirm}
        title="¿Descartar cambios?"
        description="Perderás las modificaciones que hiciste en tu perfil."
        confirmLabel="Descartar"
        cancelLabel="Seguir editando"
        destructive
        onConfirm={() => {
          setShowDiscardConfirm(false);
          router.back();
        }}
        onCancel={() => setShowDiscardConfirm(false)}
      />
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.md,
    paddingTop: Spacing.xs,
  },
  headerTitle: { ...Typography.h3, color: Colors.textPrimary },
  content: { padding: Spacing.xl, gap: Spacing.lg, paddingBottom: Spacing.xxl },
  coverSection: { gap: Spacing.sm, alignItems: 'center' },
  coverPreview: { width: '100%', height: 140, borderRadius: 16 },
  coverPlaceholder: { backgroundColor: Colors.surfaceSecondary, borderWidth: 1, borderColor: Colors.borderSoft },
  avatarSection: { alignItems: 'center', gap: Spacing.md },
  field: { gap: Spacing.sm },
  label: { ...Typography.label, color: Colors.textMuted },
  input: {
    ...Typography.body,
    color: Colors.textPrimary,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
  },
  multiline: { minHeight: 90, textAlignVertical: 'top' },
  auraList: { gap: Spacing.sm },
  chipsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.sm },
  footer: { paddingHorizontal: Spacing.xl, paddingBottom: Spacing.xl, paddingTop: Spacing.sm },
});
