
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );
  static String get baseUrl {
    final value = _configuredBaseUrl.isNotEmpty
          ? _configuredBaseUrl
          : kIsWeb
          ? 'http://localhost:3000'
          : 'http://10.0.2.2:3000';
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  static Future<Map<String, dynamic>> cadastrar({
    required String nome,
    required String nomeUsuario,
    required String email,
    required String senha,
  }) async {
    return _post('/api/auth/register', {
      'nome': nome,
      'nome_usuario': nomeUsuario,
      'email': email,
      'senha': senha,
    });
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String senha,
  }) async {
    return _post('/api/auth/login', {
      'email': email,
      'senha': senha,
    });
  }

  static Future<String?> tokenDaSessao() async {
    final preferencias = await SharedPreferences.getInstance();
    return preferencias.getString('session_token');
  }

  static Future<List<Map<String, dynamic>>> listarVideos() async {
    final token = await tokenDaSessao();
    if (token == null) throw Exception('Faça login para carregar o feed.');

    final response = await http
        .get(
          Uri.parse('$baseUrl/api/videos'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 20));
    final data = _decodeResponse(response);
    final videos = data['videos'];
    if (videos is! List) {
      throw Exception('O servidor retornou uma lista de vídeos inválida.');
    }

    return videos.map((video) {
      if (video is! Map) {
        throw Exception('O servidor retornou um vídeo inválido.');
      }
      return Map<String, dynamic>.from(video);
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> listarObras() async {
    final data = await _authenticatedGet('/api/works');
    final obras = data['obras'];
    if (obras is! List) {
      throw Exception('O servidor retornou uma lista de obras inválida.');
    }
    return obras.map(_mapResponseItem).toList();
  }

  static Future<List<Map<String, dynamic>>> listarContas() async {
    final data = await _authenticatedGet('/api/users');
    final contas = data['usuarios'];
    if (contas is! List) {
      throw Exception('O servidor retornou uma lista de contas inválida.');
    }
    return contas.map(_parseAccount).toList();
  }

  static Future<Map<String, dynamic>> obterConta(Object id) async {
    final data = await _authenticatedGet('/api/users/$id');
    return _parseAccount(data['usuario']);
  }

  static Future<void> adicionarObra({
    required String titulo,
    required String tipo,
  }) async {
    final token = await tokenDaSessao();
    if (token == null) throw Exception('Faça login para adicionar uma obra.');
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/works'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'titulo': titulo, 'tipo': tipo}),
        )
        .timeout(const Duration(seconds: 20));
    _decodeResponse(response);
  }

  static Future<void> avaliarObra({
    required Object id,
    required bool souFa,
  }) async {
    final token = await tokenDaSessao();
    if (token == null) throw Exception('Faça login para avaliar uma obra.');
    final response = await http
        .put(
          Uri.parse('$baseUrl/api/works/$id/rating'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'sou_fa': souFa}),
        )
        .timeout(const Duration(seconds: 20));
    _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> publicarVideo({
    required XFile arquivo,
    required String descricao,
    required String tipoConteudo,
    required String spoiler,
    required String privacidade,
  }) async {
    final token = await tokenDaSessao();
    if (token == null) throw Exception('Faça login para publicar um vídeo.');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/videos'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll({
      'descricao': descricao,
      'tipo_conteudo': tipoConteudo,
      'spoiler': spoiler,
      'privacidade': privacidade,
    });
    request.files.add(
      http.MultipartFile(
        'video',
        arquivo.openRead(),
        await arquivo.length(),
        filename: arquivo.name,
      ),
    );

    final streamedResponse = await request
        .send()
        .timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamedResponse);
    return _decodeResponse(response);
  }

  static String urlArquivoVideo(Object id) =>
      '$baseUrl/api/videos/$id/arquivo';

  static Future<String> urlArquivoVideoWeb(Object id) async {
    final token = await tokenDaSessao();
    if (token == null) throw Exception('Faça login para reproduzir o vídeo.');
    final response = await http
        .get(
          Uri.parse('$baseUrl/api/videos/$id/acesso'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));
    final data = _decodeResponse(response);
    final url = data['url'];
    if (url is! String) {
      throw Exception('O servidor não retornou um link de vídeo válido.');
    }
    return '$baseUrl$url';
  }

  static Future<void> salvarSessao(Map<String, dynamic> resposta) async {
    final token = resposta['token'];
    final usuario = resposta['usuario'];
    if (token is! String ||
        token.isEmpty ||
        usuario is! Map<String, dynamic>) {
      throw Exception('O servidor não retornou os dados da sessão.');
    }

    final nome = usuario['nome'];
    final nomeUsuario = usuario['nome_usuario'];
    final email = usuario['email'];
    final idUsuario = usuario['id_usuario'];
    if (nome is! String ||
        nomeUsuario is! String ||
        email is! String ||
        idUsuario == null) {
      throw Exception('O servidor retornou dados de conta inválidos.');
    }

    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString('session_token', token);
    await preferencias.setString('perfil_nome', nome);
    await preferencias.setString('perfil_usuario', '@$nomeUsuario');
    await preferencias.setString('perfil_email', email);
    await preferencias.setString('perfil_id', idUsuario.toString());
  }

  static Future<bool> temSessaoValida() async {
    final preferencias = await SharedPreferences.getInstance();
    final token = preferencias.getString('session_token');
    if (token == null) return false;

    final partes = token.split('.');
    if (partes.length != 3) {
      await _limparDadosSessao(preferencias);
      return false;
    }

    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))),
      );
      final expiracao = payload is Map<String, dynamic> ? payload['exp'] : null;
      final valida =
          expiracao is num &&
          expiracao > DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (!valida) await _limparDadosSessao(preferencias);
      return valida;
    } on FormatException {
      await _limparDadosSessao(preferencias);
      return false;
    }
  }

  static Future<void> encerrarSessao() async {
    final preferencias = await SharedPreferences.getInstance();
    await _limparDadosSessao(preferencias);
  }

  static Future<void> _limparDadosSessao(
    SharedPreferences preferencias,
  ) async {
    for (final chave in [
      'session_token',
      'perfil_id',
      'perfil_nome',
      'perfil_usuario',
      'perfil_email',
      'perfil_bio',
      'perfil_obra_favorita',
      'perfil_assistindo',
    ]) {
      await preferencias.remove(chave);
    }
  }

  static Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> _authenticatedGet(String endpoint) async {
    final token = await tokenDaSessao();
    if (token == null) throw Exception('Faça login para continuar.');
    final response = await http
        .get(
          Uri.parse('$baseUrl$endpoint'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 20));
    return _decodeResponse(response);
  }

  static Map<String, dynamic> _mapResponseItem(Object? item) {
    if (item is! Map) throw Exception('O servidor retornou um item inválido.');
    return Map<String, dynamic>.from(item);
  }

  static Map<String, dynamic> _parseAccount(Object? item) {
    final account = _mapResponseItem(item);
    final works = account['obras'];
    if (works is! List) {
      throw Exception('O servidor retornou obras de conta inválidas.');
    }
    return {
      ...account,
      'obras': works.map(_mapResponseItem).toList(),
    };
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }

      data = decoded;
    } on FormatException {
      throw Exception('O servidor retornou uma resposta inválida.');
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return data;
    }

    throw Exception(
      data['message'] ??
          data['mensagem'] ??
          data['erro'] ??
          'Erro ${response.statusCode} ao acessar a API.',
    );
  }
}
