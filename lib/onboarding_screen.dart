import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'app_preferences.dart';
import 'home_screen.dart';
import 'interest_utils.dart';
import 'work_search.dart';

class _ObraCatalogo {
  final String titulo;
  final String tipo;
  final String imagem;

  const _ObraCatalogo({
    required this.titulo,
    required this.tipo,
    required this.imagem,
  });

  SearchableWork get metadata =>
      searchableWorks.firstWhere((work) => work.title == titulo);
}

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
  final Set<String> _obrasSelecionadas = {};
  final TextEditingController _buscaObrasController = TextEditingController();

  int _etapa = 0;
  String? _filtroTipoObra;
  bool _salvando = false;

  // Etapas do onboarding
  List<String> get _fluxo => ['tipos', 'generos', 'obras'];

  static const List<_ObraCatalogo> _catalogoObras = [
    _ObraCatalogo(
      titulo: '20th Century Girl',
      tipo: 'Filme',
      imagem: 'assets/images/capa1.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Teen Wolf',
      tipo: 'Série',
      imagem: 'assets/images/capa2.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Pretty Little Liars',
      tipo: 'Série',
      imagem: 'assets/images/capa3.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Culpa Minha',
      tipo: 'Filme',
      imagem: 'assets/images/capa4.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Powerless',
      tipo: 'Livro',
      imagem: 'assets/images/capa5.jpg',
    ),
    _ObraCatalogo(
      titulo: 'The Walking Dead',
      tipo: 'Série',
      imagem: 'assets/images/capa6.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Naruto',
      tipo: 'Série',
      imagem: 'assets/images/capa7.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Twinkling Watermelon',
      tipo: 'Série',
      imagem: 'assets/images/capa8.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Quarta Asa',
      tipo: 'Livro',
      imagem: 'assets/images/capa9.jpg',
    ),
    _ObraCatalogo(
      titulo: 'A Cinco Passos de Você',
      tipo: 'Filme',
      imagem: 'assets/images/capa10.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Minions',
      tipo: 'Filme',
      imagem: 'assets/images/capa11.jpg',
    ),
    _ObraCatalogo(
      titulo: 'True Beauty',
      tipo: 'Série',
      imagem: 'assets/images/capa12.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Para Todos os Garotos que Já Amei',
      tipo: 'Filme',
      imagem: 'assets/images/capa13.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Shatter Me',
      tipo: 'Livro',
      imagem: 'assets/images/capa14.jpg',
    ),
    _ObraCatalogo(
      titulo: 'É Assim que Acaba',
      tipo: 'Livro',
      imagem: 'assets/images/capa15.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Vingadores: Guerra Infinita',
      tipo: 'Filme',
      imagem: 'assets/images/capa16.jpg',
    ),
    _ObraCatalogo(
      titulo: 'The Glory',
      tipo: 'Série',
      imagem: 'assets/images/capa17.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Frozen',
      tipo: 'Filme',
      imagem: 'assets/images/capa18.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Titanic',
      tipo: 'Filme',
      imagem: 'assets/images/capa19.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Wandinha',
      tipo: 'Série',
      imagem: 'assets/images/capa20.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Homem-Aranha: Sem Volta Para Casa',
      tipo: 'Filme',
      imagem: 'assets/images/capa21.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Sociedade dos Poetas Mortos',
      tipo: 'Filme',
      imagem: 'assets/images/capa23.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Crepúsculo',
      tipo: 'Filme',
      imagem: 'assets/images/capa25.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Matilda',
      tipo: 'Livro',
      imagem: 'assets/images/capa26.jpg',
    ),
    _ObraCatalogo(
      titulo: 'O Diário de Anne Frank',
      tipo: 'Livro',
      imagem: 'assets/images/capa27.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Extraordinário',
      tipo: 'Livro',
      imagem: 'assets/images/capa29.jpg',
    ),
    _ObraCatalogo(
      titulo: 'O Mundo de Sofia',
      tipo: 'Livro',
      imagem: 'assets/images/capa30.jpg',
    ),
    _ObraCatalogo(
      titulo: 'O Pequeno Príncipe',
      tipo: 'Livro',
      imagem: 'assets/images/capa31.jpg',
    ),
    _ObraCatalogo(
      titulo: 'Tomorrow',
      tipo: 'Série',
      imagem: 'assets/images/capa33.jpg',
    ),
  ];

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
    _buscaObrasController.dispose();
    super.dispose();
  }

  bool get _podeProsseguir {
    switch (_etapaAtual) {
      case 'tipos':
        return _tiposSelecionados.isNotEmpty;
      case 'generos':
        return _generosEntretenimento.isNotEmpty;
      case 'obras':
        return _obrasSelecionadas.length >= 3 && !_salvando;
      default:
        return false;
    }
  }

  bool get _ehUltimaEtapa => _etapa == _fluxo.length - 1;

  void _avancar() async {
    if (!_podeProsseguir) return;

    if (_ehUltimaEtapa) {
      await _finalizarOnboarding();
      return;
    }

    await _slideController.reverse();
    setState(() => _etapa++);
    _slideController.forward();
  }

  Future<void> _finalizarOnboarding() async {
    if (_salvando) return;
    setState(() => _salvando = true);
    try {
      final selecionadas = _catalogoObras
          .where((obra) => _obrasSelecionadas.contains(obra.titulo))
          .toList();

      for (final obra in selecionadas) {
        final metadata = obra.metadata;
        await ApiService.adicionarObra(
          titulo: obra.titulo,
          tipo: obra.tipo,
          descricao: metadata.description,
          generos: metadata.genres,
          palavrasChave: metadata.keywords,
        );
      }

      final obrasSalvas = await ApiService.listarObras();
      for (final selecionada in selecionadas) {
        Map<String, dynamic>? obraSalva;
        for (final obra in obrasSalvas) {
          if (normalizeInterest(obra['titulo']?.toString() ?? '') ==
                  normalizeInterest(selecionada.titulo) &&
              normalizeInterest(obra['tipo']?.toString() ?? '') ==
                  normalizeInterest(selecionada.tipo)) {
            obraSalva = obra;
            break;
          }
        }
        if (obraSalva == null || obraSalva['id'] == null) {
          throw Exception(
            'Não foi possível encontrar "${selecionada.titulo}" no catálogo.',
          );
        }
        await ApiService.avaliarObra(id: obraSalva['id'], souFa: true);
      }

      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setStringList(
        'perfil_tipos',
        _tiposSelecionados.toList(),
      );
      await preferencias.setStringList(
        'perfil_generos',
        _generosEntretenimento.toList(),
      );
      await preferencias.setBool('onboarding_completed', true);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível salvar suas escolhas: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _voltar() async {
    if (_salvando) return;
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
      backgroundColor: AppPalette.background(context),
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
                      AppPalette.surface(context),
                      AppPalette.background(context),
                      _pulseAnim.value,
                    )!,
                    AppPalette.background(context),
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
                      AppPalette.accent(
                        context,
                      ).withValues(alpha: 0.08 + _pulseAnim.value * 0.06),
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
                      AppPalette.button(
                        context,
                      ).withValues(alpha: 0.07 + _pulseAnim.value * 0.05),
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
                      GestureDetector(
                        onTap: _salvando ? null : _voltar,
                        child: AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppPalette.button(
                                context,
                              ).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppPalette.border(
                                  context,
                                ).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              color: AppPalette.primaryText(context),
                              size: 16,
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

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
                                backgroundColor: AppPalette.border(
                                  context,
                                ).withValues(alpha: 0.28),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppPalette.accent(context),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${_etapa + 1} de $totalEtapas",
                            style: TextStyle(
                              color: AppPalette.mutedText(context),
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
                          backgroundColor: AppPalette.button(context),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _podeProsseguir ? _avancar : null,
                        child: _salvando
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _ehUltimaEtapa ? "Começar" : "Próximo",
                                style: const TextStyle(
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
      case 'obras':
        return _buildObras();
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
              color: AppPalette.mutedText(context),
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
                    color: sel
                        ? AppPalette.accent(context)
                        : AppPalette.surface(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: sel
                          ? AppPalette.button(context)
                          : AppPalette.border(context).withValues(alpha: 0.35),
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        imagem,
                        width: valor == 'livros' ? 54 : 68,
                        height: 72,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.image_not_supported_outlined,
                          color: AppPalette.primaryText(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          nome,
                          style: TextStyle(
                            color: sel
                                ? Colors.white
                                : AppPalette.primaryText(context),
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
              color: AppPalette.mutedText(context),
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
                        ? AppPalette.accent(context)
                        : AppPalette.surface(context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: sel
                          ? AppPalette.button(context)
                          : AppPalette.border(context).withValues(alpha: 0.35),
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
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.image_not_supported_outlined,
                          size: 34,
                          color: AppPalette.primaryText(context),
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        nome,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: sel
                              ? Colors.white
                              : AppPalette.primaryText(context),
                          fontSize: 14,
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

  Widget _buildObras() {
    final tiposAtivos = _tiposSelecionados.map((tipo) {
      return switch (tipo) {
        'filmes' => 'Filme',
        'series' => 'Série',
        'livros' => 'Livro',
        _ => tipo,
      };
    }).toSet();
    final consulta = normalizeInterest(_buscaObrasController.text);
    final obrasVisiveis = _catalogoObras.where((obra) {
      return tiposAtivos.contains(obra.tipo) &&
          (_filtroTipoObra == null || obra.tipo == _filtroTipoObra) &&
          (consulta.isEmpty ||
              normalizeInterest(obra.titulo).contains(consulta));
    }).toList();
    final nomesTipos = {
      'Filme': 'Filmes',
      'Série': 'Séries',
      'Livro': 'Livros',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitulo('Quais são as\nsuas favoritas?'),
          Text(
            'Escolha pelo menos 3 obras para encontrar pessoas com gostos parecidos.',
            style: TextStyle(
              color: AppPalette.mutedText(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _buscaObrasController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar filme, série ou livro',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _buscaObrasController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: () {
                        _buscaObrasController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: AppPalette.surface(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: _filtroTipoObra == null,
                  onSelected: (_) => setState(() => _filtroTipoObra = null),
                ),
                for (final tipo in tiposAtivos)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(nomesTipos[tipo] ?? tipo),
                      selected: _filtroTipoObra == tipo,
                      onSelected: (_) => setState(
                        () => _filtroTipoObra = _filtroTipoObra == tipo
                            ? null
                            : tipo,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_obrasSelecionadas.length} de 3 selecionadas',
            style: TextStyle(
              color: _obrasSelecionadas.length >= 3
                  ? AppPalette.accent(context)
                  : AppPalette.mutedText(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: obrasVisiveis.isEmpty
                ? Center(
                    child: Text(
                      'Nenhuma obra encontrada.',
                      style: TextStyle(color: AppPalette.mutedText(context)),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: obrasVisiveis.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.68,
                        ),
                    itemBuilder: (context, index) {
                      final obra = obrasVisiveis[index];
                      final selecionada = _obrasSelecionadas.contains(
                        obra.titulo,
                      );
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (selecionada) {
                            _obrasSelecionadas.remove(obra.titulo);
                          } else {
                            _obrasSelecionadas.add(obra.titulo);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: AppPalette.surface(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selecionada
                                  ? AppPalette.accent(context)
                                  : AppPalette.border(
                                      context,
                                    ).withValues(alpha: 0.35),
                              width: selecionada ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.asset(
                                      obra.imagem,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Icon(
                                        Icons.auto_stories_outlined,
                                        color: AppPalette.mutedText(context),
                                        size: 42,
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: selecionada
                                              ? AppPalette.accent(context)
                                              : Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          selecionada
                                              ? Icons.check_rounded
                                              : Icons.add_rounded,
                                          color: Colors.white,
                                          size: 19,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      obra.titulo,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppPalette.primaryText(context),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      obra.tipo,
                                      style: TextStyle(
                                        color: AppPalette.mutedText(context),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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

  // ── Helper: chips de seleção múltipla ─────────────────────────────

  Widget _buildTitulo(String titulo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            color: AppPalette.mutedText(context),
            fontFamily: 'IMFellFrenchCanon',
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
