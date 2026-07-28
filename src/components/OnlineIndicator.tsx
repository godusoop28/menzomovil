import { StyleSheet, View } from 'react-native';

import { Colors } from '@/theme';

export function OnlineIndicator({ online, size = 12 }: { online: boolean; size?: number }) {
  return (
    <View
      accessibilityLabel={online ? 'En línea' : 'Desconectado'}
      style={[
        styles.dot,
        {
          width: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor: online ? Colors.online : Colors.offline,
        },
      ]}
    />
  );
}

const styles = StyleSheet.create({
  dot: { borderWidth: 2, borderColor: Colors.background },
});
