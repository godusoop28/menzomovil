import { Ionicons } from '@expo/vector-icons';
import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

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

export default function CreatePollScreen() {
  const { actions } = useAppState();
  const { success, selection } = useHaptics();
  const showToast = useToast();
  const behavior = useKeyboardBehavior();

  const [question, setQuestion] = useState('');
  const [options, setOptions] = useState(['', '']);
  const [submitting, setSubmitting] = useState(false);

  const filledOptions = options.map((o) => o.trim()).filter(Boolean);
  const valid = question.trim().length >= 3 && filledOptions.length >= 2;

  function updateOption(index: number, value: string) {
    setOptions((current) => current.map((o, i) => (i === index ? value.slice(0, 60) : o)));
  }

  function addOption() {
    if (options.length >= 4) return;
    selection();
    setOptions((current) => [...current, '']);
  }

  function removeOption(index: number) {
    if (options.length <= 2) return;
    selection();
    setOptions((current) => current.filter((_, i) => i !== index));
  }

  async function handlePublish() {
    if (!valid || submitting) return;
    setSubmitting(true);
    const post: Post = {
      id: generateId('post'),
      authorId: LOCAL_USER_ID,
      type: 'poll',
      title: question.trim(),
      body: question.trim(),
      abstractVisual: { preset: 'prism' },
      createdAt: new Date().toISOString(),
      likes: [],
      bookmarkedBy: [],
      commentCount: 0,
      featured: false,
      tags: [],
      gradient: 'creative',
      pollOptions: filledOptions.map((label) => ({ id: generateId('opt'), label, votes: [] })),
    };
    try {
      await actions.createPost(post);
      success();
      showToast('Tu encuesta ya está en Menzo.');
      router.replace('/(tabs)');
    } catch (e) {
      const message = e instanceof ApiError ? e.message : 'No pudimos publicar la encuesta. Inténtalo de nuevo.';
      showToast(message);
      setSubmitting(false);
    }
  }

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <Text style={styles.headerTitle}>Encuesta</Text>
        <View style={{ width: 44 }} />
      </View>

      <KeyboardAvoidingView behavior={behavior} style={styles.flex}>
        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
          <TextInput
            value={question}
            onChangeText={(v) => setQuestion(v.slice(0, 140))}
            placeholder="Escribe tu pregunta"
            placeholderTextColor={Colors.textMuted}
            style={styles.questionInput}
            multiline
          />

          <Text style={styles.label}>Opciones (2 a 4)</Text>
          {options.map((option, index) => (
            <View key={index} style={styles.optionRow}>
              <TextInput
                value={option}
                onChangeText={(v) => updateOption(index, v)}
                placeholder={`Opción ${index + 1}`}
                placeholderTextColor={Colors.textMuted}
                style={styles.optionInput}
              />
              {options.length > 2 && (
                <Pressable accessibilityRole="button" accessibilityLabel="Eliminar opción" onPress={() => removeOption(index)}>
                  <Ionicons name="close-circle" size={22} color={Colors.textMuted} />
                </Pressable>
              )}
            </View>
          ))}

          {options.length < 4 && (
            <Pressable style={styles.addOption} onPress={addOption} accessibilityRole="button" accessibilityLabel="Añadir opción">
              <Ionicons name="add-circle-outline" size={20} color={Colors.cyan} />
              <Text style={styles.addOptionText}>Añadir opción</Text>
            </Pressable>
          )}
        </ScrollView>

        <View style={styles.footer}>
          <GradientButton label="Publicar encuesta" onPress={handlePublish} disabled={!valid} loading={submitting} gradient="creative" />
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
  questionInput: { ...Typography.h3, color: Colors.textPrimary, minHeight: 70 },
  label: { ...Typography.label, color: Colors.textMuted, marginTop: Spacing.sm },
  optionRow: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm },
  optionInput: {
    flex: 1,
    ...Typography.body,
    color: Colors.textPrimary,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.md,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
  },
  addOption: { flexDirection: 'row', alignItems: 'center', gap: 6, paddingVertical: Spacing.xs },
  addOptionText: { ...Typography.label, color: Colors.cyan },
  footer: { paddingHorizontal: Spacing.xl, paddingBottom: Spacing.xl },
});
