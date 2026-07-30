import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Mismas dos familias que la web (next/font/google): Space Grotesk para títulos/marca,
/// Inter para el resto — ver menzoweb/app/layout.tsx + globals.css `--font-display`/`--font-body`.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle display({
    double size = 20,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.textPrimary,
  }) => GoogleFonts.spaceGrotesk(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.2,
  );

  static TextStyle body({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
  }) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.35,
  );

  static TextStyle h1({Color color = AppColors.textPrimary}) =>
      display(size: 28, weight: FontWeight.w700, color: color);
  static TextStyle h2({Color color = AppColors.textPrimary}) =>
      display(size: 22, weight: FontWeight.w700, color: color);
  static TextStyle h3({Color color = AppColors.textPrimary}) =>
      display(size: 18, weight: FontWeight.w700, color: color);
  static TextStyle label({Color color = AppColors.textPrimary}) =>
      body(size: 14, weight: FontWeight.w600, color: color);
  static TextStyle caption({Color color = AppColors.textMuted}) =>
      body(size: 12, weight: FontWeight.w500, color: color);
}
