// home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  int _tabAtual = 0;

  // Fluxo: bem-vindo → humor → home
  bool _mostrarBemVindo = true;
  bool _mostrarHumor = false;
  bool _mostrarLupez = false;
  String? _humorSelecionado;

  late AnimationController _bemVindoCtrl;
  late Animation<double> _bemVindoOpacity;
  late Animation<double> _bemVindoScale;
  late Animation<double> _bemVindoSlide;

  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  late AnimationController _lupezEntradaCtrl;
  late Animation<double> _lupezEntradaAnim;

  final List<_VideoCard> _videos = [
    _VideoCard(titulo: "Interstellar", tipo: "Filme", genero: "Ficção Científica",
        spoiler: "nenhum", stars: 2341, comentarios: 187, cor: const Color(0xFF0D1B2A)),
    _VideoCard(titulo: "Attack on Titan", tipo: "Anime", genero: "Ação",
        spoiler: "leve", stars: 5820, comentarios: 932, cor: const Color(0xFF1A0A00)),
    _VideoCard(titulo: "O Hobbit", tipo: "Livro", genero: "Fantasia",
        spoiler: "nenhum", stars: 1203, comentarios: 74, cor: const Color(0xFF0A1A0A)),
    _VideoCard(titulo: "Dark", tipo: "Série", genero: "Suspense",
        spoiler: "muito", stars: 3910, comentarios: 445, cor: const Color(0xFF0F0F1A)),
    _VideoCard(titulo: "Crash Landing on You", tipo: "K-Drama", genero: "Romance",
        spoiler: "nenhum", stars: 4102, comentarios: 661, cor: const Color(0xFF1A001A)),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    // Controlador do glow da Lupez
    _glowCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.9)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // Controlador da entrada da Lupez
    _lupezEntradaCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350));
    _lupezEntradaAnim = CurvedAnimation(
      parent: _lupezEntradaCtrl, curve: Curves.easeOutCubic);

    // ── Animação de bem-vindo ──────────────────────────────────────
    _bemVindoCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3400));

    _bemVindoOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 22),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 52),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 26),
    ]).animate(_bemVindoCtrl);

    _bemVindoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.72, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 38),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 42),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.10).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20),
    ]).animate(_bemVindoCtrl);

    _bemVindoSlide = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 74),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -50.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 26),
    ]).animate(_bemVindoCtrl);

    // Inicia bem-vindo → depois humor
    _bemVindoCtrl.forward().then((_) {
      if (!mounted) return;
      setState(() {
        _mostrarBemVindo = false;
        _mostrarHumor = true;
      });
    });
  }

  @override
  void dispose() {
    _bemVindoCtrl.dispose();
    _glowCtrl.dispose();
    _lupezEntradaCtrl.dispose();
    super.dispose();
  }

  void _abrirLupez() {
    setState(() => _mostrarLupez = true);
    _lupezEntradaCtrl.forward(from: 0);
  }

  void _fecharLupez() {
    _lupezEntradaCtrl.reverse().then((_) {
      if (mounted) setState(() => _mostrarLupez = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: [
          // ── Conteúdo das abas ──────────────────────────────────────
          IndexedStack(
            index: _tabAtual,
            children: [
              _LoopTab(videos: _videos, onAbrirLupez: _abrirLupez),
              const _BibliotecaTab(),
              const _AvaliacoesTab(),
              const _ExplorarTab(),
              const _PerfilTab(),
            ],
          ),

          // ── Botão flutuante Lupez (só no Loop) ────────────────────
          if (!_mostrarBemVindo && !_mostrarHumor && !_mostrarLupez && _tabAtual == 0)
            Positioned(
              bottom: 90, right: 16,
              child: GestureDetector(
                onTap: _abrirLupez,
                child: AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (_, child) => Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE50914), Color(0xFF6B0000)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE50914).withOpacity(0.5 * _glowAnim.value),
                          blurRadius: 20, spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                  child: const Center(
                    child: Text("L",
                      style: TextStyle(color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),

          // ── Overlay Lupez ──────────────────────────────────────────
          if (_mostrarLupez)
            AnimatedBuilder(
              animation: _lupezEntradaAnim,
              builder: (_, child) => Opacity(
                opacity: _lupezEntradaAnim.value,
                child: Transform.translate(
                  offset: Offset(0, 40 * (1 - _lupezEntradaAnim.value)),
                  child: child,
                ),
              ),
              child: _LupezOverlay(
                glowAnim: _glowAnim,
                onFechar: _fecharLupez,
              ),
            ),

          // ── Bem-vindo (aparece primeiro) ───────────────────────────
          if (_mostrarBemVindo) _buildBemVindoOverlay(),

          // ── Humor (aparece depois do bem-vindo) ────────────────────
          if (_mostrarHumor) _buildHumorOverlay(),
        ],
      ),
      bottomNavigationBar: _mostrarBemVindo || _mostrarHumor
          ? null
          : _buildBottomNav(),
    );
  }

  // ── Tela de Bem-vindo ──────────────────────────────────────────────
  Widget _buildBemVindoOverlay() {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ornamento superior direito
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFE50914).withOpacity(0.10),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          // Ornamento inferior esquerdo
          Positioned(
            bottom: -60, left: -50,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF6B0000).withOpacity(0.12),
                  Colors.transparent,
                ]),
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
                            color: const Color(0xFF6B0000).withOpacity(v),
                            blurRadius: 60, spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                    child: Image.asset('assets/images/logo.png', height: 100),
                  ),

                  const SizedBox(height: 36),

                  // "Bem-vindo!" com gradiente
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.white, Color(0xFFFFCCCC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      "Bem-vindo!",
                      style: TextStyle(
                        color: Colors.white, fontSize: 44,
                        fontWeight: FontWeight.bold, letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Linha decorativa
                  Container(
                    width: 56, height: 3,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE50914), Color(0xFF6B0000)]),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    "Seu universo de entretenimento\ne conhecimento começa aqui",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.48),
                      fontSize: 15, height: 1.55,
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
      ("😊", "Feliz"), ("😢", "Triste"), ("😤", "Ansioso"),
      ("😴", "Sonolento"), ("🔥", "Animado"), ("🤔", "Pensativo"),
      ("💕", "Romântico"), ("😱", "Suspense"),
    ];

    return GestureDetector(
      onTap: () => setState(() => _mostrarHumor = false),
      child: Container(
        color: Colors.black.withOpacity(0.80),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 40),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFE50914), Color(0xFFFF6B6B)],
                    ).createShader(bounds),
                    child: const Text(
                      "Como você está se\nsentindo hoje?",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 22,
                          fontWeight: FontWeight.bold, height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Vamos recomendar obras para o seu humor",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.42), fontSize: 13)),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: humores.map((h) {
                      final (emoji, nome) = h;
                      final sel = _humorSelecionado == nome;
                      return GestureDetector(
                        onTap: () => setState(() => _humorSelecionado = nome),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: sel ? const LinearGradient(
                              colors: [Color(0xFF1A0005), Color(0xFF0D0002)]) : null,
                            color: sel ? null : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: sel
                                  ? const Color(0xFFE50914).withOpacity(0.7)
                                  : Colors.white12,
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(nome,
                                style: TextStyle(
                                  color: sel ? Colors.white : Colors.white60,
                                  fontSize: 13,
                                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                                )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => setState(() => _mostrarHumor = false),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE50914), Color(0xFF6B0000)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFFE50914).withOpacity(0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _humorSelecionado != null
                                ? "Entrar com humor $_humorSelecionado"
                                : "Pular por hoje",
                            style: const TextStyle(color: Colors.white,
                                fontSize: 15, fontWeight: FontWeight.w600),
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
    final items = [
      (Icons.play_circle_fill_rounded, Icons.play_circle_outline_rounded, "Loop"),
      (Icons.local_library_rounded, Icons.local_library_outlined, "Biblioteca"),
      (Icons.star_rounded, Icons.star_outline_rounded, "Avaliações"),
      (Icons.explore_rounded, Icons.explore_outlined, "Explorar"),
      (Icons.person_rounded, Icons.person_outline_rounded, "Perfil"),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black,
            Colors.black.withOpacity(0.92),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final (iconOn, iconOff, label) = e.value;
              final ativo = _tabAtual == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tabAtual = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: ativo
                              ? const Color(0xFFE50914).withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          ativo ? iconOn : iconOff,
                          color: ativo ? const Color(0xFFE50914) : Colors.white38,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: TextStyle(
                          color: ativo
                              ? const Color(0xFFE50914)
                              : Colors.white38,
                          fontSize: 10,
                          fontWeight: ativo ? FontWeight.w600 : FontWeight.normal,
                        ),
                        child: Text(label),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
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
  final String titulo, tipo, genero, spoiler;
  final int stars, comentarios;
  final Color cor;
  const _VideoCard({
    required this.titulo, required this.tipo,
    required this.genero, required this.spoiler,
    required this.stars, required this.comentarios,
    required this.cor,
  });
}

// ══════════════════════════════════════════════════════════════════
// TAB: LOOP
// ══════════════════════════════════════════════════════════════════

class _LoopTab extends StatefulWidget {
  final List<_VideoCard> videos;
  final VoidCallback onAbrirLupez;
  const _LoopTab({required this.videos, required this.onAbrirLupez});

  @override
  State<_LoopTab> createState() => _LoopTabState();
}

class _LoopTabState extends State<_LoopTab> {
  final PageController _pageCtrl = PageController();
  final Set<int> _starred = {};

  String _spoilerLabel(String s) {
    switch (s) {
      case 'leve': return '⚠️ Spoiler leve';
      case 'muito': return '🚨 Muito spoiler';
      default: return '✅ Sem spoiler';
    }
  }

  Color _spoilerColor(String s) {
    switch (s) {
      case 'leve': return const Color(0xFFFFA726);
      case 'muito': return const Color(0xFFE50914);
      default: return const Color(0xFF4CAF50);
    }
  }

  String _tipoEmoji(String t) {
    switch (t) {
      case 'Filme': return '🎬';
      case 'Série': return '📺';
      case 'Livro': return '📖';
      case 'Anime': return '🎌';
      case 'K-Drama': return '🇰🇷';
      default: return '🎬';
    }
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageCtrl,
      scrollDirection: Axis.vertical,
      itemCount: widget.videos.length,
      itemBuilder: (context, i) {
        final v = widget.videos[i];
        final starrado = _starred.contains(i);
        return Stack(
          fit: StackFit.expand,
          children: [
            // Fundo
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [v.cor, Colors.black, v.cor.withOpacity(0.3)],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Center(
              child: Opacity(
                opacity: 0.06,
                child: Text(_tipoEmoji(v.tipo),
                    style: const TextStyle(fontSize: 220)),
              ),
            ),
            // Gradiente inferior
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.55,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.95), Colors.transparent],
                  ),
                ),
              ),
            ),
            // Info inferior esquerdo
            Positioned(
              left: 16, right: 72, bottom: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _badge(_tipoEmoji(v.tipo) + " " + v.tipo,
                        Colors.white.withOpacity(0.12), Colors.white),
                    const SizedBox(width: 8),
                    _badge(_spoilerLabel(v.spoiler),
                        _spoilerColor(v.spoiler).withOpacity(0.15),
                        _spoilerColor(v.spoiler)),
                  ]),
                  const SizedBox(height: 10),
                  Text(v.titulo,
                    style: const TextStyle(color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)])),
                  const SizedBox(height: 4),
                  Text(v.genero,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0x4DE50914),
                      child: Text("A",
                          style: TextStyle(color: Colors.white,
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text("@anna.beatriz",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 13)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text("Seguir",
                        style: TextStyle(color: Colors.white,
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ],
              ),
            ),
            // Ações laterais
            Positioned(
              right: 12, bottom: 100,
              child: Column(children: [
                _acao(
                  icon: starrado ? Icons.star_rounded : Icons.star_outline_rounded,
                  label: _fmt(v.stars + (starrado ? 1 : 0)),
                  cor: starrado ? const Color(0xFFFFD700) : Colors.white,
                  onTap: () => setState(
                      () => starrado ? _starred.remove(i) : _starred.add(i)),
                ),
                const SizedBox(height: 20),
                _acao(icon: Icons.chat_bubble_outline_rounded,
                    label: _fmt(v.comentarios), cor: Colors.white, onTap: () {}),
                const SizedBox(height: 20),
                _acao(icon: Icons.bookmark_border_rounded,
                    label: "Salvar", cor: Colors.white, onTap: () {}),
                const SizedBox(height: 20),
                _acao(icon: Icons.share_outlined,
                    label: "Enviar", cor: Colors.white, onTap: () {}),
              ]),
            ),
            // Top bar
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  ),
                ),
                child: Row(children: [
                  const Text("Loop",
                    style: TextStyle(color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Icon(Icons.search_rounded,
                      color: Colors.white.withOpacity(0.8), size: 26),
                  const SizedBox(width: 14),
                  // Botão Lupez no topo
                  GestureDetector(
                    onTap: widget.onAbrirLupez,
                    child: Container(
                      width: 36, height: 36,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFE50914), Color(0xFF6B0000)]),
                      ),
                      child: const Center(
                        child: Text("L",
                          style: TextStyle(color: Colors.white,
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        );
      },
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
      child: Text(text,
          style: TextStyle(color: textColor,
              fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _acao({required IconData icon, required String label,
      required Color cor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Icon(icon, color: cor, size: 32,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 6)]),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(color: cor, fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 4)])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// LUPEZ OVERLAY (chat dentro do home)
// ══════════════════════════════════════════════════════════════════

class _LupezOverlay extends StatefulWidget {
  final Animation<double> glowAnim;
  final VoidCallback onFechar;
  const _LupezOverlay({required this.glowAnim, required this.onFechar});

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

  final _respostas = {
    "suspense": "Para suspense, você vai amar **Dark** (Netflix) — muito complexo, mas genial! Ou o filme **Knives Out** pra começar. 🔍",
    "chor": "Dia de choro? 😢 **Your Lie in April** (anime) ou **A Culpa é das Estrelas** são certeiros. Tenha lenços!",
    "anime": "Para iniciantes, comece com **Fullmetal Alchemist: Brotherhood** — épico e dublado! Ou **My Hero Academia** pra ação leve. 🎌",
    "kdrama": "Curto e romântico? **Business Proposal** (16 eps, Netflix) é perfeito! Também adoro **It's Okay to Not Be Okay**. 🇰🇷❤️",
    "ficção": "**Interstellar** é obrigatório! E a série **Dark** mistura ficção científica com suspense de um jeito único. 🚀",
    "padrão": "Que escolha incrível! Com base no seu humor e histórico, vou preparar uma lista personalizada. Quer filtrar por tempo de duração ou plataforma? 🎬",
  };

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))..repeat();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _msgs.add(const _Mensagem(
          texto: "Oi! Sou a **Lupez** 🎬✨\nComo posso te ajudar hoje? Posso recomendar filmes, séries, livros, animes e K-dramas!",
          deLupez: true,
        ));
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
      final lower = msg.toLowerCase();
      String r = _respostas["padrão"]!;
      if (lower.contains("suspense") || lower.contains("thriller")) r = _respostas["suspense"]!;
      else if (lower.contains("chor") || lower.contains("triste")) r = _respostas["chor"]!;
      else if (lower.contains("anime")) r = _respostas["anime"]!;
      else if (lower.contains("kdrama") || lower.contains("k-drama") || lower.contains("coreano")) r = _respostas["kdrama"]!;
      else if (lower.contains("ficção") || lower.contains("sci-fi") || lower.contains("épic")) r = _respostas["ficção"]!;

      setState(() {
        _digitando = false;
        _msgs.add(_Mensagem(texto: r, deLupez: true));
      });
      _rolar();
    });
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
      color: Colors.black.withOpacity(0.65),
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Color(0xFF0D0D0D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    AnimatedBuilder(
                      animation: widget.glowAnim,
                      builder: (_, child) => Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE50914), Color(0xFF6B0000)]),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE50914)
                                  .withOpacity(0.4 * widget.glowAnim.value),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                      child: const Center(
                        child: Text("L",
                          style: TextStyle(color: Colors.white,
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [Color(0xFFE50914), Color(0xFFFF6B6B)],
                          ).createShader(b),
                          child: const Text("Lupez",
                            style: TextStyle(color: Colors.white,
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        Row(children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: Color(0xFF4CAF50)),
                          ),
                          const SizedBox(width: 5),
                          Text("IA de entretenimento",
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.38),
                                fontSize: 11)),
                        ]),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onFechar,
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white54, size: 18),
                      ),
                    ),
                  ]),
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
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFFE50914).withOpacity(0.3)),
                          ),
                          child: Text(_sugestoes[i],
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Input
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      14, 0, 14, MediaQuery.of(context).viewInsets.bottom + 12),
                  child: Row(children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.10)),
                        ),
                        child: TextField(
                          controller: _inputCtrl,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: "Pergunte à Lupez...",
                            hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.32),
                                fontSize: 13),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
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
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE50914), Color(0xFF6B0000)]),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE50914).withOpacity(
                                    0.35 * widget.glowAnim.value),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                          child: child,
                        ),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ]),
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
            ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (msg.deLupez) ...[
            Container(
              width: 26, height: 26,
              margin: const EdgeInsets.only(right: 7),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [Color(0xFFE50914), Color(0xFF6B0000)]),
              ),
              child: const Center(
                child: Text("L",
                  style: TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: msg.deLupez ? null : const LinearGradient(
                  colors: [Color(0xFFE50914), Color(0xFF8B0000)],
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
      spans.add(TextSpan(
        text: partes[i],
        style: TextStyle(
          color: deLupez ? Colors.white.withOpacity(0.85) : Colors.white,
          fontWeight: i.isOdd ? FontWeight.bold : FontWeight.normal,
          fontSize: 13, height: 1.5,
        ),
      ));
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
            width: 26, height: 26,
            margin: const EdgeInsets.only(right: 7),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [Color(0xFFE50914), Color(0xFF6B0000)]),
            ),
            child: const Center(
              child: Text("L",
                style: TextStyle(color: Colors.white,
                    fontSize: 12, fontWeight: FontWeight.bold)),
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
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE50914),
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
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(children: [
              const Text("Biblioteca",
                style: TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.bold)),
              const Spacer(),
              _badge("🎬", "12"),
              const SizedBox(width: 8),
              _badge("📺", "8"),
              const SizedBox(width: 8),
              _badge("📖", "5"),
            ]),
          ),
          const SizedBox(height: 20),
          DefaultTabController(
            length: 3,
            child: Expanded(
              child: Column(children: [
                const TabBar(
                  labelColor: Color(0xFFE50914),
                  unselectedLabelColor: Colors.white38,
                  indicatorColor: Color(0xFFE50914),
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: [
                    Tab(text: "Quero ver"),
                    Tab(text: "Em andamento"),
                    Tab(text: "Já vi"),
                  ],
                ),
                Expanded(
                  child: TabBarView(children: [
                    _vazio("📌", "Sua lista 'quero ver'\naparece aqui"),
                    _vazio("⏳", "O que você está\nassistindo agora"),
                    _vazio("✅", "Obras que você\njá concluiu"),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(count,
          style: const TextStyle(color: Colors.white70,
              fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  static Widget _vazio(String emoji, String msg) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 44)),
        const SizedBox(height: 12),
        Text(msg,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.35),
              fontSize: 14, height: 1.5)),
      ]),
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
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Avaliações",
                style: TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [Color(0xFFE50914), Color(0xFFFFD700)],
                  ).createShader(b),
                  child: const Text("⭐",
                      style: TextStyle(fontSize: 64, color: Colors.white)),
                ),
                const SizedBox(height: 16),
                const Text("Suas stars aparecem aqui",
                  style: TextStyle(color: Colors.white, fontSize: 17,
                      fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text("Avalie obras e acompanhe\nsuas reviews",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.35),
                      fontSize: 14, height: 1.5)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// TAB: EXPLORAR
// ══════════════════════════════════════════════════════════════════

class _ExplorarTab extends StatelessWidget {
  const _ExplorarTab();

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
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Explorar",
                style: TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.10)),
                ),
                child: Row(children: [
                  Icon(Icons.search_rounded,
                      color: Colors.white.withOpacity(0.35), size: 20),
                  const SizedBox(width: 10),
                  Text("Buscar obras, usuários...",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 15)),
                ]),
              ),
              const SizedBox(height: 28),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFE50914), Color(0xFFFF6B6B)],
                ).createShader(b),
                child: const Text("🔥  Em alta agora",
                  style: TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 14),
              ..._trending.asMap().entries.map((e) {
                final i = e.key + 1;
                final (badge, titulo, stats) = e.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.07)),
                  ),
                  child: Row(children: [
                    Text("$i",
                      style: TextStyle(
                        color: i <= 3
                            ? const Color(0xFFE50914)
                            : Colors.white38,
                        fontSize: 18, fontWeight: FontWeight.bold,
                      )),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titulo,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(stats,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(badge,
                        style: const TextStyle(fontSize: 18)),
                  ]),
                );
              }),
              const SizedBox(height: 24),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFE50914), Color(0xFFFF6B6B)],
                ).createShader(b),
                child: const Text("🎭  Por categoria",
                  style: TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: [
                  ("🎬", "Filmes"), ("📺", "Séries"), ("📖", "Livros"),
                  ("🎌", "Anime"), ("🇰🇷", "K-Drama"), ("❤️", "Romance"),
                  ("👻", "Terror"), ("🔍", "Suspense"),
                  ("🚀", "Ficção Científica"),
                ].map((c) {
                  final (emoji, nome) = c;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.10)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(emoji, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 7),
                      Text(nome,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13)),
                    ]),
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
  const _PerfilTab();

  @override
  State<_PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<_PerfilTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _mostrarFrase = true;

  final _selos = const [
    ("🎬", "Cinéfilo", Color(0xFFE50914)),
    ("🇰🇷", "Dorameiro", Color(0xFFFF6B9D)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildHeader()),
        ],
        body: Column(children: [
          Container(
            color: const Color(0xFF0D0D0D),
            child: TabBar(
              controller: _tabCtrl,
              labelColor: const Color(0xFFE50914),
              unselectedLabelColor: Colors.white38,
              indicatorColor: const Color(0xFFE50914),
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
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Capa
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 150,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A0005), Color(0xFF6B0000), Color(0xFF0D0D0D)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: Stack(children: [
                Positioned(right: -30, top: -30,
                  child: Container(width: 180, height: 180,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x08FFFFFF)))),
              ]),
            ),
            // Foto de perfil
            Positioned(
              bottom: -42, left: 20,
              child: Container(
                width: 84, height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF080808), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE50914).withOpacity(0.3),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFF1A0005),
                  child: Text("A",
                    style: TextStyle(color: Colors.white, fontSize: 30,
                        fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            // Status
            Positioned(
              bottom: -14, left: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFE50914).withOpacity(0.45)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0xFF4CAF50)),
                  ),
                  const SizedBox(width: 6),
                  const Text("Assistindo: Dark",
                    style: TextStyle(color: Colors.white70,
                        fontSize: 11, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
            // Botão editar
            Positioned(
              top: 48, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Text("Editar perfil",
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 52),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Anna Beatriz",
                      style: TextStyle(color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text("@anna.beatriz",
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                // Compatibilidade
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A0005), Color(0xFF0D0002)]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFE50914).withOpacity(0.45)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text("💞", style: TextStyle(fontSize: 13)),
                    SizedBox(width: 5),
                    Text("87% compatível",
                      style: TextStyle(color: Color(0xFFFF6B6B),
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              Text(
                "Cinéfila de plantão 🎬 | Amante de doramas e sci-fi | Leio tudo que posso ✨",
                style: TextStyle(color: Colors.white.withOpacity(0.58),
                    fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),
              // Contadores
              Row(children: [
                _contador("1.2k", "seguidores"),
                const SizedBox(width: 24),
                _contador("340", "seguindo"),
                const SizedBox(width: 24),
                _contador("4.8k", "⭐ stars"),
              ]),
              const SizedBox(height: 16),
              // Obra favorita
              Row(children: [
                Container(
                  width: 48, height: 66,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1B2A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFE50914).withOpacity(0.3)),
                  ),
                  child: const Center(
                    child: Text("🚀", style: TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Obra favorita",
                    style: TextStyle(color: Colors.white.withOpacity(0.35),
                        fontSize: 11)),
                  const SizedBox(height: 4),
                  const Text("Interstellar",
                    style: TextStyle(color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text("Filme • Ficção Científica",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.42), fontSize: 12)),
                ]),
              ]),
              const SizedBox(height: 16),
              // Selos
              Text("Selos conquistados",
                style: TextStyle(color: Colors.white.withOpacity(0.32),
                    fontSize: 12)),
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
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            cor.withOpacity(0.25), cor.withOpacity(0.05)]),
                          border: Border.all(
                              color: cor.withOpacity(0.6), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: cor.withOpacity(0.22),
                              blurRadius: 10),
                          ],
                        ),
                        child: Center(
                          child: Text(emoji,
                              style: const TextStyle(fontSize: 20))),
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
                width: double.infinity, height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {},
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE50914), Color(0xFF6B0000)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE50914).withOpacity(0.28),
                          blurRadius: 14, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Center(
                      child: Text("Seguir",
                        style: TextStyle(color: Colors.white,
                            fontSize: 15, fontWeight: FontWeight.w600)),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFFE50914), Color(0xFFFF6B6B)],
            ).createShader(b),
            child: const Text("📌 Frase fixada",
              style: TextStyle(color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _mostrarFrase = false),
            child: Icon(Icons.close, color: Colors.white38, size: 15),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          '"Não importa o que o tempo faça conosco, o que importa é o que fazemos com ele."\n— Interstellar',
          style: TextStyle(
            color: Colors.white.withOpacity(0.70),
            fontSize: 13, fontStyle: FontStyle.italic, height: 1.5,
          ),
        ),
      ]),
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  cor.withOpacity(0.3), cor.withOpacity(0.05)]),
                border: Border.all(color: cor.withOpacity(0.7), width: 2),
                boxShadow: [
                  BoxShadow(color: cor.withOpacity(0.35), blurRadius: 22)],
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 16),
            Text(nome,
              style: const TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Conquistado por dedicação e paixão pelo entretenimento!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.5),
                  fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cor, cor.withOpacity(0.6)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text("Fechar",
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _contador(String valor, String label) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(valor,
        style: const TextStyle(color: Colors.white, fontSize: 17,
            fontWeight: FontWeight.bold)),
      Text(label,
        style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 12)),
    ]);
  }

  Widget _vazio(String emoji, String msg) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 44)),
        const SizedBox(height: 12),
        Text(msg,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.35),
              fontSize: 14, height: 1.5)),
      ]),
    );
  }
}
