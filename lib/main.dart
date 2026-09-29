import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences.dart';
import 'package:flutter/material.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  appThemeMode.value = switch (preferences.getString(
    'setting_Aparência_Tema',
  )) {
    'Escuro' => ThemeMode.dark,
    'Seguir dispositivo' => ThemeMode.system,
    _ => ThemeMode.light,
  };
  appTextScale.value = switch (preferences.getString(
    'setting_Aparência_Tamanho do texto',
  )) {
    'Pequeno' => 0.9,
    'Grande' => 1.15,
    _ => 1.0,
  };
  followedUsernames.value =
      (preferences.getStringList('following_users') ?? const []).toSet();
  savedVideoIndices.value =
      (preferences.getStringList('saved_videos') ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
  runApp(const LupTokApp());
}

class LupTokApp extends StatelessWidget {
  const LupTokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, themeMode, _) => ValueListenableBuilder<double>(
        valueListenable: appTextScale,
        builder: (context, textScale, _) => MaterialApp(
          title: 'LupTok',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            scaffoldBackgroundColor: const Color(0xFFFFE9E9),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7D171D),
              brightness: Brightness.light,
              surface: const Color(0xFFFFE9E9),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFBB7575),
              brightness: Brightness.dark,
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
