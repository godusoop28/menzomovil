import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Colors, Gradients, Radius, Spacing, Typography } from '@/theme';
import type { ChatRoom } from '@/types';

/** Franja horizontal de salas en vivo — va arriba del feed, así una sala con voz activa se nota
 * de inmediato en vez de mezclarse con el resto de las tarjetas. Espejo de LiveRoomsCarousel en
 * menzoweb. */
export function LiveRoomsCarousel({ rooms }: { rooms: ChatRoom[] }) {
  if (rooms.length === 0) return null;

  return (
    <View style={styles.wrap}>
      <View style={styles.header}>
        <View style={styles.liveDot} />
        <Text style={styles.headerLabel}>En vivo ahora</Text>
      </View>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.scroll}>
        {rooms.map((room) => (
          <Pressable
            key={room.id}
            onPress={() => router.push(`/chat/${room.id}`)}
            accessibilityRole="button"
            accessibilityLabel={`Sala en vivo: ${room.name}`}
            style={styles.card}>
            {room.coverUri ? (
              <Image source={{ uri: room.coverUri }} style={StyleSheet.absoluteFill} contentFit="cover" />
            ) : (
              <LinearGradient
                colors={Gradients[room.gradient] as unknown as [string, string, ...string[]]}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={StyleSheet.absoluteFill}>
                <View style={styles.iconCenter}>
                  <Ionicons name="chatbubbles" size={26} color="rgba(255,255,255,0.7)" />
                </View>
              </LinearGradient>
            )}
            <LinearGradient
              colors={['transparent', 'rgba(0,0,0,0.2)', 'rgba(0,0,0,0.85)']}
              locations={[0, 0.4, 1]}
              style={StyleSheet.absoluteFill}
            />
            <View style={styles.liveBadge}>
              <View style={styles.liveBadgeDot} />
              <Text style={styles.liveBadgeLabel}>Live</Text>
            </View>
            <View style={styles.cardText}>
              <Text style={styles.cardName} numberOfLines={1}>
                {room.name}
              </Text>
              <Text style={styles.cardOnline}>{room.onlineCount} conectados</Text>
            </View>
          </Pressable>
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { gap: Spacing.xs },
  header: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  liveDot: { width: 8, height: 8, borderRadius: 4, backgroundColor: Colors.coral },
  headerLabel: { ...Typography.label, fontSize: 13, fontWeight: '800', textTransform: 'uppercase', letterSpacing: 0.5, color: Colors.coral },
  scroll: { gap: Spacing.sm, paddingRight: Spacing.lg },
  card: {
    width: 150,
    height: 96,
    borderRadius: Radius.lg,
    overflow: 'hidden',
    justifyContent: 'flex-end',
  },
  iconCenter: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, alignItems: 'center', justifyContent: 'center' },
  liveBadge: {
    position: 'absolute',
    top: 8,
    left: 8,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: Colors.coral,
    borderRadius: 999,
    paddingHorizontal: 8,
    paddingVertical: 2,
  },
  liveBadgeDot: { width: 5, height: 5, borderRadius: 2.5, backgroundColor: '#FFFFFF' },
  liveBadgeLabel: { ...Typography.caption, fontSize: 9, fontWeight: '800', textTransform: 'uppercase', letterSpacing: 0.4, color: '#FFFFFF' },
  cardText: { padding: 10, gap: 1 },
  cardName: { ...Typography.label, fontSize: 12, color: '#FFFFFF' },
  cardOnline: { ...Typography.caption, fontSize: 10, color: 'rgba(255,255,255,0.75)' },
});
