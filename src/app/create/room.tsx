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
import { Colors, Spacing, Typography } from '@/theme';

export default function CreateRoomScreen() {
  const { actions } = useAppState();
  const { success } = useHaptics();
  const showToast = useToast();
  const behavior = useKeyboardBehavior();

  const [name, setName] = useState('');
  const [topic, setTopic] = useState('');
  const [description, setDescription] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const valid = name.trim().length >= 3;

  async function handleCreate() {
    if (!valid || submitting) return;
    setSubmitting(true);
    const roomId = await actions.createRoom({
      name: name.trim(),
      topic: topic.trim(),
      description: description.trim(),
    });
    if (roomId) {
      success();
      router.replace(`/chat/${roomId}`);
    } else {
      showToast('No pudimos crear la sala. Inténtalo de nuevo.');
      setSubmitting(false);
    }
  }

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <Text style={styles.headerTitle}>Sala de chat</Text>
        <View style={{ width: 44 }} />
      </View>

      <KeyboardAvoidingView behavior={behavior} style={styles.flex}>
        <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
          <Text style={styles.subtitle}>
            Crea una sala pública. Cualquiera en Menzo podrá encontrarla, entrar y hablar.
          </Text>

          <View style={styles.field}>
            <Text style={styles.label}>Nombre de la sala</Text>
            <TextInput
              value={name}
              onChangeText={(v) => setName(v.slice(0, 100))}
              placeholder="Ej. Rincón de artistas"
              placeholderTextColor={Colors.textMuted}
              style={styles.input}
            />
          </View>

          <View style={styles.field}>
            <Text style={styles.label}>Tema (opcional)</Text>
            <TextInput
              value={topic}
              onChangeText={(v) => setTopic(v.slice(0, 150))}
              placeholder="De qué se habla aquí"
              placeholderTextColor={Colors.textMuted}
              style={styles.input}
            />
          </View>

          <View style={styles.field}>
            <Text style={styles.label}>Descripción (opcional)</Text>
            <TextInput
              value={description}
              onChangeText={(v) => setDescription(v.slice(0, 2000))}
              placeholder="Cuéntale a la comunidad de qué trata esta sala"
              placeholderTextColor={Colors.textMuted}
              style={[styles.input, styles.multiline]}
              multiline
            />
          </View>
        </ScrollView>

        <View style={styles.footer}>
          <GradientButton label="Crear sala" onPress={handleCreate} disabled={!valid} loading={submitting} gradient="connection" />
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
  subtitle: { ...Typography.body, color: Colors.textSecondary },
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
  footer: { paddingHorizontal: Spacing.xl, paddingBottom: Spacing.xl },
});
