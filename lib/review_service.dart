import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class ReviewService {
  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token');
    if (token == null || token.isEmpty) throw Exception('Faça login novamente.');
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }
  static Map<String, dynamic> _read(http.Response response) {
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map) throw Exception('Resposta inválida do servidor.');
    final map = Map<String, dynamic>.from(data);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(map['erro'] ?? 'Erro ${response.statusCode}');
    }
    return map;
  }
  static Future<List<Map<String, dynamic>>> listar(String videoId) async {
    final response = await http.get(Uri.parse('${ApiService.baseUrl}/api/videos/$videoId/reviews'), headers: await _headers()).timeout(const Duration(seconds: 20));
    final items = _read(response)['avaliacoes'];
    if (items is! List) throw Exception('Lista de avaliações inválida.');
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  static Future<void> enviar(String videoId, String texto, int nota) async {
    final response = await http.post(Uri.parse('${ApiService.baseUrl}/api/videos/$videoId/reviews'), headers: await _headers(), body: jsonEncode({'texto': texto, 'nota': nota})).timeout(const Duration(seconds: 20));
    _read(response);
  }
  static Future<void> excluir(String videoId, Object reviewId) async {
    final response = await http.delete(Uri.parse('${ApiService.baseUrl}/api/videos/$videoId/reviews/$reviewId'), headers: await _headers()).timeout(const Duration(seconds: 20));
    _read(response);
  }
}
