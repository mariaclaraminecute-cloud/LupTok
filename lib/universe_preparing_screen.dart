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
  late final AnimationController _spin;
  late final AnimationController _pulse;
  String _status = 'Organizando seus interesses...';
  String? _erro;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6200),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _preparar());
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _definirStatus(String status) {
    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<void> _preparar() async {
    setState(() => _erro = null);
    try {
      _definirStatus('Organizando seus interesses...');
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

      _definirStatus('Descobrindo seu universo...');
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

      _definirStatus('Preparando recomendações...');
      await ApiService.listarVideos();
      await ApiService.listarContas();

      _definirStatus('Seu LupTok está quase pronto...');
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppPalette.isDark(context);
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.2),
                radius: 1.1,
                colors: dark
                    ? const [Color(0xFF54242B), Color(0xFF371111)]
                    : const [Color(0xFFFFF4F5), Color(0xFFF4C7CC)],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _spin,
            builder: (context, _) {
              return CustomPaint(
                painter: _ConstellationPainter(
                  progress: _spin.value,
                  color: AppPalette.gold.withValues(alpha: dark ? 0.55 : 0.42),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
              child: Column(
                children: [
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 0.96 + _pulse.value * 0.06,
                        child: child,
                      );
                    },
                    child: Hero(
                      tag: 'logo_luptok',
                      child: Image.asset(
                        AppPalette.logo(context),
                        width: 148,
                        height: 148,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'LupTok',
                    style: TextStyle(
                      color: AppPalette.primaryText(context),
                      fontFamily: 'IMFellFrenchCanon',
                      fontSize: 36,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_erro == null) ...[
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppPalette.accent(context),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: Text(
                        _status,
                        key: ValueKey(_status),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppPalette.text(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      _erro!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppPalette.text(context)),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _preparar,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.button(context),
                      ),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'Preparando seu universo de filmes, séries e livros',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppPalette.mutedText(context),
                      letterSpacing: 0.3,
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
}

class _ConstellationPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ConstellationPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final random = math.Random(7);
    for (var i = 0; i < 28; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final twinkle =
          0.35 + (math.sin((progress * math.pi * 2) + i) + 1) * 0.25;
      canvas.drawCircle(
        Offset(dx, dy),
        1.4 + (i % 3) * 0.6,
        paint..color = color.withValues(alpha: twinkle),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
