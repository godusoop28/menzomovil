import * as FileSystem from 'expo-file-system/legacy';
import * as ImagePicker from 'expo-image-picker';
import { router } from 'expo-router';
import { useState } from 'react';
import { Image } from 'expo-image';
import { KeyboardAvoidingView, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { EmptyState } from '@/components/EmptyState';
import { GradientButton } from '@/components/GradientButton';
import { IconButton } from '@/components/IconButton';
import { ScreenContainer } from '@/components/ScreenContainer';
import { SecondaryButton } from '@/components/SecondaryButton';
import { useAppState } from '@/hooks/useAppState';
import { useHaptics } from '@/hooks/useHaptics';
import { useKeyboardBehavior } from '@/hooks/useKeyboardOffset';
import { useToast } from '@/hooks/useToast';
import { ApiError } from '@/services/api';
import { LOCAL_USER_ID } from '@/store/localUser';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import type { Post } from '@/types';
import { generateId } from '@/utils/id';

export default function CreateGalleryScreen() {
  const { actions } = useAppState();
  const { success } = useHaptics();
  const showToast = useToast();
  const behavior = useKeyboardBehavior();

  const [imageUri, setImageUri] = useState<string | undefined>();
  const [caption, setCaption] = useState('');
  const [tagsInput, setTagsInput] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [busy, setBusy] = useState(false);

  const valid = !!imageUri;

  async function pickImage() {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) return;
    const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], quality: 0.85 });
    if (result.canceled || !result.assets?.[0]) return;
    setBusy(true);
    try {
      const dir = `${FileSystem.documentDirectory}menzo-posts/`;
      await FileSystem.makeDirectoryAsync(dir, { intermediates: true }).catch(() => {});
      const dest = `${dir}gallery-${Date.now()}.jpg`;
      await FileSystem.copyAsync({ from: result.assets[0].uri, to: dest });
      setImageUri(dest);
    } catch {
      setImageUri(result.assets[0].uri);
    } finally {
      setBusy(false);
    }
  }

  async function handlePublish() {
    if (!valid || submitting) return;
    setSubmitting(true);
    const post: Post = {
      id: generateId('post'),
      authorId: LOCAL_USER_ID,
      type: 'image',
      body: caption.trim() || 'Un momento capturado para la comunidad.',
      imageUri,
      createdAt: new Date().toISOString(),
      likes: [],
      bookmarkedBy: [],
      commentCount: 0,
      featured: false,
      tags: tagsInput.split(',').map((t) => t.trim()).filter(Boolean).slice(0, 5),
      gradient: 'community',
    };
    try {
      await actions.createPost(post);
      success();
      showToast('Tu imagen ya está en Menzo.');
      router.replace('/(tabs)');
    } catch (e) {
      const message = e instanceof ApiError ? e.message : 'No pudimos publicar la imagen. Inténtalo de nuevo.';
      showToast(message);
      setSubmitting(false);
    }
  }

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <Text style={styles.headerTitle}>Galería</Text>
        <View style={{ width: 44 }} />
      </View>

      <KeyboardAvoidingView behavior={behavior} style={styles.flex}>
        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
          {imageUri ? (
            <View style={styles.imageWrap}>
              <Image source={{ uri: imageUri }} style={styles.image} contentFit="cover" />
              <SecondaryButton label="Cambiar imagen" onPress={pickImage} disabled={busy} />
            </View>
          ) : (
            <View style={styles.emptyWrap}>
              <EmptyState title="Elige una imagen para compartir" preset="community" />
              <SecondaryButton label={busy ? 'Preparando…' : 'Elegir desde la galería'} onPress={pickImage} disabled={busy} />
            </View>
          )}

          <TextInput
            value={caption}
            onChangeText={(v) => setCaption(v.slice(0, 300))}
            placeholder="Cuenta la historia detrás de esta imagen"
            placeholderTextColor={Colors.textMuted}
            style={styles.captionInput}
            multiline
          />
          <TextInput
            value={tagsInput}
            onChangeText={setTagsInput}
            placeholder="Etiquetas separadas por coma"
            placeholderTextColor={Colors.textMuted}
            style={styles.tagsInput}
          />
        </ScrollView>
        <View style={styles.footer}>
          <GradientButton label="Publicar en galería" onPress={handlePublish} disabled={!valid} loading={submitting} gradient="community" />
        </View>
      </KeyboardAvoidingView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: Spacing.md, paddingTop: Spacing.xs },
  headerTitle: { ...Typography.h3, color: Colors.textPrimary },
  content: { padding: Spacing.xl, gap: Spacing.md, paddingBottom: Spacing.xl },
  imageWrap: { gap: Spacing.sm },
  image: { width: '100%', height: 220, borderRadius: Radius.lg },
  emptyWrap: { gap: Spacing.md },
  captionInput: {
    ...Typography.body,
    color: Colors.textPrimary,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.md,
    padding: Spacing.md,
    minHeight: 80,
    textAlignVertical: 'top',
  },
  tagsInput: {
    ...Typography.body,
    color: Colors.textPrimary,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.md,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
  },
  footer: { paddingHorizontal: Spacing.xl, paddingBottom: Spacing.xl },
});
