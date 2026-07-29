import { Ionicons } from '@expo/vector-icons';
import * as FileSystem from 'expo-file-system/legacy';
import { Image } from 'expo-image';
import * as ImagePicker from 'expo-image-picker';
import { useState } from 'react';
import { Pressable, StyleSheet, TextInput, View } from 'react-native';

import { IconButton } from './IconButton';
import { useAppState } from '@/hooks/useAppState';
import { useHaptics } from '@/hooks/useHaptics';
import { useToast } from '@/hooks/useToast';
import { Colors, Radius, Spacing } from '@/theme';

export function WallComposer({ profileId, placeholder }: { profileId: string; placeholder: string }) {
  const { actions } = useAppState();
  const { success } = useHaptics();
  const showToast = useToast();
  const [draft, setDraft] = useState('');
  const [pendingImage, setPendingImage] = useState<string | undefined>();
  const [submitting, setSubmitting] = useState(false);

  async function pickImage() {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) {
      showToast('Necesitamos acceso a tus fotos para adjuntar una imagen.');
      return;
    }
    const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], quality: 0.8 });
    if (result.canceled || !result.assets?.[0]) return;
    try {
      const dir = `${FileSystem.documentDirectory}menzo-wall/`;
      await FileSystem.makeDirectoryAsync(dir, { intermediates: true }).catch(() => {});
      const dest = `${dir}img-${Date.now()}.jpg`;
      await FileSystem.copyAsync({ from: result.assets[0].uri, to: dest });
      setPendingImage(dest);
    } catch {
      setPendingImage(result.assets[0].uri);
    }
  }

  async function submit() {
    const trimmed = draft.trim();
    if ((!trimmed && !pendingImage) || submitting) return;
    setSubmitting(true);
    try {
      await actions.addWallMessage(profileId, trimmed, pendingImage);
      setDraft('');
      setPendingImage(undefined);
      success();
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <View style={styles.wrap}>
      {pendingImage && (
        <View style={styles.previewRow}>
          <Image source={{ uri: pendingImage }} style={styles.previewImage} contentFit="cover" />
          <Pressable onPress={() => setPendingImage(undefined)} accessibilityRole="button" accessibilityLabel="Quitar imagen">
            <Ionicons name="close-circle" size={18} color={Colors.coral} />
          </Pressable>
        </View>
      )}
      <View style={styles.composer}>
        <IconButton name="image-outline" label="Adjuntar imagen" onPress={pickImage} size={18} color={Colors.textMuted} />
        <TextInput
          value={draft}
          onChangeText={setDraft}
          placeholder={placeholder}
          placeholderTextColor={Colors.textMuted}
          style={styles.composerInput}
          multiline
        />
        <IconButton name="send" label="Publicar en el muro" onPress={submit} variant="surface" />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { gap: Spacing.xs },
  previewRow: { flexDirection: 'row', alignItems: 'center', gap: Spacing.xs },
  previewImage: { width: 48, height: 48, borderRadius: Radius.sm },
  composer: { flexDirection: 'row', alignItems: 'center', gap: Spacing.xs },
  composerInput: {
    flex: 1,
    color: Colors.textPrimary,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.md,
    paddingHorizontal: Spacing.sm,
    paddingVertical: Spacing.xs,
    maxHeight: 100,
  },
});
