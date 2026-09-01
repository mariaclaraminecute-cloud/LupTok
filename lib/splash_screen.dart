import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final List<String> _capas = [
    'assets/images/capa1.jpg',
    'assets/images/capa2.jpg',
    'assets/images/capa3.jpg',
    'assets/images/capa4.jpg',
    'assets/images/capa5.jpg',
    'assets/images/capa6.jpg',
    'assets/images/capa7.jpg',
    'assets/images/capa8.jpg',
    'assets/images/capa9.jpg',
    'assets/images/capa10.jpg',
    'assets/images/capa11.jpg',
    'assets/images/capa12.jpg',
    'assets/images/capa13.jpg',
    'assets/images/capa14.jpg',
    'assets/images/capa15.jpg',
    'assets/images/capa16.jpg',
    'assets/images/capa17.jpg',
    'assets/images/capa18.jpg',
    'assets/images/capa19.jpg',
  ];

  late List<String> _shuffledCapas;

  final ScrollController _scrollController1 = ScrollController();
  final ScrollController _scrollController2 = ScrollController();
  final ScrollController _scrollController3 = ScrollController();

  Timer? _loginTimer;
  Timer? _scrollTimer1;
  Timer? _scrollTimer2;
  Timer? _scrollTimer3;

  @override
  void initState() {
    super.initState();

    _shuffledCapas = List<String>.from(_capas);
    _shuffledCapas.shuffle();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startScrolls();
    });

    _loginTimer = Timer(const Duration(seconds: 4), () {
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
    });
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
          maxScroll,
          duration: duration,
          curve: Curves.linear,
        )
        .then((_) {
      if (!mounted || !controller.hasClients) return;

      controller.jumpTo(0);

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
                child: Image.asset(
                  images[imageIndex],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.black,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> col1 = _shuffledCapas.sublist(0, 7);
    final List<String> col2 = _shuffledCapas.sublist(7, 14);
    final List<String> col3 = _shuffledCapas.sublist(14, 19);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
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

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),

          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 0.6,
                colors: [
                  const Color(0xFFE50914).withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.95),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.95),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 50),

                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE50914).withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 100,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 100,
                          color: Colors.black,
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'LupTok',
                  style: TextStyle(
                    color: Color(0xFFF5E6D3),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Seu universo de entretenimento',
                  style: TextStyle(
                    color: const Color(0xFFF5E6D3).withValues(alpha: 0.5),
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),

                const Spacer(),

                Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            const Color(0xFFE50914).withValues(alpha: 0.8),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Carregando...',
                        style: TextStyle(
                          color: const Color(0xFFF5E6D3)
                              .withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
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