import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { router } from 'expo-router';
import * as WebBrowser from 'expo-web-browser';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { IconButton } from '@/components/IconButton';
import { ScreenContainer } from '@/components/ScreenContainer';
import { menzoAssets } from '@/constants/assets';
import { communityConfig, discordInviteUrl } from '@/config/community';
import { useHaptics } from '@/hooks/useHaptics';
import { Colors, Radius, Spacing, Typography } from '@/theme';

export default function AboutScreen() {
  const { selection } = useHaptics();

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
      </View>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <Image source={menzoAssets.banners.welcome} style={styles.hero} contentFit="cover" accessibilityLabel="MENZO — Message. Connect. Meet." />

        <Text style={styles.motto}>{communityConfig.motto}</Text>

        <Pressable
          onPress={() => {
            selection();
            WebBrowser.openBrowserAsync(discordInviteUrl);
          }}
          style={({ pressed }) => [styles.discordButton, { opacity: pressed ? 0.85 : 1 }]}
          accessibilityRole="button"
          accessibilityLabel="Únete al Discord oficial de Menzo">
          <Ionicons name="logo-discord" size={26} color="#FFFFFF" />
          <View style={styles.discordButtonText}>
            <Text style={styles.discordButtonTitle}>Únete al Discord oficial</Text>
            <Text style={styles.discordButtonSubtitle}>Chatea en vivo con la comunidad</Text>
          </View>
          <Ionicons name="chevron-forward" size={20} color="rgba(255,255,255,0.75)" />
        </Pressable>

        <Text style={styles.paragraph}>
          Menzo nació de la idea de conectar personas con intereses en común: comunidades, chats,
          llamadas en vivo y blogs, todo en un mismo lugar.
        </Text>

        <View style={styles.metaBlock}>
          <Text style={styles.metaLabel}>Versión</Text>
          <Text style={styles.metaValue}>1.0.0</Text>
        </View>
        <View style={styles.metaBlock}>
          <Text style={styles.metaLabel}>Estado</Text>
          <Text style={styles.metaValue}>Prototipo local</Text>
        </View>
        <View style={styles.metaBlock}>
          <Text style={styles.metaLabel}>Créditos</Text>
          <Text style={styles.metaValue}>Diseñado y desarrollado como un proyecto independiente.</Text>
        </View>
      </ScrollView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: { paddingHorizontal: Spacing.md, paddingTop: Spacing.xs },
  content: { padding: Spacing.xl, gap: Spacing.lg, paddingBottom: Spacing.xxl },
  hero: { width: '100%', aspectRatio: 1672 / 941, borderRadius: Radius.lg, marginTop: Spacing.sm },
  motto: { ...Typography.body, color: Colors.textSecondary, textAlign: 'center' },
  discordButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    backgroundColor: '#5865F2',
    borderRadius: Radius.lg,
    paddingVertical: Spacing.md,
    paddingHorizontal: Spacing.lg,
    minHeight: 64,
    shadowColor: '#5865F2',
    shadowOpacity: 0.45,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 8 },
    elevation: 6,
  },
  discordButtonText: { flex: 1, gap: 2 },
  discordButtonTitle: { ...Typography.label, fontSize: 16, color: '#FFFFFF' },
  discordButtonSubtitle: { ...Typography.caption, color: 'rgba(255,255,255,0.8)' },
  paragraph: { ...Typography.body, color: Colors.textSecondary, textAlign: 'center', lineHeight: 24 },
  metaBlock: { gap: 2, borderTopWidth: 1, borderTopColor: Colors.borderSoft, paddingTop: Spacing.sm },
  metaLabel: { ...Typography.caption, color: Colors.textMuted, textTransform: 'uppercase' },
  metaValue: { ...Typography.body, color: Colors.textPrimary },
});
