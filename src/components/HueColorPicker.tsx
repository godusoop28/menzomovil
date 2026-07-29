import { LinearGradient } from 'expo-linear-gradient';
import { useState } from 'react';
import { StyleSheet, Text, TextInput, View, type GestureResponderEvent } from 'react-native';

import { Colors, Radius, Spacing, Typography } from '@/theme';

const HUE_STOPS = ['#FF0000', '#FFFF00', '#00FF00', '#00FFFF', '#0000FF', '#FF00FF', '#FF0000'] as const;
const STRIP_HEIGHT = 32;

function hslToHex(h: number, s: number, l: number): string {
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
  const m = l - c / 2;
  let r = 0;
  let g = 0;
  let b = 0;
  if (h < 60) [r, g, b] = [c, x, 0];
  else if (h < 120) [r, g, b] = [x, c, 0];
  else if (h < 180) [r, g, b] = [0, c, x];
  else if (h < 240) [r, g, b] = [0, x, c];
  else if (h < 300) [r, g, b] = [x, 0, c];
  else [r, g, b] = [c, 0, x];
  const toHex = (v: number) =>
    Math.round((v + m) * 255)
      .toString(16)
      .padStart(2, '0');
  return `#${toHex(r)}${toHex(g)}${toHex(b)}`.toUpperCase();
}

/** Selector de color libre: una franja de matices que se puede arrastrar (sistema de responders
 * nativo de RN, sin dependencias nuevas) más un campo hex como respaldo para escribir un color
 * exacto. Complementa los presets fijos que ya existían, sin reemplazarlos. */
export function HueColorPicker({ value, onChange }: { value?: string; onChange: (hex: string) => void }) {
  const [stripWidth, setStripWidth] = useState(0);
  const [hexDraft, setHexDraft] = useState(value ?? '');

  function handleTouch(e: GestureResponderEvent) {
    if (!stripWidth) return;
    const x = Math.max(0, Math.min(stripWidth, e.nativeEvent.locationX));
    const hue = (x / stripWidth) * 360;
    const hex = hslToHex(hue, 0.75, 0.55);
    setHexDraft(hex);
    onChange(hex);
  }

  function submitHex() {
    const trimmed = hexDraft.trim();
    const normalized = trimmed.startsWith('#') ? trimmed : `#${trimmed}`;
    if (/^#[0-9a-fA-F]{6}$/.test(normalized)) {
      onChange(normalized.toUpperCase());
    }
  }

  return (
    <View style={styles.wrap}>
      <View
        style={styles.strip}
        onLayout={(e) => setStripWidth(e.nativeEvent.layout.width)}
        onStartShouldSetResponder={() => true}
        onMoveShouldSetResponder={() => true}
        onResponderGrant={handleTouch}
        onResponderMove={handleTouch}>
        <LinearGradient
          colors={HUE_STOPS as unknown as [string, string, ...string[]]}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 0 }}
          style={StyleSheet.absoluteFill}
        />
      </View>
      <View style={styles.hexRow}>
        <Text style={styles.hexLabel}>HEX</Text>
        <TextInput
          value={hexDraft}
          onChangeText={setHexDraft}
          onSubmitEditing={submitHex}
          onBlur={submitHex}
          placeholder="#RRGGBB"
          placeholderTextColor={Colors.textMuted}
          autoCapitalize="characters"
          maxLength={7}
          style={styles.hexInput}
        />
        <View style={[styles.hexPreview, { backgroundColor: value || Colors.surfaceSecondary }]} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { gap: Spacing.xs },
  strip: { height: STRIP_HEIGHT, borderRadius: Radius.sm, overflow: 'hidden' },
  hexRow: { flexDirection: 'row', alignItems: 'center', gap: Spacing.xs },
  hexLabel: { ...Typography.caption, color: Colors.textMuted, fontWeight: '700' },
  hexInput: {
    ...Typography.caption,
    flex: 1,
    color: Colors.textPrimary,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.sm,
    paddingHorizontal: Spacing.sm,
    paddingVertical: 6,
  },
  hexPreview: { width: 28, height: 28, borderRadius: Radius.sm, borderWidth: 1, borderColor: Colors.borderSoft },
});
