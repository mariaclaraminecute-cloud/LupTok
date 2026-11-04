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

  static const gold = Color(0xFFFFD166);
  static const wine = Color(0xFF7D171D);
  static const blush = Color(0xFFFFE9E9);

  static List<BoxShadow> softShadow(BuildContext context) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark(context) ? 0.28 : 0.08),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  static BorderRadius radius = BorderRadius.circular(18);

  static InputDecoration fieldDecoration(
    BuildContext context, {
    String? hint,
    String? label,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      labelText: label,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: input(context),
      hintStyle: TextStyle(color: mutedText(context)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border(context).withValues(alpha: 0.35)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border(context).withValues(alpha: 0.28)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent(context), width: 1.4),
      ),
    );
  }
}

Route<T> luptokFadeRoute<T extends Object?>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, _, _) => page,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
