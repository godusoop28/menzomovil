import { Image } from 'expo-image';
import { StyleSheet, View } from 'react-native';

type Props = {
  size?: number;
  rounded?: boolean;
};

export function MenzoLogo({ size = 96, rounded = true }: Props) {
  return (
    <View
      style={[
        styles.wrap,
        { width: size, height: size, borderRadius: rounded ? size * 0.24 : 0 },
      ]}>
      <Image
        source={require('@/assets/branding/menzo-logo.png')}
        style={{ width: size, height: size }}
        contentFit="cover"
        accessibilityLabel="Logotipo de MENZO"
      />
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { overflow: 'hidden' },
});
