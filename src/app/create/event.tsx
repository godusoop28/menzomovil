import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

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
import type { CommunityEvent, Post } from '@/types';
import { generateId } from '@/utils/id';

export default function CreateEventScreen() {
  const { actions } = useAppState();
  const { success } = useHaptics();
  const showToast = useToast();
  const behavior = useKeyboardBehavior();

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [date, setDate] = useState('');
  const [time, setTime] = useState('');
  const [kind, setKind] = useState('Encuentro');
  const [submitting, setSubmitting] = useState(false);

  const validDate = /^\d{4}-\d{2}-\d{2}$/.test(date.trim());
  const validTime = /^([01]\d|2[0-3]):[0-5]\d$/.test(time.trim());
  const valid = title.trim().length >= 3 && validDate && validTime;

  async function handlePublish() {
    if (!valid || submitting) return;
    setSubmitting(true);
    const draftEvent: CommunityEvent = {
      id: generateId('event'),
      title: title.trim(),
      description: description.trim() || 'Un nuevo encuentro para la comunidad.',
      date: date.trim(),
      time: time.trim(),
      kind: kind.trim() || 'Encuentro',
      attendees: [LOCAL_USER_ID],
    };
    // El post que enlaza al evento necesita el ID real que asigna el servidor
    // (si mandamos el ID local, el backend no lo reconoce y falla).
    const createdEvent = await actions.createEvent(draftEvent);
    if (!createdEvent) {
      setSubmitting(false);
      showToast('No pudimos crear el evento. Inténtalo de nuevo.');
      return;
    }

    const post: Post = {
      id: generateId('post'),
      authorId: LOCAL_USER_ID,
      type: 'event',
      title: createdEvent.title,
      body: createdEvent.description,
      abstractVisual: { preset: 'midnight' },
      createdAt: new Date().toISOString(),
      likes: [],
      bookmarkedBy: [],
      commentCount: 0,
      featured: false,
      tags: ['evento'],
      eventId: createdEvent.id,
      gradient: 'midnight',
    };
    try {
      await actions.createPost(post);
      success();
      showToast('Tu evento ya está en Menzo.');
      router.replace('/(tabs)');
    } catch (e) {
      const message = e instanceof ApiError ? e.message : 'El evento se creó, pero no pudimos publicarlo. Inténtalo de nuevo.';
      showToast(message);
      setSubmitting(false);
    }
  }

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <Text style={styles.headerTitle}>Evento</Text>
        <View style={{ width: 44 }} />
      </View>

      <KeyboardAvoidingView behavior={behavior} style={styles.flex}>
        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
          <TextInput
            value={title}
            onChangeText={(v) => setTitle(v.slice(0, 80))}
            placeholder="Nombre del evento"
            placeholderTextColor={Colors.textMuted}
            style={styles.titleInput}
          />
          <TextInput
            value={description}
            onChangeText={(v) => setDescription(v.slice(0, 300))}
            placeholder="Descripción"
            placeholderTextColor={Colors.textMuted}
            style={styles.textarea}
            multiline
          />

          <View style={styles.row}>
            <View style={styles.rowField}>
              <Text style={styles.label}>Fecha (AAAA-MM-DD)</Text>
              <TextInput
                value={date}
                onChangeText={setDate}
                placeholder="2026-07-25"
                placeholderTextColor={Colors.textMuted}
                style={styles.input}
                keyboardType="numbers-and-punctuation"
              />
            </View>
            <View style={styles.rowField}>
              <Text style={styles.label}>Hora (HH:MM)</Text>
              <TextInput
                value={time}
                onChangeText={setTime}
                placeholder="19:00"
                placeholderTextColor={Colors.textMuted}
                style={styles.input}
                keyboardType="numbers-and-punctuation"
              />
            </View>
          </View>

          <Text style={styles.label}>Tipo</Text>
          <TextInput
            value={kind}
            onChangeText={(v) => setKind(v.slice(0, 30))}
            placeholder="Encuentro, torneo, reto creativo…"
            placeholderTextColor={Colors.textMuted}
            style={styles.input}
          />
        </ScrollView>

        <View style={styles.footer}>
          <GradientButton label="Publicar evento" onPress={handlePublish} disabled={!valid} loading={submitting} gradient="midnight" />
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
  textarea: {
    ...Typography.body,
    color: Colors.textPrimary,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.md,
    padding: Spacing.md,
    minHeight: 80,
    textAlignVertical: 'top',
  },
  row: { flexDirection: 'row', gap: Spacing.md },
  rowField: { flex: 1, gap: Spacing.xs },
  label: { ...Typography.label, color: Colors.textMuted },
  input: {
    ...Typography.body,
    color: Colors.textPrimary,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.md,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
  },
  footer: { paddingHorizontal: Spacing.xl, paddingBottom: Spacing.xl },
});
