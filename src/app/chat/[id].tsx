import { Ionicons } from '@expo/vector-icons';
import * as FileSystem from 'expo-file-system/legacy';
import * as ImagePicker from 'expo-image-picker';
import { router, useLocalSearchParams } from 'expo-router';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { FlatList, KeyboardAvoidingView, Pressable, RefreshControl, StyleSheet, Text, TextInput, View } from 'react-native';
import { Image } from 'expo-image';

import { ChatBubble } from '@/components/ChatBubble';
import { EmptyState } from '@/components/EmptyState';
import { IconButton } from '@/components/IconButton';
import { ScreenContainer } from '@/components/ScreenContainer';
import { menzoAssets } from '@/constants/assets';
import { useAppState } from '@/hooks/useAppState';
import { useHaptics } from '@/hooks/useHaptics';
import { useKeyboardBehavior } from '@/hooks/useKeyboardOffset';
import { LOCAL_USER_ID } from '@/store/localUser';
import { findRoom, findUser, messagesForRoom } from '@/store/selectors';
import { Colors, Radius, Spacing, Typography, useAccent } from '@/theme';
import type { Message } from '@/types';

export default function ChatDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { state, actions } = useAppState();
  const { light } = useHaptics();
  const accent = useAccent();
  const behavior = useKeyboardBehavior();
  const listRef = useRef<FlatList<Message>>(null);
  const [draft, setDraft] = useState('');
  const [pendingImage, setPendingImage] = useState<string | undefined>();

  const room = findRoom(state.social, id);
  const isDirect = room?.type === 'direct';

  const messages = useMemo(() => messagesForRoom(state.social, id), [state.social, id]);
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    if (!room || !id) return;
    actions.loadRoomMessages(id);
    const interval = setInterval(() => actions.loadRoomMessages(id), 5000);
    return () => clearInterval(interval);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id, !!room]);

  const onRefresh = useCallback(async () => {
    if (!id) return;
    setRefreshing(true);
    await actions.loadRoomMessages(id);
    setRefreshing(false);
  }, [actions, id]);

  const headerTitle = isDirect ? room?.peer?.displayName ?? 'Conversación' : room?.name ?? 'Conversación';
  const headerSubtitle = isDirect
    ? room?.peer?.isOnline
      ? 'En línea'
      : 'Desconectado'
    : room
      ? `${room.onlineCount} conectados`
      : '';

  async function pickImage() {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) return;
    const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], quality: 0.8 });
    if (result.canceled || !result.assets?.[0]) return;
    try {
      const dir = `${FileSystem.documentDirectory}menzo-chat/`;
      await FileSystem.makeDirectoryAsync(dir, { intermediates: true }).catch(() => {});
      const dest = `${dir}img-${Date.now()}.jpg`;
      await FileSystem.copyAsync({ from: result.assets[0].uri, to: dest });
      setPendingImage(dest);
    } catch {
      setPendingImage(result.assets[0].uri);
    }
  }

  function handleSend() {
    const trimmed = draft.trim();
    if (!trimmed && !pendingImage) return;
    if (!id) return;
    light();
    actions.sendMessage(id, trimmed, pendingImage);
    setDraft('');
    setPendingImage(undefined);
    requestAnimationFrame(() => listRef.current?.scrollToEnd({ animated: true }));
  }

  if (!room) {
    return (
      <ScreenContainer>
        <View style={styles.header}>
          <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        </View>
        <EmptyState title="No encontramos esta conversación" preset="storm" />
      </ScreenContainer>
    );
  }

  return (
    <ScreenContainer edges={['top', 'bottom']}>
      <View style={styles.header}>
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <View style={styles.headerText}>
          <Text style={styles.headerTitle} numberOfLines={1}>
            {headerTitle}
          </Text>
          {!!headerSubtitle && <Text style={styles.headerSubtitle}>{headerSubtitle}</Text>}
        </View>
        <View style={{ width: 44 }} />
      </View>

      <KeyboardAvoidingView behavior={behavior} style={styles.flex} keyboardVerticalOffset={90}>
        {messages.length === 0 ? (
          <EmptyState
            title="Aún no hay mensajes aquí"
            description="Sé el primero en escribir algo."
            image={menzoAssets.illustrations.chat}
          />
        ) : (
          <FlatList
            ref={listRef}
            data={messages}
            keyExtractor={(m) => m.id}
            contentContainerStyle={styles.list}
            refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor={Colors.textPrimary} />}
            renderItem={({ item, index }) => (
              <ChatBubble
                message={item}
                author={findUser(state.social, item.authorId)}
                isOwn={item.authorId === LOCAL_USER_ID}
                showAvatar={index === 0 || messages[index - 1].authorId !== item.authorId}
              />
            )}
            onContentSizeChange={() => listRef.current?.scrollToEnd({ animated: false })}
          />
        )}

        {!!pendingImage && (
          <View style={styles.previewRow}>
            <Image source={{ uri: pendingImage }} style={styles.previewImage} contentFit="cover" />
            <IconButton name="close-circle" label="Quitar imagen" onPress={() => setPendingImage(undefined)} />
          </View>
        )}

        <View style={styles.inputRow}>
          <Pressable accessibilityRole="button" accessibilityLabel="Adjuntar imagen" onPress={pickImage} style={styles.attachButton}>
            <Ionicons name="image-outline" size={22} color={Colors.textSecondary} />
          </Pressable>
          <TextInput
            value={draft}
            onChangeText={setDraft}
            placeholder="Escribe un mensaje…"
            placeholderTextColor={Colors.textMuted}
            style={styles.input}
            multiline
          />
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Enviar mensaje"
            onPress={handleSend}
            style={[styles.sendButton, { backgroundColor: accent.color }]}>
            <Ionicons name="send" size={18} color={Colors.textOnAccent} />
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </ScreenContainer>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: Spacing.md,
    paddingTop: Spacing.xs,
    paddingBottom: Spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: Colors.borderSoft,
  },
  headerText: { flex: 1, alignItems: 'center' },
  headerTitle: { ...Typography.h3, color: Colors.textPrimary },
  headerSubtitle: { ...Typography.caption, color: Colors.green },
  list: { padding: Spacing.lg, gap: Spacing.sm },
  previewRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    paddingHorizontal: Spacing.lg,
    paddingBottom: Spacing.xs,
  },
  previewImage: { width: 48, height: 48, borderRadius: Radius.sm },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: Spacing.sm,
    paddingHorizontal: Spacing.lg,
    paddingVertical: Spacing.sm,
    borderTopWidth: 1,
    borderTopColor: Colors.borderSoft,
  },
  attachButton: { width: 40, height: 40, alignItems: 'center', justifyContent: 'center' },
  input: {
    ...Typography.body,
    flex: 1,
    color: Colors.textPrimary,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: Radius.lg,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    maxHeight: 110,
  },
  sendButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
