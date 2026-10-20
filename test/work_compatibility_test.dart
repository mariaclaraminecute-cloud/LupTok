import 'package:flutter_test/flutter_test.dart';
import 'package:luptok/work_compatibility.dart';

void main() {
  group('workCompatibility', () {
    test('gives full score for the same ratings and favorite type', () {
      final first = [
        {'id': 1, 'tipo': 'Anime', 'sou_fa': true},
      ];
      final second = [
        {'id': 1, 'tipo': 'Anime', 'sou_fa': true},
      ];

      expect(workCompatibility(first, second), 100);
    });

    test('recognizes shared type when users like different works', () {
      final first = [
        {'id': 1, 'tipo': 'Anime', 'sou_fa': true},
      ];
      final second = [
        {'id': 2, 'tipo': 'Anime', 'sou_fa': true},
      ];

      expect(workCompatibility(first, second), 30);
    });

    test('lowers score when users disagree about the same work', () {
      final first = [
        {'id': 1, 'tipo': 'Anime', 'sou_fa': true},
      ];
      final second = [
        {'id': 1, 'tipo': 'Anime', 'sou_fa': false},
      ];

      expect(workCompatibility(first, second), 0);
    });

    test('returns zero before either user rates a work', () {
      expect(workCompatibility([], []), 0);
    });
  });
}
