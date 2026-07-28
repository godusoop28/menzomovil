import { router } from 'expo-router';
import { useMemo } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { EmptyState } from '@/components/EmptyState';
import { GradientButton } from '@/components/GradientButton';
import { IconButton } from '@/components/IconButton';
import { ScreenContainer } from '@/components/ScreenContainer';
import { useAppState } from '@/hooks/useAppState';
import { LOCAL_USER_ID } from '@/store/localUser';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import type { CommunityEvent } from '@/types';

function EventCard({ event }: { event: CommunityEvent }) {
  const { actions } = useAppState();
  const attending = event.attendees.includes(LOCAL_USER_ID);

  return (
    <Pressable style={styles.card} onPress={() => router.push(`/events/${event.id}`)} accessibilityRole="button">
      <Text style={styles.cardKind}>{event.kind}</Text>
      <Text style={styles.cardTitle}>{event.title}</Text>
      <Text style={styles.cardMeta}>
        {event.date} · {event.time} · {event.attendees.length} asistentes
      </Text>
      <GradientButton
        label={attending ? 'Cancelar asistencia' : 'Confirmar asistencia'}
        onPress={() => actions.attendEvent(event.id)}
        gradient={attending ? 'community' : 'fire'}
        size="md"
      />
    </Pressable>
  );
}

export default function EventsScreen() {
  const { state } = useAppState();
  const todayKey = new Date().toISOString().slice(0, 10);

  const { today, upcoming, past } = useMemo(() => {
    const sorted = [...state.social.events].sort((a, b) => a.date.localeCompare(b.date));
    return {
      today: sorted.filter((e) => e.date === todayKey),
      upcoming: sorted.filter((e) => e.date > todayKey),
      past: sorted.filter((e) => e.date < todayKey).reverse(),
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state.social.events]);

  const isEmpty = today.length === 0 && upcoming.length === 0 && past.length === 0;

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <Text style={styles.headerTitle}>Eventos</Text>
        <View style={{ width: 44 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        {isEmpty && <EmptyState title="No hay eventos programados todavía" preset="midnight" />}

        {today.length > 0 && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Hoy</Text>
            {today.map((event) => (
              <EventCard key={event.id} event={event} />
            ))}
          </View>
        )}

        {upcoming.length > 0 && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Próximos</Text>
            {upcoming.map((event) => (
              <EventCard key={event.id} event={event} />
            ))}
          </View>
        )}

        {past.length > 0 && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Anteriores</Text>
            {past.map((event) => (
              <EventCard key={event.id} event={event} />
            ))}
          </View>
        )}
      </ScrollView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: Spacing.md, paddingTop: Spacing.xs },
  headerTitle: { ...Typography.h3, color: Colors.textPrimary },
  content: { padding: Spacing.lg, gap: Spacing.lg, paddingBottom: Spacing.xxl },
  section: { gap: Spacing.sm },
  sectionTitle: { ...Typography.h3, color: Colors.textPrimary },
  card: {
    backgroundColor: Colors.surface,
    borderRadius: Radius.lg,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    padding: Spacing.lg,
    gap: Spacing.xs,
  },
  cardKind: { ...Typography.caption, color: Colors.violet, fontWeight: '700', textTransform: 'uppercase' },
  cardTitle: { ...Typography.h3, color: Colors.textPrimary },
  cardMeta: { ...Typography.caption, color: Colors.textMuted, marginBottom: Spacing.xs },
});
