import 'package:flutter/material.dart';
import 'api_service.dart';
import 'app_preferences.dart';
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
  late Animation<double> _contentOpacity;
  late Animation<double> _contentSlide;
  late Animation<double> _glowAnim;
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _senhaVisivel = false;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.2, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    _contentSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _contentController, curve: Curves.easeOut),
    );
    _contentController.forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _glowController.dispose();
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

        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _entrar() async {
    final email = _emailController.text.trim();
    if (!email.contains('@') || _senhaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um e-mail e uma senha válidos.')),
      );
      return;
    }

    if (_carregando) return;
    setState(() => _carregando = true);
    try {
      final resposta = await ApiService.login(
        email: email,
        senha: _senhaController.text,
      );
      await ApiService.salvarSessao(resposta);
      if (!mounted) return;
      _navegarParaOnboarding();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _recuperarSenha() async {
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar senha'),
        content: TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'E-mail da conta',
            filled: true,
            fillColor: AppPalette.isDark(context)
                ? const Color(0xFF55232A)
                : const Color(0xFFFFF0F1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, _emailController.text.trim()),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (email == null || !mounted) return;
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Digite um e-mail válido.')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperação indisponível'),
        content: const Text(
          'O LupTok ainda não está conectado a um serviço de autenticação para enviar o link de recuperação. Nenhum e-mail foi enviado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Future<void> _entrarComGoogle() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google ainda não configurado'),
        content: const Text(
          'Para ativar o login, o app precisa de um provedor de autenticação e do OAuth Client ID deste projeto. Nenhuma conta foi conectada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageColor = AppPalette.background(context);
    final softTextColor = AppPalette.mutedText(context);
    return Scaffold(
      backgroundColor: pageColor,
      resizeToAvoidBottomInset: true,
      body: Theme(
        data: Theme.of(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: pageColor),
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 0.5,
                      colors: [
                        AppPalette.button(
                          context,
                        ).withValues(alpha: 0.1 * _glowAnim.value),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
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
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppPalette.button(context)
                                            .withValues(
                                              alpha: 0.35 * _glowAnim.value,
                                            ),
                                        blurRadius: 40,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),

                                  child: Image.asset(
                                    AppPalette.logo(context),
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
                                color: AppPalette.mutedText(context),
                                fontFamily: 'IMFellFrenchCanon',
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
                                onPressed: _recuperarSenha,
                                child: Text(
                                  'Esqueceu a senha?',
                                  style: TextStyle(
                                    color: AppPalette.primaryText(context),
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
                                  backgroundColor: AppPalette.button(context),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _carregando ? null : _entrar,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppPalette.button(context),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: _carregando
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Entrar',
                                            style: TextStyle(
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

                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: AppPalette.border(
                                      context,
                                    ).withValues(alpha: 0.22),
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
                                      color: AppPalette.mutedText(context),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),

                                Expanded(
                                  child: Divider(
                                    color: AppPalette.border(
                                      context,
                                    ).withValues(alpha: 0.22),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: _entrarComGoogle,
                                icon: Text(
                                  'G',
                                  style: TextStyle(
                                    color: AppPalette.primaryText(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                label: const Text('Continuar com Google'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppPalette.primaryText(
                                    context,
                                  ),
                                  side: BorderSide(
                                    color: const Color(
                                      0xFFBB7575,
                                    ).withValues(alpha: 0.4),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    PageRouteBuilder(
                                      pageBuilder:
                                          (
                                            context,
                                            animation,

                                            secondaryAnimation,
                                          ) {
                                            return const CadastroScreen();
                                          },
                                      transitionDuration: const Duration(
                                        milliseconds: 700,
                                      ),
                                      transitionsBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                            child,
                                          ) {
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
                                      color: AppPalette.mutedText(context),
                                      fontSize: 14,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Criar conta',
                                        style: TextStyle(
                                          color: AppPalette.primaryText(
                                            context,
                                          ),
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
    final fieldTextColor = AppPalette.primaryText(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppPalette.border(context).withValues(alpha: 0.35),
        ),
        color: AppPalette.isDark(context)
            ? const Color(0xFF55232A)
            : const Color(0xFFFFF0F1),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(color: fieldTextColor, fontSize: 15),
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
