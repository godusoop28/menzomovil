# This app is Flutter, not Expo/React Native

Migrated from Expo/React Native to Flutter. Flutter SDK 3.44, Dart 3.12. Before making changes,
check `flutter --version` and read the versioned docs at https://docs.flutter.dev/ for anything
non-obvious — API surfaces (especially `agora_rtc_engine`, `webview_flutter`, `go_router`) can
differ meaningfully between versions. Don't assume patterns from the old RN codebase apply
here; the architecture (Riverpod, go_router, dio) is a deliberate rewrite, not a port.
