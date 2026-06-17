import 'package:flutter/material.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _bgPulse;
  late Animation<Offset> _slideIn;
  late Animation<double> _pulseAnim;

  // Seleções
  final Set<String> _objetivos = {}; // pode ter 'entretenimento' e/ou 'estudo'
  final Set<String> _tiposSelecionados = {};
  final Set<String> _generosEntretenimento = {};
  final Set<String> _areasEstudo = {};

  int _etapa = 0;

  // Etapas dinâmicas baseadas no objetivo
  List<String> get _fluxo {
    final f = <String>['objetivo'];
    if (_objetivos.contains('entretenimento')) {
      f.add('tipos');
      f.add('generos');
    }
    if (_objetivos.contains('estudo')) {
      f.add('areas');
    }
    return f;
  }

  String get _etapaAtual => _etapa < _fluxo.length ? _fluxo[_etapa] : 'fim';

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _slideIn = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _bgPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bgPulse, curve: Curves.easeInOut),
    );

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _bgPulse.dispose();
    super.dispose();
  }

  bool get _podeProsseguir {
    switch (_etapaAtual) {
      case 'objetivo':
        return _objetivos.isNotEmpty;
      case 'tipos':
        return _tiposSelecionados.isNotEmpty;
      case 'generos':
        return _generosEntretenimento.isNotEmpty;
      case 'areas':
        return _areasEstudo.isNotEmpty;
      default:
        return false;
    }
  }

  bool get _ehUltimaEtapa => _etapa == _fluxo.length - 1;

  void _avancar() async {
    if (!_podeProsseguir) return;

   if (_ehUltimaEtapa) {
  Navigator.pushReplacement(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => const HomeScreen(),
      transitionDuration: const Duration(milliseconds: 800),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
  return;
}

    await _slideController.reverse();
    setState(() => _etapa++);
    _slideController.forward();
  }

  void _voltar() async {
    if (_etapa == 0) return;
    await _slideController.reverse();
    setState(() => _etapa--);
    _slideController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final totalEtapas = _fluxo.length;

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Gradiente de fundo animado
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.5),
                  radius: 1.2,
                  colors: [
                    Color.lerp(
                      const Color(0xFF1A0005),
                      const Color(0xFF0D0002),
                      _pulseAnim.value,
                    )!,
                    const Color(0xFF080808),
                  ],
                ),
              ),
            ),
          ),

          // Ornamento circular decorativo
          Positioned(
            top: -80, right: -80,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 260, height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE50914).withOpacity(0.08 + _pulseAnim.value * 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Ornamento circular inferior
          Positioned(
            bottom: -60, left: -60,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B0000).withOpacity(0.07 + _pulseAnim.value * 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Conteúdo
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: [
                      // Botão voltar
                      GestureDetector(
                        onTap: _etapa > 0 ? _voltar : null,
                        child: AnimatedOpacity(
                          opacity: _etapa > 0 ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white60, size: 16,
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Barra de progresso
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 140, height: 5,
                              child: LinearProgressIndicator(
                                value: totalEtapas > 0
                                    ? (_etapa + 1) / totalEtapas
                                    : 0,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFFE50914)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${_etapa + 1} de $totalEtapas",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Conteúdo animado
                Expanded(
                  child: AnimatedBuilder(
                    animation: _slideController,
                    builder: (context, child) => SlideTransition(
                      position: _slideIn,
                      child: FadeTransition(
                        opacity: _slideController,
                        child: child,
                      ),
                    ),
                    child: _buildConteudo(),
                  ),
                ),

                // Botão avançar
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
                  child: AnimatedOpacity(
                    opacity: _podeProsseguir ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 250),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _podeProsseguir ? _avancar : null,
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE50914), Color(0xFF6B0000)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _podeProsseguir
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFE50914).withOpacity(0.4),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              _ehUltimaEtapa ? "Começar  🚀" : "Próximo",
                              style: const TextStyle(
                                fontSize: 17,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConteudo() {
    switch (_etapaAtual) {
      case 'objetivo':
        return _buildObjetivo();
      case 'tipos':
        return _buildTipos();
      case 'generos':
        return _buildGeneros();
      case 'areas':
        return _buildAreas();
      default:
        return const SizedBox();
    }
  }

  // ── Etapa: Objetivo (multi-select) ─────────────────────────────────
  Widget _buildObjetivo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitulo("Olá! 👋", "O que você busca\naqui?"),
          Text(
            "Pode escolher os dois — sua experiência\nserá personalizada para cada um.",
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14, height: 1.5),
          ),

          const SizedBox(height: 36),

          _buildObjetivoCard(
            emoji: "🎬",
            titulo: "Entretenimento",
            subtitulo: "Filmes, séries, livros de ficção",
            valor: "entretenimento",
            gradiente: [const Color(0xFF1A0A00), const Color(0xFF0F0500)],
            cor: const Color(0xFFFF6B35),
          ),
          const SizedBox(height: 16),
          _buildObjetivoCard(
            emoji: "📚",
            titulo: "Estudo",
            subtitulo: "Desenvolvimento pessoal e profissional",
            valor: "estudo",
            gradiente: [const Color(0xFF001A10), const Color(0xFF000F08)],
            cor: const Color(0xFF4CAF50),
          ),
        ],
      ),
    );
  }

  Widget _buildObjetivoCard({
    required String emoji,
    required String titulo,
    required String subtitulo,
    required String valor,
    required List<Color> gradiente,
    required Color cor,
  }) {
    final sel = _objetivos.contains(valor);
    return GestureDetector(
      onTap: () => setState(() {
        sel ? _objetivos.remove(valor) : _objetivos.add(valor);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: sel
              ? LinearGradient(
                  colors: gradiente,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: sel ? null : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? cor.withOpacity(0.6) : Colors.white12,
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: sel ? cor.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                    style: TextStyle(
                      color: sel ? Colors.white : Colors.white70,
                      fontSize: 17, fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitulo,
                    style: TextStyle(
                      color: Colors.white.withOpacity(sel ? 0.55 : 0.35),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sel ? cor : Colors.transparent,
                border: Border.all(
                  color: sel ? cor : Colors.white24, width: 2,
                ),
              ),
              child: sel
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Etapa: Tipos de mídia ──────────────────────────────────────────
  Widget _buildTipos() {
    final tipos = [
      ("🎬", "Filmes", "filmes"),
      ("📺", "Séries", "series"),
      ("📖", "Livros", "livros"),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitulo("Quase lá! 🍿", "O que você mais\ngosta de consumir?"),
          Text("Pode selecionar mais de um.",
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14)),

          const SizedBox(height: 36),

          ...tipos.map((t) {
            final (emoji, nome, valor) = t;
            final sel = _tiposSelecionados.contains(valor);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: GestureDetector(
                onTap: () => setState(() {
                  sel ? _tiposSelecionados.remove(valor)
                      : _tiposSelecionados.add(valor);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: sel
                        ? const LinearGradient(
                            colors: [Color(0xFF1A0005), Color(0xFF0D0002)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: sel ? null : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: sel
                          ? const Color(0xFFE50914).withOpacity(0.6)
                          : Colors.white12,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 16),
                      Text(nome,
                        style: TextStyle(
                          color: sel ? Colors.white : Colors.white60,
                          fontSize: 17,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                      const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sel ? const Color(0xFFE50914) : Colors.transparent,
                          border: Border.all(
                            color: sel ? const Color(0xFFE50914) : Colors.white24,
                            width: 2,
                          ),
                        ),
                        child: sel
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Etapa: Gêneros de entretenimento ──────────────────────────────
  Widget _buildGeneros() {
    final generos = [
      ("❤️", "Romance"), ("🧙", "Fantasia"), ("🚀", "Ficção Científica"),
      ("👻", "Terror"), ("🔍", "Suspense"), ("🕵️", "Mistério"),
      ("🎭", "Drama"), ("😂", "Comédia"), ("💥", "Ação"),
      ("🗺️", "Aventura"), ("🔫", "Crime"), ("⚔️", "Histórico"),
      ("🎌", "Anime"), ("🇰🇷", "K-Drama"),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitulo("Última etapa! 🎉", "Quais gêneros\nvocê curte?"),
          Text("Selecione quantos quiser.",
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14)),
          const SizedBox(height: 28),
          _buildChips(
            itens: generos,
            selecionados: _generosEntretenimento,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Etapa: Áreas de estudo ─────────────────────────────────────────
  Widget _buildAreas() {
    final areas = [
      ("💰", "Dinheiro e Investimentos"), ("💻", "Tecnologia"),
      ("🖥️", "Programação"), ("🧠", "Psicologia"),
      ("📜", "História"), ("🌍", "Idiomas"),
      ("❤️", "Saúde"), ("💞", "Relacionamentos"),
      ("🚀", "Empreendedorismo"), ("📣", "Marketing"),
      ("🔬", "Ciências"), ("🎨", "Arte"),
      ("🤔", "Filosofia"), ("🏛️", "Política"),
      ("🎓", "Educação"), ("📰", "Atualidades"),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitulo("Ótima escolha! 📚", "Quais áreas te\ninteressam?"),
          Text("Selecione todas que quiser.",
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14)),
          const SizedBox(height: 28),
          _buildChips(
            itens: areas,
            selecionados: _areasEstudo,
            cor: const Color(0xFF4CAF50),
            gradiente: [const Color(0xFF001A10), const Color(0xFF000F08)],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Helper: chips de seleção múltipla ─────────────────────────────
  Widget _buildChips({
    required List<(String, String)> itens,
    required Set<String> selecionados,
    Color cor = const Color(0xFFE50914),
    List<Color> gradiente = const [Color(0xFF1A0005), Color(0xFF0D0002)],
  }) {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: itens.map((item) {
        final (emoji, nome) = item;
        final sel = selecionados.contains(nome);
        return GestureDetector(
          onTap: () => setState(() {
            sel ? selecionados.remove(nome) : selecionados.add(nome);
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              gradient: sel
                  ? LinearGradient(colors: gradiente,
                      begin: Alignment.topLeft, end: Alignment.bottomRight)
                  : null,
              color: sel ? null : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: sel ? cor.withOpacity(0.7) : Colors.white.withOpacity(0.10),
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(nome,
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.white54,
                    fontSize: 14,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Helper: título da etapa ────────────────────────────────────────
  Widget _buildTitulo(String subtitulo, String titulo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFE50914), Color(0xFFFF6B6B)],
          ).createShader(bounds),
          child: Text(subtitulo,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(height: 8),
        Text(titulo,
          style: const TextStyle(
            color: Colors.white, fontSize: 32,
            fontWeight: FontWeight.bold, height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
