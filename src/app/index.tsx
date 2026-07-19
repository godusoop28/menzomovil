import { Redirect } from 'expo-router';

import { useAppState } from '@/store/AppStateContext';

export default function RootGate() {
  const { state } = useAppState();

  if (state.onboardingCompleted) {
    return <Redirect href="/(tabs)" />;
  }

  // Ya hay una sesión (login previo) pero el perfil quedó a medias: hay que
  // llevarlo directo a completar su nombre, no al flujo de "crear cuenta"
  // (eso lo atrapaba en un loop: registro fallaba por correo duplicado y
  // nunca llegaba a la pantalla donde puede poner su nombre).
  if (state.profile) {
    return <Redirect href="/onboarding/name" />;
  }

  return <Redirect href="/onboarding" />;
}
