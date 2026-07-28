import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';

import { GradientButton } from './GradientButton';
import { SecondaryButton } from './SecondaryButton';
import { Colors, Radius, Spacing, Typography } from '@/theme';

type Props = {
  visible: boolean;
  title: string;
  description?: string;
  confirmLabel: string;
  cancelLabel?: string;
  destructive?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
};

export function ConfirmationModal({
  visible,
  title,
  description,
  confirmLabel,
  cancelLabel = 'Cancelar',
  destructive,
  onConfirm,
  onCancel,
}: Props) {
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onCancel}>
      <Pressable style={styles.backdrop} onPress={onCancel}>
        <Pressable style={styles.card} onPress={(e) => e.stopPropagation()}>
          <Text style={styles.title}>{title}</Text>
          {!!description && <Text style={styles.description}>{description}</Text>}
          <View style={styles.actions}>
            <GradientButton
              label={confirmLabel}
              onPress={onConfirm}
              gradient={destructive ? 'fire' : 'connection'}
            />
            <SecondaryButton label={cancelLabel} onPress={onCancel} />
          </View>
        </Pressable>
      </Pressable>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, backgroundColor: 'rgba(3,5,9,0.7)', alignItems: 'center', justifyContent: 'center', padding: Spacing.xl },
  card: {
    width: '100%',
    maxWidth: 400,
    backgroundColor: Colors.surfaceElevated,
    borderRadius: Radius.xl,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    padding: Spacing.xl,
    gap: Spacing.md,
  },
  title: { ...Typography.h3, color: Colors.textPrimary },
  description: { ...Typography.body, color: Colors.textSecondary },
  actions: { gap: Spacing.sm, marginTop: Spacing.sm },
});
