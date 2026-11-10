import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'api_service.dart';
import 'app_preferences.dart';
import 'groups_screen.dart' show GroupsScreen;
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'video_recorder_screen.dart';

const Color _kStarGold = Color(0xFFFFD166);
const Color _kVideoBackdrop = Color(0xFF191416);

// ══════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════

List<String> _apiStringList(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

String _cap(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _shorten(String s, [int max = 40]) {
  final t = s.trim();
  return t.length <= max ? t : '${t.substring(0, max - 1).trimRight()}…';
}

String _tipoAsset(String tipo) {
  final arquivo = switch (tipo.toLowerCase()) {
    'filme' => 'filme',
    'série' || 'serie' => 'serie',
    'livro' => 'livro',
    'anime' => 'anime',
    'k-drama' || 'dorama' => 'dorama',
    _ => 'filme',
  };
  return 'assets/images/$arquivo.png';
}

String _searchVideoTitle(Map<String, dynamic> video) {
  final obra = video['obra'];
  final tituloObra = obra is Map ? obra['titulo'] : null;
  final descricao = video['descricao'];
  if (tituloObra is String && tituloObra.isNotEmpty) return tituloObra;
  if (descricao is String && descricao.isNotEmpty) return _shorten(descricao);
  return 'Recomendação';
}

String _searchVideoAsset(Map<String, dynamic> video) {
  final obra = video['obra'];
  final tipo = obra is Map ? obra['tipo'] : video['tipo_conteudo'];
  return _tipoAsset(tipo?.toString() ?? '');
}

// ══════════════════════════════════════════════════════════════════
// HOME
// ══════════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _tabAtual = 0;

  bool _mostrarBemVindo = true;
  bool _ocultarSpoilers = false;
  List<String> _gostosPerfil = [];
  String? _idUsuarioAtual;
  String _nomePerfilAtual = '';
  String? _fotoPerfilAtual;
  String _versaoFotoPerfil = '0';

  bool _mostrarAvisoPublicado = false;
  String _tituloAvisoPublicado = '';
  Timer? _avisoPublicadoTimer;

  void _exibirAvisoPublicacao(String obra) {
    setState(() {
      _mostrarAvisoPublicado = true;
      _tituloAvisoPublicado = obra;
    });
    _avisoPublicadoTimer?.cancel();
    _avisoPublicadoTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _mostrarAvisoPublicado = false);
    });
  }

  late AnimationController _bemVindoCtrl;
  late Animation<double> _bemVindoOpacity;
  late Animation<double> _bemVindoScale;
  late Animation<double> _bemVindoSlide;

  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  final List<_VideoCard> _videos = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _carregarPreferencias();
    unawaited(_sincronizarPerfilAoAbrir());
    unawaited(_carregarVideosApi());
    ApiService.perfilAtualizado.addListener(_aoAtualizarPerfilGlobal);

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(
      begin: 0.3,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _bemVindoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _bemVindoOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 22,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 52),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 26,
      ),
    ]).animate(_bemVindoCtrl);

    _bemVindoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.94,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 38,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 42),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.98,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 20,
      ),
    ]).animate(_bemVindoCtrl);

    _bemVindoSlide = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 74),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -20.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 26,
      ),
    ]).animate(_bemVindoCtrl);

    _bemVindoCtrl.forward().then((_) {
      if (!mounted) return;
      setState(() => _mostrarBemVindo = false);
    });
  }

  Future<void> _sincronizarPerfilAoAbrir() async {
    try {
      await ApiService.meuPerfil();
      await _carregarPreferencias();
    } catch (_) {
      // Se a rede cair, o perfil pode mostrar os últimos dados locais.
    }
  }

  void _aoAtualizarPerfilGlobal() {
    unawaited(_carregarPreferencias());
    unawaited(_carregarVideosApi());
  }

  @override
  void dispose() {
    ApiService.perfilAtualizado.removeListener(_aoAtualizarPerfilGlobal);
    _avisoPublicadoTimer?.cancel();
    _bemVindoCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarPreferencias() async {
    final preferencias = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _idUsuarioAtual = preferencias.getString('perfil_id');
      _nomePerfilAtual = preferencias.getString('perfil_nome') ?? '';
      _fotoPerfilAtual = preferencias.getString('perfil_foto_url');
      _versaoFotoPerfil = preferencias.getString('perfil_avatar_versao') ?? '0';
      _ocultarSpoilers =
          preferencias.getBool('settings_hide_spoilers') ?? false;
      _gostosPerfil = [
        ...?preferencias.getStringList('perfil_tipos'),
        ...?preferencias.getStringList('perfil_generos'),
      ];
    });
  }

  Future<void> _abrirConfiguracoes() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    await _carregarPreferencias();
  }

  Future<void> _abrirGravador() async {
    final publicado = await Navigator.of(context).push<PublishedVideo>(
      MaterialPageRoute<PublishedVideo>(
        builder: (_) => const VideoRecorderScreen(),
      ),
    );
    if (!mounted || publicado == null) return;
    final preferencias = await SharedPreferences.getInstance();
    final nomeUsuario = preferencias.getString('perfil_usuario') ?? '@usuario';
    setState(() {
      _idUsuarioAtual ??= publicado.ownerId;
      _videos.insert(
        0,
        _VideoCard(
          titulo:
              publicado.workTitle ??
              (publicado.description.isEmpty
                  ? 'Meu vídeo'
                  : _shorten(publicado.description)),
          autor: nomeUsuario,
          tipo: publicado.contentType,
          genero: 'Vídeo de ${publicado.contentType.toLowerCase()}',
          descricao: publicado.description,
          spoiler: publicado.spoiler,
          obraId: publicado.workId,
          obraTitulo: publicado.workTitle,
          obraTipo: publicado.workType,
          obraDescricao: publicado.workDescription,
          obraGeneros: publicado.workGenres,
          obraPalavrasChave: publicado.workKeywords,
          stars: 0,
          comentarios: 0,
          cor: _kVideoBackdrop,
          videoPath: publicado.videoPath,
          videoToken: publicado.videoToken,
          videoId: publicado.videoId,
          ownerId: publicado.ownerId,
          privacy: publicado.privacy,
        ),
      );
    });
    _exibirAvisoPublicacao(
      publicado.workTitle?.trim().isNotEmpty == true
          ? publicado.workTitle!
          : (publicado.description.trim().isNotEmpty
              ? _shorten(publicado.description, 28)
              : 'Recomendação'),
    );
  }

  Future<void> _carregarVideosApi() async {
    try {
      final videos = await ApiService.listarVideos();
      final token = await ApiService.tokenDaSessao();
      if (token == null) {
        throw Exception('Sua sessão expirou. Entre novamente.');
      }
      final publicados = videos.map((video) {
        final id = video['id'];
        final ownerId = video['id_usuario'];
        final autor = video['autor'];
        final descricao = video['descricao'];
        final tipo = video['tipo_conteudo'];
        final spoiler = video['spoiler'];
        final privacidade = video['privacidade'];
        final curtidas = video['curtidas'];
        final curtidaUsuario = video['curtida_usuario'];
        final obraData = video['obra'];
        if (id == null ||
            ownerId == null ||
            autor is! String ||
            descricao is! String ||
            tipo is! String ||
            spoiler is! String ||
            privacidade is! String ||
            (curtidas != null && curtidas is! num) ||
            curtidaUsuario is! bool ||
            (obraData != null && obraData is! Map)) {
          throw Exception('O servidor retornou dados de vídeo inválidos.');
        }
        final obra = obraData is Map
            ? Map<String, dynamic>.from(obraData)
            : null;
        final generos = _apiStringList(obra?['generos']);
        final palavrasChave = _apiStringList(obra?['palavras_chave']);
        final tituloObra = obra?['titulo'] as String?;
        return _VideoCard(
          titulo:
              tituloObra ??
              (descricao.isEmpty
                  ? 'Vídeo de ${tipo.toLowerCase()}'
                  : _shorten(descricao)),
          autor: autor,
          tipo: obra?['tipo'] as String? ?? tipo,
          genero: generos.isEmpty
              ? 'Vídeo de ${tipo.toLowerCase()}'
              : generos.join(' · '),
          descricao: descricao,
          spoiler: spoiler,
          obraId: obra?['id']?.toString(),
          obraTitulo: tituloObra,
          obraTipo: obra?['tipo'] as String?,
          obraDescricao: obra?['descricao'] as String?,
          obraGeneros: generos,
          obraPalavrasChave: palavrasChave,
          // A API só envia a contagem ao autor; não depende da ordem
          // em que as preferências de login e os vídeos terminam de carregar.
          stars: curtidas is num ? curtidas.toInt() : 0,
          comentarios: 0,
          cor: _kVideoBackdrop,
          likedByMe: curtidaUsuario,
          videoPath: ApiService.urlArquivoVideo(id),
          videoToken: token,
          videoId: id.toString(),
          ownerId: ownerId.toString(),
          privacy: privacidade,
        );
      }).toList();
      if (!mounted) return;
      final idsServidor = publicados.map((v) => v.videoId).toSet();
      setState(() {
        _videos.removeWhere((video) => idsServidor.contains(video.videoId));
        _videos.insertAll(0, publicados);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível carregar os vídeos do servidor: '
            '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  ProfileVideo _toProfileVideo(_VideoCard video) => ProfileVideo(
    title: video.titulo,
    videoPath: video.videoPath,
    videoToken: video.videoToken,
    videoId: video.videoId,
    privacy: video.privacy,
    contentType: video.tipo,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      extendBody: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _tabAtual,
                  children: [
                    _LoopTab(
                      videos: _videos,
                      ocultarSpoilers: _ocultarSpoilers,
                      profileInterests: _gostosPerfil,
                      currentUserId: _idUsuarioAtual,
                      isVisible: _tabAtual == 0,
                    ),
                    GroupsScreen(key: ValueKey(ApiService.perfilAtualizado.value)),
                    ProfileScreen(
                      onOpenSettings: _abrirConfiguracoes,
                      availableVideos: _videos
                          .map((video) => video.titulo)
                          .toList(),
                      profileVideos: _videos
                          .where(
                            (video) =>
                                _idUsuarioAtual != null &&
                                video.ownerId == _idUsuarioAtual,
                          )
                          .map(_toProfileVideo)
                          .toList(),
                      privateVideos: _videos
                          .where(
                            (video) =>
                                video.ownerId == _idUsuarioAtual &&
                                video.privacy == 'Somente amigos',
                          )
                          .map(_toProfileVideo)
                          .toList(),
                    ),
                    _LupezOverlay(
                      glowAnim: _glowAnim,
                      onFechar: () => setState(() => _tabAtual = 0),
                      fullScreen: true,
                      videos: _videos,
                      interests: _gostosPerfil,
                    ),
                  ],
                ),
              ),
              if (!_mostrarBemVindo && _tabAtual != 3) _buildBottomNav(),
            ],
          ),
          if (_mostrarBemVindo) _buildBemVindoOverlay(),
          if (_mostrarAvisoPublicado) _buildPublicacaoToast(),
        ],
      ),
    );
  }

  Widget _buildPublicacaoToast() {
    return Positioned(
      top: 50,
      left: 18,
      right: 18,
      child: Material(
        color: Colors.transparent,
        child: AnimatedSlide(
          offset: _mostrarAvisoPublicado ? Offset.zero : const Offset(0, -1.2),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: _mostrarAvisoPublicado ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7D171D), Color(0xFF451717)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFFD166).withValues(alpha: 0.7),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD166),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF7D171D),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Vídeo publicado!',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'IMFellFrenchCanon',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tituloAvisoPublicado.isNotEmpty
                              ? 'Sua recomendação de "$_tituloAvisoPublicado" já está no feed.'
                              : 'Sua recomendação já está visível para a comunidade.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBemVindoOverlay() {
    final dark = AppPalette.isDark(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  AppPalette.darkBackground,
                  const Color(0xFF54242B),
                  AppPalette.darkBackground,
                ]
              : const [Color(0xFFFFF4F5), Color(0xFFFFE2E5), Color(0xFFF8CDD2)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFB8787C).withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFBB7575).withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _bemVindoCtrl,
            builder: (_, child) => Opacity(
              opacity: _bemVindoOpacity.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, _bemVindoSlide.value),
                child: Transform.scale(
                  scale: _bemVindoScale.value,
                  child: child,
                ),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.2, end: 0.6),
                    duration: const Duration(milliseconds: 2000),
                    builder: (_, v, child) => Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFBB7575).withValues(alpha: v),
                            blurRadius: 60,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                    child: Image.asset(AppPalette.logo(context), height: 100),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Bem-vindo!',
                    style: TextStyle(
                      color: dark
                          ? const Color(0xFFFFE9E9)
                          : const Color(0xFF7D343E),
                      fontFamily: 'IMFellFrenchCanon',
                      fontSize: 50,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: const Color(
                            0xFF7D343E,
                          ).withValues(alpha: 0.14),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: 56,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFBB7575), Color(0xFFD99AA0)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppPalette.accent(
                          context,
                        ).withValues(alpha: 0.24),
                      ),
                    ),
                    child: Text(
                      'Seu universo de entretenimento começa aqui',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: dark
                            ? const Color(0xFFFFE9E9)
                            : const Color(0xFF70494D),
                        fontSize: 15,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.background(context),
        border: Border(
          top: BorderSide(
            color: AppPalette.border(context).withValues(alpha: 0.35),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              _navAssetItem(
                image: 'assets/images/loop.png',
                label: 'Loop',
                active: _tabAtual == 0,
                onTap: () => setState(() => _tabAtual = 0),
              ),
              _navAssetItem(
                image: 'assets/images/grupos.png',
                label: 'Pessoas',
                active: _tabAtual == 1,
                onTap: () => setState(() => _tabAtual = 1),
                fallback: Icons.groups_rounded,
              ),
              Expanded(
                child: Center(
                  child: Material(
                    color: AppPalette.button(context),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _abrirGravador,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Image.asset(
                          'assets/images/gravar.png',
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _navAssetItem(
                image: 'assets/images/lupez.png',
                label: 'Lupez',
                active: _tabAtual == 3,
                onTap: () => setState(() => _tabAtual = 3),
              ),
              _navProfileItem(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navAssetItem({
    required String image,
    required String label,
    required bool active,
    required VoidCallback onTap,
    IconData? fallback,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Image.asset(
                  image,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    fallback ?? Icons.circle_outlined,
                    color: active
                        ? AppPalette.primaryText(context)
                        : AppPalette.accent(context),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: active
                      ? AppPalette.primaryText(context)
                      : AppPalette.mutedText(context),
                  fontSize: 9,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navProfileItem() {
    final active = _tabAtual == 2;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabAtual = 2),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: active
                    ? AppPalette.button(context)
                    : AppPalette.accent(context),
                foregroundImage: _fotoPerfilAtual != null && _fotoPerfilAtual!.isNotEmpty
                    ? NetworkImage(ApiService.urlFotoPerfil(_fotoPerfilAtual, _versaoFotoPerfil)!)
                    : null,
                child: _fotoPerfilAtual == null || _fotoPerfilAtual!.isEmpty
                    ? Text(
                        _nomePerfilAtual.isNotEmpty ? _nomePerfilAtual[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      )
                    : null,
              ),
              const SizedBox(height: 2),
              Text(
                'Perfil',
                style: TextStyle(
                  color: active
                      ? AppPalette.primaryText(context)
                      : AppPalette.mutedText(context),
                  fontSize: 9,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// MODEL
// ══════════════════════════════════════════════════════════════════

class _VideoCard {
  final String titulo, tipo, genero, descricao, spoiler, autor;
  final String? obraId, obraTitulo, obraTipo, obraDescricao;
  final List<String> obraGeneros, obraPalavrasChave;
  final String? videoPath;
  final String? videoToken;
  final String? videoId;
  final String? ownerId;
  final String privacy;
  final int stars, comentarios;
  final Color cor;
  final bool likedByMe;
  const _VideoCard({
    required this.titulo,
    required this.autor,
    required this.tipo,
    required this.genero,
    required this.descricao,
    required this.spoiler,
    required this.stars,
    required this.comentarios,
    required this.cor,
    this.likedByMe = false,
    this.obraId,
    this.obraTitulo,
    this.obraTipo,
    this.obraDescricao,
    this.obraGeneros = const [],
    this.obraPalavrasChave = const [],
    this.videoPath,
    this.videoToken,
    this.videoId,
    this.ownerId,
    this.privacy = 'Público',
  });
}

// ══════════════════════════════════════════════════════════════════
// ANIMAÇÃO DA ESTRELA (duplo toque)
// ══════════════════════════════════════════════════════════════════

/// Curtida do Loop: estrela que nasce pequena, cresce, dá um leve impulso,
/// permanece em destaque e solta partículas delicadas antes de sumir.
/// A profundidade vem das camadas da estrela, não de uma rotação exagerada.
class _LikeBurst extends StatefulWidget {
  final bool removing;
  const _LikeBurst({super.key, this.removing = false});

  @override
  State<_LikeBurst> createState() => _LikeBurstState();
}

class _LikeBurstState extends State<_LikeBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1750),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox(
          width: 300,
          height: 300,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => CustomPaint(
              painter: _SoftStarBurstPainter(
                progress: _controller.value,
                removing: widget.removing,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoftStarBurstPainter extends CustomPainter {
  final double progress;
  final bool removing;

  const _SoftStarBurstPainter({
    required this.progress,
    required this.removing,
  });

  double _segment(double begin, double end) =>
      ((progress - begin) / (end - begin)).clamp(0.0, 1.0).toDouble();

  double _smooth(double value) => value * value * (3 - 2 * value);

  double _outCubic(double value) {
    final inverse = 1 - value;
    return 1 - inverse * inverse * inverse;
  }

  // As partículas usam valores fixos por índice, sem saltos de um frame a outro.
  double _random(int index, int salt) {
    final result = math.sin(index * 24.17 + salt * 76.31) * 43758.5453;
    return result - result.floorToDouble();
  }

  Path _starPath(double outerRadius) {
    final path = Path();
    for (var index = 0; index < 10; index++) {
      final angle = -math.pi / 2 + math.pi * index / 5;
      final radius = index.isEven ? outerRadius : outerRadius * 0.47;
      final x = math.cos(angle) * radius;
      final y = math.sin(angle) * radius;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  Path _littleSparkle(Offset point, double radius) {
    return Path()
      ..moveTo(point.dx, point.dy - radius)
      ..quadraticBezierTo(point.dx + radius * 0.17,
          point.dy - radius * 0.17, point.dx + radius, point.dy)
      ..quadraticBezierTo(point.dx + radius * 0.17,
          point.dy + radius * 0.17, point.dx, point.dy + radius)
      ..quadraticBezierTo(point.dx - radius * 0.17,
          point.dy + radius * 0.17, point.dx - radius, point.dy)
      ..quadraticBezierTo(point.dx - radius * 0.17,
          point.dy - radius * 0.17, point.dx, point.dy - radius)
      ..close();
  }

  void _drawParticles(Canvas canvas, Offset center, Color gold, Color light) {
    // Nascem quando a estrela atinge o tamanho máximo e se espalham devagar.
    for (var i = 0; i < 30; i++) {
      final begin = 0.27 + _random(i, 1) * 0.12;
      final duration = 0.41 + _random(i, 2) * 0.17;
      final u = ((progress - begin) / duration).clamp(0.0, 1.0).toDouble();
      if (u <= 0 || u >= 1) continue;

      final ease = _outCubic(u);
      final angle = i * 2.3999632297 + (_random(i, 3) - 0.5) * 0.46;
      final distance = 40 + (50 + 35 * _random(i, 4)) * ease;
      final point = center + Offset(
        math.cos(angle) * distance,
        math.sin(angle) * distance * 0.93 + 9 * u * u,
      );
      final alpha = math.sin(math.pi * u) *
          (1 - _smooth(_segment(0.84, 1.0))) * 0.93;
      if (alpha <= 0.002) continue;

      final color = i % 4 == 0 ? light : gold;
      final size = (1.15 + _random(i, 5) * 1.5) * (1 - 0.22 * u);
      if (i % 7 == 0) {
        canvas.drawPath(
          _littleSparkle(point, size * 2.25),
          Paint()..color = light.withValues(alpha: alpha),
        );
      } else {
        canvas.drawCircle(
          point,
          size * 2.2,
          Paint()
            ..color = color.withValues(alpha: alpha * 0.16)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawCircle(
          point,
          size,
          Paint()..color = color.withValues(alpha: alpha),
        );
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final gold = removing ? const Color(0xFFECA0A8) : const Color(0xFFFFD166);
    final light = removing ? const Color(0xFFFFE8E9) : const Color(0xFFFFF4D1);
    final shadow = removing ? const Color(0xFF8D2E3F) : const Color(0xFFB66A17);

    // Crescimento principal: pequeno -> grande -> pequena acomodação.
    // A estrela fica legível por um momento ANTES de sumir.
    final growth = _outCubic(_segment(0.00, 0.38));
    final bounceWindow = _segment(0.28, 0.56);
    final bounce = (progress >= 0.28 && progress <= 0.56)
        ? math.sin(math.pi * bounceWindow) * 0.10
        : 0.0;
    final fade = 1 - _smooth(_segment(0.77, 1.0));
    final appear = _smooth(_segment(0.0, 0.08));
    final alpha = (appear * fade).clamp(0.0, 1.0).toDouble();
    final scale = (0.10 + 0.90 * growth + bounce) *
        (1 - 0.13 * _smooth(_segment(0.77, 1.0)));

    if (alpha <= 0.002) return;

    // Halo leve, restrito ao contorno da estrela, sem anéis gigantes.
    final flash = math.sin(math.pi * _segment(0.23, 0.55))
        .clamp(0.0, 1.0).toDouble();
    final haloRadius = 72 + 18 * flash;
    canvas.drawCircle(
      center,
      haloRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            gold.withValues(alpha: alpha * (0.20 + 0.14 * flash)),
            gold.withValues(alpha: alpha * 0.07),
            Colors.transparent,
          ],
          stops: const [0, 0.57, 1],
        ).createShader(Rect.fromCircle(center: center, radius: haloRadius)),
    );

    // Partículas passam atrás da estrela e aparecem só depois da expansão.
    _drawParticles(canvas, center, gold, light);

    canvas.save();
    canvas.translate(center.dx, center.dy + 9 * (1 - growth));
    canvas.rotate((removing ? 0.15 : -0.15) * (1 - growth));
    canvas.scale(scale);
    final star = _starPath(66);

    // Profundidade discreta: cinco camadas laterais dão volume de verdade.
    canvas.drawPath(
      star.shift(const Offset(0, 8)),
      Paint()
        ..color = shadow.withValues(alpha: alpha * 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    for (var layer = 6; layer >= 1; layer--) {
      canvas.drawPath(
        star.shift(Offset(0, layer * 0.85)),
        Paint()..color = Color.lerp(
          shadow,
          gold,
          (6 - layer) / 9,
        )!.withValues(alpha: alpha),
      );
    }

    // Face principal limpa e arredondada visualmente pelo contorno suave.
    canvas.drawPath(
      star,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light.withValues(alpha: alpha),
            gold.withValues(alpha: alpha),
            shadow.withValues(alpha: alpha)],
          stops: const [0.04, 0.58, 1.0],
        ).createShader(const Rect.fromLTWH(-70, -70, 140, 140)),
    );
    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.45
        ..strokeJoin = StrokeJoin.round
        ..color = light.withValues(alpha: alpha * 0.85),
    );

    // Um único reflexo deslizando pela face, sem excesso de luz.
    final shineProgress = _smooth(_segment(0.27, 0.69));
    final shineAlpha = alpha *
        math.sin(math.pi * _segment(0.27, 0.69))
            .clamp(0.0, 1.0).toDouble() * 0.32;
    if (shineAlpha > 0.002) {
      canvas.save();
      canvas.clipPath(star);
      final left = -105 + 190 * shineProgress;
      final rect = Rect.fromLTWH(left, -80, 25, 160);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: shineAlpha),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SoftStarBurstPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.removing != removing;
}

/// Pequena, discreta e só visível quando o vídeo estiver curtido.
class _LikedStarBadge extends StatelessWidget {
  const _LikedStarBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 38,
      height: 34,
      child: Center(
        child: Icon(Icons.star_rounded, size: 27, color: _kStarGold),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// PLAYER
// ══════════════════════════════════════════════════════════════════

class _FeedVideo extends StatefulWidget {
  final String path;
  final String? token;
  final String? videoId;
  final bool isActive;
  final bool userPaused;
  final VoidCallback? onTapVideo;
  final VoidCallback? onDoubleTapVideo;
  final double muteTop;

  const _FeedVideo({
    required this.path,
    this.token,
    this.videoId,
    this.isActive = true,
    this.userPaused = false,
    this.onTapVideo,
    this.onDoubleTapVideo,
    this.muteTop = 12,
  });

  @override
  State<_FeedVideo> createState() => _FeedVideoState();
}

class _FeedVideoState extends State<_FeedVideo> {
  VideoPlayerController? _controller;
  late final Future<void> _initialize;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _initialize = _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final parsedUri = Uri.tryParse(widget.path);
    final isNetworkUri =
        parsedUri != null &&
        (parsedUri.scheme == 'http' || parsedUri.scheme == 'https');
    final uri = kIsWeb && widget.videoId != null
        ? Uri.parse(await ApiService.urlArquivoVideoWeb(widget.videoId!))
        : isNetworkUri
        ? parsedUri
        : kIsWeb
        ? Uri.parse(widget.path)
        : Uri.file(widget.path);
    if (!mounted) return;
    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: kIsWeb || widget.token == null
          ? const {}
          : {'Authorization': 'Bearer ${widget.token}'},
    );
    _controller = controller;
    await controller.initialize();
    await controller.setLooping(true);
    await _syncPlayback();
  }

  @override
  void didUpdateWidget(covariant _FeedVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive ||
        oldWidget.userPaused != widget.userPaused) {
      unawaited(_syncPlayback());
    }
  }

  Future<void> _syncPlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.isActive && !widget.userPaused) {
      await controller.play();
    } else {
      await controller.pause();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // Executa pause/play no MESMO evento do toque. No navegador,
  // iniciar reprodução a partir de um rebuild assíncrono pode ser bloqueado.
  void _onVideoTap() {
    final callback = widget.onTapVideo;
    if (callback == null) return;
    final player = _controller;
    if (player != null && player.value.isInitialized) {
      if (widget.userPaused && widget.isActive) {
        unawaited(player.play());
      } else {
        unawaited(player.pause());
      }
    }
    callback();
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    final muted = !_muted;
    await controller.setVolume(muted ? 0 : 1);
    if (mounted) setState(() => _muted = muted);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialize,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const ColoredBox(color: Colors.black);
        if (snapshot.connectionState != ConnectionState.done) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF4D67)),
            ),
          );
        }
        final controller = _controller!;
        final value = controller.value;
        final aspectRatio = value.aspectRatio;
        final displayAspectRatio = value.rotationCorrection % 180 == 0
            ? aspectRatio
            : 1 / aspectRatio;
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.black,
              child: Center(
                child: AspectRatio(
                  aspectRatio: displayAspectRatio == 0
                      ? 9 / 16
                      : displayAspectRatio,
                  child: IgnorePointer(child: VideoPlayer(controller)),
                ),
              ),
            ),
            // A camada de toque fica ACIMA do player HTML (Flutter Web).
            // Sem isso, o elemento <video> pode consumir o clique antes
            // que o GestureDetector externo do feed o reconheça.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTapVideo == null ? null : _onVideoTap,
                onDoubleTap: widget.onDoubleTapVideo,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: widget.muteTop,
              right: 14,
              child: Material(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _toggleMute,
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Icon(
                      _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      size: 21,
                      color: Colors.white,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// BUSCA INTELIGENTE DE OBRAS E VÍDEOS
// ══════════════════════════════════════════════════════════════════

class _SearchBundle {
  final List<Map<String, dynamic>> obras;
  final List<Map<String, dynamic>> videos;
  const _SearchBundle({required this.obras, required this.videos});
}

class _LoopSearchDelegate extends SearchDelegate<void> {
  String? _lastSearchQuery;
  Future<_SearchBundle>? _searchFuture;

  _LoopSearchDelegate();

  Future<_SearchBundle> _search(String term) {
    if (_lastSearchQuery != term || _searchFuture == null) {
      _lastSearchQuery = term;
      _searchFuture = Future.wait([
        ApiService.buscarObras(term),
        ApiService.buscarVideos(term),
      ]).then(
        (results) => _SearchBundle(
          obras: results[0],
          videos: results[1],
        ),
      );
    }
    return _searchFuture!;
  }

  @override
  String get searchFieldLabel => 'Buscar no Loop (ex: dorama colegial, True Beauty)';

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
    scaffoldBackgroundColor: AppPalette.background(context),
    appBarTheme: AppBarTheme(
      backgroundColor: AppPalette.background(context),
      foregroundColor: AppPalette.primaryText(context),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(
        color: AppPalette.mutedText(context).withValues(alpha: 0.6),
        fontSize: 14,
      ),
      border: InputBorder.none,
    ),
  );

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        tooltip: 'Limpar busca',
        onPressed: () => query = '',
        icon: const Icon(Icons.close_rounded),
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: 'Voltar',
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back_rounded),
  );

  @override
  Widget buildResults(BuildContext context) => _buildMatches(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildMatches(context);

  Widget _buildMatches(BuildContext context) {
    final term = query.trim();
    if (term.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_rounded,
                size: 46,
                color: AppPalette.mutedText(context).withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Pesquisa inteligente no LupTok',
                style: TextStyle(
                  color: AppPalette.primaryText(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'IMFellFrenchCanon',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Busque por características (ex: "dorama colegial", "romance escolar") ou diretamente pelo nome de uma obra (ex: "True Beauty").',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppPalette.mutedText(context),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<_SearchBundle>(
      future: _search(term),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Não foi possível pesquisar: '
                '${snapshot.error.toString().replaceFirst('Exception: ', '')}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final bundle = snapshot.data!;
        final obras = bundle.obras;
        final videos = bundle.videos;

        if (obras.isEmpty && videos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 44,
                    color: AppPalette.mutedText(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nenhum resultado encontrado para "$term"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppPalette.primaryText(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tente outros termos como gêneros (romance, ação, suspense) ou características da história.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppPalette.mutedText(context),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 14),
          children: [
            // 1. Obras encontradas e recomendadas
            if (obras.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: AppPalette.button(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Obras recomendadas (${obras.length})',
                      style: TextStyle(
                        color: AppPalette.primaryText(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: obras.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final obra = obras[index];
                    final titulo = obra['titulo'] as String? ?? 'Obra';
                    final tipo = obra['tipo'] as String? ?? '';
                    final generos = _apiStringList(obra['generos']);
                    final palavras = _apiStringList(obra['palavras_chave']);
                    final tags = [...generos, ...palavras].take(2).join(' · ');

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        query = titulo;
                      },
                      child: Container(
                        width: 200,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppPalette.raisedSurface(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppPalette.border(context).withValues(alpha: 0.25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppPalette.button(context)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tipo,
                                    style: TextStyle(
                                      color: AppPalette.primaryText(context),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppPalette.primaryText(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (tags.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                tags,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppPalette.mutedText(context),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
            ],

            // 2. Vídeos relacionados encontrados
            if (videos.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.play_circle_outline_rounded,
                      size: 18,
                      color: AppPalette.button(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Vídeos relacionados (${videos.length})',
                      style: TextStyle(
                        color: AppPalette.primaryText(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _VideoSearchGrid(
                videos: videos,
                shrinkWrap: true,
                onTap: (video) => _openSearchVideo(context, video),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _VideoSearchGrid extends StatelessWidget {
  final List<Map<String, dynamic>> videos;
  final ValueChanged<Map<String, dynamic>> onTap;
  final bool shrinkWrap;

  const _VideoSearchGrid({
    required this.videos,
    required this.onTap,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 5
          : constraints.maxWidth >= 650
          ? 4
          : constraints.maxWidth >= 420
          ? 3
          : 2;
      return GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return _VideoSearchTile(video: video, onTap: () => onTap(video));
        },
      );
    },
  );
}

class _VideoSearchTile extends StatelessWidget {
  final Map<String, dynamic> video;
  final VoidCallback onTap;

  const _VideoSearchTile({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = _searchVideoTitle(video);
    final description = video['descricao'] as String? ?? '';
    final author = video['autor'] as String? ?? '';
    return Material(
      color: AppPalette.raisedSurface(context),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFBB7575), Color(0xFF191416)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Image.asset(
                _searchVideoAsset(video),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.movie_creation_outlined,
                    color: Colors.white70,
                    size: 44,
                  ),
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.transparent, Colors.black87],
                  stops: [0, 0.4, 1],
                ),
              ),
            ),
            const Positioned(
              top: 8,
              right: 8,
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 26,
                shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
                    ),
                  ),
                  if (description.isNotEmpty && description != title) ...[
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
                      ),
                    ),
                  ],
                  if (author.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openSearchVideo(
  BuildContext context,
  Map<String, dynamic> video,
) async {
  try {
    final id = video['id'];
    if (id == null) throw Exception('O vídeo não possui um identificador.');
    final token = await ApiService.tokenDaSessao();
    if (token == null) throw Exception('Sua sessão expirou. Entre novamente.');
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            _SearchVideoPlayerScreen(video: video, id: id, token: token),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Não foi possível abrir o vídeo: '
          '${error.toString().replaceFirst('Exception: ', '')}',
        ),
      ),
    );
  }
}

class _SearchVideoPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> video;
  final Object id;
  final String token;

  const _SearchVideoPlayerScreen({
    required this.video,
    required this.id,
    required this.token,
  });

  @override
  State<_SearchVideoPlayerScreen> createState() =>
      _SearchVideoPlayerScreenState();
}

class _SearchVideoPlayerScreenState extends State<_SearchVideoPlayerScreen> {
  bool _paused = false;
  bool _liked = false;
  bool _busy = false;
  bool _showPauseFeedback = false;
  bool _burstVisible = false;
  bool _burstRemoving = false;
  int _burstSequence = 0;
  int? _likes;
  String? _myUserId;
  Timer? _pauseTimer;
  Timer? _burstTimer;

  @override
  void initState() {
    super.initState();
    _liked = widget.video['curtida_usuario'] == true;
    final count = widget.video['curtidas'];
    _likes = count is num ? count.toInt() : null;
    unawaited(_getCurrentUser());
  }

  Future<void> _getCurrentUser() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _myUserId = p.getString('perfil_id'));
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _burstTimer?.cancel();
    super.dispose();
  }

  void _tapVideo() {
    setState(() {
      _paused = !_paused;
      _showPauseFeedback = true;
    });
    _pauseTimer?.cancel();
    _pauseTimer = Timer(const Duration(milliseconds: 680), () {
      if (mounted) setState(() => _showPauseFeedback = false);
    });
  }

  Future<void> _doubleTapVideo() async {
    if (_busy) return;
    final wasLiked = _liked;
    final oldCount = _likes;
    final next = !wasLiked;
    _burstTimer?.cancel();
    setState(() {
      _busy = true;
      _liked = next;
      _likes = oldCount == null
          ? null
          : (oldCount + (next ? 1 : -1)).clamp(0, 0x7fffffff).toInt();
      _burstVisible = true;
      _burstRemoving = !next;
      _burstSequence++;
    });
    _burstTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _burstVisible = false);
    });
    try {
      final response = await ApiService.atualizarCurtidaVideo(
        id: widget.id,
        curtido: next,
      );
      if (response['curtido'] is! bool ||
          (response['curtidas'] != null && response['curtidas'] is! num)) {
        throw Exception('Resposta de curtida inválida.');
      }
      if (!mounted) return;
      setState(() {
        _liked = response['curtido'] as bool;
        if (response['curtidas'] is num) {
          _likes = (response['curtidas'] as num).toInt();
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _liked = wasLiked;
        _likes = oldCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível curtir: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    final title = _searchVideoTitle(video);
    final description = video['descricao'] as String? ?? '';
    final author = video['autor'] as String? ?? '';
    final isOwner = _myUserId != null &&
        _myUserId == video['id_usuario']?.toString();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Denunciar vídeo',
            onPressed: () => _promptReportVideo(context, widget.id),
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _tapVideo,
              onDoubleTap: _doubleTapVideo,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _FeedVideo(
                    path: ApiService.urlArquivoVideo(widget.id),
                    token: widget.token,
                    videoId: widget.id.toString(),
                    userPaused: _paused,
                    onTapVideo: _tapVideo,
                    onDoubleTapVideo: _doubleTapVideo,
                  ),
                  if (_burstVisible)
                    Center(
                      child: IgnorePointer(
                        child: _LikeBurst(
                          key: ValueKey('search:$_burstSequence'),
                          removing: _burstRemoving,
                        ),
                      ),
                    ),
                  Center(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: (_paused || _showPauseFeedback) ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Icon(
                            _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                            color: Colors.white,
                            size: 46,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_liked)
                    Positioned(
                      right: 16,
                      bottom: 18,
                      child: IgnorePointer(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _LikedStarBadge(),
                            if (isOwner && _likes != null)
                              Text(
                                '$_likes',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (description.isNotEmpty || author.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              color: _kVideoBackdrop,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (author.isNotEmpty)
                    Text(author, style: const TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w600,
                    )),
                  if (description.isNotEmpty) ...[
                    if (author.isNotEmpty) const SizedBox(height: 5),
                    Text(description, style: const TextStyle(color: Colors.white)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _promptReportVideo(BuildContext context, Object videoId) async {
  const reasons = [
    'Fora do propósito do LupTok',
    'Assédio ou bullying',
    'Conteúdo inadequado',
    'Spam',
    'Outro motivo',
  ];
  final descriptionController = TextEditingController();
  String? selectedReason;
  final report = await showDialog<(String, String)>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Denunciar vídeo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sua denúncia é privada e será encaminhada para análise.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                decoration: const InputDecoration(labelText: 'Motivo'),
                items: reasons
                    .map(
                      (reason) =>
                          DropdownMenuItem(value: reason, child: Text(reason)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => selectedReason = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Detalhes (opcional)',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: selectedReason == null
                ? null
                : () => Navigator.pop(dialogContext, (
                    selectedReason!,
                    descriptionController.text.trim(),
                  )),
            child: const Text('Continuar'),
          ),
        ],
      ),
    ),
  );
  descriptionController.dispose();
  if (report == null || !context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Confirmar denúncia'),
      content: const Text('Deseja enviar esta denúncia para análise?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Enviar'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ApiService.denunciarVideo(
      id: videoId,
      motivo: report.$1,
      descricao: report.$2,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Denúncia enviada para análise.')),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TAB: LOOP (FEED)
// ══════════════════════════════════════════════════════════════════

class _LoopTab extends StatefulWidget {
  final List<_VideoCard> videos;
  final bool ocultarSpoilers;
  final List<String> profileInterests;
  final String? currentUserId;
  final bool isVisible;
  const _LoopTab({
    required this.videos,
    required this.ocultarSpoilers,
    required this.profileInterests,
    required this.currentUserId,
    this.isVisible = true,
  });

  @override
  State<_LoopTab> createState() => _LoopTabState();
}

class _LoopTabState extends State<_LoopTab> {
  final PageController _pageCtrl = PageController();
  final Set<int> _saved = {};
  final Set<String> _following = {};
  final Map<int, List<String>> _comentarios = {};
  final Map<String, bool> _likeStates = {};
  final Map<String, int> _likeCounts = {};
  final Set<String> _pendingLikes = {};
  final Map<String, bool> _queuedLikes = {};
  final Set<String> _likeAnimations = {};
  final Map<String, int> _likeAnimationVersions = {};
  final Map<String, bool> _likeAnimationRemovals = {};
  final Map<String, Timer> _likeAnimationTimers = {};
  bool _mostrandoSeguindo = false;
  int _pageIndex = 0;
  bool _userPaused = false;

  Timer? _pauseIndicatorTimer;
  bool _showPauseIndicator = false;
  bool _indicatorIsPause = true;

  void _aoTocarSimples() {
    setState(() {
      _userPaused = !_userPaused;
      _showPauseIndicator = true;
      _indicatorIsPause = _userPaused;
    });
    _pauseIndicatorTimer?.cancel();
    _pauseIndicatorTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _showPauseIndicator = false);
    });
  }

  @override
  void initState() {
    super.initState();
    _following.addAll(followedUsernames.value);
    _saved.addAll(savedVideoIndices.value);
    followedUsernames.addListener(_syncFollowedUsers);
    savedVideoIndices.addListener(_syncSavedVideos);
    _carregarInteracoes();
  }

  @override
  void didUpdateWidget(covariant _LoopTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible && !widget.isVisible && !_userPaused) {
      setState(() => _userPaused = true);
    } else if (!oldWidget.isVisible && widget.isVisible && _userPaused) {
      setState(() => _userPaused = false);
    }
  }

  @override
  void dispose() {
    _pauseIndicatorTimer?.cancel();
    followedUsernames.removeListener(_syncFollowedUsers);
    savedVideoIndices.removeListener(_syncSavedVideos);
    for (final timer in _likeAnimationTimers.values) {
      timer.cancel();
    }
    _pageCtrl.dispose();
    super.dispose();
  }

  void _syncFollowedUsers() {
    if (!mounted) return;
    setState(() {
      _following
        ..clear()
        ..addAll(followedUsernames.value);
    });
  }

  void _syncSavedVideos() {
    if (!mounted) return;
    setState(() {
      _saved
        ..clear()
        ..addAll(savedVideoIndices.value);
    });
  }

  Future<void> _abrirPerfilAutor(_VideoCard video) async {
    final id = video.ownerId;
    if (id == null) return;
    try {
      final account = await ApiService.obterConta(id);
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      final isOwner =
          preferences.getString('perfil_id') == account['id'].toString();
      final username = account['nome_usuario'] as String;
      final works = (account['obras'] as List).cast<Map<String, dynamic>>();
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ProfileScreen(
            isOwner: isOwner,
            publicUsername: '@$username',
            publicName: account['nome'] as String,
            publicWorks: works,
            availableVideos: widget.videos.map((item) => item.titulo).toList(),
            profileVideos: widget.videos
                .where(
                  (item) =>
                      item.ownerId == id &&
                      (isOwner || item.privacy == 'Público'),
                )
                .map(
                  (item) => ProfileVideo(
                    title: item.titulo,
                    videoPath: item.videoPath,
                    videoToken: item.videoToken,
                    videoId: item.videoId,
                    privacy: item.privacy,
                    contentType: item.tipo,
                  ),
                )
                .toList(),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível abrir esse perfil: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _carregarInteracoes() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _following.addAll(
        preferences.getStringList('following_users') ?? const [],
      );
      _saved.addAll(
        (preferences.getStringList('saved_videos') ?? const [])
            .map(int.tryParse)
            .whereType<int>(),
      );
    });
    followedUsernames.value = Set<String>.from(_following);
    savedVideoIndices.value = Set<int>.from(_saved);
  }

  Future<void> _toggleFollow(String user) async {
    setState(() {
      if (!_following.add(user)) _following.remove(user);
    });
    followedUsernames.value = Set<String>.from(_following);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('following_users', _following.toList());
  }

  Future<void> _toggleSaved(int videoIndex) async {
    setState(() {
      if (!_saved.add(videoIndex)) _saved.remove(videoIndex);
    });
    savedVideoIndices.value = Set<int>.from(_saved);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'saved_videos',
      _saved.map((index) => '$index').toList(),
    );
  }

  // ── Curtidas (estrela) ──────────────────────────────────────────

  String _likeKey(_VideoCard video, int index) =>
      video.videoId ?? 'local:$index';

  bool _isLiked(_VideoCard video, int index) =>
      _likeStates[_likeKey(video, index)] ?? video.likedByMe;

  int _likeCount(_VideoCard video, int index) =>
      _likeCounts[_likeKey(video, index)] ?? video.stars;

  void _aoDarDoisToques(_VideoCard video, int index) {
    final key = _likeKey(video, index);
    final vaCurtir = !_isLiked(video, index);
    _animateLike(key, removing: !vaCurtir);

    // Se uma chamada ainda estiver em andamento, memoriza a intenção mais
    // recente e atualiza a interface já, sem disparar duas requisições em disputa.
    if (_pendingLikes.contains(key)) {
      setState(() {
        _queuedLikes[key] = vaCurtir;
        _likeStates[key] = vaCurtir;
        final delta = vaCurtir ? 1 : -1;
        _likeCounts[key] = (_likeCount(video, index) + delta).clamp(0, 0x7fffffff).toInt();
      });
      return;
    }
    unawaited(_setLike(video, index, vaCurtir));
  }

  Future<void> _setLike(_VideoCard video, int index, bool shouldLike) async {
    final key = _likeKey(video, index);
    if (_pendingLikes.contains(key)) return;
    final wasLiked = _isLiked(video, index);
    if (wasLiked == shouldLike) return;
    final previousCount = _likeCount(video, index);
    setState(() {
      _likeStates[key] = shouldLike;
      _likeCounts[key] = (previousCount + (shouldLike ? 1 : -1)).clamp(
        0,
        0x7fffffff,
      ).toInt();
      if (video.videoId != null) _pendingLikes.add(key);
    });
    final id = video.videoId;
    if (id == null) return;

    try {
      final result = await ApiService.atualizarCurtidaVideo(
        id: id,
        curtido: shouldLike,
      );
      final count = result['curtidas'];
      final state = result['curtido'];
      if (state is! bool || (count != null && count is! num)) {
        throw Exception('O servidor retornou uma curtida inválida.');
      }
      if (!mounted) return;
      setState(() {
        if (count is num) _likeCounts[key] = count.toInt();
        _likeStates[key] = state;
        _pendingLikes.remove(key);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _likeCounts[key] = previousCount;
        _likeStates[key] = wasLiked;
        _pendingLikes.remove(key);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível atualizar a curtida: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }

    // Processa o último duplo toque recebido durante a requisição anterior.
    if (!mounted) return;
    final queued = _queuedLikes.remove(key);
    if (queued != null && queued != _isLiked(video, index)) {
      unawaited(_setLike(video, index, queued));
    }
  }

  void _animateLike(String key, {required bool removing}) {
    _likeAnimationTimers.remove(key)?.cancel();
    setState(() {
      _likeAnimations.add(key);
      _likeAnimationRemovals[key] = removing;
      _likeAnimationVersions.update(
        key,
        (version) => version + 1,
        ifAbsent: () => 1,
      );
    });
    _likeAnimationTimers[key] = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _likeAnimations.remove(key));
      _likeAnimationTimers.remove(key);
    });
  }

  // ── Ações ───────────────────────────────────────────────────────

  Future<void> _reportVideo(_VideoCard video) async {
    final id = video.videoId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este vídeo não pode ser denunciado.')),
      );
      return;
    }
    await _promptReportVideo(context, id);
  }

  Future<void> _abrirComentarios(int index) async {
    final comentarios = _comentarios.putIfAbsent(index, () => []);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.raisedSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CommentsSheet(
        titulo: widget.videos[index].titulo,
        comentarios: comentarios,
        onCommentAdded: () => setState(() {}),
      ),
    );
  }

  Future<void> _compartilhar(_VideoCard video) async {
    final obra = video.obraTitulo ?? video.titulo;
    await SharePlus.instance.share(
      ShareParams(
        subject: 'LupTok: $obra',
        text:
            '$obra (${video.tipo}). '
            'Recomendado por ${video.autor} no LupTok.',
      ),
    );
  }

  Future<void> _pesquisar() async {
    _trocarFeed(false);
    await showSearch<void>(context: context, delegate: _LoopSearchDelegate());
  }

  void _trocarFeed(bool seguindo) {
    if (_mostrandoSeguindo == seguindo) return;
    setState(() {
      _mostrandoSeguindo = seguindo;
      _pageIndex = 0;
      _userPaused = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
    });
  }

  // ── Textos e cores ─────────────────────────────────────────────

  String _spoilerLabel(String s) {
    if (widget.ocultarSpoilers && s != 'nenhum') return 'Spoiler oculto';
    switch (s) {
      case 'leve':
        return 'Spoiler leve';
      case 'muito':
        return 'Muito spoiler';
      default:
        return 'Sem spoiler';
    }
  }

  Color _spoilerColor(String s) {
    if (widget.ocultarSpoilers && s != 'nenhum') return Colors.white70;
    switch (s) {
      case 'leve':
        return const Color(0xFFFFB74D);
      case 'muito':
        return const Color(0xFFFF6B7A);
      default:
        return const Color(0xFF66D17A);
    }
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = AppPalette.isDark(context);
    final publicVideos = widget.videos
        .where((video) => video.privacy == 'Público')
        .toList();
    final feed = _mostrandoSeguindo
        ? publicVideos
              .where((video) => _following.contains(video.autor))
              .toList()
        : publicVideos;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. O feed de vídeos ocupa a tela inteira e rola verticalmente
          feed.isEmpty ? _buildEmpty() : _buildFeed(feed),

          // 2. A barra superior fica FIXA no topo, nunca se move ou duplica com os vídeos
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),
        ],
      ),
    );
  }

  /// Barra superior FIXA fora do PageView (não acompanha a rolagem dos vídeos).
  Widget _buildTopBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.65),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 14),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Image.asset(
              AppPalette.logo(context),
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.play_circle_filled_rounded,
                color: Color(0xFFFFD166),
                size: 28,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Center(
                child: Container(
                  height: 38,
                  constraints: const BoxConstraints(maxWidth: 196),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      _feedTab(
                        'Looping',
                        active: !_mostrandoSeguindo,
                        onTap: () => _trocarFeed(false),
                      ),
                      _feedTab(
                        'Seguindo',
                        active: _mostrandoSeguindo,
                        onTap: () => _trocarFeed(true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Pesquisar obras e vídeos',
              onPressed: _pesquisar,
              icon: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _feedTab(
    String label, {
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: 0.19)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final seguindo = _mostrandoSeguindo;
    return ColoredBox(
      color: AppPalette.isDark(context)
          ? AppPalette.darkBackground
          : _kVideoBackdrop,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                seguindo
                    ? Icons.people_outline_rounded
                    : Icons.video_library_outlined,
                color: Colors.white70,
                size: 44,
              ),
              const SizedBox(height: 14),
              Text(
                seguindo
                    ? 'Seu feed Seguindo começa aqui'
                    : 'Ainda não há vídeos por aqui',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                seguindo
                    ? 'Siga criadores no Looping para ver as publicações deles aqui.'
                    : 'Grave o primeiro vídeo recomendando um filme, série ou livro.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              if (seguindo) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => _trocarFeed(false),
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Ver Looping'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeed(List<_VideoCard> feed) {
    return PageView.builder(
      controller: _pageCtrl,
      scrollDirection: Axis.vertical,
      physics: const ClampingScrollPhysics(),
      onPageChanged: (index) {
        setState(() {
          _pageIndex = index;
          _userPaused = false;
          _showPauseIndicator = false;
        });
        _pauseIndicatorTimer?.cancel();
      },
      itemCount: feed.length,
      itemBuilder: (context, i) => _buildPage(feed[i], i),
    );
  }

  Widget _buildPage(_VideoCard v, int i) {
    final videoIndex = widget.videos.indexOf(v);
    final likeKey = _likeKey(v, videoIndex);
    final liked = _isLiked(v, videoIndex);
    final likes = _likeCount(v, videoIndex);
    final isOwner = v.ownerId != null && v.ownerId == widget.currentUserId;
    final saved = _saved.contains(videoIndex);
    final active = widget.isVisible && i == _pageIndex;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Toque simples = pausa/retoma com feedback temporário
      // Dois toques = curte/descurte com estrela e animação
      onTap: _aoTocarSimples,
      onDoubleTap: () => _aoDarDoisToques(v, videoIndex),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Fundo ou vídeo em reprodução
          if (v.videoPath == null)
            ColoredBox(
              color: AppPalette.isDark(context)
                  ? AppPalette.darkBackground
                  : v.cor,
            )
          else
            _FeedVideo(
              path: v.videoPath!,
              token: v.videoToken,
              videoId: v.videoId,
              isActive: active,
              userPaused: _userPaused,
              muteTop: 88,
              onTapVideo: _aoTocarSimples,
              onDoubleTapVideo: () => _aoDarDoisToques(v, videoIndex),
            ),

          // 2. Degradê inferior suave para dar leitura excelente aos textos
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 320,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.84),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // 3. Animação da estrela no centro (ao curtir)
          if (_likeAnimations.contains(likeKey))
            Center(
              child: IgnorePointer(
                child: _LikeBurst(
                  key: ValueKey('$likeKey:${_likeAnimationVersions[likeKey]}'),
                  removing: _likeAnimationRemovals[likeKey] ?? false,
                ),
              ),
            ),

          // 4. Indicador temporário de pausa / play: aparece por instantes e some sozinho
          Center(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: (_userPaused || _showPauseIndicator) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: AnimatedScale(
                  scale: (_userPaused || _showPauseIndicator) ? 1.0 : 0.65,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: Container(
                    padding: const EdgeInsets.all(19),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 24,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Icon(
                      _userPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: Colors.white,
                      size: 46,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 6. Coluna vertical de interação lateral (lado direito)
          Positioned(
            right: 10,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A estrela NÃO existe no layout até a pessoa curtir.
                // A contagem também só aparece para o autor da publicação.
                AnimatedSize(
                  duration: const Duration(milliseconds: 330),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.bottomCenter,
                  child: liked
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 17),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _LikedStarBadge(),
                              if (isOwner) ...[
                                const SizedBox(height: 1),
                                Text(
                                  _fmt(likes),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    shadows: [
                                      Shadow(color: Colors.black87, blurRadius: 7),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                // Comentários
                _acao(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: _fmt(
                    v.comentarios + (_comentarios[videoIndex]?.length ?? 0),
                  ),
                  onTap: () => _abrirComentarios(videoIndex),
                ),
                const SizedBox(height: 10),

                // Compartilhar
                _acao(
                  icon: Icons.share_outlined,
                  onTap: () => _compartilhar(v),
                ),
                const SizedBox(height: 10),

                // Salvar publicação
                _acao(
                  icon: saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  iconColor: saved ? _kStarGold : Colors.white,
                  onTap: () => _toggleSaved(videoIndex),
                ),
                const SizedBox(height: 10),

                // Mais opções / Denunciar
                PopupMenuButton<String>(
                  tooltip: 'Mais ações',
                  color: AppPalette.raisedSurface(context),
                  onSelected: (action) {
                    if (action == 'report') _reportVideo(v);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'report',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.flag_outlined),
                        title: Text('Denunciar vídeo'),
                      ),
                    ),
                  ],
                  child: _botaoRedondo(
                    const Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 7. Informações inferiores reorganizadas: Obra, Autor, Descrição e Spoiler
          Positioned(
            left: 16,
            right: 76,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Identificação elegante da obra à qual o vídeo está relacionado
                _obraBadge(v),
                const SizedBox(height: 10),

                // Linha do autor com avatar, nome de usuário e botão de seguir
                _autorRow(v, isOwner),

                // Descrição da publicação
                if (v.descricao.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    v.descricao.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 6),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // Nível de spoiler
                _spoilerBadge(v.spoiler),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Peças da interface do feed ──────────────────────────────────

  Widget _obraBadge(_VideoCard v) {
    final titulo = v.obraTitulo ?? (v.titulo.isNotEmpty ? v.titulo : 'Obra');
    final tipo = v.obraTipo ?? v.tipo;
    final generos = v.obraGeneros.take(2).map(_cap).join(' · ');

    final iconData = switch (tipo.toLowerCase()) {
      'filme' => Icons.movie_rounded,
      'série' || 'serie' => Icons.tv_rounded,
      'livro' => Icons.menu_book_rounded,
      'anime' => Icons.animation_rounded,
      'dorama' || 'k-drama' => Icons.theater_comedy_rounded,
      _ => Icons.movie_filter_rounded,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.27),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            size: 14,
            color: const Color(0xFFFFD166),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$titulo${tipo.isNotEmpty ? ' · $tipo' : ''}${generos.isNotEmpty ? ' ($generos)' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _autorRow(_VideoCard v, bool isOwner) {
    final nome = v.autor.replaceFirst('@', '');
    final inicial = nome.isEmpty ? '?' : nome.substring(0, 1).toUpperCase();
    final following = _following.contains(v.autor);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _abrirPerfilAutor(v),
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppPalette.button(context),
                      AppPalette.accent(context),
                    ],
                  ),
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                alignment: Alignment.center,
                child: Text(
                  inicial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                v.autor,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                ),
              ),
            ],
          ),
        ),
        if (!isOwner) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _toggleFollow(v.autor),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: following
                    ? Colors.white.withValues(alpha: 0.18)
                    : AppPalette.button(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: following ? Colors.white38 : Colors.transparent,
                ),
              ),
              child: Text(
                following ? 'Seguindo' : 'Seguir',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _spoilerBadge(String spoiler) {
    final cor = _spoilerColor(spoiler);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.5,
            height: 6.5,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            _spoilerLabel(spoiler),
            style: TextStyle(
              color: cor,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _botaoRedondo(Widget child) {
    // Ações flutuantes: área de toque confortável, sem bolhas pretas rígidas.
    return SizedBox(
      width: 44,
      height: 42,
      child: Center(child: child),
    );
  }

  Widget _acao({
    required IconData icon,
    required VoidCallback onTap,
    String? label,
    Color? iconColor,
    String? imageAsset,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _botaoRedondo(
            imageAsset == null
                ? Icon(
                    icon,
                    color: iconColor ?? Colors.white,
                    size: 25,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 11),
                      Shadow(color: Colors.black45, blurRadius: 3),
                    ],
                  )
                : Image.asset(
                    imageAsset,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        Icon(icon, color: iconColor ?? Colors.white, size: 24),
                  ),
          ),
          if (label != null) ...[
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// COMENTÁRIOS
// ══════════════════════════════════════════════════════════════════

class _CommentsSheet extends StatefulWidget {
  final String titulo;
  final List<String> comentarios;
  final VoidCallback onCommentAdded;

  const _CommentsSheet({
    required this.titulo,
    required this.comentarios,
    required this.onCommentAdded,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _enviarComentario() {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;
    setState(() => widget.comentarios.add(texto));
    widget.onCommentAdded();
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            12 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppPalette.border(context).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Comentários · ${widget.titulo}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppPalette.text(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: widget.comentarios.isEmpty
                    ? Center(
                        child: Text(
                          'Seja a primeira pessoa a comentar.',
                          style: TextStyle(
                            color: AppPalette.mutedText(context),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: widget.comentarios.length,
                        itemBuilder: (context, index) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppPalette.surface(context),
                            child: Icon(
                              Icons.person_rounded,
                              size: 20,
                              color: AppPalette.primaryText(context),
                            ),
                          ),
                          title: Text(
                            'Você',
                            style: TextStyle(color: AppPalette.text(context)),
                          ),
                          subtitle: Text(
                            widget.comentarios[index],
                            style: TextStyle(
                              color: AppPalette.mutedText(context),
                            ),
                          ),
                        ),
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _enviarComentario(),
                      decoration: InputDecoration(
                        hintText: 'Escreva um comentário',
                        filled: true,
                        fillColor: AppPalette.surface(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Enviar comentário',
                    onPressed: _enviarComentario,
                    style: IconButton.styleFrom(
                      backgroundColor: AppPalette.button(context),
                    ),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// LUPEZ (chat)
// ══════════════════════════════════════════════════════════════════

class _LupezOverlay extends StatefulWidget {
  final Animation<double> glowAnim;
  final VoidCallback onFechar;
  final bool fullScreen;
  final List<_VideoCard> videos;
  final List<String> interests;
  const _LupezOverlay({
    required this.glowAnim,
    required this.onFechar,
    required this.videos,
    required this.interests,
    this.fullScreen = false,
  });

  @override
  State<_LupezOverlay> createState() => _LupezOverlayState();
}

class _LupezOverlayState extends State<_LupezOverlay>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_Mensagem> _msgs = [];
  bool _digitando = false;
  int _respostasPendentes = 0;

  late AnimationController _dotCtrl;

  final _sugestoes = [
    'Me recomenda um suspense 🔍',
    'Quero chorar muito 😢',
    'Anime pra iniciante?',
    'K-drama curto ❤️',
    'Ficção científica épica 🚀',
  ];

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _msgs.add(
          const _Mensagem(
            texto:
                'Oi! Sou a **Lupez** 🎬✨\nComo posso te ajudar hoje? Posso recomendar filmes, séries, livros, animes e K-dramas!',
            deLupez: true,
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  void _enviar([String? texto]) {
    final msg = texto ?? _inputCtrl.text.trim();
    if (msg.isEmpty) return;
    final historico = _msgs
        .map(
          (mensagem) => {
            'role': mensagem.deLupez ? 'assistant' : 'user',
            'content': mensagem.texto,
          },
        )
        .toList()
        .reversed
        .take(20)
        .toList()
        .reversed
        .toList();
    final mensagemEnviada = _Mensagem(texto: msg, deLupez: false);
    setState(() {
      _msgs.add(mensagemEnviada);
      _inputCtrl.clear();
      _respostasPendentes++;
      _digitando = true;
    });
    _rolar();

    _responder(msg, historico, mensagemEnviada);
  }

  Future<void> _responder(
    String mensagem,
    List<Map<String, String>> historico,
    _Mensagem mensagemEnviada,
  ) async {
    String resposta;
    try {
      resposta = await ApiService.conversarComLupez(
        mensagem: mensagem,
        historico: historico,
      );
    } catch (error, stackTrace) {
      debugPrint('Erro ao conversar com a Lupez: $error\n$stackTrace');
      resposta = 'Não consegui responder: $error';
    }

    if (!mounted) return;
    final indiceMensagem = _msgs.indexOf(mensagemEnviada);
    if (indiceMensagem < 0) return;
    setState(() {
      _msgs.insert(
        indiceMensagem + 1,
        _Mensagem(texto: resposta, deLupez: true),
      );
      _respostasPendentes--;
      _digitando = _respostasPendentes > 0;
    });
    _rolar();
  }

  void _rolar() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.fullScreen
          ? AppPalette.background(context)
          : Colors.black.withValues(alpha: 0.65),
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: widget.fullScreen
                ? MediaQuery.sizeOf(context).height
                : MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: AppPalette.raisedSurface(context),
              borderRadius: widget.fullScreen
                  ? BorderRadius.zero
                  : const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                if (!widget.fullScreen)
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppPalette.border(context).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: widget.glowAnim,
                        builder: (_, child) => Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppPalette.button(context),
                                AppPalette.accent(context),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.accent(context).withValues(
                                  alpha: 0.4 * widget.glowAnim.value,
                                ),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: child,
                        ),
                        child: const Center(
                          child: Text(
                            'L',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (b) => LinearGradient(
                              colors: [
                                AppPalette.accent(context),
                                AppPalette.primaryText(context),
                              ],
                            ).createShader(b),
                            child: const Text(
                              'Lupez',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'IA de entretenimento',
                                style: TextStyle(
                                  color: AppPalette.mutedText(context),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: widget.onFechar,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppPalette.button(
                              context,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.close,
                            color: AppPalette.mutedText(context),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(
                  color: AppPalette.border(context).withValues(alpha: 0.18),
                  height: 1,
                ),

                // Mensagens
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    itemCount: _msgs.length + (_digitando ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _msgs.length && _digitando) {
                        return _bolhaDigitando();
                      }
                      return _bolha(_msgs[i]);
                    },
                  ),
                ),

                // Sugestões
                if (_msgs.length <= 1)
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: _sugestoes.length,
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => _enviar(_sugestoes[i]),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.surface(context),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppPalette.border(context),
                            ),
                          ),
                          child: Text(
                            _sugestoes[i],
                            style: TextStyle(
                              color: AppPalette.primaryText(context),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Input
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    14,
                    0,
                    14,
                    widget.fullScreen
                        ? 12
                        : MediaQuery.of(context).viewInsets.bottom + 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppPalette.surface(context),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: AppPalette.border(
                                context,
                              ).withValues(alpha: 0.45),
                            ),
                          ),
                          child: TextField(
                            controller: _inputCtrl,
                            style: TextStyle(
                              color: AppPalette.text(context),
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Pergunte à Lupez...',
                              hintStyle: TextStyle(
                                color: AppPalette.mutedText(
                                  context,
                                ).withValues(alpha: 0.72),
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _enviar(),
                            textInputAction: TextInputAction.send,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _enviar,
                        child: AnimatedBuilder(
                          animation: widget.glowAnim,
                          builder: (_, child) => Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [
                                  AppPalette.button(context),
                                  AppPalette.accent(context),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppPalette.accent(context).withValues(
                                    alpha: 0.35 * widget.glowAnim.value,
                                  ),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                            child: child,
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bolha(_Mensagem msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: msg.deLupez
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (msg.deLupez) ...[
            Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.only(right: 7),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppPalette.button(context),
                    AppPalette.accent(context),
                  ],
                ),
              ),
              child: const Center(
                child: Text(
                  'L',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: msg.deLupez
                    ? null
                    : LinearGradient(
                        colors: [
                          AppPalette.button(context),
                          AppPalette.accent(context),
                        ],
                      ),
                color: msg.deLupez ? AppPalette.surface(context) : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.deLupez ? 4 : 16),
                  bottomRight: Radius.circular(msg.deLupez ? 16 : 4),
                ),
                border: msg.deLupez
                    ? Border.all(
                        color: AppPalette.border(
                          context,
                        ).withValues(alpha: 0.18),
                      )
                    : null,
              ),
              child: _textoFormatado(msg.texto, msg.deLupez),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textoFormatado(String texto, bool deLupez) {
    final partes = texto.split('**');
    final spans = <TextSpan>[];
    for (int i = 0; i < partes.length; i++) {
      spans.add(
        TextSpan(
          text: partes[i],
          style: TextStyle(
            color: deLupez ? AppPalette.text(context) : Colors.white,
            fontWeight: i.isOdd ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      );
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _bolhaDigitando() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(right: 7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppPalette.button(context),
                  AppPalette.accent(context),
                ],
              ),
            ),
            child: const Center(
              child: Text(
                'L',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: AppPalette.surface(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: AppPalette.border(context).withValues(alpha: 0.18),
              ),
            ),
            child: AnimatedBuilder(
              animation: _dotCtrl,
              builder: (_, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final delay = i / 3;
                  final val = (_dotCtrl.value - delay).clamp(0.0, 1.0);
                  final op = val < 0.5 ? val * 2 : (1.0 - val) * 2;
                  return Container(
                    margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                    child: Opacity(
                      opacity: 0.3 + op * 0.7,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFBB7575),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mensagem {
  final String texto;
  final bool deLupez;
  const _Mensagem({required this.texto, required this.deLupez});
}