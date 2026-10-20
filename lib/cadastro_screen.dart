
import 'package:flutter/material.dart';

import 'app_preferences.dart';
import 'api_service.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _contentController;
  late AnimationController _glowController;

  late Animation<double> _contentOpacity;
  late Animation<double> _contentSlide;
  late Animation<double> _glowAnim;

  final _nomeCompletoController = TextEditingController();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _senhaVisivel = false;
  bool _confirmarSenhaVisivel = false;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _glowAnim = Tween<double>(begin: 0.2, end: 0.7).animate(
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
    _bgController.dispose();
    _contentController.dispose();
    _glowController.dispose();

    _nomeCompletoController.dispose();
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();

    super.dispose();
  }

  Future<void> _cadastrar() async {
    final nomeCompleto = _nomeCompletoController.text.trim();
    final nomeUsuario = _nomeController.text.trim();
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    final confirmarSenha = _confirmarSenhaController.text;

    if (nomeCompleto.isEmpty ||
        nomeUsuario.isEmpty ||
        email.isEmpty ||
        senha.isEmpty ||
        confirmarSenha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos.'),
          backgroundColor: Color(0xFF111111),
        ),
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite um e-mail válido.'),
          backgroundColor: Color(0xFF111111),
        ),
      );
      return;
    }

    if (senha != confirmarSenha) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('As senhas não coincidem.'),
          backgroundColor: Color(0xFF111111),
        ),
      );
      return;
    }

    if (_carregando) return;

    setState(() {
      _carregando = true;
    });

    try {
      await ApiService.cadastrar(
        nome: nomeCompleto,
        nomeUsuario: nomeUsuario,
        email: email,
        senha: senha,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conta criada com sucesso!'),
          backgroundColor: Color(0xFF111111),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: const Color(0xFF111111),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  Widget _buildColumn(List<String> images, double speed) {
    final allImages = [...images, ...images, ...images];

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;

        return ClipRect(
          child: AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              const totalItemHeight = 228.0;
              final totalHeight = allImages.length * totalItemHeight;

              final offset =
                  (_bgController.value * height * speed) %
                  totalItemHeight;

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
                          child: Image.asset(
                            image,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: AppPalette.background(context),
          ),

          AnimatedBuilder(
            animation: _glowAnim,
            builder: (context, _) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.55),
                  colors: [
                    AppPalette.button(context).withValues(
                      alpha:
                          (AppPalette.isDark(context) ? 0.18 : 0.1) *
                          _glowAnim.value,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: AnimatedBuilder(
              animation: _contentController,
              builder: (context, child) => Opacity(
                opacity: _contentOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _contentSlide.value),
                  child: child,
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new),
                        color: AppPalette.primaryText(context),
                        tooltip: 'Voltar',
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Logo com glow
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (_, __) => Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppPalette.button(context).withValues(
                                alpha: 0.35 * _glowAnim.value,
                              ),
                              blurRadius: 40,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          AppPalette.logo(context),
                          height: 75,
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Criar conta',
                            style: TextStyle(
                              color: AppPalette.mutedText(context),
                              fontFamily: 'IMFellFrenchCanon',
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'Comece a descobrir filmes, séries e livros',
                            style: TextStyle(
                              color: AppPalette.mutedText(context),
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Nome completo
                          _buildTextField(
                            controller: _nomeCompletoController,
                            hint: 'Nome completo',
                            icon: Icons.badge_outlined,
                            obscure: false,
                          ),

                          const SizedBox(height: 14),

                          // Nome de usuário
                          _buildTextField(
                            controller: _nomeController,
                            hint: '@ Nome de usuário',
                            icon: Icons.person_outline,
                            obscure: false,
                          ),

                          const SizedBox(height: 14),

                          // Email
                          _buildTextField(
                            controller: _emailController,
                            hint: 'Email',
                            icon: Icons.email_outlined,
                            obscure: false,
                            keyboardType: TextInputType.emailAddress,
                          ),

                          const SizedBox(height: 14),

                          // Senha
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
                                color: const Color(0xFF7D171D)
                                    .withOpacity(0.55),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _senhaVisivel = !_senhaVisivel;
                                });
                              },
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Confirmar senha
                          _buildTextField(
                            controller: _confirmarSenhaController,
                            hint: 'Confirmar senha',
                            icon: Icons.lock_outline,
                            obscure: !_confirmarSenhaVisivel,
                            suffix: IconButton(
                              icon: Icon(
                                _confirmarSenhaVisivel
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF7D171D)
                                    .withOpacity(0.55),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _confirmarSenhaVisivel =
                                      !_confirmarSenhaVisivel;
                                });
                              },
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Botão criar conta
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    AppPalette.button(context),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                disabledBackgroundColor:
                                    AppPalette.button(context)
                                        .withOpacity(0.65),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed:
                                  _carregando ? null : _cadastrar,
                              child: _carregando
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Criar conta',
                                      style: TextStyle(
                                        fontSize: 17,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Termos
                          Center(
                            child: Text(
                              'Ao criar uma conta, você concorda com os\n'
                              'Termos de Uso e Política de Privacidade',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppPalette.mutedText(context),
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: AppPalette.border(context)
                                      .withValues(alpha: 0.22),
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
                                  color: AppPalette.border(context)
                                      .withValues(alpha: 0.22),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Voltar para login
                          Center(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: RichText(
                                text: TextSpan(
                                  text: 'Já tem uma conta? ',
                                  style: TextStyle(
                                    color: AppPalette.mutedText(context),
                                    fontSize: 14,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Entrar',
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

                          const SizedBox(height: 36),
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool obscure,
    Widget? suffix,
    TextInputType? keyboardType,
  }) {
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
        keyboardType: keyboardType,
        style: TextStyle(
          color: AppPalette.primaryText(context),
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppPalette.mutedText(context),
            fontSize: 15,
          ),
          prefixIcon: Icon(
            icon,
            color: AppPalette.accent(context),
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
