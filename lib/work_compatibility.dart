import 'interest_utils.dart';

int workCompatibility(
  List<Map<String, dynamic>> first,
  List<Map<String, dynamic>> second,
) {
  final firstRatings = _ratingsByWork(first);
  final secondRatings = _ratingsByWork(second);
  final allWorkIds = {...firstRatings.keys, ...secondRatings.keys};

  final agreements = allWorkIds.where((id) {
    return firstRatings.containsKey(id) &&
        secondRatings.containsKey(id) &&
        firstRatings[id] == secondRatings[id];
  }).length;
  final workScore = allWorkIds.isEmpty ? 0.0 : agreements / allWorkIds.length;

  final firstTypes = _favoriteTypes(first);
  final secondTypes = _favoriteTypes(second);
  final allTypes = {...firstTypes, ...secondTypes};
  final sharedTypes = firstTypes.intersection(secondTypes).length;
  final typeScore = allTypes.isEmpty ? 0.0 : sharedTypes / allTypes.length;

  return ((workScore * 0.7 + typeScore * 0.3) * 100).round();
}

Map<String, bool> _ratingsByWork(List<Map<String, dynamic>> works) {
  final ratings = <String, bool>{};
  for (final work in works) {
    final id = work['id']?.toString();
    final rating = work['sou_fa'];
    if (id != null && rating is bool) ratings[id] = rating;
  }
  return ratings;
}

Set<String> _favoriteTypes(List<Map<String, dynamic>> works) => works
    .where((work) => work['sou_fa'] == true)
    .map((work) => normalizeInterest(work['tipo'] as String))
    .toSet();
