import 'package:flutter/material.dart';
import 'login_screen.dart';
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _logoController;
  late AnimationController _glowController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _slideAnim;
  late Animation<double> _scaleExitAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _shimmerAnim;
  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.25, end: 0.75).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
    _scaleAnim = Tween<double>(begin: 0.15, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.48, curve: Curves.elasticOut),
      ),
    );
    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.18, curve: Curves.easeIn),
      ),
    );
    _scaleExitAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.66, 0.76, curve: Curves.easeOut),
      ),
    );
    _slideAnim = Tween<double>(begin: 0.0, end: -700.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.76, 1.0, curve: Curves.easeInQuart),
      ),
    );
    _logoController.forward();
    _logoController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const LoginScreen(),
            transitionDuration: const Duration(milliseconds: 900),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      }
    });
  }
  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    _glowController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }
  Widget _buildColumn(List<String> images, double speed) {
    final allImages = [...images, ...images, ...images];
    return LayoutBuilder(builder: (context, constraints) {
      final height = constraints.maxHeight;
      return ClipRect(
        child: AnimatedBuilder(
          animation: _bgController,
          builder: (context, child) {
            const totalItemHeight = 228.0;
            final totalHeight = allImages.length * totalItemHeight;
            final offset =
                (_bgController.value * height * speed) % totalItemHeight;
            return OverflowBox(
              minHeight: totalHeight + height,
              maxHeight: totalHeight + height,
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: Offset(0, -offset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: allImages.map((image) {
                    return Padding(
                      padding: const EdgeInsets.all(4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(image,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      );
    });
  }
  @override
  Widget build(BuildContext context) {
    final images = [
      "assets/images/capa1.jpg", "assets/images/capa2.jpg",
      "assets/images/capa3.jpg", "assets/images/capa4.jpg",
      "assets/images/capa5.jpg", "assets/images/capa6.jpg",
      "assets/images/capa7.jpg", "assets/images/capa8.jpg",
      "assets/images/capa9.jpg", "assets/images/capa10.jpg",
      "assets/images/capa11.jpg", "assets/images/capa12.jpg",
      "assets/images/capa13.jpg", "assets/images/capa14.jpg",
      "assets/images/capa15.jpg",
    ];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Row(children: [
            Expanded(child: _buildColumn([images[0], images[3], images[6], images[9], images[12]], 1.0)),
            Expanded(child: _buildColumn([images[1], images[4], images[7], images[10], images[13]], 1.2)),
            Expanded(child: _buildColumn([images[2], images[5], images[8], images[11], images[14]], 0.8)),
          ]),
          // Overlay transparente — fotos aparecem
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.68),
                  Colors.black.withOpacity(0.52),
                  Colors.black.withOpacity(0.68),
                ],
              ),
            ),
          ),
          // Glow vinho central
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.6,
                  colors: [
                    const Color(0xFF8B0000).withOpacity(0.15 * _glowAnim.value),
                    const Color(0xFF4A0010).withOpacity(0.06 * _glowAnim.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Partículas douradas
          AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => CustomPaint(
              painter: _ParticlePainter(_bgController.value),
              size: Size.infinite,
            ),
          ),
          // Vinheta superior
          Positioned(top: 0, left: 0, right: 0,
            child: Container(height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.92), Colors.transparent],
                ),
              ),
            ),
          ),
          // Vinheta inferior
          Positioned(bottom: 0, left: 0, right: 0,
            child: Container(height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.95), Colors.transparent],
                ),
              ),
            ),
          ),
          // Logo
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_logoController, _glowController, _shimmerController]),
              builder: (context, child) {
                final scale = _scaleAnim.value * _scaleExitAnim.value;
                return Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: _opacityAnim.value,
                      child: Stack(alignment: Alignment.center, children: [
                        Container(
                          width: 300, height: 300,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [
                              const Color(0xFF6B0000).withOpacity(0.18 * _glowAnim.value),
                              const Color(0xFF3D0010).withOpacity(0.07 * _glowAnim.value),
                              Colors.transparent,
                            ]),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF6B0000).withOpacity(0.45 * _glowAnim.value), blurRadius: 60, spreadRadius: 2),
                              BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.05 * _glowAnim.value), blurRadius: 30),
                              BoxShadow(color: Colors.white.withOpacity(0.05 * _glowAnim.value), blurRadius: 20),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Stack(alignment: Alignment.center, children: [
                              Image.asset('assets/images/logo.png', width: 200),
                              Positioned.fill(
                                child: OverflowBox(
                                  maxWidth: double.infinity,
                                  child: Transform.translate(
                                    offset: Offset(_shimmerAnim.value * 260, 0),
                                    child: Transform.rotate(
                                      angle: 0.35,
                                      child: Container(
                                        width: 45,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [
                                            Colors.white.withOpacity(0.0),
                                            Colors.white.withOpacity(0.18),
                                            Colors.white.withOpacity(0.0),
                                          ]),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter(this.progress);
  static const _particles = [
    (0.15, 0.30, 2.2), (0.82, 0.60, 1.7), (0.45, 0.80, 1.9),
    (0.70, 0.20, 1.4), (0.30, 0.55, 1.1), (0.60, 0.45, 2.0),
    (0.88, 0.85, 1.5), (0.12, 0.70, 1.8), (0.50, 0.15, 1.3),
    (0.25, 0.90, 2.0), (0.75, 0.38, 1.6), (0.40, 0.62, 1.2),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _particles.length; i++) {
      final (px, py, radius) = _particles[i];
      final phase = (progress * 0.4 + i * 0.083) % 1.0;
      final y = (py - phase * 0.35) * size.height;
      final opacity = phase < 0.15 ? phase / 0.15 : phase > 0.85 ? (1 - phase) / 0.15 : 1.0;
      canvas.drawCircle(
        Offset(px * size.width, y), radius,
        Paint()
          ..color = const Color(0xFFFFD700).withOpacity(0.22 * opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }
  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
