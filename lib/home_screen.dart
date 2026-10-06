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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _tabAtual = 0;

  bool _mostrarBemVindo = true;
  bool _mostrarHumor = false;
  bool _ocultarSpoilers = false;
  List<String> _gostosPerfil = [];
  String? _humorSelecionado;

  late AnimationController _bemVindoCtrl;
  late Animation<double> _bemVindoOpacity;
  late Animation<double> _bemVindoScale;
  late Animation<double> _bemVindoSlide;

  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  final List<_VideoCard> _videos = [
    _VideoCard(
      titulo: "Interstellar",
      autor: '@gui.scifi',
      tipo: "Filme",
      genero: "Ficção Científica",
      descricao:
          "Uma jornada emocionante pelo espaço sobre amor, tempo e sobrevivência.",
      spoiler: "nenhum",
      stars: 2341,
      comentarios: 187,
      cor: const Color(0xFF0D1B2A),
    ),
    _VideoCard(
      titulo: "Attack on Titan",
      autor: '@marina.anime',
      tipo: "Anime",
      genero: "Ação",
      descricao:
          "Uma história intensa de coragem, escolhas difíceis e grandes batalhas.",
      spoiler: "leve",
      stars: 5820,
      comentarios: 932,
      cor: const Color(0xFF1A0A00),
    ),
    _VideoCard(
      titulo: "O Hobbit",
      autor: '@bia.leitora',
      tipo: "Livro",
      genero: "Fantasia",
      descricao:
          "Uma aventura fantástica que começa com uma jornada inesperada.",
      spoiler: "nenhum",
      stars: 1203,
      comentarios: 74,
      cor: const Color(0xFF0A1A0A),
    ),
    _VideoCard(
      titulo: "Dark",
      autor: '@gui.scifi',
      tipo: "Série",
      genero: "Suspense",
      descricao:
          "Mistério, suspense e viagens no tempo em uma pequena cidade alemã.",
      spoiler: "muito",
      stars: 3910,
      comentarios: 445,
      cor: const Color(0xFF0F0F1A),
    ),
    _VideoCard(
      titulo: "Crash Landing on You",
      autor: '@julia.dorama',
      tipo: "K-Drama",
      genero: "Romance",
      descricao:
          "Um romance delicado que atravessa fronteiras e muda duas vidas.",
      spoiler: "nenhum",
      stars: 4102,
      comentarios: 661,
      cor: const Color(0xFF1A001A),
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _carregarPreferencias();

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
    setState(() {
      _videos.insert(
        0,
        _VideoCard(
          titulo: publicado.description.isEmpty
              ? 'Meu vídeo'
              : 'Minha recomendação',
          autor: '@seu.usuario',
          tipo: publicado.contentType,
          genero: 'Vídeo de ${publicado.contentType.toLowerCase()}',
          descricao: publicado.description.isEmpty
              ? 'Confira minha recomendação de ${publicado.contentType.toLowerCase()}.'
              : publicado.description,
          spoiler: publicado.spoiler,
          stars: 0,
          comentarios: 0,
          cor: const Color(0xFF191416),
          videoPath: publicado.videoPath,
          privacy: publicado.privacy,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      extendBody: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(
            index: _tabAtual,
            children: [
              _LoopTab(
                videos: _videos,
                ocultarSpoilers: _ocultarSpoilers,
                profileInterests: _gostosPerfil,
              ),
              GroupsScreen(interests: _gostosPerfil),
              ProfileScreen(
                onOpenSettings: _abrirConfiguracoes,
                availableVideos: _videos.map((video) => video.titulo).toList(),
                privateVideos: _videos
                    .where((video) => video.privacy == 'Somente amigos')
                    .map((video) => video.titulo)
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
          if (!_mostrarBemVindo && !_mostrarHumor && _tabAtual != 3)
            Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNav()),

          // ── Bem-vindo (aparece primeiro) ───────────────────────────
          if (_mostrarBemVindo) _buildBemVindoOverlay(),

          // ── Humor (aparece depois do bem-vindo) ────────────────────
          if (_mostrarHumor) _buildHumorOverlay(),
        ],
      ),
    );
  }

  // ── Tela de Bem-vindo ──────────────────────────────────────────────
  Widget _buildBemVindoOverlay() {
    return Container(
      color: AppPalette.isDark(context)
          ? AppPalette.darkBackground
          : const Color(0xFF000000),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ornamento superior direito
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
                    const Color(0xFFB8787C).withOpacity(0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Ornamento inferior esquerdo
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
                    const Color.fromARGB(255, 255, 215, 218).withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Conteúdo animado
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
                  // Logo com glow pulsante
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

                  const SizedBox(height: 36),

                  Text(
                    "Bem-vindo!",
                    style: TextStyle(
                      color: AppPalette.isDark(context)
                          ? Colors.white
                          : const Color(0xFFBB7575),
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Linha decorativa
                  Container(
                    width: 56,
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFBB7575), Color(0xFFBB7575)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    "Seu universo de entretenimento começa aqui",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color.fromARGB(
                        255,
                        255,
                        218,
                        220,
                      ).withOpacity(0.60),
                      fontSize: 15,
                      height: 1.55,
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

  // ── Humor do dia ───────────────────────────────────────────────────
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
                  // Ícone decorativo
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

  // ── Bottom Navigation ──────────────────────────────────────────────
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
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
                label: 'Grupos',
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
                          horizontal: 12,
                          vertical: 2,
                        ),
                        child: Image.asset(
                          'assets/images/gravar.png',
                          width: 28,
                          height: 28,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 30,
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
                width: 22,
                height: 22,
                child: Image.asset(
                  image,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    fallback ?? Icons.circle_outlined,
                    color: active
                        ? AppPalette.primaryText(context)
                        : AppPalette.accent(context),
                    size: 24,
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
                  fontSize: 8,
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
                radius: 12,
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
                  fontSize: 8,
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

class _LoopSearchDelegate extends SearchDelegate<int?> {
  final List<_VideoCard> videos;

  _LoopSearchDelegate(this.videos);

  @override
  String get searchFieldLabel => 'Buscar obras no Loop';

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
    final term = query.trim().toLowerCase();
    final matches = videos.indexed.where((entry) {
      if (term.isEmpty) return true;
      final video = entry.$2;
      return '${video.titulo} ${video.tipo} ${video.genero}'
          .toLowerCase()
          .contains(term);
    }).toList();

    if (matches.isEmpty) {
      return const Center(child: Text('Nenhuma obra encontrada.'));
    }

    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final video = matches[index].$2;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: video.cor,
            child: const Icon(Icons.movie_outlined, color: Colors.white),
          ),
          title: Text(video.titulo),
          subtitle: Text('${video.tipo} · ${video.genero}'),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// MODEL
// ══════════════════════════════════════════════════════════════════

class _VideoCard {
  final String titulo, tipo, genero, descricao, spoiler, autor;
  final String? videoPath;
  final String privacy;
  final int stars, comentarios;
  final Color cor;
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
    this.videoPath,
    this.privacy = 'Público',
  });
}

class _FeedVideo extends StatefulWidget {
  final String path;

  const _FeedVideo({required this.path});

  @override
  State<_FeedVideo> createState() => _FeedVideoState();
}

class _FeedVideoState extends State<_FeedVideo> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialize;

  @override
  void initState() {
    super.initState();
    final uri = kIsWeb ? Uri.parse(widget.path) : Uri.file(widget.path);
    _controller = VideoPlayerController.networkUrl(uri);
    _initialize = _controller.initialize().then((_) async {
      await _controller.setLooping(true);
      await _controller.play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        final aspectRatio = _controller.value.aspectRatio;
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 1000 * aspectRatio,
              height: 1000,
              child: VideoPlayer(_controller),
            ),
          ),
        );
      },
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
  const _LoopTab({
    required this.videos,
    required this.ocultarSpoilers,
    required this.profileInterests,
  });

  @override
  State<_LoopTab> createState() => _LoopTabState();
}

class _LoopTabState extends State<_LoopTab> {
  final PageController _pageCtrl = PageController();
  final Set<int> _starred = {};
  final Set<int> _saved = {};
  final Set<String> _following = {};
  final Map<int, List<String>> _comentarios = {};
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
    final indice = await showSearch<int?>(
      context: context,
      delegate: _LoopSearchDelegate(widget.videos),
    );
    if (indice == null || !_pageCtrl.hasClients) return;
    await _pageCtrl.animateToPage(
      indice,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
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
        final starrado = _starred.contains(videoIndex);
        final salvo = _saved.contains(videoIndex);
        final corAnel = switch (v.spoiler) {
          'muito' => const Color(0xFFD9273E),
          'leve' => const Color(0xFFFFC247),
          _ => const Color(0xFF4CAF68),
        };
        return Stack(
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
              _FeedVideo(path: v.videoPath!),
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
                  _badge(
                    _spoilerLabel(v.spoiler),
                    _spoilerColor(v.spoiler).withOpacity(0.16),
                    _spoilerColor(v.spoiler),
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
                  const SizedBox(height: 4),
                  Text(
                    '${v.tipo} · ${v.genero}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12,
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
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ProfileScreen(
                                      isOwner: false,
                                      publicUsername: v.autor,
                                      publicInterests: [v.tipo, v.genero],
                                      availableVideos: widget.videos
                                          .map((video) => video.titulo)
                                          .toList(),
                                    ),
                                  ),
                                ),
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
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _toggleFollow(v.autor),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.transparent,
                                minimumSize: const Size(0, 32),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Text(
                                _following.contains(v.autor)
                                    ? 'Seguindo'
                                    : 'Seguir',
                              ),
                            ),
                          ],
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
                  _acao(
                    icon: starrado
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    label: _fmt(v.stars + (starrado ? 1 : 0)),
                    cor: starrado ? const Color(0xFFFFD54F) : Colors.white,
                    onTap: () => setState(
                      () => starrado
                          ? _starred.remove(videoIndex)
                          : _starred.add(videoIndex),
                    ),
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
                ],
              ),
            ),
            _buildTopBar(),
          ],
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
                        fillColor: AppPalette.input(context),
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
              color: AppPalette.isDark(context)
                  ? AppPalette.darkBackground
                  : const Color(0xFF0D0D0D),
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
                      color: Colors.white12,
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
                                color: Color.fromARGB(255, 207, 143, 143),
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
                                  color: const Color.fromARGB(
                                    255,
                                    211,
                                    146,
                                    146,
                                  ).withOpacity(0.38),
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
                            color: Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white54,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(color: Colors.white.withOpacity(0.07), height: 1),

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
                            style: const TextStyle(
                              color: Colors.white70,
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: "Pergunte à Lupez...",
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.32),
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
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppPalette.button(context),
                                  AppPalette.darkButton,
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFBB7575), Color(0xFF7D171D)],
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
                    : const LinearGradient(
                        colors: [Color(0xFFBB7575), Color(0xFF7D171D)],
                      ),
                color: msg.deLupez ? const Color(0xFF1A1A1A) : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(msg.deLupez ? 4 : 16),
                  bottomRight: Radius.circular(msg.deLupez ? 16 : 4),
                ),
                border: msg.deLupez
                    ? Border.all(color: Colors.white.withOpacity(0.07))
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
            color: deLupez ? Colors.white.withOpacity(0.85) : Colors.white,
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFBB7575), Color(0xFF7D171D)],
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
              color: const Color(0xFF1A1A1A),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
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
// TAB: BIBLIOTECA
// ══════════════════════════════════════════════════════════════════

class _BibliotecaTab extends StatelessWidget {
  const _BibliotecaTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE9E9),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Text(
                    "Biblioteca",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _badge("🎬", "12"),
                  const SizedBox(width: 8),
                  _badge("📺", "8"),
                  const SizedBox(width: 8),
                  _badge("📖", "5"),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DefaultTabController(
              length: 3,
              child: Expanded(
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Color(0xFF7D171D),
                      unselectedLabelColor: Color(0xFFB8787C),
                      indicatorColor: Color(0xFFB8787C),
                      indicatorSize: TabBarIndicatorSize.label,
                      tabs: [
                        Tab(text: "Quero ver"),
                        Tab(text: "Em andamento"),
                        Tab(text: "Já vi"),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _vazio("📌", "Sua lista 'quero ver'\naparece aqui"),
                          _vazio("⏳", "O que você está\nassistindo agora"),
                          _vazio("✅", "Obras que você\njá concluiu"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _badge(String emoji, String count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            count,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _vazio(String emoji, String msg) {
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
              color: Colors.white.withOpacity(0.35),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TAB: AVALIAÇÕES
// ══════════════════════════════════════════════════════════════════

class _AvaliacoesTab extends StatelessWidget {
  const _AvaliacoesTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE9E9),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Avaliações",
                  style: TextStyle(
                    color: Color(0xFF7D171D),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [Color(0xFFB8787C), Color(0xFF7D171D)],
                      ).createShader(b),
                      child: const Text(
                        "⭐",
                        style: TextStyle(fontSize: 64, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Suas stars aparecem aqui",
                      style: TextStyle(
                        color: Color(0xFF7D171D),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Avalie obras e acompanhe\nsuas reviews",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TAB: EXPLORAR
// ══════════════════════════════════════════════════════════════════

class _ExplorarTab extends StatefulWidget {
  final List<_VideoCard> videos;

  const _ExplorarTab({required this.videos});

  @override
  State<_ExplorarTab> createState() => _ExplorarTabState();
}

class _ExplorarTabState extends State<_ExplorarTab> {
  String _consulta = '';

  static const _trending = [
    ("🔥", "Duna: Parte 2", "34.2k comentários"),
    ("🔥", "The Last of Us S2", "28.7k comentários"),
    ("🔥", "Cem Anos de Solidão", "19.1k comentários"),
    ("📈", "Shogun", "14.5k comentários"),
    ("📈", "Persepólis", "9.8k comentários"),
  ];

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
                        onChanged: (value) => setState(() => _consulta = value),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: "Buscar obras...",
                          hintStyle: TextStyle(
                            color: const Color(0xFFBB7575).withOpacity(0.70),
                            fontSize: 15,
                          ),
                          isDense: true,
                          border: InputBorder.none,
                        ),
                      ),
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
                ...widget.videos
                    .where((video) {
                      final texto =
                          '${video.titulo} ${video.tipo} ${video.genero}'
                              .toLowerCase();
                      return texto.contains(_consulta.trim().toLowerCase());
                    })
                    .map(
                      (video) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: video.cor,
                          child: const Icon(
                            Icons.movie_outlined,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(video.titulo),
                        subtitle: Text('${video.tipo} · ${video.genero}'),
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(video.titulo),
                            content: Text('${video.tipo} · ${video.genero}'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Fechar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                if (!widget.videos.any((video) {
                  final texto = '${video.titulo} ${video.tipo} ${video.genero}'
                      .toLowerCase();
                  return texto.contains(_consulta.trim().toLowerCase());
                }))
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Nenhuma obra encontrada no catálogo atual.'),
                  ),
              ],
              const SizedBox(height: 28),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFBB7575), Color(0xFF7D171D)],
                ).createShader(b),
                child: const Text(
                  "🔥  Em alta agora",
                  style: TextStyle(
                    color: Color(0xFFBB7575),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ..._trending.asMap().entries.map((e) {
                final i = e.key + 1;
                final (badge, titulo, stats) = e.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBB7575).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFBB7575).withOpacity(0.20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "$i",
                        style: TextStyle(
                          color: i <= 3
                              ? const Color(0xFFBB7575)
                              : const Color(0xFFBB7575).withOpacity(0.55),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              style: const TextStyle(
                                color: Color(0xFFBB7575),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              stats,
                              style: TextStyle(
                                color: const Color(
                                  0xFFBB7575,
                                ).withOpacity(0.65),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(badge, style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                );
              }),
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
                      return Container(
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
                                color: const Color(0xFFBB7575),
                                fontSize: 13,
                              ),
                            ),
                          ],
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
  bool _mostrarFrase = true;
  String _nomePerfil = 'Anna Beatriz';
  String _usuarioPerfil = '@anna.beatriz';
  String _bioPerfil =
      'Cinéfila de plantão 🎬 | Amante de doramas e sci-fi | Leio tudo que posso ✨';

  final _selos = const [
    ("🎬", "Cinéfilo", Color(0xFFBB7575)),
    ("🇰🇷", "Dorameiro", Color(0xFFBB7575)),
    ("🗺️", "Aventureiro", Color(0xFFFFA726)),
    ("📖", "Leitor", Color(0xFF4CAF50)),
    ("🎌", "Otaku", Color(0xFF9C27B0)),
  ];

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
                  // Compatibilidade
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFBB7575), Color(0xFFBB7575)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFBB7575).withOpacity(0.45),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("💞", style: TextStyle(fontSize: 13)),
                        SizedBox(width: 5),
                        Text(
                          "87% compatível",
                          style: TextStyle(
                            color: Color(0xFFFFE9E9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
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
              // Contadores
              Row(
                children: [
                  _contador("1.2k", "seguidores"),
                  const SizedBox(width: 24),
                  _contador("340", "seguindo"),
                  const SizedBox(width: 24),
                  _contador("4.8k", "⭐ stars"),
                ],
              ),
              const SizedBox(height: 16),
              // Obra favorita
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 66,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1B2A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFBB7575).withOpacity(0.3),
                      ),
                    ),
                    child: const Center(
                      child: Text("🚀", style: TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Obra favorita",
                        style: TextStyle(
                          color: const Color(0xFF7D171D).withOpacity(0.65),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Interstellar",
                        style: TextStyle(
                          color: Color(0xFF7D171D),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Filme • Ficção Científica",
                        style: TextStyle(
                          color: const Color(0xFF7D171D).withOpacity(0.60),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Selos
              Text(
                "Selos conquistados",
                style: TextStyle(
                  color: const Color(0xFF7D171D).withOpacity(0.65),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _selos.map((s) {
                    final (emoji, nome, cor) = s;
                    return GestureDetector(
                      onTap: () => _mostrarSeloDialog(emoji, nome, cor),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              cor.withOpacity(0.25),
                              cor.withOpacity(0.05),
                            ],
                          ),
                          border: Border.all(
                            color: cor.withOpacity(0.6),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cor.withOpacity(0.22),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              // Frase fixada
              if (_mostrarFrase) _buildFrase(),
              const SizedBox(height: 12),
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

  Widget _buildFrase() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [
                    Color.fromARGB(255, 199, 138, 141),
                    Color.fromARGB(255, 208, 146, 146),
                  ],
                ).createShader(b),
                child: const Text(
                  "📌 Frase fixada",
                  style: TextStyle(
                    color: Color.fromARGB(255, 209, 144, 144),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _mostrarFrase = false),
                child: Icon(
                  Icons.close,
                  color: const Color.fromARGB(97, 203, 141, 141),
                  size: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"Não importa o que o tempo faça conosco, o que importa é o que fazemos com ele."\n— Interstellar',
            style: TextStyle(
              color: const Color(0xFFBB7575).withOpacity(0.78),
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarSeloDialog(String emoji, String nome, Color cor) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [cor.withOpacity(0.3), cor.withOpacity(0.05)],
                  ),
                  border: Border.all(color: cor.withOpacity(0.7), width: 2),
                  boxShadow: [
                    BoxShadow(color: cor.withOpacity(0.35), blurRadius: 22),
                  ],
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                nome,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Conquistado por dedicação e paixão pelo entretenimento!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cor, cor.withOpacity(0.6)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Fechar",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contador(String valor, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valor,
          style: const TextStyle(
            color: Color(0xFF7D171D),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF7D171D).withOpacity(0.58),
            fontSize: 12,
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
