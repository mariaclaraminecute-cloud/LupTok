import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

abstract final class SavedVideoService {
  static final videos = ValueNotifier<List<Map<String, dynamic>>>([]);
  static String? token;
  static bool _busy = false;
  static bool contains(String? id) => id != null && videos.value.any((v) => v['id'].toString() == id);
  static Future<void> load() async {
    if (_busy) return;
    _busy = true;
    try {
      final current = await ApiService.tokenDaSessao();
      if (current != token) { token = current; videos.value = []; }
      if (current == null) throw Exception('Faça login para continuar.');
      await _load(current);
    } finally { _busy = false; }
  }
  static Future<void> _load(String current) async {
    final response = await http.get(Uri.parse('${ApiService.baseUrl}/api/saved-videos'), headers: {'Authorization': 'Bearer $current'}).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw Exception('Não foi possível carregar os salvos.');
    final data = jsonDecode(response.body) as Map;
    final items = (data['videos'] as List).map((v) => Map<String, dynamic>.from(v as Map)).toList();
    if (await ApiService.tokenDaSessao() == current) videos.value = items;
  }
  static Future<void> toggle(String id) async {
    if (_busy) throw Exception('Aguarde a atualização dos salvos.');
    _busy = true;
    try {
      final current = await ApiService.tokenDaSessao();
      if (current == null) throw Exception('Faça login para continuar.');
      if (current != token) { token = current; videos.value = []; }
      await _load(current);
      final response = await http.put(Uri.parse('${ApiService.baseUrl}/api/saved-videos/$id'), headers: {'Authorization': 'Bearer $current', 'Content-Type': 'application/json'}, body: jsonEncode({'salvo': !contains(id)})).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw Exception('Não foi possível atualizar os salvos.');
      await _load(current);
    } finally { _busy = false; }
  }
}