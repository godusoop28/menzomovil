import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { useHaptics } from '@/hooks/useHaptics';
import { Colors, Gradients, Radius, Spacing, Typography } from '@/theme';

const options: {
  key: 'post' | 'question' | 'poll' | 'gallery' | 'event' | 'room';
  label: string;
  description: string;
  icon: keyof typeof Ionicons.glyphMap;
  gradient: keyof typeof Gradients;
}[] = [
  { key: 'post', label: 'Publicación', description: 'Comparte un pensamiento con la comunidad.', icon: 'document-text-outline', gradient: 'fire' },
  { key: 'question', label: 'Pregunta', description: 'Pregunta algo y deja que respondan.', icon: 'help-circle-outline', gradient: 'connection' },
  { key: 'poll', label: 'Encuesta', description: 'Vota entre 2 y 4 opciones.', icon: 'bar-chart-outline', gradient: 'creative' },
  { key: 'gallery', label: 'Galería', description: 'Comparte una imagen con una historia.', icon: 'image-outline', gradient: 'community' },
  { key: 'event', label: 'Evento', description: 'Organiza un encuentro para la comunidad.', icon: 'calendar-outline', gradient: 'midnight' },
  { key: 'room', label: 'Sala de chat', description: 'Crea una sala pública para que otros entren y hablen.', icon: 'chatbubbles-outline', gradient: 'connection' },
];

export function CreateMenu() {
  const { selection } = useHaptics();

  return (
    <View style={styles.list}>
      {options.map((option) => (
        <Pressable
          key={option.key}
          onPress={() => {
            selection();
            router.push(`/create/${option.key}`);
          }}
          style={({ pressed }) => [styles.item, { opacity: pressed ? 0.85 : 1 }]}
          accessibilityRole="button"
          accessibilityLabel={option.label}>
          <LinearGradient
            colors={Gradients[option.gradient] as unknown as [string, string, ...string[]]}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.iconWrap}>
            <Ionicons name={option.icon} size={22} color="#FFFFFF" />
          </LinearGradient>
          <View style={styles.textWrap}>
            <Text style={styles.label}>{option.label}</Text>
            <Text style={styles.description}>{option.description}</Text>
          </View>
          <Ionicons name="chevron-forward" size={18} color={Colors.textMuted} />
        </Pressable>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  list: { gap: Spacing.sm },
  item: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.lg,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    padding: Spacing.md,
  },
  iconWrap: { width: 48, height: 48, borderRadius: Radius.md, alignItems: 'center', justifyContent: 'center' },
  textWrap: { flex: 1, gap: 2 },
  label: { ...Typography.bodyMedium, color: Colors.textPrimary },
  description: { ...Typography.caption, color: Colors.textMuted },
});
