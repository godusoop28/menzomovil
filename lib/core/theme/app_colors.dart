import 'package:flutter/widgets.dart';

/// Paleta 1:1 con menzoweb/app/globals.css — mismos valores hex exactos, así la app
/// se ve igual entre web y móvil.
class AppColors {
  AppColors._();

  static const background = Color(0xFF07090D);
  static const backgroundDeep = Color(0xFF030509);
  static const surface = Color(0xFF11141B);
  static const surfaceSecondary = Color(0xFF171B24);
  static const surfaceElevated = Color(0xFF1E2330);
  static const surfaceSoft = Color(0xFF242A36);

  static const border = Color(0xFF292F3D);
  static const borderSoft = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const borderStrong = Color(0x29FFFFFF); // rgba(255,255,255,0.16)

  static const textPrimary = Color(0xFFF7F8FC);
  static const textSecondary = Color(0xFFB3BAC8);
  static const textMuted = Color(0xFF767F91);
  static const textOnAccent = Color(0xFF090A0E);

  static const orange = Color(0xFFFF7A1A);
  static const yellow = Color(0xFFFFBE2E);
  static const coral = Color(0xFFFF4F45);
  static const red = Color(0xFFF43F5E);
  static const blue = Color(0xFF3478F6);
  static const cyan = Color(0xFF22D3EE);
  static const purple = Color(0xFF8B5CF6);
  static const violet = Color(0xFFA855F7);
  static const green = Color(0xFF68D391);

  static const success = Color(0xFF4ADE80);
  static const danger = Color(0xFFFB7185);
  static const online = Color(0xFF4ADE80);
  static const offline = Color(0xFF6B7280);
}
