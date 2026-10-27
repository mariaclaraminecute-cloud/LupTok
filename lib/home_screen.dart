import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'app_preferences.dart';
import 'groups_screen.dart' show GroupsScreen;
import 'interest_utils.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'video_recorder_screen.dart';
import 'api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _LikeBurst extends StatelessWidget {
  const _LikeBurst({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) {
        final scale = Curves.easeOutBack.transform(progress);
        final opacity = (1 - Curves.easeIn.transform(progress)).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: 0.55 + scale * 0.55,
            child: SizedBox(
              width: 148,
              height: 148,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 112 + progress * 24,
                    height: 112 + progress * 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: 0.38 * (1 - progress),
                        ),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFFFD166,
                          ).withValues(alpha: 0.28 * (1 - progress)),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFD166),
                    size: 96,
                    shadows: [
                      Shadow(
                        color: Colors.black38,
                        blurRadius: 18,
                        offset: Offset(0, 5),
                      ),
                      Shadow(color: Color(0x99FFD166), blurRadius: 28),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _tabAtual = 0;

  bool _mostrarBemVindo = true;
  bool _mostrarHumor = false;
  bool _ocultarSpoilers = false;
  List<String> _gostosPerfil = [];
  String? _humorSelecionado;
  String? _idUsuarioAtual;

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
      setState(() {
        _mostrarBemVindo = false;
        _mostrarHumor = false;
      });
    });
  }

  @override
  void dispose() {
    _bemVindoCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
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
    setState(() {
      _idUsuarioAtual ??= publicado.ownerId;
      _videos.insert(
        0,
        _VideoCard(
          titulo: publicado.description.isEmpty
              ? 'Meu vídeo'
              : 'Minha recomendação',
          autor: nomeUsuario,
          tipo: publicado.contentType,
          genero: 'Vídeo de ${publicado.contentType.toLowerCase()}',
          descricao: publicado.description.isEmpty
              ? 'Confira minha recomendação de ${publicado.contentType.toLowerCase()}.'
              : publicado.description,
          spoiler: publicado.spoiler,
          obraId: publicado.workId,
          obraTitulo: publicado.workTitle,
          obraTipo: publicado.workType,
          obraDescricao: publicado.workDescription,
          obraGeneros: publicado.workGenres,
          obraPalavrasChave: publicado.workKeywords,
          stars: 0,
          comentarios: 0,
          cor: const Color(0xFF191416),
          videoPath: publicado.videoPath,
          videoToken: publicado.videoToken,
          videoId: publicado.videoId,
          ownerId: publicado.ownerId,
          privacy: publicado.privacy,
        ),
      );
    });
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
        return _VideoCard(
          titulo:
              obra?['titulo'] as String? ??
              (descricao.isEmpty ? 'Vídeo publicado' : 'Minha recomendação'),
          autor: autor,
          tipo: obra?['tipo'] as String? ?? tipo,
          genero: generos.isEmpty
              ? 'Vídeo de ${tipo.toLowerCase()}'
              : generos.join(' · '),
          descricao: descricao,
          spoiler: spoiler,
          obraId: obra?['id']?.toString(),
          obraTitulo: obra?['titulo'] as String?,
          obraTipo: obra?['tipo'] as String?,
          obraDescricao: obra?['descricao'] as String?,
          obraGeneros: generos,
          obraPalavrasChave: palavrasChave,
          stars: curtidas is num ? curtidas.toInt() : 0,
          comentarios: 0,
          cor: const Color(0xFF191416),
          likedByMe: curtidaUsuario,
          videoPath: ApiService.urlArquivoVideo(id),
          videoToken: token,
          videoId: id.toString(),
          ownerId: ownerId.toString(),
          privacy: privacidade,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _videos.removeWhere((video) => video.videoToken != null);
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
                    ),
                    const GroupsScreen(),
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
              if (!_mostrarBemVindo && !_mostrarHumor && _tabAtual != 3)
                _buildBottomNav(),
            ],
          ),

          if (_mostrarBemVindo) _buildBemVindoOverlay(),

          if (_mostrarHumor) _buildHumorOverlay(),
        ],
      ),
    );
  }

  ProfileVideo _toProfileVideo(_VideoCard video) => ProfileVideo(
    title: video.titulo,
    videoPath: video.videoPath,
    videoToken: video.videoToken,
    videoId: video.videoId,
    privacy: video.privacy,
    contentType: video.tipo,
  );

  Widget _buildBemVindoOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppPalette.isDark(context)
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
                            color: const Color(0xFFBB7575).withOpacity(v),
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
                    "Bem-vindo!",
                    style: TextStyle(
                      color: AppPalette.isDark(context)
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
                      color: AppPalette.isDark(context)
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
                      "Seu universo de entretenimento começa aqui",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppPalette.isDark(context)
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

  Widget _buildHumorOverlay() {
    final humores = [
      ("😊", "Feliz", const Color(0xFFFFD700)),
      ("😢", "Triste", const Color(0xFF4A90D9)),
      ("😤", "Ansioso", const Color(0xFFFF6B35)),
      ("😴", "Sonolento", const Color(0xFF9B59B6)),
      ("🔥", "Animado", const Color(0xFFB8787C)),
      ("🤔", "Pensativo", const Color(0xFF95A5A6)),
      ("💕", "Romântico", const Color(0xFFBB7575)),
      ("😱", "Suspense", const Color(0xFF2C3E50)),
    ];

    return GestureDetector(
      onTap: () => setState(() => _mostrarHumor = false),
      child: Container(
        color: AppPalette.background(context).withValues(alpha: 0.94),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppPalette.surface(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color.fromARGB(
                    255,
                    221,
                    155,
                    159,
                  ).withOpacity(0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB8787C).withOpacity(0.1),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                  BoxShadow(
                    color: const Color(0xFFBB7575).withOpacity(0.18),
                    blurRadius: 40,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFBB7575), Color(0xFFD59EA1)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFBB7575).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mood_rounded,
                      color: Color(0xFFFFE9E9),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    "Como você está se sentindo?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFBB7575),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Vamos personalizar suas recomendações",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppPalette.mutedText(context),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: humores.length,
                    itemBuilder: (context, index) {
                      final (emoji, nome, cor) = humores[index];
                      final sel = _humorSelecionado == nome;
                      return GestureDetector(
                        onTap: () => setState(() => _humorSelecionado = nome),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            gradient: sel
                                ? LinearGradient(
                                    colors: [
                                      cor.withOpacity(0.3),
                                      cor.withOpacity(0.1),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: sel
                                ? null
                                : AppPalette.raisedSurface(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: sel
                                  ? cor.withOpacity(0.6)
                                  : AppPalette.border(context),
                              width: sel ? 2 : 1,
                            ),
                            boxShadow: sel
                                ? [
                                    BoxShadow(
                                      color: cor.withOpacity(0.2),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(
                                nome,
                                style: TextStyle(
                                  color: sel
                                      ? Colors.white
                                      : AppPalette.primaryText(context),
                                  fontSize: 14,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Botão confirmar
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.button(context),
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => setState(() => _mostrarHumor = false),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppPalette.button(context),
                              AppPalette.darkButton,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFB8787C).withOpacity(0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _humorSelecionado != null
                                ? "Continuar  ✨"
                                : "Pular por hoje",
                            style: const TextStyle(
                              color: Color(0xFFFFE9E9),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
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
                          errorBuilder: (_, __, ___) => const Icon(
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
                  errorBuilder: (_, __, ___) => Icon(
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
                child: const Text(
                  'A',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
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

class _LoopSearchDelegate extends SearchDelegate<void> {
  String? _lastSearchQuery;
  Future<List<Map<String, dynamic>>>? _searchFuture;

  _LoopSearchDelegate();

  Future<List<Map<String, dynamic>>> _search(String term) {
    if (_lastSearchQuery != term || _searchFuture == null) {
      _lastSearchQuery = term;
      _searchFuture = ApiService.buscarVideos(term);
    }
    return _searchFuture!;
  }

  @override
  String get searchFieldLabel => 'Buscar vídeos no Loop';

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
    scaffoldBackgroundColor: AppPalette.background(context),
    appBarTheme: AppBarTheme(
      backgroundColor: AppPalette.background(context),
      foregroundColor: AppPalette.primaryText(context),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(color: AppPalette.mutedText(context)),
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
          child: Text(
            'Busque por título, gênero ou tema. Ex.: “dorama colegial”.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.mutedText(context)),
          ),
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
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
        final videos = snapshot.data!;
        if (videos.isEmpty) {
          return const Center(child: Text('Nenhum resultado encontrado.'));
        }

        return _VideoSearchGrid(
          videos: videos,
          onTap: (video) => _openSearchVideo(context, video),
        );
      },
    );
  }
}

List<String> _apiStringList(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

String _searchVideoTitle(Map<String, dynamic> video) {
  final obra = video['obra'];
  final tituloObra = obra is Map ? obra['titulo'] : null;
  final descricao = video['descricao'];
  if (tituloObra is String && tituloObra.isNotEmpty) return tituloObra;
  if (descricao is String && descricao.isNotEmpty) return descricao;
  return 'Vídeo publicado';
}

String _searchVideoAsset(Map<String, dynamic> video) {
  final obra = video['obra'];
  final tipo = obra is Map ? obra['tipo'] : video['tipo_conteudo'];
  return switch (tipo?.toString().toLowerCase()) {
    'série' || 'serie' => 'assets/images/serie.png',
    'livro' => 'assets/images/livro.png',
    'anime' => 'assets/images/anime.png',
    'dorama' || 'k-drama' => 'assets/images/dorama.png',
    _ => 'assets/images/filme.png',
  };
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
      borderRadius: BorderRadius.circular(12),
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
            Image.asset(
              _searchVideoAsset(video),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: AppPalette.button(context),
                child: const Center(
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
                  colors: [Colors.black12, Colors.transparent, Colors.black87],
                  stops: [0, 0.35, 1],
                ),
              ),
            ),
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 44,
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
                      shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
                    ),
                  ),
                  if (description.isNotEmpty) ...[
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

class _FeedVideo extends StatefulWidget {
  final String path;
  final String? token;
  final String? videoId;

  const _FeedVideo({required this.path, this.token, this.videoId});

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
    await controller.play();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleMute() async {
    final muted = !_muted;
    await _controller!.setVolume(muted ? 0 : 1);
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
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 1000 * displayAspectRatio,
                  height: 1000,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            Positioned(
              top: 70,
              right: 12,
              child: Material(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(10),
                child: IconButton(
                  tooltip: _muted ? 'Ativar som' : 'Silenciar vídeo',
                  onPressed: _toggleMute,
                  color: Colors.white,
                  icon: Icon(
                    _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
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

class _SearchVideoPlayerScreen extends StatelessWidget {
  final Map<String, dynamic> video;
  final Object id;
  final String token;

  const _SearchVideoPlayerScreen({
    required this.video,
    required this.id,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    final title = _searchVideoTitle(video);
    final description = video['descricao'] as String? ?? '';
    final author = video['autor'] as String? ?? '';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Denunciar vídeo',
            onPressed: () => _promptReportVideo(context, id),
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _FeedVideo(
              path: ApiService.urlArquivoVideo(id),
              token: token,
              videoId: id.toString(),
            ),
          ),
          if (description.isNotEmpty || author.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              color: const Color(0xFF191416),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (author.isNotEmpty)
                    Text(
                      author,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (description.isNotEmpty) ...[
                    if (author.isNotEmpty) const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TAB: LOOP
// ══════════════════════════════════════════════════════════════════

class _LoopTab extends StatefulWidget {
  final List<_VideoCard> videos;
  final bool ocultarSpoilers;
  final List<String> profileInterests;
  final String? currentUserId;
  const _LoopTab({
    required this.videos,
    required this.ocultarSpoilers,
    required this.profileInterests,
    required this.currentUserId,
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
  final Set<String> _likeAnimations = {};
  final Map<String, int> _likeAnimationVersions = {};
  final Map<String, Timer> _likeAnimationTimers = {};
  bool _mostrandoSeguindo = false;

  @override
  void initState() {
    super.initState();
    _following.addAll(followedUsernames.value);
    _saved.addAll(savedVideoIndices.value);
    followedUsernames.addListener(_syncFollowedUsers);
    savedVideoIndices.addListener(_syncSavedVideos);
    _carregarInteracoes();
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
      final works = account['obras'] as List<Map<String, dynamic>>;
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

  String _likeKey(_VideoCard video, int index) =>
      video.videoId ?? 'local:$index';

  bool _isLiked(_VideoCard video, int index) =>
      _likeStates[_likeKey(video, index)] ?? video.likedByMe;

  int _likeCount(_VideoCard video, int index) =>
      _likeCounts[_likeKey(video, index)] ?? video.stars;

  Future<void> _toggleLike(_VideoCard video, int index) async {
    await _setLike(video, index, !_isLiked(video, index));
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
      );
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
      final isOwner =
          video.ownerId != null && video.ownerId == widget.currentUserId;
      if (state is! bool || (isOwner && count is! num)) {
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
  }

  void _animateLike(String key) {
    _likeAnimationTimers.remove(key)?.cancel();
    setState(() {
      _likeAnimations.add(key);
      _likeAnimationVersions.update(
        key,
        (version) => version + 1,
        ifAbsent: () => 1,
      );
    });
    _likeAnimationTimers[key] = Timer(const Duration(milliseconds: 850), () {
      if (!mounted) return;
      setState(() => _likeAnimations.remove(key));
      _likeAnimationTimers.remove(key);
    });
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
    final comentarios = _comentarios.putIfAbsent(index, () => []);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF7F7),
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
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Luptok: ${video.titulo}',
        text:
            '${video.titulo} - ${video.tipo} de ${video.genero}. '
            'Recomendado por @anna.beatriz no Luptok.',
      ),
    );
  }

  Future<void> _pesquisar() async {
    setState(() => _mostrandoSeguindo = false);
    await showSearch<void>(context: context, delegate: _LoopSearchDelegate());
  }

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

  String _tipoImagem(String tipo) {
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

  Color _spoilerColor(String s) {
    if (widget.ocultarSpoilers && s != 'nenhum') {
      return Colors.white70;
    }
    switch (s) {
      case 'leve':
        return const Color(0xFFFFA726);
      case 'muito':
        return const Color(0xFFBB7575);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  String _tipoEmoji(String t) {
    switch (t) {
      case 'Filme':
        return '🎬';
      case 'Série':
        return '📺';
      case 'Livro':
        return '📖';
      case 'Anime':
        return '🎌';
      case 'K-Drama':
        return '🇰🇷';
      default:
        return '🎬';
    }
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  @override
  void dispose() {
    followedUsernames.removeListener(_syncFollowedUsers);
    savedVideoIndices.removeListener(_syncSavedVideos);
    for (final timer in _likeAnimationTimers.values) {
      timer.cancel();
    }
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final publicVideos = widget.videos
        .where((video) => video.privacy == 'Público')
        .toList();
    final feed = _mostrandoSeguindo
        ? publicVideos
              .where((video) => _following.contains(video.autor))
              .toList()
        : publicVideos;
    if (feed.isEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: AppPalette.isDark(context)
                ? AppPalette.darkBackground
                : const Color(0xFF191416),
          ),
          _buildTopBar(),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.people_outline_rounded,
                    color: Colors.white70,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Seu feed Seguindo começa aqui',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Siga criadores no Loop para ver as publicações deles nesta aba.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => setState(() => _mostrandoSeguindo = false),
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text('Ver Looping'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return PageView.builder(
      controller: _pageCtrl,
      scrollDirection: Axis.vertical,
      itemCount: feed.length,
      itemBuilder: (context, i) {
        final v = feed[i];
        final videoIndex = widget.videos.indexOf(v);
        final likeKey = _likeKey(v, videoIndex);
        final starrado = _isLiked(v, videoIndex);
        final curtidas = _likeCount(v, videoIndex);
        final isVideoOwner =
            v.ownerId != null && v.ownerId == widget.currentUserId;
        final salvo = _saved.contains(videoIndex);
        final corAnel = switch (v.spoiler) {
          'muito' => const Color(0xFFD9273E),
          'leve' => const Color(0xFFFFC247),
          _ => const Color(0xFF4CAF68),
        };
        return GestureDetector(
          onDoubleTap: () {
            _animateLike(likeKey);
            unawaited(_setLike(v, videoIndex, true));
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Fundo
              if (v.videoPath == null)
                Container(
                  color: AppPalette.isDark(context)
                      ? AppPalette.darkBackground
                      : v.cor,
                )
              else
                _FeedVideo(
                  path: v.videoPath!,
                  token: v.videoToken,
                  videoId: v.videoId,
                ),
              if (_likeAnimations.contains(likeKey))
                Center(
                  child: IgnorePointer(
                    child: _LikeBurst(
                      key: ValueKey(_likeAnimationVersions[likeKey]),
                    ),
                  ),
                ),
              Center(
                child: Opacity(
                  opacity: 0.06,
                  child: Text(
                    _tipoEmoji(v.tipo),
                    style: const TextStyle(fontSize: 220),
                  ),
                ),
              ),
              // Info inferior esquerdo
              Positioned(
                left: 16,
                right: 72,
                bottom: 70,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _badge(
                      _spoilerLabel(v.spoiler),
                      _spoilerColor(v.spoiler).withOpacity(0.16),
                      _spoilerColor(v.spoiler),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      v.titulo,
                      style: TextStyle(
                        color: AppPalette.isDark(context)
                            ? Colors.white
                            : const Color(0xFFBB7575),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      v.descricao,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppPalette.isDark(context)
                            ? Colors.white
                            : const Color(0xFFFFE9E9),
                        fontSize: 14,
                        height: 1.35,
                        shadows: const [
                          Shadow(color: Colors.black87, blurRadius: 6),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 128,
                left: 14,
                right: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _abrirPerfilAutor(v),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(2.5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: corAnel,
                                            width: 2.5,
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 18,
                                          backgroundColor: AppPalette.accent(
                                            context,
                                          ),
                                          child: Text(
                                            v.autor
                                                .replaceFirst('@', '')
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          v.autor,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black87,
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _toggleFollow(v.autor),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: AppPalette.button(
                                context,
                              ).withValues(alpha: 0.72),
                              minimumSize: const Size(0, 30),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.48),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: Icon(
                              _following.contains(v.autor)
                                  ? Icons.check_rounded
                                  : Icons.person_add_alt_1_rounded,
                              size: 14,
                            ),
                            label: Text(
                              _following.contains(v.autor)
                                  ? 'Seguindo'
                                  : 'Seguir',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 104),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.isDark(context)
                            ? AppPalette.darkBackground.withValues(alpha: 0.92)
                            : Colors.black.withOpacity(0.38),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            _tipoImagem(v.tipo),
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.movie_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              v.tipo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Ações laterais
              Positioned(
                right: 12,
                top: MediaQuery.sizeOf(context).height * 0.37,
                child: Column(
                  children: [
                    _starAction(
                      selected: starrado,
                      count: isVideoOwner ? _fmt(curtidas) : null,
                      onTap: () => _toggleLike(v, videoIndex),
                    ),
                    const SizedBox(height: 20),
                    _acao(
                      icon: Icons.chat_bubble_outline_rounded,
                      imageAsset: 'assets/images/balao.png',
                      label: _fmt(
                        v.comentarios + (_comentarios[videoIndex]?.length ?? 0),
                      ),
                      cor: Colors.white,
                      onTap: () => _abrirComentarios(videoIndex),
                    ),
                    const SizedBox(height: 20),
                    _acao(
                      icon: Icons.share_outlined,
                      label: null,
                      cor: Colors.white,
                      onTap: () => _compartilhar(v),
                    ),
                    const SizedBox(height: 20),
                    _acao(
                      icon: salvo
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: null,
                      cor: Colors.white,
                      onTap: () => _toggleSaved(videoIndex),
                    ),
                    const SizedBox(height: 16),
                    PopupMenuButton<String>(
                      tooltip: 'Mais ações',
                      iconColor: Colors.white,
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
                    ),
                  ],
                ),
              ),
              _buildTopBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: AppPalette.background(context),
        padding: const EdgeInsets.fromLTRB(12, 4, 10, 8),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Image.asset(
                AppPalette.logo(context),
                width: 38,
                height: 38,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: AppPalette.button(context).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _feedTab(
                        'Looping',
                        active: !_mostrandoSeguindo,
                        onTap: () => setState(() => _mostrandoSeguindo = false),
                      ),
                      _feedTab(
                        'Seguindo',
                        active: _mostrandoSeguindo,
                        onTap: () => setState(() => _mostrandoSeguindo = true),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Pesquisar',
                onPressed: _pesquisar,
                icon: Icon(
                  Icons.search_rounded,
                  color: AppPalette.primaryText(context),
                ),
              ),
            ],
          ),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppPalette.button(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : AppPalette.primaryText(context),
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _acao({
    required IconData icon,
    required String? label,
    required Color cor,
    required VoidCallback onTap,
    String? imageAsset,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          if (imageAsset == null)
            Icon(
              icon,
              color: cor,
              size: 32,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
            )
          else
            Image.asset(imageAsset, width: 32, height: 32, fit: BoxFit.contain),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: cor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _starAction({
    required bool selected,
    required String? count,
    required VoidCallback onTap,
  }) {
    const gold = Color(0xFFFFD166);
    return Semantics(
      button: true,
      label: selected ? 'Remover estrela' : 'Dar estrela',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFE7A8), gold, Color(0xFFE99A34)],
                      )
                    : null,
                color: selected ? null : Colors.black.withValues(alpha: 0.28),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFFFF2CB)
                      : Colors.white.withValues(alpha: 0.72),
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? gold.withValues(alpha: 0.52)
                        : Colors.black.withValues(alpha: 0.28),
                    blurRadius: selected ? 18 : 8,
                    spreadRadius: selected ? 1 : 0,
                  ),
                ],
              ),
              child: Icon(
                selected ? Icons.star_rounded : Icons.star_border_rounded,
                size: 31,
                color: selected ? const Color(0xFF542F00) : Colors.white,
                shadows: selected
                    ? const [Shadow(color: Color(0x88FFFFFF), blurRadius: 5)]
                    : const [Shadow(color: Colors.black54, blurRadius: 6)],
              ),
            ),
            if (count != null) ...[
              const SizedBox(height: 5),
              Text(
                count,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

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
                    color: const Color(0xFFBB7575).withOpacity(0.35),
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
                    ? const Center(
                        child: Text('Seja a primeira pessoa a comentar.'),
                      )
                    : ListView.builder(
                        itemCount: widget.comentarios.length,
                        itemBuilder: (context, index) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppPalette.surface(context),
                            child: Text(
                              'A',
                              style: TextStyle(
                                color: AppPalette.primaryText(context),
                              ),
                            ),
                          ),
                          title: const Text('@anna.beatriz'),
                          subtitle: Text(widget.comentarios[index]),
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
                        fillColor: AppPalette.isDark(context)
                            ? const Color(0xFF55232A)
                            : const Color(0xFFFFF0F1),
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
// LUPEZ OVERLAY (chat dentro do home)
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

  late AnimationController _dotCtrl;

  final _sugestoes = [
    "Me recomenda um suspense 🔍",
    "Quero chorar muito 😢",
    "Anime pra iniciante?",
    "K-drama curto ❤️",
    "Ficção científica épica 🚀",
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
                "Oi! Sou a **Lupez** 🎬✨\nComo posso te ajudar hoje? Posso recomendar filmes, séries, livros, animes e K-dramas!",
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
    setState(() {
      _msgs.add(_Mensagem(texto: msg, deLupez: false));
      _inputCtrl.clear();
      _digitando = true;
    });
    _rolar();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final resposta = _gerarResposta(msg);

      setState(() {
        _digitando = false;
        _msgs.add(_Mensagem(texto: resposta, deLupez: true));
      });
      _rolar();
    });
  }

  String _gerarResposta(String prompt) {
    final pergunta = normalizeInterest(prompt);
    final termos = <String>[];
    if (pergunta.contains('suspense') || pergunta.contains('thriller')) {
      termos.add('suspense');
    }
    if (pergunta.contains('anime')) termos.add('anime');
    if (pergunta.contains('livro') || pergunta.contains('leitura')) {
      termos.add('livro');
    }
    if (pergunta.contains('dorama') ||
        pergunta.contains('k-drama') ||
        pergunta.contains('coreano')) {
      termos.add('dorama');
    }
    if (pergunta.contains('romance') || pergunta.contains('romântico')) {
      termos.add('romance');
    }
    if (pergunta.contains('ficcao') || pergunta.contains('sci-fi')) {
      termos.add('ficcao');
    }
    if (pergunta.contains('terror')) termos.add('terror');
    if (pergunta.contains('fantasia')) termos.add('fantasia');
    if (pergunta.contains('triste') || pergunta.contains('chorar')) {
      termos.add('drama');
    }

    final tituloMencionado = widget.videos.where(
      (video) => pergunta.contains(video.titulo.toLowerCase()),
    );
    List<_VideoCard> resultados;
    if (tituloMencionado.isNotEmpty) {
      resultados = tituloMencionado.toList();
    } else if (termos.isNotEmpty) {
      resultados = widget.videos.where((video) {
        final dados = [
          video.titulo,
          video.genero,
          video.tipo,
        ].map(normalizeInterest).toList();
        return termos
            .map(normalizeInterest)
            .any((termo) => dados.any((campo) => campo.contains(termo)));
      }).toList();
    } else {
      final preferidos = widget.interests.map(normalizeInterest).toList();
      resultados = widget.videos.where((video) {
        final dados = [
          video.titulo,
          video.genero,
          video.tipo,
        ].map(normalizeInterest).toList();
        return preferidos.any(
          (interest) =>
              interest.isNotEmpty &&
              dados.any((campo) => campo.contains(interest)),
        );
      }).toList();
      if (resultados.isEmpty) resultados = widget.videos;
    }

    if (resultados.isEmpty) {
      return 'Não encontrei uma obra desse tipo no catálogo deste aparelho. Tente buscar por filme, série, livro ou por um gênero que aparece no Loop.';
    }

    final recomendacoes = resultados
        .take(2)
        .map((video) {
          final interesseEmComum = widget.interests.firstWhere(
            (interest) => [video.genero, video.tipo]
                .map(normalizeInterest)
                .any((campo) => campo.contains(normalizeInterest(interest))),
            orElse: () => '',
          );
          final contexto = interesseEmComum.isEmpty
              ? '${video.tipo} de ${video.genero}'
              : 'combina com seu gosto por $interesseEmComum';
          final aviso = video.spoiler == 'muito'
              ? ' Tem aviso de muito spoiler.'
              : video.spoiler == 'leve'
              ? ' Tem aviso de spoiler parcial.'
              : '';
          return '**${video.titulo}** ($contexto).$aviso';
        })
        .join('\n');

    return 'Separei do catálogo do LupTok:\n$recomendacoes\n\nQuer filtrar por outro gênero ou tipo?';
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
          : Colors.black.withOpacity(0.65),
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
                // Handle
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
                            "L",
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
                              "Lupez",
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
                                "IA de entretenimento",
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
                              hintText: "Pergunte à Lupez...",
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
                  "L",
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
                "L",
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
              builder: (_, __) => Row(
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

// ══════════════════════════════════════════════════════════════════
// TAB: EXPLORAR
// ══════════════════════════════════════════════════════════════════

class _ExplorarTab extends StatefulWidget {
  const _ExplorarTab();

  @override
  State<_ExplorarTab> createState() => _ExplorarTabState();
}

class _ExplorarTabState extends State<_ExplorarTab> {
  String _consulta = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String? _searchedQuery;
  Future<List<Map<String, dynamic>>>? _searchResults;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _searchFor(String value, {bool immediate = false}) {
    setState(() {
      _consulta = value;
      _searchedQuery = null;
      _searchResults = null;
    });
    _searchDebounce?.cancel();
    final term = value.trim();
    if (term.isEmpty) return;
    void startSearch() {
      if (!mounted || _consulta.trim() != term) return;
      setState(() {
        _searchedQuery = term;
        _searchResults = ApiService.buscarVideos(term);
      });
    }

    if (immediate) {
      startSearch();
    } else {
      _searchDebounce = Timer(const Duration(milliseconds: 300), startSearch);
    }
  }

  void _selectCategory(String category) {
    _searchController
      ..text = category
      ..selection = TextSelection.collapsed(offset: category.length);
    _searchFor(category, immediate: true);
  }

  Widget _buildSearchResults() {
    if (_searchedQuery != _consulta.trim() || _searchResults == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _searchResults,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Não foi possível pesquisar: '
              '${snapshot.error.toString().replaceFirst('Exception: ', '')}',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final videos = snapshot.data!;
        if (videos.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Nenhum vídeo encontrado. Tente outro título, gênero ou tema.',
            ),
          );
        }

        return _VideoSearchGrid(
          videos: videos,
          shrinkWrap: true,
          onTap: (video) => _openSearchVideo(context, video),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE9E9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Explorar",
                style: TextStyle(
                  color: Color(0xFFBB7575),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFBB7575).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFBB7575).withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: const Color(0xFFBB7575).withOpacity(0.65),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _searchFor,
                        onSubmitted: (value) =>
                            _searchFor(value, immediate: true),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Busque vídeos por obra, gênero ou tema...',
                          hintStyle: TextStyle(
                            color: const Color(0xFFBB7575).withOpacity(0.70),
                            fontSize: 15,
                          ),
                          isDense: true,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_consulta.isNotEmpty)
                      IconButton(
                        tooltip: 'Limpar busca',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          _searchController.clear();
                          _searchFor('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                ),
              ),
              if (_consulta.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Resultados',
                  style: const TextStyle(
                    color: Color(0xFF7D171D),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildSearchResults(),
              ],
              const SizedBox(height: 24),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFBB7575), Color(0xFF7D171D)],
                ).createShader(b),
                child: const Text(
                  "🎭  Por categoria",
                  style: TextStyle(
                    color: Color(0xFFBB7575),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    [
                      ("🎬", "Filmes"),
                      ("📺", "Séries"),
                      ("📖", "Livros"),
                      ("🎌", "Anime"),
                      ("🇰🇷", "K-Drama"),
                      ("❤️", "Romance"),
                      ("👻", "Terror"),
                      ("🔍", "Suspense"),
                      ("🚀", "Ficção Científica"),
                    ].map((c) {
                      final (emoji, nome) = c;
                      return InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: () => _selectCategory(switch (nome) {
                          'Filmes' => 'filme',
                          'Séries' => 'série',
                          'Livros' => 'livro',
                          'K-Drama' => 'dorama',
                          'Ficção Científica' => 'ficção científica',
                          _ => nome,
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBB7575).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: const Color(0xFFBB7575).withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 15)),
                              const SizedBox(width: 7),
                              Text(
                                nome,
                                style: const TextStyle(
                                  color: Color(0xFFBB7575),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TAB: PERFIL
// ══════════════════════════════════════════════════════════════════

class _PerfilTab extends StatefulWidget {
  final VoidCallback onAbrirConfiguracoes;

  const _PerfilTab({required this.onAbrirConfiguracoes});

  @override
  State<_PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<_PerfilTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _nomePerfil = '';
  String _usuarioPerfil = '';
  String _bioPerfil = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _editarPerfil() async {
    final nomeController = TextEditingController(text: _nomePerfil);
    final usuarioController = TextEditingController(
      text: _usuarioPerfil.replaceFirst('@', ''),
    );
    final bioController = TextEditingController(text: _bioPerfil);
    final formKey = GlobalKey<FormState>();

    final dados = await showModalBottomSheet<(String, String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF7F7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Editar perfil',
                    style: TextStyle(
                      color: Color(0xFF7D171D),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: nomeController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Informe seu nome.'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: usuarioController,
                    decoration: const InputDecoration(
                      labelText: 'Nome de usuário',
                      prefixText: '@',
                    ),
                    validator: (value) =>
                        value == null ||
                            value
                                .trim()
                                .replaceFirst(RegExp(r'^@+'), '')
                                .isEmpty
                        ? 'Informe seu nome de usuário.'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: bioController,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 160,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Bio'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        final usuario = usuarioController.text
                            .trim()
                            .replaceFirst(RegExp(r'^@+'), '');
                        Navigator.of(sheetContext).pop((
                          nomeController.text.trim(),
                          '@$usuario',
                          bioController.text.trim(),
                        ));
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Salvar alterações'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFBB7575),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    nomeController.dispose();
    usuarioController.dispose();
    bioController.dispose();
    if (dados == null || !mounted) return;

    setState(() {
      _nomePerfil = dados.$1;
      _usuarioPerfil = dados.$2;
      _bioPerfil = dados.$3;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE9E9),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildHeader()),
        ],
        body: Column(
          children: [
            Container(
              color: const Color(0xFFFFD6D8),
              child: TabBar(
                controller: _tabCtrl,
                labelColor: const Color(0xFFBB7575),
                unselectedLabelColor: const Color(0xFFB8787C),
                indicatorColor: const Color(0xFFB8787C),
                indicatorSize: TabBarIndicatorSize.label,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tabs: const [
                  Tab(text: "Vídeos"),
                  Tab(text: "Assistidos"),
                  Tab(text: "Reviews"),
                  Tab(text: "Salvos"),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _vazio("🎥", "Nenhum vídeo postado ainda"),
                  _vazio("✅", "Sua lista de assistidos aparece aqui"),
                  _vazio("⭐", "Suas reviews aparecem aqui"),
                  _vazio("🔒", "Só você pode ver seus salvos"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Capa
        SizedBox(
          height: 230,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 150,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFBB7575),
                        Color(0xFFBB7575),
                        Color(0xFFFFD6D8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        right: -30,
                        top: -30,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x08FFFFFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Foto de perfil
              Positioned(
                top: 108,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFFE9E9),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB8787C).withOpacity(0.3),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 40,
                      backgroundColor: Color(0xFFB8787C),
                      child: Text(
                        "A",
                        style: TextStyle(
                          color: Color(0xFFFFE9E9),
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Status
              Positioned(
                top: 198,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE9E9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFBB7575).withOpacity(0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Assistindo: Dark",
                          style: TextStyle(
                            color: Color(0xFFBB7575),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Botão editar
              Positioned(
                top: 48,
                right: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Configurações',
                      onPressed: widget.onAbrirConfiguracoes,
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xFFFFE9E9),
                        backgroundColor: const Color(0xFFBB7575),
                        fixedSize: const Size(38, 38),
                      ),
                      icon: const Icon(Icons.settings_outlined, size: 19),
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: _editarPerfil,
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Editar perfil'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFFE9E9),
                        backgroundColor: const Color(0xFFBB7575),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nomePerfil,
                        style: TextStyle(
                          color: Color(0xFF7D171D),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        _usuarioPerfil,
                        style: TextStyle(
                          color: Color(0xFF7D171D),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _bioPerfil,
                style: TextStyle(
                  color: const Color(0xFFBB7575).withOpacity(0.70),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              // Botão seguir
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {},
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFBB7575), Color(0xFFBB7575)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(
                            255,
                            207,
                            132,
                            136,
                          ).withOpacity(0.28),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "Seguir",
                        style: TextStyle(
                          color: Color(0xFFFFE9E9),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }

  Widget _vazio(String emoji, String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF7D171D).withOpacity(0.62),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
