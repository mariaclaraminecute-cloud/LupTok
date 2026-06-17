import 'package:flutter/material.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _contentController;
  late AnimationController _glowController;
  late Animation<double> _contentOpacity;
  late Animation<double> _contentSlide;
  late Animation<double> _glowAnim;
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _senhaVisivel = false;
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
    _bgController.dispose();
    _contentController.dispose();
    _glowController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
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
            final offset = (_bgController.value * height * speed) % totalItemHeight;
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
                        child: Image.asset(image, height: 220,
                            width: double.infinity, fit: BoxFit.cover),
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
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
         
          Row(children: [
            Expanded(child: _buildColumn([images[0], images[3], images[6], images[9], images[12]], 1.0)),
            Expanded(child: _buildColumn([images[1], images[4], images[7], images[10], images[13]], 1.2)),
            Expanded(child: _buildColumn([images[2], images[5], images[8], images[11], images[14]], 0.8)),
          ]),
      
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
   
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.97),
                    Colors.black.withOpacity(0.88),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
     
          Positioned(top: 0, left: 0, right: 0,
            child: Container(height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.92), Colors.transparent],
                ),
              ),
            ),
          ),
    
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Positioned(
              top: MediaQuery.of(context).size.height * 0.22,
              left: 0, right: 0,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6B0000).withOpacity(0.12 * _glowAnim.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Conteúdo
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
              child: Column(
                children: [
                  const SizedBox(height: 40),
               
                  AnimatedBuilder(
                    animation: _glowController,
                    builder: (_, __) => Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6B0000).withOpacity(0.35 * _glowAnim.value),
                            blurRadius: 40,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Image.asset('assets/images/logo.png', height: 90),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Bem-vindo!",
                          style: TextStyle(color: Colors.white, fontSize: 26,
                              fontWeight: FontWeight.bold, letterSpacing: 0.3),
                        ),
                        const SizedBox(height: 6),
                        Text("Entre para desvendar!",
                          style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14),
                        ),
                        const SizedBox(height: 32),
                        _buildTextField(
                          controller: _emailController,
                          hint: "Email",
                          icon: Icons.email_outlined,
                          obscure: false,
                        ),
                        const SizedBox(height: 14),
                        _buildTextField(
                          controller: _senhaController,
                          hint: "Senha",
                          icon: Icons.lock_outline,
                          obscure: !_senhaVisivel,
                          suffix: IconButton(
                            icon: Icon(
                              _senhaVisivel ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.white38, size: 20,
                            ),
                            onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
  final email = _emailController.text.trim();
  final senha = _senhaController.text.trim();

  if (email.isEmpty || senha.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Preencha e-mail e senha")),
    );
    return;
  }

  if (email == "teste@teste.com" && senha == "123456") {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Login realizado!")),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Email ou senha inválidos")),
    );
  }
},
                            child: Text("Esqueceu a senha?",
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                       
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {},
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFE50914), Color(0xFF8B0000)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE50914).withOpacity(0.35),
                                    blurRadius: 20, offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text("Entrar",
                                  style: TextStyle(fontSize: 17, color: Colors.white,
                                      fontWeight: FontWeight.w600, letterSpacing: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(children: [
                          Expanded(child: Divider(color: Colors.white.withOpacity(0.12), thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text("ou", style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13)),
                          ),
                          Expanded(child: Divider(color: Colors.white.withOpacity(0.12), thickness: 1)),
                        ]),
                        const SizedBox(height: 20),
                        Center(
                          child: GestureDetector(
                            onTap: () {},
                            child: RichText(
                              text: TextSpan(
                                text: "Não tem conta? ",
                                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 14),
                                children: const [
                                  TextSpan(
                                    text: "Criar conta",
                                    style: TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
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
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool obscure,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        color: Colors.white.withOpacity(0.07),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 15),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.35), size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }
}