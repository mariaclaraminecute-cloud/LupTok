import 'package:flutter_test/flutter_test.dart';
import 'package:luptok/work_search.dart';

void main() {
  group('searchWorks', () {
    test('finds school doramas from topic terms, not only title matches', () {
      final results = searchWorks('dorama colegial');

      expect(results, isNotEmpty);
      expect(results.map((work) => work.title), contains('True Beauty'));
      expect(results.every((work) => work.type == 'Dorama'), isTrue);
    });

    test('matches accents and ignores query word order', () {
      final results = searchWorks('ficção científica');

      expect(results.map((work) => work.title), contains('Shatter Me'));
      expect(
        results.map((work) => work.title),
        contains('Vingadores: Guerra Infinita'),
      );
    });

    test('recognizes alternative spellings of Korean dramas', () {
      final results = searchWorks('k-drama colegial');

      expect(results.map((work) => work.title), contains('True Beauty'));
      expect(results.every((work) => work.type == 'Dorama'), isTrue);
    });

    test('matches searches by a work description', () {
      final results = searchWorks('cavaleiros de dragões');

      expect(results.map((work) => work.title), contains('Quarta Asa'));
    });

    test('does not return unrelated works for combined topics', () {
      final results = searchWorks('dorama terror');

      expect(results, isEmpty);
    });
  });
}
