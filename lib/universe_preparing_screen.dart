import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'app_preferences.dart';
import 'home_screen.dart';
import 'interest_utils.dart';

class UniversePreparingScreen extends StatefulWidget {
  final List<Map<String, dynamic>> obras;
  final List<String> tipos;
  final List<String> generos;

  const UniversePreparingScreen({
    super.key,
    required this.obras,
    required this.tipos,
    required this.generos,
  });

  @override
  State<UniversePreparingScreen> createState() =>
      _UniversePreparingScreenState();
}

class _UniversePreparingScreenState extends State<UniversePreparingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ambient;
  late final AnimationController _entrance;
  String _status = 'Organizando seus interesses...';
  String? _erro;
  bool _preparando = false;
  int _etapaVisual = 0;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _preparar());
  }

  @override
  void dispose() {
    _ambient.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _definirStatus(String status, int etapa) {
    if (!mounted) return;
    setState(() {
      _status = status;
      _etapaVisual = etapa;
    });
  }

  Future<void> _preparar() async {
    if (_preparando) return;
    _preparando = true;
    if (mounted) setState(() => _erro = null);
    try {
      _definirStatus('Organizando seus interesses...', 0);
      for (final obra in widget.obras) {
        await ApiService.adicionarObra(
          titulo: obra['titulo'] as String,
          tipo: obra['tipo'] as String,
          descricao: obra['descricao'] as String? ?? '',
          generos: (obra['generos'] as List?)?.whereType<String>().toList() ??
              const [],
          palavrasChave:
              (obra['palavras_chave'] as List?)?.whereType<String>().toList() ??
                  const [],
        );
      }

      _definirStatus('Descobrindo seu universo...', 1);
      final obrasSalvas = await ApiService.listarObras();
      for (final selecionada in widget.obras) {
        Map<String, dynamic>? obraSalva;
        for (final obra in obrasSalvas) {
          if (normalizeInterest(obra['titulo']?.toString() ?? '') ==
                  normalizeInterest(selecionada['titulo']?.toString() ?? '') &&
              normalizeInterest(obra['tipo']?.toString() ?? '') ==
                  normalizeInterest(selecionada['tipo']?.toString() ?? '')) {
            obraSalva = obra;
            break;
          }
        }
        if (obraSalva == null || obraSalva['id'] == null) {
          throw Exception(
            'Não foi possível encontrar "${selecionada['titulo']}" no catálogo.',
          );
        }
        await ApiService.avaliarObra(id: obraSalva['id'], souFa: true);
      }

      _definirStatus('Preparando suas recomendações...', 2);
      await ApiService.listarVideos();
      await ApiService.listarContas();

      _definirStatus('Tudo pronto para começar!', 3);
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setStringList('perfil_tipos', widget.tipos);
      await preferencias.setStringList('perfil_generos', widget.generos);
      await preferencias.setBool('onboarding_completed', true);

      if (!mounted) return;
      Navigator.pushReplacement(context, luptokFadeRoute(const HomeScreen()));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _erro = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      _preparando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppPalette.isDark(context);
    final foreground = AppPalette.primaryText(context);
    final secondary = AppPalette.mutedText(context);
    final accent = AppPalette.button(context);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppPalette.background(context),
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [Color(0xFF1C1117), Color(0xFF321B27), Color(0xFF170E14)]
                    : const [Color(0xFFFFF8F9), Color(0xFFFFE9EC), Color(0xFFFFF5F6)],
                stops: const [0, 0.52, 1],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _ambient,
            builder: (context, _) => CustomPaint(
              painter: _StoryDustPainter(
                progress: _ambient.value,
                color: dark ? const Color(0xFFF5B9C8) : const Color(0xFFC17D91),
              ),
            ),
          ),
          Positioned(
            top: -size.width * 0.48,
            right: -size.width * 0.42,
            child: _GlowOrb(
              diameter: size.width * 1.15,
              color: const Color(0xFFE8A5B7).withValues(alpha: dark ? .12 : .22),
            ),
          ),
          Positioned(
            bottom: -size.width * 0.54,
            left: -size.width * 0.44,
            child: _GlowOrb(
              diameter: size.width * 1.12,
              color: const Color(0xFFD39BAE).withValues(alpha: dark ? .10 : .16),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: FadeTransition(
                    opacity: CurvedAnimation(parent: _entrance, curve: Curves.easeOut),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'UM NOVO CAPÍTULO COMEÇA',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: secondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3.1,
                          ),
                        ),
                        const SizedBox(height: 38),
                        AnimatedBuilder(
                          animation: _ambient,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(0, math.sin(_ambient.value * 2 * math.pi) * 5),
                            child: child,
                          ),
                          child: Container(
                            width: 190,
                            height: 190,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFFE5A0B2).withValues(alpha: dark ? .20 : .25),
                                  const Color(0xFFE5A0B2).withValues(alpha: .04),
                                  Colors.transparent,
                                ],
                              ),
                              border: Border.all(
                                color: accent.withValues(alpha: dark ? .25 : .18),
                                width: 1,
                              ),
                            ),
                            child: Hero(
                              tag: 'logo_luptok',
                              child: Image.asset(
                                AppPalette.logo(context),
                                width: 124,
                                height: 124,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.auto_stories_rounded,
                                  size: 76,
                                  color: accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Bem-vindo ao seu\nuniverso de histórias.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'IMFellFrenchCanon',
                            color: foreground,
                            fontSize: size.width < 360 ? 30 : 35,
                            height: 1.16,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Cada história tem algo especial.\nEstamos encontrando as suas próximas favoritas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: secondary,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 40),
                        if (_erro == null) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              final selected = index <= _etapaVisual;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 450),
                                curve: Curves.easeInOut,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: selected && index == _etapaVisual ? 38 : 19,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? accent
                                      : accent.withValues(alpha: .18),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 22),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            child: Text(
                              _status,
                              key: ValueKey(_status),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: foreground,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: .15,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.7,
                              color: accent.withValues(alpha: .7),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: accent.withValues(alpha: .20)),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.wifi_off_rounded, color: accent, size: 25),
                                const SizedBox(height: 10),
                                Text(
                                  _erro!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: foreground, fontSize: 13, height: 1.45),
                                ),
                                const SizedBox(height: 15),
                                FilledButton.icon(
                                  onPressed: _preparando ? null : _preparar,
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text('Tentar novamente'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: accent,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 45),
                        Container(
                          width: 32,
                          height: 1,
                          color: accent.withValues(alpha: .3),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'LUPTOK  ·  LIVROS  ·  FILMES  ·  SÉRIES',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: secondary.withValues(alpha: .8),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double diameter;
  final Color color;
  const _GlowOrb({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, Colors.transparent]),
          ),
        ),
      );
}

class _StoryDustPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _StoryDustPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(19);
    for (var i = 0; i < 34; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final y = (baseY - progress * (12 + i % 9) + size.height) % size.height;
      final twinkle = .22 + .24 * (1 + math.sin(progress * math.pi * 2 + i * .8));
      final paint = Paint()..color = color.withValues(alpha: twinkle);
      canvas.drawCircle(Offset(x, y), i % 5 == 0 ? 1.8 : .9, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StoryDustPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
