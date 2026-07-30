import 'package:intl/intl.dart';

/// 1:1 con menzoweb/lib/time.ts — mismo formato es-MX.
String relativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  if (diff.inDays < 7) return 'hace ${diff.inDays} d';
  return DateFormat('d MMM', 'es_MX').format(date);
}

String formatJoinDate(DateTime date) =>
    DateFormat('d MMMM yyyy, HH:mm', 'es_MX').format(date);
