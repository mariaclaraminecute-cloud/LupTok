import 'dart:async';
import 'dart:ui' as ui;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'api_service.dart';
import 'saved_video_service.dart';
import 'video_work_label.dart';
import 'review_service.dart';
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

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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
  String? _navAvatarUrl;
  String _navName = '';

  void _updateNavProfile(String? photo, String name) {
    if (!mounted) return;
    if (_navAvatarUrl == photo && _navName == name) return;
    setState(() {
      _navAvatarUrl = photo;
      _navName = name;
    });
  }

  Color _navColor(bool active) => AppPalette.isDark(context)
      ? (active ? const Color(0xFFFFE9E9) : const Color(0xFFE1B7BB))
      : (active ? const Color(0xFF7D171D) : const Color(0xFF805459));

  bool _mostrarBemVindo = true;
  bool _ocultarSpoilers = false;
  List<String> _gostosPerfil = [];
  String? _idUsuarioAtual;

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
    ApiService.videosExcluidos.addListener(_sincronizarExclusoes);
    _carregarPreferencias();
    unawaited(_carregarVideosApi());

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

  @override
  void dispose() {
    ApiService.videosExcluidos.removeListener(_sincronizarExclusoes);
    _avisoPublicadoTimer?.cancel();
    _bemVindoCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  void _sincronizarExclusoes() {
    if (mounted) setState(() => _videos.removeWhere((v) => ApiService.videosExcluidos.value.contains(v.videoId)));
  }

  Future<void> _carregarPreferencias() async {
    final preferencias = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _idUsuarioAtual = preferencias.getString('perfil_id');
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
    final apelidoLocal = preferencias.getString('perfil_nome')?.trim();
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
          apelido: apelidoLocal?.isNotEmpty == true ? apelidoLocal : null,
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
        final apelido = video['apelido'] ?? video['nome'] ??
            video['nome_exibicao'] ?? video['nomeExibicao'];
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
          apelido: apelido is String && apelido.trim().isNotEmpty ? apelido.trim() : null,
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
          fotoUrl: video['foto_url'] as String?,
          privacy: privacidade,
        );
      }).toList();
      if (!mounted) return;
      final idsServidor = publicados.map((v) => v.videoId).toSet();
      setState(() {
        _videos.removeWhere((video) => idsServidor.contains(video.videoId));
        _videos.insertAll(0, publicados.where((v) => !ApiService.videosExcluidos.value.contains(v.videoId)));
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
                    GroupsScreen(),
                    ProfileScreen(
                      onOpenSettings: _abrirConfiguracoes,
                      onProfileChanged: _updateNavProfile,
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
      top: 44, left: 20, right: 20,
      child: Material(
        color: Colors.transparent,
        child: AnimatedSlide(
          offset: _mostrarAvisoPublicado ? Offset.zero : const Offset(0, -1.2),
          duration: const Duration(milliseconds: 280),
          child: AnimatedOpacity(
            opacity: _mostrarAvisoPublicado ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: AppPalette.raisedSurface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFB8787C).withValues(alpha: .45)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 16, offset: const Offset(0, 5))],
              ),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFB8787C).withValues(alpha: .16),shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Color(0xFFB8787C), size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,mainAxisSize: MainAxisSize.min,children: [
                  Text('Vídeo publicado',style: TextStyle(color: AppPalette.primaryText(context),fontSize: 14,fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(_tituloAvisoPublicado.isNotEmpty ? '$_tituloAvisoPublicado já está no Loop.' : 'Seu vídeo já está no Loop.',
                    maxLines: 1,overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppPalette.mutedText(context),fontSize: 12)),
                ])),
              ]),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
            decoration: BoxDecoration(
              color: AppPalette.surface(context),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppPalette.isDark(context) ? const Color(0xFF805054) : const Color(0xFFEBCBCD)),
            ),
            child: Row(
            children: [
              _navAssetItem(
                image: AppPalette.isDark(context)
                    ? 'assets/images/infinito.png'
                    : 'assets/images/loop.png',
                label: 'Loop',
                active: _tabAtual == 0,
                onTap: () => setState(() => _tabAtual = 0),
              ),
              _navAssetItem(
                image: null,
                label: 'Conversas',
                active: _tabAtual == 1,
                onTap: () => setState(() => _tabAtual = 1),
                fallback: LucideIcons.messageCircle,
              ),
              Expanded(
                child: Center(
                  child: Material(
                    color: AppPalette.button(context),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: _abrirGravador,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
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
      ),
    );
  }

  Widget _navAssetItem({
    required String? image,
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
                child: image == null
                    ? Icon(
                        fallback ?? Icons.chat_bubble_outline_rounded,
                        color: _navColor(active),
                        size: 22,
                      )
                    : Image.asset(
                  image,
                  color: _navColor(active),
                  colorBlendMode: BlendMode.srcIn,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    fallback ?? Icons.circle_outlined,
                    color: _navColor(active),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: _navColor(active),
                  fontSize: 11,
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
        onTap: () { setState(() => _tabAtual = 2); unawaited(SavedVideoService.load().catchError((Object _) {})); },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: active ? _navColor(true) : Colors.transparent),
                ),
                child: CircleAvatar(
                  radius: 11,
                  backgroundColor: const Color(0xFF7D171D),
                  foregroundImage: _navAvatarUrl == null ? null : NetworkImage(_navAvatarUrl!),
                  child: Text(
                    _navName.trim().isEmpty ? '?' : _navName.trim()[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Perfil',
                style: TextStyle(
                  color: _navColor(active),
                  fontSize: 11,
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


Widget _luptokAvatar(String? url, String inicial, double radius) {
  final resolved = ApiService.urlImagemPerfil(url);
  return CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFB8787C),
    foregroundImage: resolved == null ? null : NetworkImage(resolved),
    child: Text(inicial, style: TextStyle(color: Colors.white, fontSize: radius * 0.8)),
  );
}

class _VideoCard {
  final String titulo, tipo, genero, descricao, spoiler, autor;
  final String? apelido;
  final String? obraId, obraTitulo, obraTipo, obraDescricao;
  final List<String> obraGeneros, obraPalavrasChave;
  final String? videoPath;
  final String? videoToken;
  final String? videoId;
  final String? ownerId;
  final String? fotoUrl;
  final String privacy;
  final int stars, comentarios;
  final Color cor;
  final bool likedByMe;
  const _VideoCard({
    required this.titulo,
    required this.autor,
    this.apelido,
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
    this.fotoUrl,
    this.privacy = 'Público',
  });
}

// ══════════════════════════════════════════════════════════════════
// ANIMAÇÃO DA ESTRELA (duplo toque)
// ══════════════════════════════════════════════════════════════════

/// Explosão de curtida: uma estrela tridimensional construída a partir de
/// malha extrudada, iluminação, projeção com perspectiva e partículas.
/// Sem imagens prontas nem bibliotecas adicionais.
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
    duration: const Duration(milliseconds: 1850),
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
          width: 330,
          height: 330,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _StarPopPainter(
                t: _controller.value,
                removing: widget.removing,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Um ponto real no espaço tridimensional, antes da projeção 2D no canvas.
class _StarPoint3 {
  final double x;
  final double y;
  final double z;
  const _StarPoint3(this.x, this.y, this.z);
}

/// Malha de 10 vértices nas duas faces, borda chanfrada e frente facetada.
/// A rotação altera a projeção de TODOS os vértices (inclusive a espessura).
class _PrismStarMesh {
  static const _brightGold = Color(0xFFFFF4C2);
  static const _midGold = Color(0xFFFFCF56);
  static const _darkGold = Color(0xFF9E4D13);
  static const _brightRose = Color(0xFFFFDCE8);
  static const _midRose = Color(0xFFFF668A);
  static const _darkRose = Color(0xFF7D123D);

  static double _clamp01(double t) => t.clamp(0.0, 1.0).toDouble();

  static List<_StarPoint3> _points(double radius, double z) {
    return List.generate(10, (i) {
      final a = -math.pi / 2 + math.pi * i / 5;
      final r = i.isEven ? radius : radius * 0.43;
      return _StarPoint3(r * math.cos(a), r * math.sin(a), z);
    });
  }

  static Offset _project(
    _StarPoint3 p,
    Offset center,
    double rx,
    double ry,
    double rz,
    double scale,
  ) {
    // Z -> Y -> X: orientação espacial, sem simples Transform.rotate 2D.
    final x0 = p.x * math.cos(rz) - p.y * math.sin(rz);
    final y0 = p.x * math.sin(rz) + p.y * math.cos(rz);
    final x1 = x0 * math.cos(ry) + p.z * math.sin(ry);
    final z1 = -x0 * math.sin(ry) + p.z * math.cos(ry);
    final y2 = y0 * math.cos(rx) - z1 * math.sin(rx);
    final z2 = y0 * math.sin(rx) + z1 * math.cos(rx);
    final distance = (420 - z2).clamp(100.0, 800.0).toDouble();
    final perspective = 420 / distance;
    return center + Offset(x1 * perspective * scale, y2 * perspective * scale);
  }

  static Path _poly(List<Offset> points) => Path()..addPolygon(points, true);

  static void draw(
    Canvas canvas, {
    required Offset center,
    required double scale,
    required double rx,
    required double ry,
    required double rz,
    required double time,
    required bool removing,
    double opacity = 1,
  }) {
    if (scale <= 0 || opacity <= 0) return;
    final bright = removing ? _brightRose : _brightGold;
    final mid = removing ? _midRose : _midGold;
    final dark = removing ? _darkRose : _darkGold;
    final edgeBack = _points(72, -15);
    final edgeFront = _points(72, 9);
    final bevelFront = _points(63, 22);
    final back = edgeBack
        .map((p) => _project(p, center, rx, ry, rz, scale))
        .toList();
    final rim = edgeFront
        .map((p) => _project(p, center, rx, ry, rz, scale))
        .toList();
    final face = bevelFront
        .map((p) => _project(p, center, rx, ry, rz, scale))
        .toList();
    final middle = _project(
      const _StarPoint3(0, 0, 24),
      center,
      rx,
      ry,
      rz,
      scale,
    );

    // A sombra acompanha o volume (e não um ícone achatado).
    canvas.drawPath(
      _poly(back),
      Paint()
        ..color = dark.withValues(alpha: opacity * 0.38)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );
    canvas.drawPath(
      _poly(back),
      Paint()..color = dark.withValues(alpha: opacity),
    );

    // Faces laterais: luz incidente variável por direção da superfície.
    final sides = <({double depth, Path path, Color color})>[];
    for (var i = 0; i < 10; i++) {
      final j = (i + 1) % 10;
      final midAngle = -math.pi / 2 + math.pi * (i + 0.5) / 5;
      final lightValue = _clamp01(
        0.32 +
            0.35 * math.cos(midAngle - rz - 0.6) +
            0.22 * math.cos(ry + midAngle),
      );
      final points = [back[i], back[j], rim[j], rim[i]];
      final depth = math.sin(midAngle + ry) * math.cos(rx);
      sides.add((
        depth: depth,
        path: _poly(points),
        color: Color.lerp(dark, mid, lightValue)!.withValues(alpha: opacity),
      ));
    }
    sides.sort((a, b) => a.depth.compareTo(b.depth));
    for (final side in sides) {
      canvas.drawPath(side.path, Paint()..color = side.color);
    }

    // Bisel polido: cada uma das dez faixas tem um reflexo próprio.
    for (var i = 0; i < 10; i++) {
      final j = (i + 1) % 10;
      final glint = _clamp01(
        0.40 + 0.35 * math.sin(i * 1.35 + ry * 1.5 - rz + 1.1),
      );
      canvas.drawPath(
        _poly([rim[i], rim[j], face[j], face[i]]),
        Paint()
          ..color = Color.lerp(mid, bright, glint)!.withValues(alpha: opacity),
      );
    }

    // Triângulos centrais da frente, cada um com sombreamento diferente.
    for (var i = 0; i < 10; i++) {
      final j = (i + 1) % 10;
      final luminance = _clamp01(
        0.38 +
            0.25 * math.sin(i * 2.3 - ry + 0.5) +
            0.28 * math.cos(rx * 1.5 + i * 0.9),
      );
      final color = Color.lerp(mid, bright, luminance)!;
      canvas.drawPath(
        _poly([middle, face[i], face[j]]),
        Paint()..color = color.withValues(alpha: opacity),
      );
    }

    final outline = _poly(face);
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 1.3 * scale.clamp(0.35, 1.3).toDouble()
        ..color = bright.withValues(alpha: opacity * 0.92),
    );

    // Reflexo especular móvel: passa somente pelo recorte da face frontal.
    canvas.save();
    canvas.clipPath(outline);
    final scanX = center.dx - 150 * scale + 300 * scale * time;
    final scanRect = Rect.fromLTWH(
      scanX - 18 * scale,
      center.dy - 105 * scale,
      36 * scale,
      210 * scale,
    );
    canvas.drawRect(
      scanRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: opacity * 0.40),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(scanRect),
    );
    canvas.restore();
  }
}

/// Desenho do brilho, partículas de vários tamanhos, trilhas e geometria 3D.
/// Animação de curtida coreografada em cinco atos, ~1,85 s:
/// 1. antecipação luminosa, 2. giro da estrela com perspectiva,
/// 3. impacto elástico, 4. trilhas e poeira de estrelas,
/// 5. permanência curta e saída desacelerada.
///
/// O movimento NÃO é somente um ScaleTransition. Cada frame redesenha
/// a malha tridimensional e faz as partículas percorrerem curvas distintas.
class _StarPopPainter extends CustomPainter {
  final double t;
  final bool removing;
  const _StarPopPainter({required this.t, required this.removing});

  double _part(double start, double end) =>
      ((t - start) / (end - start)).clamp(0.0, 1.0).toDouble();

  double _smooth(double v) => v * v * (3 - 2 * v);
  double _out(double v) {
    final q = 1 - v;
    return 1 - q * q * q;
  }

  // Números pseudoaleatórios reproduzíveis: partículas NÃO mudam de caminho
  // entre os frames, mesmo quando a animação é reconstruída pelo Flutter.
  double _rand(int i, int salt) {
    final n = math.sin((i + 1) * 12.9898 + salt * 78.233) * 43758.5453;
    return n - n.floorToDouble();
  }

  Path _sparkle(Offset c, double r) => Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx + r * 0.13, c.dy - r * 0.13, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx + r * 0.13, c.dy + r * 0.13, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx - r * 0.13, c.dy + r * 0.13, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx - r * 0.13, c.dy - r * 0.13, c.dx, c.dy - r)
    ..close();

  void _aura(
    Canvas canvas,
    Offset c,
    Color gold,
    Color cream,
    double impact,
    double visibility,
  ) {
    if (visibility <= 0.001) return;
    const radius = 126.0;
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..shader = RadialGradient(
          stops: const [0.0, 0.28, 0.65, 1.0],
          colors: [
            cream.withValues(alpha: visibility * (0.12 + 0.13 * impact)),
            gold.withValues(alpha: visibility * (0.12 + 0.16 * impact)),
            gold.withValues(alpha: visibility * 0.045),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: radius)),
    );
  }

  void _drawTrails(
    Canvas canvas,
    Offset c,
    Color gold,
    Color pale,
    double visibility,
  ) {
    // Duas linhas curvas curtas passando por trás da estrela; elas se abrem
    // após o impacto e não permanecem como anéis decorativos no vídeo.
    for (var i = 0; i < 2; i++) {
      final progress = _smooth(_part(0.32 + 0.055 * i, 0.70 + 0.05 * i));
      final opacity = (1 - _smooth(_part(0.57 + i * 0.04, 0.79))) * visibility;
      if (progress <= 0 || opacity <= 0.005) continue;
      final radius = 49 + 75 * progress;
      final start = -1.90 + i * 1.62 + 0.40 * progress;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: radius),
        start,
        1.15,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.2 * (1 - progress * 0.55)
          ..color = (i == 0 ? pale : gold).withValues(alpha: opacity * 0.76),
      );
    }
  }

  void _drawParticles(Canvas canvas, Offset center, Color gold, Color pale) {
    // Primeira camada: estilhaços e poeira dourada, com profundidade simulada,
    // aceleração inicial, desaceleração e uma queda gravitacional quase sutil.
    for (var i = 0; i < 46; i++) {
      final delay = 0.36 + 0.085 * _rand(i, 1);
      final finish = 0.77 + 0.15 * _rand(i, 2);
      final u = _part(delay, finish);
      if (u <= 0 || u >= 1) continue;

      final easing = _out(u);
      final angle =
          i * 2.399963229728653 +
          (_rand(i, 3) - 0.5) * 0.6 +
          (removing ? -0.08 : 0.08);
      final perspective = 0.65 + _rand(i, 4) * 0.85;
      final travel = (54 + 95 * _rand(i, 5)) * easing * perspective;
      final swirl = (removing ? -1.0 : 1.0) * 0.35 * u * u;
      final moveAngle = angle + swirl;
      final gravity = 18 * u * u * perspective;
      final point =
          center +
          Offset(
            math.cos(moveAngle) * travel,
            math.sin(moveAngle) * travel * 0.78 + gravity,
          );

      final opacity =
          (_smooth((u / 0.18).clamp(0.0, 1.0).toDouble()) *
                  (1 - _smooth(((u - 0.52) / 0.48).clamp(0.0, 1.0).toDouble())))
              .clamp(0.0, 1.0)
              .toDouble();
      final radius = (0.85 + _rand(i, 6) * 1.75) * perspective;
      final color = i % 4 == 0 ? pale : gold;

      // Cauda orientada pelo vetor de velocidade, mais curta quando desacelera.
      final tail = (8 + 14 * _rand(i, 7)) * (1 - 0.55 * u) * perspective;
      final back =
          point -
          Offset(
            math.cos(moveAngle) * tail,
            math.sin(moveAngle) * tail * 0.78 + 1,
          );
      canvas.drawLine(
        back,
        point,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = radius * 0.72
          ..color = color.withValues(alpha: opacity * 0.62),
      );
      if (i % 7 == 0) {
        canvas.drawPath(
          _sparkle(point, radius * (1.5 + 0.35 * math.sin(u * math.pi))),
          Paint()..color = pale.withValues(alpha: opacity * 0.95),
        );
      } else {
        canvas.drawCircle(
          point,
          radius,
          Paint()..color = color.withValues(alpha: opacity),
        );
      }
    }

    // Segunda camada: partículas atrasadas mais delicadas, pequenas estrelas
    // que surgem quando a estrela principal já terminou seu giro.
    for (var i = 0; i < 14; i++) {
      final begin = 0.48 + 0.12 * _rand(i, 20);
      final u = _part(begin, 0.93);
      if (u <= 0 || u >= 1) continue;
      final angle = i * (2 * math.pi / 14) + 0.15;
      final travel = 55 + (42 + 26 * _rand(i, 21)) * _smooth(u);
      final pos =
          center +
          Offset(
            math.cos(angle) * travel,
            math.sin(angle) * travel * 0.83 + 13 * u * u,
          );
      final shine = math.sin(u * math.pi).clamp(0.0, 1.0).toDouble();
      canvas.drawPath(
        _sparkle(pos, 2.0 + 2.0 * _rand(i, 22)),
        Paint()..color = pale.withValues(alpha: shine * 0.65),
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final gold = removing ? const Color(0xFFEA7187) : const Color(0xFFFFCF66);
    final cream = removing ? const Color(0xFFFFE4E7) : const Color(0xFFFFF7DA);

    final arriving = _part(0.09, 0.41);
    final spin = _out(arriving);
    final impactProgress = _part(0.30, 0.49);
    final impact = math.sin(math.pi * impactProgress);
    final exiting = _smooth(_part(0.79, 1.0));
    final visibility = 1 - exiting;

    // A antecipação começa com um ponto e não com um círculo gigante.
    final glimmer = math.sin(math.pi * _part(0.0, 0.19));
    if (glimmer > 0) {
      canvas.drawPath(
        _sparkle(c, 4 + 8 * glimmer),
        Paint()..color = cream.withValues(alpha: glimmer * 0.70),
      );
    }

    // Luz atrás do objeto 3D. Cresce no impacto, reduz durante a permanência.
    final glow = _smooth(_part(0.12, 0.35)) * visibility;
    _aura(canvas, c, gold, cream, impact, glow);
    _drawTrails(canvas, c, gold, cream, glow);
    _drawParticles(canvas, c, gold, cream);

    // A escala tem dois tempos: aproximação e acomodação. O amortecimento
    // cria a batida elástica, sem o efeito genérico de "zoom e desaparece".
    final spring =
        0.14 * math.sin(math.pi * 2.55 * arriving) * math.exp(-2.7 * arriving);
    final scale = (0.07 + 0.93 * spin + spring) * (1 - exiting * 0.40);
    final exitTilt = exiting * (removing ? -0.62 : 0.46);
    final rx = -0.36 * (1 - spin) + 0.08 * math.sin(t * 5.2) + 0.28 * exiting;
    final ry = (removing ? 1 : -1) * 1.27 * (1 - spin) + exitTilt;
    final rz = (removing ? -1 : 1) * (0.58 * (1 - spin)) - 0.08 * spring;

    _PrismStarMesh.draw(
      canvas,
      center: c + Offset(0, 14 * (1 - spin) - 11 * impact + 15 * exiting),
      scale: scale,
      rx: rx,
      ry: ry,
      rz: rz,
      time: _smooth(_part(0.35, 0.77)),
      removing: removing,
      opacity: _smooth(_part(0.09, 0.20)) * visibility,
    );

    // Reflexos na frente, chegando DEPOIS da estrela, não todos de uma vez.
    for (var i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5) - 0.72;
      final begin = 0.43 + i * 0.045;
      final p = _part(begin, begin + 0.26);
      if (p <= 0 || p >= 1) continue;
      final alpha = math.sin(p * math.pi) * 0.80;
      final radius = 83 + 18 * _out(p) + (i % 2) * 9;
      final pos =
          c + Offset(math.cos(angle) * radius, math.sin(angle) * radius * 0.87);
      canvas.drawPath(
        _sparkle(pos, 3.2 + 2.4 * math.sin(p * math.pi)),
        Paint()..color = cream.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarPopPainter old) =>
      old.t != t || old.removing != removing;
}

/// Ícone discreto de estado curtido. A animação 3D fica no centro do vídeo;
/// na lateral aparece apenas esta estrelinha simples, e só após o duplo toque.
class _LikedStarBadge extends StatelessWidget {
  const _LikedStarBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 42,
      height: 38,
      child: Center(
        child: Icon(
          LucideIcons.star,
          size: 25,
          color: Color(0xFFFFD166),
          shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
        ),
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
        final sourceAspectRatio = value.aspectRatio > 0
            ? value.aspectRatio
            : 9 / 16;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Preenche toda a área do feed, sem a moldura fixa 9:16.
            // BoxFit.cover preserva a proporção e recorta apenas o excesso.
            ClipRect(
              child: SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: sourceAspectRatio * 1000,
                    height: 1000,
                    child: IgnorePointer(child: VideoPlayer(controller)),
                  ),
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
                      _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      size: 21,
                      color: Colors.white,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 6),
                      ],
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

  final SharedPreferences _prefs;
  final String _historyKey;
  late List<String> _history = _prefs.getStringList(_historyKey) ?? <String>[];

  final List<_VideoCard> _feedVideos;
  _LoopSearchDelegate(this._prefs, this._historyKey, this._feedVideos);

  void _remember(String value) {
    final term = value.trim();
    if (term.isEmpty || term.length > 120) return;
    _history.removeWhere((old) => old.toLowerCase() == term.toLowerCase());
    _history.insert(0, term);
    if (_history.length > 20) _history = _history.take(20).toList();
    unawaited(_prefs.setStringList(_historyKey, List<String>.from(_history)));
  }

  Widget _historyView(BuildContext context) => StatefulBuilder(
    builder: (context, refresh) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_history.isNotEmpty) Row(children: [
          Expanded(child: Text('Pesquisas recentes', style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w700,
            color: AppPalette.primaryText(context)))),
          if (_history.isNotEmpty) TextButton(onPressed: () {
            refresh(() => _history.clear());
            unawaited(_prefs.remove(_historyKey));
          }, child: const Text('Limpar tudo')),
        ]),
        if (_history.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppPalette.accent(context).withValues(alpha: .10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.search_rounded, size: 32,
                    color: AppPalette.accent(context)),
                ),
                const SizedBox(height: 20),
                Text('O que você procura?', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                    color: AppPalette.primaryText(context))),
                const SizedBox(height: 8),
                Text('Use a busca para encontrar o que deseja.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.5,
                    color: AppPalette.mutedText(context))),
              ],
            ),
          ),
        for (final term in _history)
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: Text(term, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () { query = term; showResults(context); },
            trailing: IconButton(tooltip: 'Remover pesquisa', icon: const Icon(Icons.close_rounded),
              onPressed: () {
                refresh(() => _history.remove(term));
                unawaited(_prefs.setStringList(_historyKey, List<String>.from(_history)));
              }),
          ),
      ],
    ),
  );

  Future<_SearchBundle> _search(String term) {
    if (_lastSearchQuery != term || _searchFuture == null) {
      _lastSearchQuery = term;
      _searchFuture = Future.wait(
        [ApiService.buscarObras(term), ApiService.buscarVideos(term)],
      ).then((results) => _SearchBundle(obras: results[0], videos: results[1]));
    }
    return _searchFuture!;
  }

  @override
  String get searchFieldLabel =>
      'Pesquisar no LupTok';

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
  Widget buildResults(BuildContext context) {
    _remember(query);
    return _buildMatches(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) => _buildMatches(context);

  Widget _buildMatches(BuildContext context) {
    final term = query.trim();
    if (term.isEmpty) return _historyView(context);

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
        if (snapshot.connectionState != ConnectionState.done || !snapshot.hasData) {
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
                    'Tente uma nova pesquisa.',
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
                        _remember(term);
                        query = titulo;
                        showResults(context);
                      },
                      child: Container(
                        width: 200,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppPalette.raisedSurface(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppPalette.border(
                              context,
                            ).withValues(alpha: 0.25),
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
                                    color: AppPalette.button(
                                      context,
                                    ).withValues(alpha: 0.15),
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
                onTap: (video) { _remember(term); _openSearchVideo(context, video, _feedVideos); },
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
            _SearchFrameThumbnail(key: ValueKey(video['id']), video: video),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black87,
                  ],
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

class _SearchFrameThumbnail extends StatefulWidget {
  final Map<String, dynamic> video;
  const _SearchFrameThumbnail({super.key, required this.video});
  @override
  State<_SearchFrameThumbnail> createState() => _SearchFrameThumbnailState();
}
class _SearchFrameThumbnailState extends State<_SearchFrameThumbnail> {
  VideoPlayerController? _controller;
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    VideoPlayerController? controller;
    try {
      final id = widget.video['id'];
      if (id == null) return;
      final token = await ApiService.tokenDaSessao();
      if (token == null || !mounted) return;
      final uri = Uri.parse(kIsWeb
          ? await ApiService.urlArquivoVideoWeb(id)
          : ApiService.urlArquivoVideo(id));
      if (!mounted) return;
      controller = VideoPlayerController.networkUrl(uri,
        httpHeaders: kIsWeb ? const {} : {'Authorization': 'Bearer $token'});
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      await controller.setVolume(0);
      final duration = controller.value.duration;
      final position = duration > const Duration(seconds: 1)
          ? const Duration(seconds: 1)
          : Duration.zero;
      if (!mounted) return;
      await controller.seekTo(position);
      if (!mounted) return;
      await controller.pause();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      // Se a mídia estiver indisponível, mantém a capa padrão.
    }
  }
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppPalette.button(context),
                AppPalette.raisedSurface(context),
                AppPalette.background(context),
              ],
            ),
          ),
        ),
        if (_ready && controller != null && controller.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
      ],
    );
  }
}

Future<void> _openSearchVideo(
  BuildContext context,
  Map<String, dynamic> video,
  List<_VideoCard> feedVideos,
) async {
  try {
    final id = video['id'];
    if (id == null) throw Exception('O vídeo não possui um identificador.');
    final token = await ApiService.tokenDaSessao();
    if (token == null) throw Exception('Sua sessão expirou. Entre novamente.');
    final prefs = await SharedPreferences.getInstance();
    final obraData = video['obra'];
    final obra = obraData is Map ? Map<String, dynamic>.from(obraData) : null;
    final tipo = (obra?['tipo'] ?? video['tipo_conteudo'] ?? '').toString();
    final generos = _apiStringList(obra?['generos']);
    final selected = _VideoCard(
      titulo: _searchVideoTitle(video),
      autor: (video['autor'] ?? '').toString(),
      apelido: (video['apelido'] ?? video['nome'])?.toString(),
      tipo: tipo,
      genero: generos.join(' · '),
      descricao: (video['descricao'] ?? '').toString(),
      spoiler: (video['spoiler'] ?? 'nenhum').toString(),
      stars: (video['curtidas'] as num?)?.toInt() ?? 0,
      comentarios: 0,
      cor: _kVideoBackdrop,
      likedByMe: video['curtida_usuario'] == true,
      obraId: obra?['id']?.toString(),
      obraTitulo: obra?['titulo']?.toString(),
      obraTipo: obra?['tipo']?.toString(),
      obraDescricao: obra?['descricao']?.toString(),
      obraGeneros: generos,
      obraPalavrasChave: _apiStringList(obra?['palavras_chave']),
      videoPath: ApiService.urlArquivoVideo(id),
      videoToken: token,
      videoId: id.toString(),
      ownerId: video['id_usuario']?.toString(),
      fotoUrl: video['foto_url']?.toString(),
      privacy: (video['privacidade'] ?? 'Público').toString(),
    );
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: _LoopTab(
          videos: [selected, ...feedVideos.where((v) => v.videoId != selected.videoId)],
          ocultarSpoilers: prefs.getBool('settings_hide_spoilers') ?? false,
          profileInterests: const [],
          currentUserId: prefs.getString('perfil_id'),
          singleVideo: true,
        ),
      )),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Não foi possível abrir o vídeo: ${error.toString().replaceFirst('Exception: ', '')}'),
    ));
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
  final bool singleVideo;
  const _LoopTab({
    required this.videos,
    required this.ocultarSpoilers,
    required this.profileInterests,
    required this.currentUserId,
    this.isVisible = true,
    this.singleVideo = false,
  });

  @override
  State<_LoopTab> createState() => _LoopTabState();
}

class _LoopTabState extends State<_LoopTab> {
  final PageController _pageCtrl = PageController();
  final Set<String> _saved = {};
  final Set<String> _following = {};
  final Map<String, String> _apelidosPorId = {};
  final Set<String> _apelidosConsultados = {};
  final Map<String, int> _reviewCounts = {};
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
    _saved.addAll(SavedVideoService.videos.value.map((v) => v['id'].toString()));
    followedUsernames.addListener(_syncFollowedUsers);
    SavedVideoService.videos.addListener(_syncSavedVideos);
    _carregarInteracoes();
    _carregarApelidos();
  }

  // Busca o nome público da conta quando o endpoint de vídeos retorna
  // apenas o username. O username continua sendo a chave para seguir.
  void _carregarApelidos() {
    for (final video in widget.videos) {
      final id = video.ownerId;
      if (id == null || id.isEmpty ||
          (video.apelido != null && video.apelido!.trim().isNotEmpty) ||
          !_apelidosConsultados.add(id)) continue;
      unawaited(_buscarApelido(id));
    }
  }

  Future<void> _buscarApelido(String id) async {
    try {
      final conta = await ApiService.obterConta(id);
      final nome = (conta['apelido'] ?? conta['nome'] ??
              conta['nome_exibicao'])?.toString().trim();
      if (mounted && nome != null && nome.isNotEmpty) {
        setState(() => _apelidosPorId[id] = nome);
      }
    } catch (_) {
      // Se a consulta falhar, mantém o identificador já disponível.
    }
  }

  @override
  void didUpdateWidget(covariant _LoopTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _carregarApelidos();
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
    SavedVideoService.videos.removeListener(_syncSavedVideos);
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
        ..addAll(SavedVideoService.videos.value.map((v) => v['id'].toString()));
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
            publicUserId: int.tryParse(id),
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
    });
    followedUsernames.value = Set<String>.from(_following);
    try { await SavedVideoService.load(); } catch (_) {}
  }

  Future<void> _toggleFollow(String user) async {
    setState(() {
      if (!_following.add(user)) _following.remove(user);
    });
    followedUsernames.value = Set<String>.from(_following);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('following_users', _following.toList());
  }

  Future<void> _toggleSaved(String? id) async {
    if (id == null) return;
    try {
      await SavedVideoService.toggle(id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
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
        _likeCounts[key] = (_likeCount(video, index) + delta)
            .clamp(0, 0x7fffffff)
            .toInt();
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
      _likeCounts[key] = (previousCount + (shouldLike ? 1 : -1))
          .clamp(0, 0x7fffffff)
          .toInt();
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
    _likeAnimationTimers[key] = Timer(const Duration(milliseconds: 1890), () {
      if (!mounted) return;
      setState(() => _likeAnimations.remove(key));
      _likeAnimationTimers.remove(key);
    });
  }

  // ── Ações ───────────────────────────────────────────────────────

  Future<void> _excluirVideo(_VideoCard video) async {
    final id = video.videoId;
    if (id == null || video.ownerId == null || video.ownerId != widget.currentUserId) return;
    final confirmar = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Excluir publicação?'),
      content: const Text('O vídeo e suas interações serão removidos permanentemente.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir', style: TextStyle(color: Colors.red)))],
    ));
    if (confirmar != true || !mounted) return;
    try {
      await ApiService.excluirVideo(id);
      unawaited(SavedVideoService.load().catchError((Object _) {}));
      if (!mounted) return;
      if (widget.singleVideo) { Navigator.of(context).pop(); return; }
      setState(() { _pageIndex = 0; });
      if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(0);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vídeo excluído.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

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
    final videoId = widget.videos[index].videoId;
    if (videoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vídeo ainda não sincronizado.')));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppPalette.raisedSurface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CommentsSheet(videoId: videoId, onChanged: (count) {
        if (mounted) setState(() => _reviewCounts[videoId] = count);
      }),
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
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final userId = prefs.getString('perfil_id');
    if (userId == null) return;
    await showSearch<void>(context: context,
      delegate: _LoopSearchDelegate(prefs, 'search_history_$userId', widget.videos));
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
    final feed = widget.singleVideo ? widget.videos.take(1).toList() : _mostrandoSeguindo
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
          if (widget.singleVideo)
            Positioned(top: 0, left: 0, child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Material(
                  color: Colors.black.withValues(alpha: .35),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Voltar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  ),
                ),
              ),
            ))
          else
            Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
        ],
      ),
    );
  }

  /// Barra superior FIXA fora do PageView (não acompanha a rolagem dos vídeos).
  Widget _buildTopBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.background(context),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.20), blurRadius: 14, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 8),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Image.asset(
              AppPalette.logo(context),
              width: 46,
              height: 46,
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
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      _feedTab(
                        'Loop',
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
              icon: Icon(
                Icons.search_rounded,
                color: AppPalette.primaryText(context),
                size: 25,
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
                ? const Color(0xFFB8787C).withValues(alpha: 0.20)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: AppPalette.primaryText(context),
              fontSize: 13.5,
              letterSpacing: 0.2,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
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
    final saved = _saved.contains(v.videoId);
    final active = widget.isVisible && i == _pageIndex &&
        (ModalRoute.of(context)?.isCurrent ?? true);

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
              muteTop: widget.singleVideo ? MediaQuery.paddingOf(context).top + 12 : 112,
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

          // Etiqueta de spoiler no topo, fora da área de descrição.
          Positioned(
            top: MediaQuery.paddingOf(context).top + (widget.singleVideo ? 68 : 77),
            left: 16,
            right: 74,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _spoilerBadge(v.spoiler),
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
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      _userPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 6. Coluna vertical de interação lateral (lado direito)
          Positioned(
            right: 10,
            bottom: 112,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21171C).withValues(alpha: .33),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: const Color(0xFFFFE9E9).withValues(alpha: .27)),
                  ),
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
                          padding: const EdgeInsets.only(bottom: 4),
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
                                      Shadow(
                                        color: Colors.black87,
                                        blurRadius: 7,
                                      ),
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
                  icon: LucideIcons.messageCircle,
                  label: _fmt(
                    _reviewCounts[v.videoId] ?? v.comentarios,
                  ),
                  onTap: () => _abrirComentarios(videoIndex),
                ),
                const SizedBox(height: 2),

                // Compartilhar
                _acao(
                  icon: LucideIcons.send,
                  onTap: () => _compartilhar(v),
                ),
                const SizedBox(height: 2),

                // Salvar publicação
                _acao(
                  icon: LucideIcons.bookmark,
                  iconColor: saved ? const Color(0xFFF4B8BF) : const Color(0xFFFFE9E9),
                  onTap: () => _toggleSaved(v.videoId),
                ),
                const SizedBox(height: 2),

                Container(width: 22, height: 1, color: const Color(0xFFFFE9E9).withValues(alpha: .24)),
                // Mais opções / Denunciar
                PopupMenuButton<String>(
                  tooltip: 'Mais ações',
                  color: AppPalette.raisedSurface(context),
                  onSelected: (action) {
                    if (action == 'report') _reportVideo(v);
                    if (action == 'delete') _excluirVideo(v);
                  },
                  itemBuilder: (context) => [
                    if (isOwner) const PopupMenuItem(value: 'delete', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Excluir vídeo'))),
                    if (!isOwner) const PopupMenuItem(
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
                      LucideIcons.moreHorizontal,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
                  ),
                ),
              ),
            ),
          ),

          // Autor e legenda próximos da base; a obra fica separada à direita.
          Positioned(
            left: 16,
            right: 80,
            bottom: 86,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
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
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                    ),
                  ),
                ],

              ],
            ),
          ),

          // Etiqueta pequena, no canto inferior direito (estilo áudio do TikTok).
          // É uma sobreposição: não muda a altura nem a proporção do vídeo.
          Positioned(
            right: 8,
            bottom: 24,
            child: _obraBadge(v),
          ),
        ],
      ),
    );
  }

  // ── Peças da interface do feed ──────────────────────────────────

  Widget _obraBadge(_VideoCard v) {
    return VideoWorkLabel(
      title: v.obraTitulo ?? (v.titulo.isNotEmpty ? v.titulo : 'Obra'),
      type: v.obraTipo ?? v.tipo,
    );
  }

  Widget _autorRow(_VideoCard v, bool isOwner) {
    final apelido = (v.apelido?.trim().isNotEmpty == true
            ? v.apelido!.trim()
            : _apelidosPorId[v.ownerId]?.trim()) ??
        v.autor.replaceFirst('@', '');
    final inicial = apelido.isEmpty ? '?' : apelido.substring(0, 1).toUpperCase();
    final following = _following.contains(v.autor);

    return Row(
      children: [
        GestureDetector(
          onTap: () => _abrirPerfilAutor(v),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF4B8BF).withValues(alpha: .85)),
            ),
            child: _luptokAvatar(v.fotoUrl, inicial, 18),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _abrirPerfilAutor(v),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(apelido, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFFFE9E9), fontSize: 16,
                    fontWeight: FontWeight.w700, letterSpacing: .2)),
                if (v.autor.trim().isNotEmpty)
                  Text('@${v.autor.replaceFirst('@', '')}', maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFEBD8DB), fontSize: 12)),
              ],
            ),
          ),
        ),
        if (!isOwner) ...[
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _toggleFollow(v.autor),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE9E9).withValues(alpha: following ? .19 : .08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF4B8BF).withValues(alpha: .65)),
                ),
                child: Text(following ? 'Seguindo' : '+ Seguir',
                  style: const TextStyle(color: Color(0xFFFFE9E9), fontSize: 11,
                    fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _spoilerBadge(String spoiler) {
    final hidden = widget.ocultarSpoilers && spoiler != 'nenhum';
    final isStrong = spoiler == 'muito';
    final isLight = spoiler == 'leve';
    final color = hidden
        ? const Color(0xFFFFE9E9)
        : isStrong
            ? const Color(0xFFFFC3CB)
            : isLight
                ? const Color(0xFFFFD9A0)
                : const Color(0xFFCAF0D5);
    final icon = hidden
        ? Icons.visibility_off_outlined
        : isStrong
            ? Icons.warning_amber_rounded
            : isLight
                ? Icons.auto_awesome_outlined
                : Icons.verified_outlined;
    return Container(
      constraints: const BoxConstraints(maxWidth: 245),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF21171C).withValues(alpha: .76),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .48)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .20), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Flexible(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_spoilerLabel(spoiler), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
            Text(hidden ? 'Conteúdo protegido' : isStrong ? 'Revela partes importantes' : isLight ? 'Pode revelar alguns detalhes' : 'Assista sem preocupação',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        )),
      ]),
    );
  }

  Widget _botaoRedondo(Widget child) {
    return SizedBox(width: 48, height: 44, child: Center(child: child));
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
                    color: iconColor ?? const Color(0xFFFFE9E9),
                    size: 24,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 4),
                      Shadow(color: Colors.black45, blurRadius: 3),
                    ],
                  )
                : Image.asset(
                    imageAsset,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        Icon(icon, color: iconColor ?? const Color(0xFFFFE9E9), size: 24),
                  ),
          ),
          if (label != null) ...[
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
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
  final String videoId;
  final ValueChanged<int> onChanged;
  const _CommentsSheet({required this.videoId, required this.onChanged});
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _reviews = [];
  int _nota = 0;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _myId;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reviews = await ReviewService.listar(widget.videoId);
      if (!mounted) return;
      setState(() { _reviews = reviews; _myId = prefs.getString('perfil_id'); _loading = false; _error = null; });
      widget.onChanged(reviews.length);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _send() async {
    final texto = _controller.text.trim();
    if (_sending || texto.isEmpty || _nota == 0) return;
    setState(() => _sending = true);
    try {
      await ReviewService.enviar(widget.videoId, texto, _nota);
      _controller.clear();
      if (!mounted) return;
      setState(() => _nota = 0);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _delete(Object id) async {
    try { await ReviewService.excluir(widget.videoId, id); await _load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  @override
  Widget build(BuildContext context) {
    final foreground = AppPalette.text(context);
    return SafeArea(child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppPalette.border(context), borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 14),
          Text('Comentários', style: TextStyle(color: foreground, fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) :
            _error != null ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, style: TextStyle(color: foreground), textAlign: TextAlign.center), TextButton(onPressed: () { setState(() => _loading = true); _load(); }, child: const Text('Tentar novamente'))])) :
            _reviews.isEmpty ? Center(child: Text('Seja a primeira pessoa a avaliar.', style: TextStyle(color: foreground))) :
            ListView.builder(itemCount: _reviews.length, itemBuilder: (context, i) {
              final review = _reviews[i];
              final nota = (review['nota'] as num).toInt();
              final own = _myId != null && review['id_usuario'].toString() == _myId;
              return ListTile(contentPadding: EdgeInsets.zero,
                leading: _luptokAvatar(review['foto_url']?.toString(), (review['nome_usuario']?.toString().trim().isNotEmpty == true ? review['nome_usuario'].toString().trim()[0] : 'U').toUpperCase(), 20),
                title: Row(children: [Expanded(child: Text('@${review['nome_usuario']}', style: TextStyle(color: foreground, fontWeight: FontWeight.w600))), if (own) IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Excluir avaliação', onPressed: () => _delete(review['id']))]),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: List.generate(5, (s) => Icon(s < nota ? Icons.star_rounded : Icons.star_border_rounded, size: 18, color: _kStarGold))),
                  const SizedBox(height: 4),
                  Text(review['texto']?.toString() ?? '', style: TextStyle(color: AppPalette.mutedText(context))),
                ]),
              );
            })),
          const SizedBox(height: 8),
          Text('Sua nota', style: TextStyle(color: foreground, fontWeight: FontWeight.w600)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(
            onPressed: _sending ? null : () => setState(() => _nota = i + 1),
            icon: Icon(i < _nota ? Icons.star_rounded : Icons.star_border_rounded, color: _kStarGold, size: 30),
          ))),
          Row(children: [Expanded(child: TextField(controller: _controller, maxLength: 2000, minLines: 1, maxLines: 3,
            style: TextStyle(color: foreground), decoration: InputDecoration(hintText: 'Sua opinião sobre a obra...', filled: true, fillColor: AppPalette.surface(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
            const SizedBox(width: 6),
            IconButton.filled(onPressed: _sending || _nota == 0 ? null : _send, icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded)),
          ]),
        ]),
      ),
    ));
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
                'Oi! Sou a **Lupez** \nComo posso te ajudar hoje? ',
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
