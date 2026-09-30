import 'package:flutter/material.dart';

final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);
final ValueNotifier<double> appTextScale = ValueNotifier(1.0);
final ValueNotifier<Set<String>> followedUsernames = ValueNotifier({});
final ValueNotifier<Set<int>> savedVideoIndices = ValueNotifier({});

abstract final class AppPalette {
  static const darkBackground = Color(0xFF371111);
  static const darkButton = Color(0xFF810000);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? darkBackground : const Color(0xFFFFE9E9);

  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF451717) : const Color(0xFFFFF7F7);

  static Color raisedSurface(BuildContext context) =>
      isDark(context) ? const Color(0xFF4B1A1A) : Colors.white;

  static Color text(BuildContext context) =>
      isDark(context) ? Colors.white : const Color(0xFF493333);

  static Color primaryText(BuildContext context) =>
      isDark(context) ? Colors.white : const Color(0xFF7D171D);

  static Color mutedText(BuildContext context) =>
      isDark(context) ? Colors.white70 : const Color(0xFF80686A);

  static Color button(BuildContext context) =>
      isDark(context) ? darkButton : const Color(0xFFB8787C);

  static Color accent(BuildContext context) =>
      isDark(context) ? darkButton : const Color(0xFFBB7575);

  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0xFF810000) : const Color(0xFFBB7575);

  static Color input(BuildContext context) =>
      isDark(context) ? const Color(0xFF4B1A1A) : Colors.white;

  static String logo(BuildContext context) => isDark(context)
      ? 'assets/images/logobranca.png'
      : 'assets/images/logo.png';
}
