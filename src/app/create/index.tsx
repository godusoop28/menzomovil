import { router } from 'expo-router';
import { ScrollView, StyleSheet, Text, View } from 'react-native';

import { CreateMenu } from '@/components/CreateMenu';
import { IconButton } from '@/components/IconButton';
import { ScreenContainer } from '@/components/ScreenContainer';
import { Colors, Spacing, Typography } from '@/theme';

export default function CreateIndex() {
  return (
    <ScreenContainer>
      <View style={styles.header}>
        <Text style={styles.title}>¿Qué quieres dejar en la comunidad?</Text>
        <IconButton name="close" label="Cerrar" onPress={() => router.back()} variant="surface" />
      </View>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <CreateMenu />
      </ScrollView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.xl,
    paddingTop: Spacing.lg,
    gap: Spacing.md,
  },
  title: { ...Typography.h2, color: Colors.textPrimary, flex: 1 },
  content: { padding: Spacing.xl, paddingTop: Spacing.lg },
});
