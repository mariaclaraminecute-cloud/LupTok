import 'package:flutter/material.dart';

import 'cadastro_screen.dart';

import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {

  const LoginScreen({super.key});

  @override

  State<LoginScreen> createState() => _LoginScreenState();

}

class _LoginScreenState extends State<LoginScreen>

    with TickerProviderStateMixin {

  late AnimationController _contentController;

  late AnimationController _glowController;

  late AnimationController _bgController;

  late Animation<double> _contentOpacity;

  late Animation<double> _contentSlide;

  late Animation<double> _glowAnim;

  final _emailController = TextEditingController();

  final _senhaController = TextEditingController();

  bool _senhaVisivel = false;

  final List<String> _capas = List.generate(
    33,
    (index) => 'assets/images/capa${index + 1}.jpg',
  );

  late List<String> _shuffledCapas;

  @override

  void initState() {

    super.initState();

    _shuffledCapas = List<String>.from(_capas)..shuffle();

    _bgController = AnimationController(

      vsync: this,

      duration: const Duration(seconds: 60),

    )..repeat();

    _glowController = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 2200),

    )..repeat(reverse: true);

    _glowAnim = Tween<double>(

      begin: 0.2,

      end: 0.7,

    ).animate(

      CurvedAnimation(

        parent: _glowController,

        curve: Curves.easeInOut,

      ),

    );

    _contentController = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 900),

    );

    _contentOpacity = Tween<double>(

      begin: 0.0,

      end: 1.0,

    ).animate(

      CurvedAnimation(

        parent: _contentController,

        curve: Curves.easeOut,

      ),

    );

    _contentSlide = Tween<double>(

      begin: 30.0,

      end: 0.0,

    ).animate(

      CurvedAnimation(

        parent: _contentController,

        curve: Curves.easeOut,

      ),

    );

    _contentController.forward();

  }

  @override

  void dispose() {

    _contentController.dispose();

    _glowController.dispose();

    _bgController.dispose();

    _emailController.dispose();

    _senhaController.dispose();

    super.dispose();

  }

  void _navegarParaOnboarding() {

    Navigator.of(context).pushReplacement(

      PageRouteBuilder(

        pageBuilder: (context, animation, secondaryAnimation) {

          return const OnboardingScreen();

        },

        transitionDuration: const Duration(milliseconds: 700),

        transitionsBuilder:

            (context, animation, secondaryAnimation, child) {

          return FadeTransition(

            opacity: animation,

            child: child,

          );

        },

      ),

    );

  }

  Widget _buildRollingColumn(List<String> images) {

    const itemHeight = 180.0;

    const itemPadding = 8.0;

    const totalItemHeight = itemHeight + itemPadding;

    final allImages = [...images, ...images, ...images];

    final totalHeight = allImages.length * totalItemHeight;

    return SizedBox.expand(

      child: ClipRect(

        child: AnimatedBuilder(

          animation: _bgController,

          builder: (context, child) {

            final maxOffset = totalItemHeight * images.length;

            final offset =

                _bgController.value * maxOffset;

            return OverflowBox(

              minHeight: totalHeight,

              maxHeight: totalHeight,

              alignment: Alignment.topCenter,

              child: Transform.translate(

                offset: Offset(0, -offset),

                child: Column(

                  mainAxisSize: MainAxisSize.min,

                  children: allImages.map((image) {

                    return Padding(

                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 3,
                      ),

                      child: ClipRRect(

                        borderRadius: BorderRadius.circular(12),

                        child: SizedBox(

                          height: itemHeight,

                          width: double.infinity,

                          child: Image.asset(

                            image,

                            fit: BoxFit.cover,

                            errorBuilder: (context, error, stackTrace) {

                              return Container(color: Colors.black);

                            },

                          ),

                        ),

                      ),

                    );

                  }).toList(),

                ),

              ),

            );

          },

        ),

      ),

    );

  }

  @override

  Widget build(BuildContext context) {

    final pageColor = const Color(0xFF000000);
    final softTextColor = const Color(0xFFD09A9F);

    final col1 = _shuffledCapas.sublist(0, 11);

    final col2 = _shuffledCapas.sublist(11, 22);

    final col3 = _shuffledCapas.sublist(22, 33);

    return Scaffold(

      backgroundColor: pageColor,

      resizeToAvoidBottomInset: true,

      body: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(
            fontFamily: 'IMFellFrenchCanon',
          ),
        ),
        child: Stack(

        fit: StackFit.expand,

        children: [

          Row(

            children: [

              Expanded(

                child: _buildRollingColumn(col1),

              ),

              Expanded(

                child: _buildRollingColumn(col2),

              ),

              Expanded(

                child: _buildRollingColumn(col3),

              ),

            ],

          ),

          Container(

            decoration: BoxDecoration(

              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF000000).withValues(alpha: 0.85),
                  const Color(0xFF000000).withValues(alpha: 0.70),
                  const Color(0xFF000000).withValues(alpha: 0.90),
                ],
              ),

            ),

          ),

          AnimatedBuilder(
            animation: _glowAnim,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.5,
                    colors: [
                      const Color(0xFFE50914).withValues(
                        alpha: 0.1 * _glowAnim.value,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF000000).withValues(alpha: 0.95),
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

              height: 200,

              decoration: BoxDecoration(

                gradient: LinearGradient(

                  begin: Alignment.bottomCenter,

                  end: Alignment.topCenter,

                  colors: [

                    const Color(0xFF000000).withValues(alpha: 0.95),

                    Colors.transparent,

                  ],

                ),

              ),

            ),

          ),

          SafeArea(

            child: AnimatedBuilder(

              animation: _contentController,

              builder: (context, child) {

                return Opacity(

                  opacity: _contentOpacity.value,

                  child: Transform.translate(

                    offset: Offset(0, _contentSlide.value),

                    child: child,

                  ),

                );

              },

              child: SingleChildScrollView(

                child: Column(

                  children: [

                    const SizedBox(height: 40),

                    AnimatedBuilder(

                      animation: _glowController,

                      builder: (context, child) {

                        return Column(

                          children: [

                            Hero(
                              tag: 'logo_luptok',
                              transitionOnUserGestures: false,
                              child: 
                              Container(
  
                                decoration: BoxDecoration(
  
                                  borderRadius: BorderRadius.circular(24),
  
                                  boxShadow: [
  
                                    BoxShadow(
  
                                      color: const Color(0xFFE50914)
  
                                          .withValues(
  
                                        alpha: 0.35 * _glowAnim.value,
  
                                      ),
  
                                      blurRadius: 40,
  
                                      spreadRadius: 1,
  
                                    ),
  
                                  ],
  
                                ),
  
                                child: Image.asset(
  
                                  'assets/images/logo.png',
  
                                  height: 70,
  
                                  errorBuilder: (context, error, stackTrace) {
  
                                    return const SizedBox(
  
                                      height: 70,
  
                                      width: 70,
  
                                    );
  
                                  },
  
                                ),
  
                              ),
                            ),

                            const SizedBox(height: 10),

                            ShaderMask(

                              shaderCallback: (bounds) {

                                return const LinearGradient(

                                  colors: [

                                    Color(0xFFD09A9F),

                                    Color(0xFFD09A9F),

                                  ],

                                ).createShader(bounds);

                              },

                            ),

                          ],

                        );

                      },

                    ),

                    const SizedBox(height: 40),

                    Padding(

                      padding: const EdgeInsets.symmetric(horizontal: 28),

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          Text(

                            'Bem-vindo',

                            style: TextStyle(

                              color: softTextColor,

                              fontSize: 30,

                              fontWeight: FontWeight.w400,

                              letterSpacing: 1.1,

                            ),

                          ),

                          const SizedBox(height: 6),

                          Text(

                            'Entre e continue sua jornada',

                            style: TextStyle(

                                color: softTextColor.withValues(alpha: 0.62),

                              fontSize: 15,
                              letterSpacing: 0.2,

                            ),

                          ),

                          const SizedBox(height: 32),

                          _buildTextField(

                            controller: _emailController,

                            hint: 'Email',

                            icon: Icons.email_outlined,

                            obscure: false,

                          ),

                          const SizedBox(height: 16),

                          _buildTextField(

                            controller: _senhaController,

                            hint: 'Senha',

                            icon: Icons.lock_outline,

                            obscure: !_senhaVisivel,

                            suffix: IconButton(

                              icon: Icon(

                                _senhaVisivel

                                    ? Icons.visibility_off_outlined

                                    : Icons.visibility_outlined,

                                color: softTextColor.withValues(alpha: 0.65),

                                size: 20,

                              ),

                              onPressed: () {

                                setState(() {

                                  _senhaVisivel = !_senhaVisivel;

                                });

                              },

                            ),

                          ),

                          const SizedBox(height: 12),

                          Align(

                            alignment: Alignment.centerRight,

                            child: TextButton(

                              onPressed: () {},

                              child: Text(

                                'Esqueceu a senha?',

                                style: TextStyle(

                                  color: const Color(0xFFE50914)

                                      .withValues(alpha: 0.8),

                                  fontSize: 13,

                                ),

                              ),

                            ),

                          ),

                          const SizedBox(height: 20),

                          SizedBox(

                            width: double.infinity,

                            height: 54,

                            child: ElevatedButton(

                              style: ElevatedButton.styleFrom(

                                backgroundColor: const Color(0xFF8F0C14),

                                foregroundColor: const Color(0xFFD9AEB2),

                                elevation: 0,

                                shadowColor: Colors.transparent,

                                padding: EdgeInsets.zero,

                                shape: RoundedRectangleBorder(

                                  borderRadius: BorderRadius.circular(16),

                                ),

                              ),

                              onPressed: _navegarParaOnboarding,

                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8F0C14),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Entrar',
                                    style: TextStyle(
                                      fontSize: 17,
                                      color: Color(0xFFD9AEB2),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),

                            ),

                          ),

                          const SizedBox(height: 24),

                          Row(

                            children: [

                              Expanded(

                                child: Divider(

                                  color: const Color(0xFFD09A9F)

                                      .withValues(alpha: 0.12),

                                  thickness: 1,

                                ),

                              ),

                              Padding(

                                padding: const EdgeInsets.symmetric(

                                  horizontal: 14,

                                ),

                                child: Text(

                                  'ou',

                                  style: TextStyle(

                                    color: const Color(0xFFD09A9F)

                                        .withValues(alpha: 0.35),

                                    fontSize: 13,

                                  ),

                                ),

                              ),

                              Expanded(

                                child: Divider(

                                  color: const Color(0xFFD09A9F)

                                      .withValues(alpha: 0.12),

                                  thickness: 1,

                                ),

                              ),

                            ],

                          ),

                          const SizedBox(height: 20),

                          Center(

                            child: GestureDetector(

                              onTap: () {

                                Navigator.of(context).push(

                                  PageRouteBuilder(

                                    pageBuilder: (context, animation,

                                        secondaryAnimation) {

                                      return const CadastroScreen();

                                    },

                                    transitionDuration:

                                        const Duration(milliseconds: 700),

                                    transitionsBuilder: (context, animation,

                                        secondaryAnimation, child) {

                                      return FadeTransition(

                                        opacity: animation,

                                        child: child,

                                      );

                                    },

                                  ),

                                );

                              },

                              child: RichText(

                                text: TextSpan(

                                  text: 'Não tem conta? ',

                                  style: TextStyle(

                                    color: const Color(0xFFD09A9F)

                                        .withValues(alpha: 0.45),

                                    fontSize: 14,

                                  ),

                                  children: const [

                                    TextSpan(

                                      text: 'Criar conta',

                                      style: TextStyle(

                                        color: Color(0xFFE50914),

                                        fontWeight: FontWeight.w600,

                                      ),

                                    ),

                                  ],

                                ),

                              ),

                            ),

                          ),

                          const SizedBox(height: 30),

                        ],

                      ),

                    ),

                  ],

                ),

              ),

            ),

          ),

        ],

        ),

      ),

    );

  }

  Widget _buildTextField({

    required TextEditingController controller,

    required String hint,

    required IconData icon,

    required bool obscure,

    Widget? suffix,

  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldTextColor = isDark
        ? const Color(0xFFD09A9F)
        : const Color(0xFF6B252D);

    return Container(

      decoration: BoxDecoration(

        borderRadius: BorderRadius.circular(16),

        border: Border.all(

          color: fieldTextColor.withValues(alpha: isDark ? 0.35 : 0.18),

        ),

        color: isDark ? const Color(0xFF25080C).withValues(alpha: 0.75) :
          const Color(0xFFFFE4E4),

      ),

      child: TextField(

        controller: controller,

        obscureText: obscure,

        style: TextStyle(

          color: fieldTextColor,

          fontSize: 15,

        ),

        decoration: InputDecoration(

          hintText: hint,

          hintStyle: TextStyle(

            color: fieldTextColor.withValues(alpha: 0.50),

            fontSize: 15,

          ),

          prefixIcon: Icon(

            icon,

            color: fieldTextColor.withValues(alpha: 0.50),

            size: 20,

          ),

          suffixIcon: suffix,

          border: InputBorder.none,

          contentPadding: const EdgeInsets.symmetric(

            vertical: 18,

            horizontal: 16,

          ),

        ),

      ),

    );

  }

}