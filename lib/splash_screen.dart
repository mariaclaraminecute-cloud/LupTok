import 'dart:async';

import 'package:flutter/material.dart';

import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _capas = List.generate(
    33,
    (index) => 'assets/images/capa${index + 1}.jpg',
  );

  late List<String> _shuffledCapas;

  final ScrollController _scrollController1 = ScrollController();
  final ScrollController _scrollController2 = ScrollController();
  final ScrollController _scrollController3 = ScrollController();

  Timer? _loginTimer;
  Timer? _scrollTimer1;
  Timer? _scrollTimer2;
  Timer? _scrollTimer3;

  late AnimationController _logoAnimationController;
  late Animation<double> _logoFloatAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoGlowAnimation;

  @override
  void initState() {
    super.initState();

    _shuffledCapas = List<String>.from(_capas);
    _shuffledCapas.shuffle();

    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _logoFloatAnimation = Tween<double>(
      begin: -5,
      end: 5,
    ).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _logoScaleAnimation = Tween<double>(
      begin: 0.97,
      end: 1.03,
    ).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _logoGlowAnimation = Tween<double>(
      begin: 0.18,
      end: 0.38,
    ).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startScrolls();
    });

    _loginTimer = Timer(
      const Duration(seconds: 4),
      () {
        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              return const LoginScreen();
            },
            transitionDuration: const Duration(milliseconds: 800),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      },
    );
  }

  void _startScrolls() {
    _scrollColumn(
      _scrollController1,
      const Duration(seconds: 55),
      (timer) => _scrollTimer1 = timer,
    );

    _scrollColumn(
      _scrollController2,
      const Duration(seconds: 70),
      (timer) => _scrollTimer2 = timer,
    );

    _scrollColumn(
      _scrollController3,
      const Duration(seconds: 62),
      (timer) => _scrollTimer3 = timer,
    );
  }

  void _scrollColumn(
    ScrollController controller,
    Duration duration,
    void Function(Timer timer) saveTimer,
  ) {
    if (!mounted || !controller.hasClients) return;

    final maxScroll = controller.position.maxScrollExtent;

    if (maxScroll <= 0) return;

    final timer = Timer(Duration.zero, () {});
    saveTimer(timer);

    controller
        .animateTo(
          (maxScroll + controller.position.viewportDimension) / 3,
          duration: duration,
          curve: Curves.linear,
        )
        .then((_) {
      if (!mounted || !controller.hasClients) return;

      controller.jumpTo(
        controller.offset -
            (maxScroll + controller.position.viewportDimension) / 3,
      );

      final nextTimer = Timer(
        const Duration(milliseconds: 100),
        () {
          if (mounted) {
            _scrollColumn(
              controller,
              duration,
              saveTimer,
            );
          }
        },
      );

      saveTimer(nextTimer);
    });
  }

  @override
  void dispose() {
    _loginTimer?.cancel();
    _scrollTimer1?.cancel();
    _scrollTimer2?.cancel();
    _scrollTimer3?.cancel();

    _scrollController1.dispose();
    _scrollController2.dispose();
    _scrollController3.dispose();

    _logoAnimationController.dispose();

    super.dispose();
  }

  Widget _buildImageColumn(List<String> images) {
    return Column(
      children: List.generate(
        images.length * 3,
        (index) {
          final imageIndex = index % images.length;

          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 4,
              horizontal: 3,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: Opacity(
                  opacity: 0.12,
                  child: Image.asset(
                    images[imageIndex],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFFF9F4F2),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: _logoAnimationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _logoFloatAnimation.value),
          child: Transform.scale(
            scale: _logoScaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFA8BA).withValues(
                      alpha: _logoGlowAnimation.value,
                    ),
                    blurRadius: 38,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
      child: Hero(
        tag: 'logo_luptok',
        transitionOnUserGestures: false,
        child: Image.asset(
          'assets/images/logo.png',
          width: 170,
          height: 170,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox(
              width: 170,
              height: 170,
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> col1 = _shuffledCapas.sublist(0, 11);
    final List<String> col2 = _shuffledCapas.sublist(11, 22);
    final List<String> col3 = _shuffledCapas.sublist(22, 33);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F4F2),
      body: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController1,
                  physics: const NeverScrollableScrollPhysics(),
                  child: _buildImageColumn(col1),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController2,
                  physics: const NeverScrollableScrollPhysics(),
                  child: _buildImageColumn(col2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController3,
                  physics: const NeverScrollableScrollPhysics(),
                  child: _buildImageColumn(col3),
                ),
              ),
            ],
          ),

          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: const Color(0xFFF9F4F2).withValues(alpha: 0.58),
              ),
            ),
          ),

          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.7,
                    colors: [
                      const Color(0xFFFFE8EC).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAnimatedLogo(),
                      const SizedBox(height: 20),
                      const Text(
                        'LupTok',
                        style: TextStyle(
                          color: Color(0xFFA85D63),
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'filmes  /  séries  /  livros',
                        style: TextStyle(
                          color: const Color(0xFF7D171D).withValues(
                            alpha: 0.82,
                          ),
                          fontSize: 12,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  top: 22,
                  left: 24,
                  right: 24,
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF9F555B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'LUPTOK / 01',
                        style: TextStyle(
                          color: Color(0xFF9F555B),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.7,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'SEU UNIVERSO',
                        style: TextStyle(
                          color: const Color(0xFF9F555B).withValues(
                            alpha: 0.78,
                          ),
                          fontSize: 9,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      28,
                      0,
                      28,
                      28,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'PREPARANDO SUA PRÓXIMA HISTÓRIA',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF7D171D)
                                      .withValues(alpha: 0.78),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '01 / 04',
                              style: TextStyle(
                                color: Color(0xFF9F555B),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFFBB7575).withValues(
                                alpha: 0.82,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Carregando...',
                          style: TextStyle(
                            color: const Color(0xFF7D171D).withValues(
                              alpha: 0.72,
                            ),
                            fontSize: 10,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
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
}