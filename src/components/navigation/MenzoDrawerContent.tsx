import { router, usePathname } from 'expo-router';
import { useEffect, useState } from 'react';
import { BackHandler, Modal, Pressable, ScrollView, Share, StyleSheet, useWindowDimensions, View } from 'react-native';
import Animated, { runOnJS, useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import * as WebBrowser from 'expo-web-browser';

import { MenzoImageBackground } from '@/components/common/MenzoImageBackground';
import { menzoAssets } from '@/constants/assets';
import { discordInviteUrl, shareInviteMessage } from '@/config/community';
import { useHaptics } from '@/hooks/useHaptics';
import { useAppState } from '@/store/AppStateContext';
import { LOCAL_USER_ID } from '@/store/localUser';
import { Colors, Spacing } from '@/theme';

import { DrawerFooter } from './DrawerFooter';
import { DrawerMenuItem } from './DrawerMenuItem';
import { DrawerProfileHeader } from './DrawerProfileHeader';

const ANIM_OPEN_MS = 280;
const ANIM_CLOSE_MS = 220;

type Props = { visible: boolean; onClose: () => void };

export function MenzoDrawerContent({ visible, onClose }: Props) {
  const { state } = useAppState();
  const { selection } = useHaptics();
  const insets = useSafeAreaInsets();
  const { width } = useWindowDimensions();
  const pathname = usePathname();

  const drawerWidth = Math.min(width * 0.86, 380);
  const translateX = useSharedValue(-drawerWidth);
  const backdropOpacity = useSharedValue(0);
  const [rendered, setRendered] = useState(visible);

  if (visible && !rendered) {
    // Adjusting state during render (not in an effect) to mount immediately when opening.
    setRendered(true);
  }

  useEffect(() => {
    if (visible) {
      translateX.value = withTiming(0, { duration: ANIM_OPEN_MS });
      backdropOpacity.value = withTiming(0.55, { duration: ANIM_OPEN_MS });
    } else if (rendered) {
      translateX.value = withTiming(-drawerWidth, { duration: ANIM_CLOSE_MS });
      backdropOpacity.value = withTiming(0, { duration: ANIM_CLOSE_MS }, (finished) => {
        if (finished) runOnJS(setRendered)(false);
      });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible, drawerWidth]);

  useEffect(() => {
    if (!rendered) return;
    const sub = BackHandler.addEventListener('hardwareBackPress', () => {
      onClose();
      return true;
    });
    return () => sub.remove();
  }, [rendered, onClose]);

  const panelStyle = useAnimatedStyle(() => ({ transform: [{ translateX: translateX.value }] }));
  const backdropStyle = useAnimatedStyle(() => ({ opacity: backdropOpacity.value }));

  if (!rendered) return null;

  function go(path: Parameters<typeof router.push>[0]) {
    selection();
    onClose();
    router.push(path);
  }

  const isHome = pathname === '/' || pathname === '/(tabs)' || pathname === '/(tabs)/index';
  const isOnline = pathname.includes('/online');

  const items: { key: string; label: string; icon: Parameters<typeof DrawerMenuItem>[0]['icon']; color: string; active?: boolean; action: () => void }[] = [
    { key: 'home', label: 'Inicio', icon: 'home', color: Colors.orange, active: isHome, action: () => go('/(tabs)') },
    { key: 'hangout', label: 'Hangout', icon: 'flame', color: Colors.coral, action: () => go('/(tabs)') },
    { key: 'online', label: 'Miembros en línea', icon: 'people', color: Colors.green, active: isOnline, action: () => go('/(tabs)/online') },
    { key: 'recent', label: 'Lo más reciente', icon: 'time', color: Colors.yellow, active: pathname === '/recent', action: () => go('/recent') },
    { key: 'visitor', label: 'Modo visitante', icon: 'eye', color: Colors.cyan, action: () => go(`/member/${LOCAL_USER_ID}`) },
    { key: 'following', label: 'Siguiendo', icon: 'person-add', color: Colors.purple, active: pathname === '/following', action: () => go('/following') },
    { key: 'bookmarks', label: 'Guardados', icon: 'bookmark', color: Colors.blue, active: pathname === '/bookmarks', action: () => go('/bookmarks') },
    { key: 'viewed', label: 'Vistos recientemente', icon: 'eye-outline', color: Colors.violet, active: pathname === '/recently-viewed', action: () => go('/recently-viewed') },
    {
      key: 'invite',
      label: 'Invitar amigos',
      icon: 'share-social',
      color: Colors.orange,
      action: () => {
        selection();
        Share.share({ message: shareInviteMessage });
      },
    },
    {
      key: 'discord',
      label: 'Únete a nuestro Discord',
      icon: 'logo-discord',
      color: '#5865F2',
      action: () => {
        selection();
        WebBrowser.openBrowserAsync(discordInviteUrl);
      },
    },
    { key: 'settings', label: 'Configuración', icon: 'settings', color: Colors.offline, active: pathname === '/settings', action: () => go('/settings') },
    { key: 'about', label: 'Acerca de Menzo', icon: 'information-circle', color: Colors.cyan, active: pathname === '/about', action: () => go('/about') },
  ];

  return (
    <Modal visible={rendered} transparent animationType="none" statusBarTranslucent onRequestClose={onClose}>
      <View style={styles.root}>
        <Animated.View style={[StyleSheet.absoluteFill, styles.backdrop, backdropStyle]}>
          <Pressable style={StyleSheet.absoluteFill} onPress={onClose} accessibilityLabel="Cerrar menú" accessibilityRole="button" />
        </Animated.View>

        <Animated.View style={[styles.panel, { width: drawerWidth }, panelStyle]}>
          <MenzoImageBackground source={menzoAssets.backgrounds.drawer} overlayOpacity={0.72}>
            <View style={{ paddingTop: insets.top + 8, flex: 1 }}>
              <DrawerProfileHeader
                profile={state.profile}
                onPressProfile={() => go(`/member/${LOCAL_USER_ID}`)}
                onPressSearch={() => go('/search')}
              />

              <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.itemsList}>
                {items.map((item) => (
                  <DrawerMenuItem
                    key={item.key}
                    label={item.label}
                    icon={item.icon}
                    color={item.color}
                    active={item.active}
                    onPress={item.action}
                  />
                ))}
              </ScrollView>

              <View style={{ paddingBottom: insets.bottom + 8 }}>
                <DrawerFooter />
              </View>
            </View>
          </MenzoImageBackground>
        </Animated.View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  backdrop: { backgroundColor: '#000000' },
  panel: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    left: 0,
    overflow: 'hidden',
  },
  itemsList: { paddingVertical: Spacing.sm, gap: 2 },
});
