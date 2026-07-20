import { router } from 'expo-router';
import { useState } from 'react';
import { ScrollView, Share, StyleSheet, Switch, Text, View } from 'react-native';

import { ConfirmationModal } from '@/components/ConfirmationModal';
import { IconButton } from '@/components/IconButton';
import { ScreenContainer } from '@/components/ScreenContainer';
import { SecondaryButton } from '@/components/SecondaryButton';
import { SegmentedTabs } from '@/components/SegmentedTabs';
import { useAppState } from '@/hooks/useAppState';
import { Colors, Radius, Spacing, Typography, useAccent } from '@/theme';
import { formatJoinDate } from '@/utils/time';

function SettingRow({ label, description, value, onChange }: { label: string; description?: string; value: boolean; onChange: (v: boolean) => void }) {
  const accent = useAccent();
  return (
    <View style={styles.row}>
      <View style={styles.rowText}>
        <Text style={styles.rowLabel}>{label}</Text>
        {!!description && <Text style={styles.rowDescription}>{description}</Text>}
      </View>
      <Switch
        value={value}
        onValueChange={onChange}
        trackColor={{ false: Colors.surfaceSoft, true: accent.color }}
        thumbColor={Colors.textPrimary}
      />
    </View>
  );
}

export default function SettingsScreen() {
  const { state, actions } = useAppState();
  const [showResetConfirm, setShowResetConfirm] = useState(false);
  const { settings, profile } = state;

  async function handleExport() {
    if (!profile) return;
    const summary = [
      `Perfil de MENZO — ${profile.displayName} (@${profile.username})`,
      profile.bio,
      `Nivel ${profile.level} · ${profile.reputation} de reputación`,
      `Miembro desde ${formatJoinDate(profile.joinedAt)}`,
      `Intereses: ${profile.interests.join(', ')}`,
    ].join('\n');
    await Share.share({ message: summary });
  }

  // No navegamos aquí a propósito: en cuanto profile pasa a null,
  // HydrationGate (en _layout.tsx) redirige solo a /login. Llamar a
  // router.replace también aquí dispara una segunda navegación casi
  // simultánea a la automática, lo que puede dejar el navegador
  // atascado (pantalla congelada, sin responder a toques).
  async function handleReset() {
    setShowResetConfirm(false);
    await actions.resetDemo();
  }

  async function handleLogout() {
    await actions.logout();
  }

  return (
    <ScreenContainer>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <Text style={styles.headerTitle}>Configuración</Text>
        <View style={{ width: 44 }} />
      </View>

      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <Text style={styles.sectionTitle}>Cuenta local</Text>
        <SecondaryButton label="Editar perfil" onPress={() => router.push('/edit-profile')} />
        <SecondaryButton label="Exportar resumen local" onPress={handleExport} />
        <SecondaryButton label="Cerrar sesión" onPress={handleLogout} />
        <SecondaryButton label="Restablecer Menzo" tone="danger" onPress={() => setShowResetConfirm(true)} />

        <Text style={styles.sectionTitle}>Apariencia</Text>
        <Text style={styles.label}>Tema</Text>
        <SegmentedTabs
          value={settings.theme}
          onChange={(theme) => actions.updateSettings({ theme })}
          options={[
            { value: 'medianoche', label: 'Medianoche' },
            { value: 'amoled', label: 'AMOLED' },
          ]}
        />
        <Text style={styles.label}>Intensidad de efectos</Text>
        <SegmentedTabs
          value={settings.effectIntensity}
          onChange={(effectIntensity) => actions.updateSettings({ effectIntensity })}
          options={[
            { value: 'suave', label: 'Suave' },
            { value: 'normal', label: 'Normal' },
            { value: 'alta', label: 'Alta' },
          ]}
        />

        <Text style={styles.sectionTitle}>Experiencia</Text>
        <SettingRow
          label="Vibración (haptics)"
          value={settings.hapticsEnabled}
          onChange={(v) => actions.updateSettings({ hapticsEnabled: v })}
        />
        <SettingRow
          label="Animaciones"
          value={settings.animationsEnabled}
          onChange={(v) => actions.updateSettings({ animationsEnabled: v })}
        />
        <SettingRow
          label="Mostrar actividad simulada"
          value={settings.showSimulatedActivity}
          onChange={(v) => actions.updateSettings({ showSimulatedActivity: v })}
        />
        <SettingRow
          label="Confirmaciones"
          value={settings.confirmationsEnabled}
          onChange={(v) => actions.updateSettings({ confirmationsEnabled: v })}
        />

        <Text style={styles.sectionTitle}>Privacidad de demostración</Text>
        <SettingRow
          label="Mostrar estado en línea"
          value={settings.showOnlineStatus}
          onChange={(v) => actions.updateSettings({ showOnlineStatus: v })}
        />
        <SettingRow
          label="Permitir visitas al perfil"
          value={settings.allowProfileVisits}
          onChange={(v) => actions.updateSettings({ allowProfileVisits: v })}
        />
        <SettingRow
          label="Mostrar intereses"
          value={settings.showInterests}
          onChange={(v) => actions.updateSettings({ showInterests: v })}
        />

        <Text style={styles.sectionTitle}>Información</Text>
        <SecondaryButton label="Acerca de Menzo" onPress={() => router.push('/about')} />
        <Text style={styles.version}>Versión 1.0.0 · Prototipo local</Text>
        <Text style={styles.notice}>
          Esta versión funciona únicamente con datos locales y de demostración.
        </Text>
      </ScrollView>

      <ConfirmationModal
        visible={showResetConfirm}
        title="¿Restablecer Menzo?"
        description="Se borrará tu perfil, publicaciones y mensajes locales. Volverás al inicio."
        confirmLabel="Restablecer"
        cancelLabel="Cancelar"
        destructive
        onConfirm={handleReset}
        onCancel={() => setShowResetConfirm(false)}
      />
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: Spacing.md, paddingTop: Spacing.xs },
  headerTitle: { ...Typography.h3, color: Colors.textPrimary },
  content: { padding: Spacing.xl, gap: Spacing.sm, paddingBottom: Spacing.xxl },
  sectionTitle: { ...Typography.h3, color: Colors.textPrimary, marginTop: Spacing.lg, marginBottom: Spacing.xs },
  label: { ...Typography.label, color: Colors.textMuted, marginTop: Spacing.xs },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: Colors.surface,
    borderRadius: Radius.md,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    padding: Spacing.md,
  },
  rowText: { flex: 1, paddingRight: Spacing.md },
  rowLabel: { ...Typography.bodyMedium, color: Colors.textPrimary },
  rowDescription: { ...Typography.caption, color: Colors.textMuted },
  version: { ...Typography.caption, color: Colors.textMuted, marginTop: Spacing.sm },
  notice: { ...Typography.caption, color: Colors.textMuted },
});
