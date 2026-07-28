import { router, useLocalSearchParams } from 'expo-router';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { AbstractArtwork } from '@/components/AbstractArtwork';
import { EmptyState } from '@/components/EmptyState';
import { GradientButton } from '@/components/GradientButton';
import { IconButton } from '@/components/IconButton';
import { MemberCard } from '@/components/MemberCard';
import { ScreenContainer } from '@/components/ScreenContainer';
import { useAppState } from '@/hooks/useAppState';
import { LOCAL_USER_ID } from '@/store/localUser';
import { findEvent } from '@/store/selectors';
import { Colors, Spacing, Typography } from '@/theme';

export default function EventDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { state, actions } = useAppState();
  const event = findEvent(state.social, id);

  if (!event) {
    return (
      <ScreenContainer>
        <View style={styles.header}>
          <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        </View>
        <EmptyState title="No encontramos este evento" preset="storm" />
      </ScreenContainer>
    );
  }

  const attending = event.attendees.includes(LOCAL_USER_ID);
  const attendees = event.attendees
    .map((uid) => state.social.users.find((u) => u.id === uid))
    .filter((u): u is NonNullable<typeof u> => !!u);

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
      </View>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <AbstractArtwork preset="midnight" style={styles.hero} />
        <Text style={styles.kind}>{event.kind}</Text>
        <Text style={styles.title}>{event.title}</Text>
        <Text style={styles.meta}>{event.date} · {event.time}</Text>
        <Text style={styles.description}>{event.description}</Text>

        <GradientButton
          label={attending ? 'Cancelar asistencia' : 'Confirmar asistencia'}
          onPress={() => actions.attendEvent(event.id)}
          gradient={attending ? 'community' : 'fire'}
        />

        <Text style={styles.sectionTitle}>Asistentes ({attendees.length})</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.attendeesRow}>
          {attendees.map((user) => (
            <MemberCard key={user.id} user={user} variant="column" />
          ))}
        </ScrollView>
      </ScrollView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: { paddingHorizontal: Spacing.md, paddingTop: Spacing.xs },
  content: { padding: Spacing.lg, gap: Spacing.sm, paddingBottom: Spacing.xxl },
  hero: { height: 140, marginBottom: Spacing.sm },
  kind: { ...Typography.caption, color: Colors.violet, fontWeight: '700', textTransform: 'uppercase' },
  title: { ...Typography.h1, color: Colors.textPrimary },
  meta: { ...Typography.body, color: Colors.textMuted },
  description: { ...Typography.body, color: Colors.textSecondary, marginBottom: Spacing.md },
  sectionTitle: { ...Typography.h3, color: Colors.textPrimary, marginTop: Spacing.lg },
  attendeesRow: { gap: Spacing.md, paddingVertical: Spacing.xs },
});
