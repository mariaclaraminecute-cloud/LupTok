import 'package:flutter/material.dart';

final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);
final ValueNotifier<double> appTextScale = ValueNotifier(1.0);
final ValueNotifier<Set<String>> followedUsernames = ValueNotifier({});
final ValueNotifier<Set<int>> savedVideoIndices = ValueNotifier({});
