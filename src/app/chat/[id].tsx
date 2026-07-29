import { Ionicons } from '@expo/vector-icons';
import * as FileSystem from 'expo-file-system/legacy';
import * as ImagePicker from 'expo-image-picker';
import { router, useLocalSearchParams } from 'expo-router';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, FlatList, KeyboardAvoidingView, Pressable, RefreshControl, StyleSheet, Text, TextInput, View } from 'react-native';
import { Image } from 'expo-image';

import { ChatBubble } from '@/components/ChatBubble';
import { TypingBubble } from '@/components/TypingBubble';
import { MenzoImageBackground } from '@/components/common/MenzoImageBackground';
import { EmptyState } from '@/components/EmptyState';
import { IconButton } from '@/components/IconButton';
import { ScreenContainer } from '@/components/ScreenContainer';
import { VoiceAvatarBubble } from '@/components/VoiceAvatarBubble';
import { menzoAssets } from '@/constants/assets';
import { useAppState } from '@/hooks/useAppState';
import { useHaptics } from '@/hooks/useHaptics';
import { useKeyboardBehavior } from '@/hooks/useKeyboardOffset';
import { useRoomSocket } from '@/hooks/useRoomSocket';
import { useToast } from '@/hooks/useToast';
import { useVoiceRoom } from '@/hooks/useVoiceRoom';
import { LOCAL_USER_ID } from '@/store/localUser';
import { findRoom, findUser, messagesForRoom } from '@/store/selectors';
import { Colors, Radius, Spacing, Typography, useAccent } from '@/theme';
import type { Message } from '@/types';

export default function ChatDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { state, actions } = useAppState();
  const { light } = useHaptics();
  const showToast = useToast();
  const accent = useAccent();
  const voice = useVoiceRoom(id);
  const behavior = useKeyboardBehavior();
  const listRef = useRef<FlatList<Message>>(null);
  const [draft, setDraft] = useState('');
  const [pendingImage, setPendingImage] = useState<string | undefined>();
  const [busyCover, setBusyCover] = useState(false);
  const [busyBackground, setBusyBackground] = useState(false);
  const [sending, setSending] = useState(false);

  const room = findRoom(state.social, id);
  const isDirect = room?.type === 'direct';

  const messages = useMemo(() => messagesForRoom(state.social, id), [state.social, id]);
  const [refreshing, setRefreshing] = useState(false);
  const { typingUsers, publishTyping } = useRoomSocket(id);

  useEffect(() => {
    if (!room || !id) return;
    actions.loadRoomMessages(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id, !!room]);

  const onRefresh = useCallback(async () => {
    if (!id) return;
    setRefreshing(true);
    await actions.loadRoomMessages(id);
    setRefreshing(false);
  }, [actions, id]);

  useEffect(() => {
    if (voice.permissionDenied) {
      showToast('Necesitamos acceso al micrófono para unirte a la voz.');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [voice.permissionDenied]);

  const headerTitle = isDirect ? room?.peer?.displayName ?? 'Conversación' : room?.name ?? 'Conversación';
  const headerOnline = isDirect ? !!room?.peer?.isOnline : !!room && room.onlineCount > 0;
  const headerSubtitle = isDirect
    ? room?.peer?.isOnline
      ? 'En línea'
      : 'Desconectado'
    : room
      ? `${room.onlineCount} conectados`
      : '';

  async function pickImage() {
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) {
      showToast('Necesitamos acceso a tus fotos para poder adjuntar una imagen.');
      return;
    }
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

  async function pickRoomCover() {
    if (!id) return;
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) {
      showToast('Necesitamos acceso a tus fotos para poder adjuntar una imagen.');
      return;
    }
    const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], allowsEditing: true, aspect: [16, 9], quality: 0.85 });
    if (result.canceled || !result.assets?.[0]) return;
    setBusyCover(true);
    try {
      const dir = `${FileSystem.documentDirectory}menzo-room-covers/`;
      await FileSystem.makeDirectoryAsync(dir, { intermediates: true }).catch(() => {});
      const dest = `${dir}cover-${Date.now()}.jpg`;
      await FileSystem.copyAsync({ from: result.assets[0].uri, to: dest });
      await actions.updateRoomCover(id, dest);
    } catch (error) {
      console.warn('[menzo/api] pickRoomCover failed', error);
    } finally {
      setBusyCover(false);
    }
  }

  async function pickRoomBackground() {
    if (!id) return;
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) {
      showToast('Necesitamos acceso a tus fotos para poder adjuntar una imagen.');
      return;
    }
    const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], quality: 0.85 });
    if (result.canceled || !result.assets?.[0]) return;
    setBusyBackground(true);
    try {
      const dir = `${FileSystem.documentDirectory}menzo-room-backgrounds/`;
      await FileSystem.makeDirectoryAsync(dir, { intermediates: true }).catch(() => {});
      const dest = `${dir}background-${Date.now()}.jpg`;
      await FileSystem.copyAsync({ from: result.assets[0].uri, to: dest });
      await actions.updateRoomBackground(id, dest);
    } catch (error) {
      console.warn('[menzo/api] pickRoomBackground failed', error);
    } finally {
      setBusyBackground(false);
    }
  }

  async function handleSend() {
    const trimmed = draft.trim();
    if ((!trimmed && !pendingImage) || sending) return;
    if (!id) return;
    light();
    setSending(true);
    const imageToSend = pendingImage;
    setDraft('');
    setPendingImage(undefined);
    const ok = await actions.sendMessage(id, trimmed, imageToSend);
    setSending(false);
    if (!ok) {
      // Devolvemos el borrador para que el usuario no pierda lo que escribió.
      setDraft(trimmed);
      setPendingImage(imageToSend);
      return;
    }
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

  const messagesList =
    messages.length === 0 ? (
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
        renderItem={({ item }) => (
          <ChatBubble message={item} author={findUser(state.social, item.authorId)} isOwn={item.authorId === LOCAL_USER_ID} />
        )}
        ListFooterComponent={<TypingBubble typingUsers={typingUsers} />}
        onContentSizeChange={() => listRef.current?.scrollToEnd({ animated: false })}
      />
    );

  return (
    <ScreenContainer edges={['top', 'bottom']}>
      <View style={[styles.header, room.coverUri && styles.headerNoBorder]}>
        {!!room.coverUri && (
          <Image source={{ uri: room.coverUri }} style={StyleSheet.absoluteFill} contentFit="cover" />
        )}
        {!!room.coverUri && <View style={[StyleSheet.absoluteFill, styles.headerOverlay]} />}
        <IconButton name="chevron-back" label="Volver" onPress={() => router.back()} />
        <View style={styles.headerText}>
          <Text style={styles.headerTitle} numberOfLines={1}>
            {headerTitle}
          </Text>
          {!!headerSubtitle && (
            <Text style={[styles.headerSubtitle, !headerOnline && styles.headerSubtitleOffline]}>{headerSubtitle}</Text>
          )}
        </View>
        <View style={styles.headerActions}>
          <Pressable
            onPress={pickRoomCover}
            disabled={busyCover}
            accessibilityRole="button"
            accessibilityLabel="Cambiar portada de la sala"
            style={styles.headerIconButton}>
            {busyCover ? <ActivityIndicator size="small" color="#FFFFFF" /> : <Ionicons name="image-outline" size={16} color="#FFFFFF" />}
          </Pressable>
          <Pressable
            onPress={pickRoomBackground}
            disabled={busyBackground}
            accessibilityRole="button"
            accessibilityLabel="Cambiar fondo de la sala"
            style={styles.headerIconButton}>
            {busyBackground ? <ActivityIndicator size="small" color="#FFFFFF" /> : <Ionicons name="color-palette-outline" size={16} color="#FFFFFF" />}
          </Pressable>
          <Pressable
            onPress={voice.connected ? voice.leave : voice.join}
            disabled={voice.connecting}
            accessibilityRole="button"
            accessibilityLabel={voice.connected ? 'Salir del live' : 'Unirse al live'}
            style={[styles.voicePill, voice.connected && styles.voicePillLive]}>
            {voice.connecting ? (
              <ActivityIndicator size="small" color="#FFFFFF" />
            ) : (
              <>
                {voice.connected && <View style={styles.voicePillDot} />}
                <Text style={styles.voicePillLabel}>Live</Text>
                {voice.participants.length > 0 && <Text style={styles.voicePillCount}>{voice.participants.length}</Text>}
              </>
            )}
          </Pressable>
        </View>
      </View>

      {(voice.connected || voice.participants.length > 0) && (
        <View style={styles.voiceBar}>
          <View style={styles.voiceBarParticipants}>
            {voice.participants.length === 0 ? (
              <Text style={styles.voiceBarEmpty}>Nadie en la voz todavía</Text>
            ) : (
              voice.participants.map((p) => (
                <View key={p.id} style={styles.voiceChip}>
                  <VoiceAvatarBubble
                    name={p.displayName}
                    avatarUri={p.avatarUri}
                    gradient={p.avatarGradient}
                    size={32}
                    level={voice.speakingLevels.get(p.id) ?? 0}
                    accentColor={accent.color}
                  />
                  <Text style={styles.voiceChipLabel} numberOfLines={1}>
                    {p.displayName}
                  </Text>
                </View>
              ))
            )}
          </View>
          {voice.connected && (
            <Pressable
              onPress={voice.toggleMute}
              accessibilityRole="button"
              accessibilityLabel={voice.muted ? 'Activar micrófono' : 'Silenciar micrófono'}
              style={[styles.muteButton, voice.muted && styles.muteButtonActive]}>
              <Ionicons name={voice.muted ? 'mic-off' : 'mic'} size={16} color={voice.muted ? Colors.coral : Colors.textPrimary} />
            </Pressable>
          )}
        </View>
      )}

      <KeyboardAvoidingView behavior={behavior} style={styles.flex} keyboardVerticalOffset={90}>
        {room.backgroundUri ? (
          <MenzoImageBackground source={{ uri: room.backgroundUri }} style={styles.flex}>
            {messagesList}
          </MenzoImageBackground>
        ) : (
          messagesList
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
            onChangeText={(text) => {
              setDraft(text);
              if (text.trim()) publishTyping();
            }}
            placeholder="Escribe un mensaje…"
            placeholderTextColor={Colors.textMuted}
            style={styles.input}
            multiline
          />
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Enviar mensaje"
            onPress={handleSend}
            disabled={sending}
            style={[styles.sendButton, { backgroundColor: accent.color, opacity: sending ? 0.6 : 1 }]}>
            {sending ? <ActivityIndicator size="small" color={Colors.textOnAccent} /> : <Ionicons name="send" size={18} color={Colors.textOnAccent} />}
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
    overflow: 'hidden',
  },
  headerNoBorder: { borderBottomColor: 'transparent' },
  headerOverlay: { backgroundColor: 'rgba(7,9,13,0.45)' },
  headerActions: { flexDirection: 'row', gap: Spacing.xs },
  headerIconButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(0,0,0,0.35)',
  },
  headerText: { flex: 1, alignItems: 'center' },
  headerTitle: { ...Typography.h3, color: Colors.textPrimary },
  headerSubtitle: { ...Typography.caption, color: Colors.green },
  headerSubtitleOffline: { color: Colors.textMuted },
  voicePill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    height: 32,
    paddingHorizontal: 12,
    borderRadius: 16,
    backgroundColor: 'rgba(0,0,0,0.35)',
  },
  voicePillLive: { backgroundColor: Colors.coral },
  voicePillDot: { width: 6, height: 6, borderRadius: 3, backgroundColor: '#FFFFFF' },
  voicePillLabel: { ...Typography.caption, fontSize: 11, fontWeight: '800', color: '#FFFFFF', textTransform: 'uppercase', letterSpacing: 0.5 },
  voicePillCount: { ...Typography.caption, fontSize: 11, fontWeight: '600', color: '#FFFFFF' },
  voiceBar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: Colors.borderSoft,
    backgroundColor: Colors.surface,
  },
  voiceBarParticipants: { flex: 1, flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.xs },
  voiceBarEmpty: { ...Typography.caption, color: Colors.textMuted },
  voiceChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    backgroundColor: Colors.surfaceSecondary,
    borderRadius: 999,
    paddingVertical: 3,
    paddingRight: 8,
    paddingLeft: 3,
  },
  voiceChipLabel: { ...Typography.caption, fontSize: 11, maxWidth: 90 },
  muteButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: Colors.surfaceSecondary,
  },
  muteButtonActive: { backgroundColor: 'rgba(251,113,133,0.15)' },
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
