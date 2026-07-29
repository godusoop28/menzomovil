import { Ionicons } from '@expo/vector-icons';
import { useState } from 'react';
import { ActivityIndicator, type GestureResponderEvent, Pressable, StyleSheet, Text, View } from 'react-native';

import { useAppState } from '@/hooks/useAppState';
import { useHaptics } from '@/hooks/useHaptics';
import { useToast } from '@/hooks/useToast';
import { LOCAL_USER_ID } from '@/store/localUser';
import { Colors, Radius, Spacing, Typography, useAccent } from '@/theme';
import type { Post } from '@/types';

/** Antes de votar no se muestran barras ni porcentajes; apenas el servidor confirma el voto, esta
 * misma tarjeta cambia a la vista de resultados con los conteos reales — nunca inventa nada
 * localmente. Espejo del PollCard de menzoweb. */
export function PollCard({ post }: { post: Post }) {
  const { actions } = useAppState();
  const accent = useAccent();
  const showToast = useToast();
  const { selection } = useHaptics();
  const [votingOptionId, setVotingOptionId] = useState<string | null>(null);

  const options = post.pollOptions ?? [];
  if (options.length === 0) return null;

  const totalVotes = options.reduce((sum, o) => sum + o.votes.length, 0);
  const myOption = options.find((o) => o.votes.includes(LOCAL_USER_ID));
  const hasVoted = !!myOption;

  async function handleVote(optionId: string) {
    if (votingOptionId) return;
    if (myOption?.id === optionId) return;
    selection();
    setVotingOptionId(optionId);
    try {
      await actions.votePoll(post.id, optionId);
    } catch (error) {
      console.warn('[menzo/mobile] votePoll failed', error);
      showToast('No pudimos registrar tu voto. Inténtalo de nuevo.');
    } finally {
      setVotingOptionId(null);
    }
  }

  return (
    <View style={styles.wrap}>
      {options.map((option) => {
        const votes = option.votes.length;
        const pct = totalVotes === 0 ? 0 : Math.round((votes / totalVotes) * 100);
        const isMine = option.id === myOption?.id;
        const isVoting = votingOptionId === option.id;
        return (
          <Pressable
            key={option.id}
            onPress={(e: GestureResponderEvent) => {
              e.stopPropagation();
              handleVote(option.id);
            }}
            disabled={!!votingOptionId}
            style={[styles.option, isMine && { borderColor: Colors.orange }]}>
            {hasVoted && (
              <View
                style={[
                  styles.fill,
                  { width: `${pct}%`, backgroundColor: isMine ? `${accent.color}33` : Colors.surfaceSoft },
                ]}
              />
            )}
            <View style={styles.optionContent}>
              {hasVoted ? (
                isMine && (
                  <View style={[styles.checkDot, { backgroundColor: accent.color }]}>
                    <Ionicons name="checkmark" size={10} color={Colors.textOnAccent} />
                  </View>
                )
              ) : (
                <View style={[styles.radioDot, isMine && { borderColor: Colors.orange }]} />
              )}
              <Text style={styles.label} numberOfLines={2}>
                {option.label}
              </Text>
              {isVoting ? (
                <ActivityIndicator size="small" color={Colors.textMuted} />
              ) : (
                hasVoted && <Text style={styles.pct}>{pct}%</Text>
              )}
            </View>
          </Pressable>
        );
      })}
      <Text style={styles.total}>{totalVotes === 0 ? 'Sé el primero en votar' : `${totalVotes} voto${totalVotes === 1 ? '' : 's'}`}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { gap: Spacing.sm },
  option: {
    minHeight: 44,
    justifyContent: 'center',
    borderRadius: Radius.md,
    borderWidth: 1,
    borderColor: Colors.borderSoft,
    overflow: 'hidden',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
  },
  fill: { position: 'absolute', left: 0, top: 0, bottom: 0 },
  optionContent: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm },
  radioDot: { width: 16, height: 16, borderRadius: 8, borderWidth: 2, borderColor: Colors.textMuted },
  checkDot: { width: 16, height: 16, borderRadius: 8, alignItems: 'center', justifyContent: 'center' },
  label: { ...Typography.bodyMedium, flex: 1, color: Colors.textPrimary },
  pct: { ...Typography.caption, fontWeight: '700', color: Colors.textSecondary },
  total: { ...Typography.caption, color: Colors.textMuted },
});
