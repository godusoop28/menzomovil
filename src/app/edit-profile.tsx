import { Ionicons } from '@expo/vector-icons';
import * as FileSystem from 'expo-file-system/legacy';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { router } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, KeyboardAvoidingView, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { AuraCard } from '@/components/AuraCard';
import { ConfirmationModal } from '@/components/ConfirmationModal';
import { GradientButton } from '@/components/GradientButton';
import { IconButton } from '@/components/IconButton';
import { InterestChip } from '@/components/InterestChip';
import { ScreenContainer } from '@/components/ScreenContainer';
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

const BACKGROUND_COLORS = [
  Colors.orange,
  Colors.coral,
  Colors.blue,
  Colors.purple,
  Colors.green,
  Colors.cyan,
  Colors.yellow,
];

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
  const [backgroundUri, setBackgroundUri] = useState(profile.backgroundUri);
  const [backgroundColor, setBackgroundColor] = useState(profile.backgroundColor);
  const [selectedInterests, setSelectedInterests] = useState<InterestId[]>(profile.interests);
  const [showDiscardConfirm, setShowDiscardConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [busyCover, setBusyCover] = useState(false);
  const [busyBackground, setBusyBackground] = useState(false);
  const [saving, setSaving] = useState(false);

  const dirty =
    displayName !== profile.displayName ||
    bio !== profile.bio ||
    statusText !== profile.statusText ||
    aura !== profile.aura ||
    avatarUri !== profile.avatarUri ||
    coverUri !== profile.coverUri ||
    backgroundUri !== profile.backgroundUri ||
    backgroundColor !== profile.backgroundColor ||
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

  async function pickBackground() {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) return;
    const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], quality: 0.85 });
    if (result.canceled || !result.assets?.[0]) return;

    setBusyBackground(true);
    try {
      const dir = `${FileSystem.documentDirectory}menzo-backgrounds/`;
      await FileSystem.makeDirectoryAsync(dir, { intermediates: true }).catch(() => {});
      const dest = `${dir}background-${Date.now()}.jpg`;
      await FileSystem.copyAsync({ from: result.assets[0].uri, to: dest });
      setBackgroundUri(dest);
      setBackgroundColor(undefined);
    } catch {
      setBackgroundUri(result.assets[0].uri);
      setBackgroundColor(undefined);
    } finally {
      setBusyBackground(false);
    }
  }

  function handlePickBackgroundColor(color: string) {
    setBackgroundColor(color);
    setBackgroundUri(undefined);
  }

  function handleClearBackground() {
    setBackgroundUri(undefined);
    setBackgroundColor(undefined);
  }

  async function handleSave() {
    if (!valid || saving) return;
    setSaving(true);
    try {
      // "" limpia el campo en el backend; solo se manda si el usuario tenía algo puesto antes y lo quitó.
      const finalBackgroundUri = backgroundUri ?? (profile.backgroundUri ? '' : undefined);
      const finalBackgroundColor = backgroundColor ?? (profile.backgroundColor ? '' : undefined);
      await actions.updateProfile({
        displayName: collapseSpaces(displayName).trim(),
        bio,
        statusText,
        aura,
        avatarGradient: auraById(aura).gradient,
        avatarUri,
        coverUri,
        backgroundUri: finalBackgroundUri,
        backgroundColor: finalBackgroundColor,
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
            <Pressable
              onPress={pickCover}
              disabled={busyCover}
              accessibilityRole="button"
              accessibilityLabel="Cambiar portada"
              style={styles.coverCameraButton}>
              {busyCover ? <ActivityIndicator size="small" color="#FFFFFF" /> : <Ionicons name="camera" size={17} color="#FFFFFF" />}
            </Pressable>

            <View style={styles.avatarWrap}>
              <UserAvatar name={displayName} avatarUri={avatarUri} gradient={auraById(aura).gradient} size={92} />
              <Pressable
                onPress={pickAvatar}
                disabled={busy}
                accessibilityRole="button"
                accessibilityLabel="Cambiar foto de perfil"
                style={styles.avatarCameraButton}>
                {busy ? <ActivityIndicator size="small" color="#FFFFFF" /> : <Ionicons name="camera" size={15} color="#FFFFFF" />}
              </Pressable>
            </View>
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
            <Text style={styles.label}>Fondo del perfil</Text>
            {(backgroundUri || backgroundColor) && (
              backgroundUri ? (
                <Image source={{ uri: backgroundUri }} style={styles.backgroundPreview} contentFit="cover" />
              ) : (
                <View style={[styles.backgroundPreview, { backgroundColor }]} />
              )
            )}
            <View style={styles.chipsRow}>
              {BACKGROUND_COLORS.map((color) => (
                <Pressable
                  key={color}
                  onPress={() => handlePickBackgroundColor(color)}
                  accessibilityRole="button"
                  accessibilityLabel={`Fondo color ${color}`}
                  style={[
                    styles.colorSwatch,
                    { backgroundColor: color },
                    backgroundColor === color && styles.colorSwatchSelected,
                  ]}
                />
              ))}
              <Pressable onPress={pickBackground} disabled={busyBackground} style={styles.backgroundActionButton}>
                {busyBackground ? (
                  <ActivityIndicator size="small" color={Colors.textPrimary} />
                ) : (
                  <Text style={styles.backgroundActionLabel}>Subir foto</Text>
                )}
              </Pressable>
              {(backgroundUri || backgroundColor) && (
                <Pressable onPress={handleClearBackground} style={styles.backgroundActionButton}>
                  <Text style={[styles.backgroundActionLabel, styles.backgroundActionDanger]}>Quitar fondo</Text>
                </Pressable>
              )}
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
  coverSection: { position: 'relative', marginBottom: 70 },
  coverPreview: { width: '100%', height: 160, borderRadius: 16 },
  coverPlaceholder: { backgroundColor: Colors.surfaceSecondary, borderWidth: 1, borderColor: Colors.borderSoft },
  coverCameraButton: {
    position: 'absolute',
    top: 124,
    right: 12,
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(0,0,0,0.55)',
  },
  avatarWrap: {
    position: 'absolute',
    top: 110,
    alignSelf: 'center',
    borderRadius: 999,
    borderWidth: 4,
    borderColor: Colors.background,
  },
  avatarCameraButton: {
    position: 'absolute',
    bottom: 0,
    right: 0,
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(0,0,0,0.55)',
  },
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
  chipsRow: { flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center', gap: Spacing.sm },
  backgroundPreview: { width: '100%', height: 80, borderRadius: 14, marginBottom: Spacing.sm },
  colorSwatch: {
    width: 32,
    height: 32,
    borderRadius: 16,
    borderWidth: 2,
    borderColor: 'transparent',
  },
  colorSwatchSelected: { borderColor: Colors.textPrimary },
  backgroundActionButton: {
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    borderRadius: 999,
    paddingHorizontal: Spacing.sm,
    paddingVertical: 6,
  },
  backgroundActionLabel: { ...Typography.caption, color: Colors.textSecondary, fontWeight: '600' },
  backgroundActionDanger: { color: Colors.coral },
  footer: { paddingHorizontal: Spacing.xl, paddingBottom: Spacing.xl, paddingTop: Spacing.sm },
});
