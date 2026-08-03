import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/communities_repository.dart';
import '../../data/repositories/community_repository.dart';
import '../../data/repositories/gifs_repository.dart';
import '../../data/repositories/live_repository.dart';
import '../../data/repositories/music_repository.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repositories/sticker_repository.dart';
import '../../data/repositories/uploads_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../network/api_client.dart';

/// Un provider por dominio, todos envolviendo el mismo [ApiClient] singleton — mismo patrón de
/// "repositorio por dominio" descrito en el plan. Todos son `Provider` simples (no dependen de
/// estado, así que no hace falta que sean notifiers).
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(apiClientProvider)),
);
final postRepositoryProvider = Provider<PostRepository>(
  (ref) => PostRepository(ref.watch(apiClientProvider)),
);
final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);
final liveRepositoryProvider = Provider<LiveRepository>(
  (ref) => LiveRepository(ref.watch(apiClientProvider)),
);
final musicRepositoryProvider = Provider<MusicRepository>(
  (ref) => MusicRepository(ref.watch(apiClientProvider)),
);
final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(ref.watch(apiClientProvider)),
);
final communitiesRepositoryProvider = Provider<CommunitiesRepository>(
  (ref) => CommunitiesRepository(ref.watch(apiClientProvider)),
);
final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(apiClientProvider)),
);
final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(ref.watch(apiClientProvider)),
);
final uploadsRepositoryProvider = Provider<UploadsRepository>(
  (ref) => UploadsRepository(ref.watch(apiClientProvider)),
);
final gifsRepositoryProvider = Provider<GifsRepository>(
  (ref) => GifsRepository(ref.watch(apiClientProvider)),
);
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(apiClientProvider)),
);
final stickerRepositoryProvider = Provider<StickerRepository>(
  (ref) => StickerRepository(ref.watch(apiClientProvider)),
);
