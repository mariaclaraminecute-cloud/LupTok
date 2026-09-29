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
  final Set<String> _tiposSelecionados = {};
  final Set<String> _generosEntretenimento = {};

  int _etapa = 0;

  // Etapas do onboarding
  List<String> get _fluxo => ['tipos', 'generos'];

  String get _etapaAtual => _etapa < _fluxo.length ? _fluxo[_etapa] : 'fim';

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _slideIn = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _bgPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bgPulse, curve: Curves.easeInOut));

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
      case 'tipos':
        return _tiposSelecionados.isNotEmpty;
      case 'generos':
        return _generosEntretenimento.isNotEmpty;
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
    if (_etapa == 0) {
      Navigator.pop(context);
      return;
    }
    await _slideController.reverse();
    setState(() => _etapa--);
    _slideController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final totalEtapas = _fluxo.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFFE9E9),
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
                      const Color(0xFFFFD6D8),
                      const Color(0xFFFFE9E9),
                      _pulseAnim.value,
                    )!,
                    const Color(0xFFFFE9E9),
                  ],
                ),
              ),
            ),
          ),

          // Ornamento circular decorativo
          Positioned(
            top: -80,
            right: -80,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(
                        0xFFBB7575,
                      ).withOpacity(0.08 + _pulseAnim.value * 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Ornamento circular inferior
          Positioned(
            bottom: -60,
            left: -60,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(
                        0xFFB8787C,
                      ).withOpacity(0.07 + _pulseAnim.value * 0.05),
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
                        onTap: _voltar,
                        child: AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFB8787C).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFFBB7575,
                                ).withOpacity(0.18),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Color(0xFFBB7575),
                              size: 16,
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
                              width: 140,
                              height: 5,
                              child: LinearProgressIndicator(
                                value: totalEtapas > 0
                                    ? (_etapa + 1) / totalEtapas
                                    : 0,
                                backgroundColor: const Color(
                                  0xFFB8787C,
                                ).withOpacity(0.28),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFBB7575),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${_etapa + 1} de $totalEtapas",
                            style: TextStyle(
                              color: const Color.fromARGB(
                                255,
                                200,
                                122,
                                127,
                              ).withOpacity(0.55),
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
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _podeProsseguir ? _avancar : null,
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color.fromARGB(255, 200, 145, 149),
                                Color.fromARGB(255, 200, 145, 149),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _podeProsseguir
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFB8787C,
                                      ).withOpacity(0.4),
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
                                color: Color(0xFFFFE9E9),
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
      case 'tipos':
        return _buildTipos();
      case 'generos':
        return _buildGeneros();
      default:
        return const SizedBox();
    }
  }

  // ── Etapa: Tipos de mídia ──────────────────────────────────────────
  Widget _buildTipos() {
    final tipos = [
      ("assets/images/filme.png", "Filmes", "filmes"),
      ("assets/images/serie.png", "Séries", "series"),
      ("assets/images/livro.png", "Livros", "livros"),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitulo("O que você mais\ngosta de consumir?"),
          Text(
            "Pode selecionar mais de um.",
            style: TextStyle(
              color: const Color(0xFFB8787C).withOpacity(0.70),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 22),

          ...tipos.map((t) {
            final (imagem, nome, valor) = t;
            final sel = _tiposSelecionados.contains(valor);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => setState(() {
                  sel
                      ? _tiposSelecionados.remove(valor)
                      : _tiposSelecionados.add(valor);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 118,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: sel
                        ? const LinearGradient(
                            colors: [Color(0xFFBB7575), Color(0xFFBB7575)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: sel
                        ? null
                        : const Color(0xFFB8787C).withOpacity(0.20),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: sel
                          ? const Color(0xFFB8787C).withOpacity(0.75)
                          : const Color(0xFFB8787C).withOpacity(0.25),
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          imagem,
                          width: 68,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 68,
                            height: 72,
                            color: const Color(0xFF7D171D),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFFFFE9E9),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          nome,
                          style: TextStyle(
                            color: sel
                                ? const Color(0xFFFFE9E9)
                                : const Color(0xFFB8787C),
                            fontSize: 17,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
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
      ("assets/images/romance.png", "Romance"),
      ("assets/images/fantasia.png", "Fantasia"),
      ("assets/images/ficcao.png", "Ficção"),
      ("assets/images/terror.png", "Terror"),
      ("assets/images/suspense.png", "Suspense"),
      ("assets/images/misterio.png", "Mistério"),
      ("assets/images/drama.png", "Drama"),
      ("assets/images/comedia.png", "Comédia"),
      ("assets/images/acao.png", "Ação"),
      ("assets/images/aventura.png", "Aventura"),
      ("assets/images/crime.png", "Crime"),
      ("assets/images/historico.png", "Histórico"),
      ("assets/images/anime.png", "Anime"),
      ("assets/images/dorama.png", "Dorama"),
      ("assets/images/esporte.png", "Esporte"),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitulo("Quais gêneros\nvocê curte?"),

          Text(
            "Selecione quantos quiser.",
            style: TextStyle(
              color: const Color(0xFFB8787C).withOpacity(0.70),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 28),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: generos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 11,
              mainAxisSpacing: 11,
              childAspectRatio: 1.28,
            ),
            itemBuilder: (context, index) {
              final (imagem, nome) = generos[index];
              final sel = _generosEntretenimento.contains(nome);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    sel
                        ? _generosEntretenimento.remove(nome)
                        : _generosEntretenimento.add(nome);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFFBB7575)
                        : const Color(0xFFDEB2B4),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: sel
                          ? const Color(0xFF9E5555)
                          : const Color(0xFFD7A5A7),
                      width: sel ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        imagem,
                        width: 42,
                        height: 42,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          size: 34,
                          color: Color(0xFF7D171D),
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        nome,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: sel
                              ? const Color(0xFFFFE9E9)
                              : const Color(0xFF7D1717),
                          fontSize: 14,
                          fontFamily: 'Quicksand',
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Helper: chips de seleção múltipla ─────────────────────────────

  Widget _buildTitulo(String titulo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: Color(0xFFB8787C),
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
