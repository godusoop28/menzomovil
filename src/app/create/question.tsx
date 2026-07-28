import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { AbstractArtwork } from '@/components/AbstractArtwork';
import { GradientButton } from '@/components/GradientButton';
import { IconButton } from '@/components/IconButton';
import { ScreenContainer } from '@/components/ScreenContainer';
import { useAppState } from '@/hooks/useAppState';
import { useHaptics } from '@/hooks/useHaptics';
import { useKeyboardBehavior } from '@/hooks/useKeyboardOffset';
import { useToast } from '@/hooks/useToast';
import { ApiError } from '@/services/api';
import { LOCAL_USER_ID } from '@/store/localUser';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import type { Post } from '@/types';
import { generateId } from '@/utils/id';

export default function CreateQuestionScreen() {
  const { actions } = useAppState();
  const { success } = useHaptics();
  const showToast = useToast();
  const behavior = useKeyboardBehavior();

  const [question, setQuestion] = useState('');
  const [context, setContext] = useState('');
  const [tagsInput, setTagsInput] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const valid = question.trim().length >= 5;

  async function handlePublish() {
    if (!valid || submitting) return;
    setSubmitting(true);
    const post: Post = {
      id: generateId('post'),
      authorId: LOCAL_USER_ID,
      type: 'question',
      title: question.trim(),
      body: context.trim() || question.trim(),
      abstractVisual: { preset: 'storm' },
      createdAt: new Date().toISOString(),
      likes: [],
      bookmarkedBy: [],
      commentCount: 0,
      featured: false,
      tags: tagsInput.split(',').map((t) => t.trim()).filter(Boolean).slice(0, 5),
      gradient: 'connection',
    };
    try {
      await actions.createPost(post);
      success();
      showToast('Tu pregunta ya está en Menzo.');
      router.replace('/(tabs)');
    } catch (e) {
      const message = e instanceof ApiError ? e.message : 'No pudimos publicar la pregunta. Inténtalo de nuevo.';
      showToast(message);
      setSubmitting(false);
    }
  }

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <Text style={styles.headerTitle}>Pregunta</Text>
        <View style={{ width: 44 }} />
      </View>

      <KeyboardAvoidingView behavior={behavior} style={styles.flex}>
        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
          <AbstractArtwork preset="storm" style={styles.hero} />
          <TextInput
            value={question}
            onChangeText={(v) => setQuestion(v.slice(0, 140))}
            placeholder="¿Qué quieres preguntarle a la comunidad?"
            placeholderTextColor={Colors.textMuted}
            style={styles.questionInput}
            multiline
          />
          <TextInput
            value={context}
            onChangeText={(v) => setContext(v.slice(0, 300))}
            placeholder="Contexto (opcional)"
            placeholderTextColor={Colors.textMuted}
            style={styles.contextInput}
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
          <GradientButton label="Publicar pregunta" onPress={handlePublish} disabled={!valid} loading={submitting} gradient="connection" />
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
  hero: { height: 100 },
  questionInput: { ...Typography.h3, color: Colors.textPrimary, minHeight: 70 },
  contextInput: {
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
