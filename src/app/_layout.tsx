import { Inter_400Regular, Inter_500Medium, Inter_600SemiBold } from '@expo-google-fonts/inter';
import { SpaceGrotesk_600SemiBold, SpaceGrotesk_700Bold } from '@expo-google-fonts/space-grotesk';
import { useFonts } from 'expo-font';
import { router, Stack } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { useEffect, useRef } from 'react';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { PersistentVoiceBubble } from '@/components/PersistentVoiceBubble';
import { MenziDjAutoplayBar } from '@/components/music/MenziDjAutoplayBar';
import { MenziDjMiniBar } from '@/components/music/MenziDjMiniBar';
import { ServerWakingBanner } from '@/components/ServerWakingBanner';
import { AppStateProvider, useAppState } from '@/store/AppStateContext';
import { MenziDjProvider } from '@/store/MenziDjContext';
import { VoiceRoomProvider } from '@/store/VoiceRoomContext';
import { AccentProvider, Colors } from '@/theme';
import { ToastProvider } from '@/hooks/useToast';

SplashScreen.preventAutoHideAsync().catch(() => {});

function HydrationGate({ children }: { children: React.ReactNode }) {
  const { state } = useAppState();
  const wasLoggedIn = useRef(false);

  useEffect(() => {
    if (state.isHydrated) {
      SplashScreen.hideAsync().catch(() => {});
    }
  }, [state.isHydrated]);

  useEffect(() => {
    if (!state.isHydrated) return;
    if (state.profile) {
      wasLoggedIn.current = true;
    } else if (wasLoggedIn.current) {
      wasLoggedIn.current = false;
      router.replace('/login');
    }
  }, [state.isHydrated, state.profile]);

  if (!state.isHydrated) return null;
  return <>{children}</>;
}

export default function RootLayout() {
  const [fontsLoaded, fontError] = useFonts({
    SpaceGrotesk_600SemiBold,
    SpaceGrotesk_700Bold,
    Inter_400Regular,
    Inter_500Medium,
    Inter_600SemiBold,
  });

  if (!fontsLoaded && !fontError) {
    return null;
  }

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <ToastProvider>
          <AppStateProvider>
            <AccentProvider>
              <VoiceRoomProvider>
                <MenziDjProvider>
                  <HydrationGate>
                    <StatusBar style="light" />
                    <ServerWakingBanner />
                    <MenziDjAutoplayBar />
                    <Stack
                      screenOptions={{
                        headerShown: false,
                        contentStyle: { backgroundColor: Colors.background },
                        animation: 'slide_from_right',
                      }}>
                      <Stack.Screen name="index" options={{ animation: 'fade' }} />
                      <Stack.Screen name="onboarding" options={{ animation: 'fade' }} />
                      <Stack.Screen name="(tabs)" options={{ animation: 'fade' }} />
                      <Stack.Screen
                        name="create"
                        options={{ presentation: 'modal', animation: 'slide_from_bottom' }}
                      />
                    </Stack>
                    <MenziDjMiniBar />
                    <PersistentVoiceBubble />
                  </HydrationGate>
                </MenziDjProvider>
              </VoiceRoomProvider>
            </AccentProvider>
          </AppStateProvider>
        </ToastProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
