import { Ionicons } from '@expo/vector-icons';
import type { BottomTabBarProps } from 'expo-router/js-tabs';
import { BlurView } from 'expo-blur';
import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { useHaptics } from '@/hooks/useHaptics';
import { Colors, Radius, Spacing, Typography, useAccent } from '@/theme';

const TAB_META: Record<string, { label: string; icon: keyof typeof Ionicons.glyphMap; iconActive: keyof typeof Ionicons.glyphMap }> = {
  index: { label: 'Inicio', icon: 'home-outline', iconActive: 'home' },
  online: { label: 'En línea', icon: 'people-outline', iconActive: 'people' },
  chats: { label: 'Chats', icon: 'chatbubbles-outline', iconActive: 'chatbubbles' },
  profile: { label: 'Perfil', icon: 'person-circle-outline', iconActive: 'person-circle' },
};

export function CustomTabBar({ state, navigation }: BottomTabBarProps) {
  const insets = useSafeAreaInsets();
  const { light, medium } = useHaptics();
  const accent = useAccent();

  const leftRoutes = state.routes.slice(0, 2);
  const rightRoutes = state.routes.slice(2);

  function renderTab(route: (typeof state.routes)[number]) {
    const meta = TAB_META[route.name];
    if (!meta) return null;
    const routeIndex = state.routes.findIndex((r) => r.key === route.key);
    const focused = state.index === routeIndex;

    return (
      <Pressable
        key={route.key}
        accessibilityRole="button"
        accessibilityState={{ selected: focused }}
        accessibilityLabel={meta.label}
        onPress={() => {
          light();
          if (!focused) navigation.navigate(route.name);
        }}
        style={styles.tabButton}>
        <Ionicons
          name={focused ? meta.iconActive : meta.icon}
          size={23}
          color={focused ? accent.color : Colors.textMuted}
        />
        <Text style={[styles.tabLabel, focused && styles.tabLabelActive, focused && { color: accent.color }]}>
          {meta.label}
        </Text>
      </Pressable>
    );
  }

  return (
    <View style={[styles.wrap, { paddingBottom: Math.max(insets.bottom, 10) }]} pointerEvents="box-none">
      <BlurView intensity={Platform.OS === 'ios' ? 46 : 0} tint="dark" style={styles.blur}>
        <View style={styles.bar}>
          <View style={styles.side}>{leftRoutes.map(renderTab)}</View>

          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Crear contenido"
            onPress={() => {
              medium();
              router.push('/create');
            }}
            style={[styles.createButtonWrap, { shadowColor: accent.color }]}>
            <LinearGradient
              colors={accent.gradient as unknown as [string, string, ...string[]]}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.createButton}>
              <Ionicons name="add" size={30} color={Colors.textOnAccent} />
            </LinearGradient>
          </Pressable>

          <View style={styles.side}>{rightRoutes.map(renderTab)}</View>
        </View>
      </BlurView>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { position: 'absolute', left: 0, right: 0, bottom: 0 },
  blur: {
    backgroundColor: Platform.OS === 'android' ? 'rgba(7,9,13,0.96)' : 'rgba(7,9,13,0.55)',
    borderTopWidth: 1,
    borderTopColor: Colors.borderSoft,
  },
  bar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.md,
    paddingTop: Spacing.sm,
  },
  side: { flexDirection: 'row', flex: 1, justifyContent: 'space-around' },
  tabButton: { alignItems: 'center', gap: 3, minWidth: 56, paddingVertical: 4 },
  tabLabel: { ...Typography.caption, fontSize: 11, color: Colors.textMuted },
  tabLabelActive: { fontWeight: '700' },
  createButtonWrap: {
    marginHorizontal: Spacing.sm,
    marginTop: -30,
    shadowOpacity: 0.5,
    shadowRadius: 14,
    shadowOffset: { width: 0, height: 6 },
  },
  createButton: {
    width: 60,
    height: 60,
    borderRadius: Radius.pill,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 3,
    borderColor: Colors.background,
  },
});
