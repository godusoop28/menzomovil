import { router } from 'expo-router';
import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { ChatRoomCard } from '@/components/ChatRoomCard';
import { EmptyState } from '@/components/EmptyState';
import { IconButton } from '@/components/IconButton';
import { MemberCard } from '@/components/MemberCard';
import { PostCard } from '@/components/PostCard';
import { ScreenContainer } from '@/components/ScreenContainer';
import { useAppState } from '@/hooks/useAppState';
import { Colors, Radius, Spacing, Typography } from '@/theme';
import { matchesQuery } from '@/utils/search';

export default function SearchScreen() {
  const { state, actions } = useAppState();
  const [query, setQuery] = useState('');

  const results = useMemo(() => {
    if (!query.trim()) return null;
    const members = state.social.users.filter(
      (u) => matchesQuery(u.displayName, query) || matchesQuery(u.username, query)
    );
    const posts = state.social.posts.filter(
      (p) =>
        matchesQuery(p.body, query) ||
        (p.title && matchesQuery(p.title, query)) ||
        p.tags.some((t) => matchesQuery(t, query))
    );
    const rooms = state.social.rooms.filter(
      (r) => matchesQuery(r.name, query) || matchesQuery(r.topic, query) || matchesQuery(r.description, query)
    );
    return { members, posts, rooms };
  }, [query, state.social]);

  const hasResults = results && (results.members.length + results.posts.length + results.rooms.length > 0);

  function commitSearch() {
    if (query.trim()) actions.addRecentSearch(query.trim());
  }

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <View style={styles.inputWrap}>
          <TextInput
            value={query}
            onChangeText={setQuery}
            onSubmitEditing={commitSearch}
            placeholder="Busca miembros, publicaciones, salas o tags"
            placeholderTextColor={Colors.textMuted}
            style={styles.input}
            autoFocus
            returnKeyType="search"
          />
          {!!query && (
            <Pressable onPress={() => setQuery('')} accessibilityRole="button" accessibilityLabel="Limpiar búsqueda">
              <Text style={styles.clear}>Limpiar</Text>
            </Pressable>
          )}
        </View>
      </View>

      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        {!query.trim() && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Búsquedas recientes</Text>
            {state.social.recentSearches.length === 0 ? (
              <Text style={styles.emptyRecent}>Aún no has buscado nada.</Text>
            ) : (
              <View style={styles.recentList}>
                {state.social.recentSearches.map((item) => (
                  <Pressable key={item} onPress={() => setQuery(item)} style={styles.recentChip}>
                    <Text style={styles.recentChipText}>{item}</Text>
                  </Pressable>
                ))}
                <Pressable onPress={actions.clearRecentSearches} accessibilityRole="button" accessibilityLabel="Borrar búsquedas recientes">
                  <Text style={styles.clear}>Borrar historial</Text>
                </Pressable>
              </View>
            )}
          </View>
        )}

        {results && !hasResults && (
          <EmptyState
            title="No encontramos nada con ese nombre"
            description="Pero quizá aún no ha regresado."
            preset="storm"
          />
        )}

        {results && results.members.length > 0 && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Miembros</Text>
            {results.members.map((user) => (
              <MemberCard key={user.id} user={user} />
            ))}
          </View>
        )}

        {results && results.rooms.length > 0 && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Salas</Text>
            {results.rooms.map((room) => (
              <ChatRoomCard key={room.id} room={room} />
            ))}
          </View>
        )}

        {results && results.posts.length > 0 && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Publicaciones</Text>
            {results.posts.map((post) => (
              <PostCard key={post.id} post={post} />
            ))}
          </View>
        )}
      </ScrollView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm, paddingHorizontal: Spacing.md, paddingTop: Spacing.xs },
  inputWrap: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.pill,
    paddingHorizontal: Spacing.md,
  },
  input: { flex: 1, ...Typography.body, color: Colors.textPrimary, paddingVertical: Spacing.sm },
  clear: { ...Typography.label, color: Colors.cyan },
  content: { padding: Spacing.lg, gap: Spacing.lg, paddingBottom: Spacing.xxl },
  section: { gap: Spacing.sm },
  sectionTitle: { ...Typography.h3, color: Colors.textPrimary },
  emptyRecent: { ...Typography.body, color: Colors.textMuted },
  recentList: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.sm, alignItems: 'center' },
  recentChip: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: Radius.pill,
    backgroundColor: Colors.surfaceSecondary,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
  },
  recentChipText: { ...Typography.caption, color: Colors.textSecondary },
});
