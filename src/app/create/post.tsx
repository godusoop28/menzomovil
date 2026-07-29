import * as FileSystem from 'expo-file-system/legacy';
import * as ImagePicker from 'expo-image-picker';
import { router } from 'expo-router';
import { useState } from 'react';
import { Image } from 'expo-image';
import { KeyboardAvoidingView, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { AbstractArtwork } from '@/components/AbstractArtwork';
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
import { Colors, Radius, Spacing, Typography, useAccent } from '@/theme';
import type { AbstractVisualPreset, Post } from '@/types';
import { generateId } from '@/utils/id';

const presets: AbstractVisualPreset[] = ['fire', 'storm', 'eclipse', 'rebirth', 'prism', 'midnight', 'memory', 'community'];

export default function CreatePostScreen() {
  const { actions } = useAppState();
  const accent = useAccent();
  const { success } = useHaptics();
  const showToast = useToast();
  const behavior = useKeyboardBehavior();

  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [tagsInput, setTagsInput] = useState('');
  const [preset, setPreset] = useState<AbstractVisualPreset | null>('fire');
  const [imageUri, setImageUri] = useState<string | undefined>();
  const [submitting, setSubmitting] = useState(false);

  const valid = body.trim().length >= 3;

  async function pickImage() {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) {
      showToast('Necesitamos acceso a tus fotos para poder adjuntar una imagen.');
      return;
    }
    const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], quality: 0.85 });
    if (result.canceled || !result.assets?.[0]) return;
    try {
      const dir = `${FileSystem.documentDirectory}menzo-posts/`;
      await FileSystem.makeDirectoryAsync(dir, { intermediates: true }).catch(() => {});
      const dest = `${dir}post-${Date.now()}.jpg`;
      await FileSystem.copyAsync({ from: result.assets[0].uri, to: dest });
      setImageUri(dest);
    } catch {
      setImageUri(result.assets[0].uri);
    }
  }

  async function handlePublish() {
    if (!valid || submitting) return;
    setSubmitting(true);
    const post: Post = {
      id: generateId('post'),
      authorId: LOCAL_USER_ID,
      type: imageUri ? 'image' : 'text',
      title: title.trim() || undefined,
      body: body.trim(),
      abstractVisual: preset ? { preset } : undefined,
      imageUri,
      createdAt: new Date().toISOString(),
      likes: [],
      bookmarkedBy: [],
      commentCount: 0,
      featured: false,
      tags: tagsInput
        .split(',')
        .map((t) => t.trim())
        .filter(Boolean)
        .slice(0, 5),
      gradient: 'fire',
    };
    try {
      await actions.createPost(post);
      success();
      showToast('Tu publicación ya está en Menzo.');
      router.replace('/(tabs)');
    } catch (e) {
      const message = e instanceof ApiError ? e.message : 'No pudimos publicar. Inténtalo de nuevo.';
      showToast(message);
      setSubmitting(false);
    }
  }

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <Text style={styles.headerTitle}>Publicación</Text>
        <View style={{ width: 44 }} />
      </View>

      <KeyboardAvoidingView behavior={behavior} style={styles.flex}>
        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
          <TextInput
            value={title}
            onChangeText={(v) => setTitle(v.slice(0, 80))}
            placeholder="Título (opcional)"
            placeholderTextColor={Colors.textMuted}
            style={styles.titleInput}
          />
          <TextInput
            value={body}
            onChangeText={(v) => setBody(v.slice(0, 600))}
            placeholder="¿Qué quieres contar?"
            placeholderTextColor={Colors.textMuted}
            style={styles.bodyInput}
            multiline
          />
          <Text style={styles.counter}>{body.length}/600</Text>

          <TextInput
            value={tagsInput}
            onChangeText={setTagsInput}
            placeholder="Etiquetas separadas por coma"
            placeholderTextColor={Colors.textMuted}
            style={styles.tagsInput}
          />

          {imageUri ? (
            <View style={styles.imagePreviewWrap}>
              <Image source={{ uri: imageUri }} style={styles.imagePreview} contentFit="cover" />
              <SecondaryButton label="Quitar imagen" onPress={() => setImageUri(undefined)} />
            </View>
          ) : (
            <SecondaryButton label="Añadir imagen desde la galería" onPress={pickImage} />
          )}

          <Text style={styles.label}>Visual abstracto</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.presetRow}>
            {presets.map((p) => (
              <View key={p} style={styles.presetItem}>
                <AbstractArtwork
                  preset={p}
                  radius={Radius.md}
                  style={[styles.presetArt, preset === p && { borderColor: accent.color }]}
                />
                <Text
                  onPress={() => setPreset(preset === p ? null : p)}
                  accessibilityRole="button"
                  style={styles.presetLabel}>
                  {p}
                </Text>
              </View>
            ))}
          </ScrollView>
        </ScrollView>

        <View style={styles.footer}>
          <GradientButton label="Publicar" onPress={handlePublish} disabled={!valid} loading={submitting} />
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
  titleInput: { ...Typography.h3, color: Colors.textPrimary, borderBottomWidth: 1, borderBottomColor: Colors.borderSoft, paddingVertical: Spacing.sm },
  bodyInput: { ...Typography.body, color: Colors.textPrimary, minHeight: 120, textAlignVertical: 'top' },
  counter: { ...Typography.caption, color: Colors.textMuted, textAlign: 'right', marginTop: -8 },
  tagsInput: {
    ...Typography.body,
    color: Colors.textPrimary,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.md,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
  },
  imagePreviewWrap: { gap: Spacing.sm },
  imagePreview: { width: '100%', height: 160, borderRadius: Radius.md },
  label: { ...Typography.label, color: Colors.textMuted, marginTop: Spacing.sm },
  presetRow: { gap: Spacing.sm, paddingVertical: 4 },
  presetItem: { alignItems: 'center', gap: 4 },
  presetArt: { width: 64, height: 64, borderWidth: 2, borderColor: 'transparent' },
  presetLabel: { ...Typography.caption, color: Colors.textSecondary, textTransform: 'capitalize' },
  footer: { paddingHorizontal: Spacing.xl, paddingBottom: Spacing.xl },
});
