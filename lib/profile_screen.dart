import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences.dart';
import 'interest_utils.dart';

class ProfileScreen extends StatefulWidget {
  final bool isOwner;
  final VoidCallback? onOpenSettings;
  final String? publicUsername;
  final List<String> publicInterests;
  final List<String> availableVideos;
  final List<String> privateVideos;

  const ProfileScreen({
    super.key,
    this.isOwner = true,
    this.onOpenSettings,
    this.publicUsername,
    this.publicInterests = const [],
    this.availableVideos = const [],
    this.privateVideos = const [],
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _name = 'Seu nome';
  String _username = '@seu.usuario';
  String _bio = '';
  String _favorite = '';
  String _watching = '';
  List<String> _interests = [];
  Set<String> _following = {};
  Set<int> _savedIndices = {};
  bool _loading = true;

  bool get _isOwner => widget.isOwner;
  String get _shownUsername =>
      _isOwner ? _username : widget.publicUsername ?? '@criador';
  String get _shownName => _isOwner ? _name : _nameFromUsername(_shownUsername);
  List<String> get _shownInterests =>
      _isOwner ? _interests : widget.publicInterests;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    followedUsernames.addListener(_syncFollowing);
    savedVideoIndices.addListener(_syncSaved);
    _loadProfile();
  }

  void _syncFollowing() {
    if (!mounted) return;
    setState(() => _following = Set<String>.from(followedUsernames.value));
  }

  void _syncSaved() {
    if (!mounted) return;
    setState(() => _savedIndices = Set<int>.from(savedVideoIndices.value));
  }

  String _nameFromUsername(String username) => username
      .replaceFirst('@', '')
      .split('.')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  Future<void> _loadProfile() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _name = preferences.getString('perfil_nome') ?? _name;
      _username = preferences.getString('perfil_usuario') ?? _username;
      _bio = preferences.getString('perfil_bio') ?? _bio;
      _favorite = preferences.getString('perfil_obra_favorita') ?? '';
      _watching = preferences.getString('perfil_assistindo') ?? '';
      _interests = [
        ...?preferences.getStringList('perfil_tipos'),
        ...?preferences.getStringList('perfil_generos'),
      ];
      _following = Set<String>.from(followedUsernames.value);
      _savedIndices = Set<int>.from(savedVideoIndices.value);
      _loading = false;
    });
  }

  int _compatibility() {
    final own = _interests.map(normalizeInterest).toSet();
    final other = widget.publicInterests.map(normalizeInterest).toSet();
    if (own.isEmpty || other.isEmpty) return 0;
    return (own.intersection(other).length / own.union(other).length * 100)
        .round();
  }

  Future<void> _editProfile() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final name = TextEditingController(text: _name);
    final username = TextEditingController(
      text: _username.replaceFirst('@', ''),
    );
    final bio = TextEditingController(text: _bio);
    final favorite = TextEditingController(text: _favorite);
    final watching = TextEditingController(text: _watching);
    final updated =
        await showModalBottomSheet<(String, String, String, String, String)>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppPalette.surface(context),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          builder: (sheetContext) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                18 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Editar perfil',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nome'),
                    ),
                    TextField(
                      controller: username,
                      decoration: const InputDecoration(
                        labelText: 'Usuário',
                        prefixText: '@',
                      ),
                    ),
                    TextField(
                      controller: bio,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 160,
                      decoration: const InputDecoration(labelText: 'Biografia'),
                    ),
                    TextField(
                      controller: favorite,
                      decoration: const InputDecoration(
                        labelText: 'Obra favorita',
                      ),
                    ),
                    TextField(
                      controller: watching,
                      decoration: const InputDecoration(
                        labelText: 'Assistindo agora',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          final cleanUsername = username.text
                              .trim()
                              .replaceFirst(RegExp(r'^@+'), '');
                          if (name.text.trim().isEmpty || cleanUsername.isEmpty)
                            return;
                          Navigator.pop(sheetContext, (
                            name.text.trim(),
                            '@$cleanUsername',
                            bio.text.trim(),
                            favorite.text.trim(),
                            watching.text.trim(),
                          ));
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.button(context),
                        ),
                        child: const Text('Salvar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    name.dispose();
    username.dispose();
    bio.dispose();
    favorite.dispose();
    watching.dispose();
    if (updated == null) return;
    await preferences.setString('perfil_nome', updated.$1);
    await preferences.setString('perfil_usuario', updated.$2);
    await preferences.setString('perfil_bio', updated.$3);
    await preferences.setString('perfil_obra_favorita', updated.$4);
    await preferences.setString('perfil_assistindo', updated.$5);
    if (!mounted) return;
    setState(() {
      _name = updated.$1;
      _username = updated.$2;
      _bio = updated.$3;
      _favorite = updated.$4;
      _watching = updated.$5;
    });
  }

  Future<void> _toggleFollow() async {
    final username = _shownUsername;
    setState(() {
      if (!_following.add(username)) _following.remove(username);
    });
    followedUsernames.value = Set<String>.from(_following);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('following_users', _following.toList());
  }

  @override
  void dispose() {
    followedUsernames.removeListener(_syncFollowing);
    savedVideoIndices.removeListener(_syncSaved);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = _shownUsername;
    final initial = _shownName.isEmpty ? '?' : _shownName[0].toUpperCase();
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerScrolled) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 228,
            backgroundColor: AppPalette.background(context),
            foregroundColor: AppPalette.primaryText(context),
            actions: [
              if (_isOwner)
                IconButton(
                  tooltip: 'Configurações',
                  onPressed: widget.onOpenSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppPalette.isDark(context)
                              ? [
                                  AppPalette.darkBackground,
                                  AppPalette.darkBackground,
                                  AppPalette.darkBackground,
                                ]
                              : const [
                                  Color(0xFF9D414B),
                                  Color(0xFFDA9297),
                                  Color(0xFFFFD6D8),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -48,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppPalette.background(context),
                            border: Border.all(
                              color: AppPalette.accent(context),
                              width: 3,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 43,
                            backgroundColor: AppPalette.button(context),
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        if (_watching.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.surface(context),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppPalette.border(
                                  context,
                                ).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              'Assistindo agora\n$_watching',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppPalette.primaryText(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildProfileDetails(initial, username)),
        ],
        body: Column(
          children: [
            TabBar(
              controller: _tabs,
              labelColor: AppPalette.primaryText(context),
              unselectedLabelColor: AppPalette.mutedText(context),
              indicatorColor: AppPalette.accent(context),
              tabs: const [
                Tab(text: 'Vídeos'),
                Tab(text: 'Salvos'),
                Tab(text: 'Privados'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _empty('Ainda não há vídeos publicados.'),
                  _savedTab(),
                  _privateTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetails(String initial, String username) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  _shownName,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.primaryText(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  username,
                  style: TextStyle(color: AppPalette.mutedText(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_isOwner)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _editProfile,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar perfil'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.primaryText(context),
                  side: BorderSide(color: AppPalette.border(context)),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _toggleFollow,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.button(context),
                    ),
                    child: Text(
                      _following.contains(username) ? 'Seguindo' : 'Seguir',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Chip(
                  avatar: Icon(
                    Icons.favorite_rounded,
                    size: 16,
                    color: AppPalette.primaryText(context),
                  ),
                  label: Text('${_compatibility()}% compatível'),
                  backgroundColor: AppPalette.surface(context),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stat(_following.length.toString(), 'seguindo'),
              const SizedBox(width: 30),
              _stat('0', 'seguidores'),
              const SizedBox(width: 30),
              _stat('0', 'vídeos'),
            ],
          ),
          const SizedBox(height: 14),
          if (_isOwner && _bio.isNotEmpty)
            Text(
              _bio,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.text(context), height: 1.4),
            ),
          if (_isOwner && _favorite.isNotEmpty) ...[
            const SizedBox(height: 14),
            _favoriteLine(),
          ],
          const SizedBox(height: 16),
          Text(
            _isOwner ? 'Gostos' : 'Gostos em comum',
            style: TextStyle(
              color: AppPalette.primaryText(context),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            LinearProgressIndicator(color: AppPalette.accent(context))
          else if (_shownInterests.isEmpty)
            const Text(
              'Adicione gêneros no onboarding para mostrar seus gostos.',
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _shownInterests.map((interest) {
                final shared =
                    !_isOwner &&
                    _interests
                        .map(normalizeInterest)
                        .contains(normalizeInterest(interest));
                return Chip(
                  avatar: _interestImage(interest),
                  label: Text(displayInterest(interest)),
                  backgroundColor: shared
                      ? AppPalette.surface(context)
                      : AppPalette.raisedSurface(context),
                  side: BorderSide(
                    color: AppPalette.border(context).withValues(alpha: 0.3),
                  ),
                );
              }).toList(),
            ),
          if (_isOwner && _favorite.isEmpty) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar obra favorita'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _favoriteLine() => Row(
    children: [
      Icon(Icons.bookmark_rounded, color: AppPalette.accent(context)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Obra favorita · $_favorite',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );

  Widget _stat(String value, String label) => Column(
    children: [
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppPalette.primaryText(context),
        ),
      ),
      Text(
        label,
        style: TextStyle(fontSize: 12, color: AppPalette.mutedText(context)),
      ),
    ],
  );

  Widget _interestImage(String interest) {
    final normalized = interest.toLowerCase();
    final asset =
        normalized.contains('dorama') || normalized.contains('k-drama')
        ? 'assets/images/dorama.png'
        : normalized.contains('anime')
        ? 'assets/images/anime.png'
        : normalized.contains('livro')
        ? 'assets/images/livro.png'
        : normalized.contains('filme')
        ? 'assets/images/filme.png'
        : normalized.contains('série') || normalized.contains('serie')
        ? 'assets/images/serie.png'
        : 'assets/images/${_interestFile(normalized)}.png';
    return Image.asset(
      asset,
      width: 20,
      height: 20,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.favorite_border_rounded,
        size: 16,
        color: AppPalette.accent(context),
      ),
    );
  }

  String _interestFile(String value) {
    if (value.contains('ficção') || value.contains('ficcao')) return 'ficcao';
    if (value.contains('suspense')) return 'suspense';
    if (value.contains('romance')) return 'romance';
    if (value.contains('fantasia')) return 'fantasia';
    if (value.contains('terror')) return 'terror';
    if (value.contains('drama')) return 'drama';
    if (value.contains('comédia') || value.contains('comedia'))
      return 'comedia';
    if (value.contains('ação') || value.contains('acao')) return 'acao';
    if (value.contains('aventura')) return 'aventura';
    return 'historico';
  }

  Widget _savedTab() {
    if (_savedIndices.isEmpty)
      return _empty('Seus vídeos salvos aparecem aqui.');
    final items = _savedIndices
        .where((index) => index >= 0 && index < widget.availableVideos.length)
        .map((index) => widget.availableVideos[index])
        .toList();
    if (items.isEmpty) return _empty('Seus vídeos salvos aparecem aqui.');
    return ListView(
      children: [
        for (final item in items)
          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: Text(item),
          ),
      ],
    );
  }

  Widget _privateTab() {
    if (!_isOwner) return _empty('Este espaço é privado.');
    if (widget.privateVideos.isEmpty) {
      return _empty('Seus vídeos privados aparecem aqui.');
    }
    return ListView(
      children: [
        for (final video in widget.privateVideos)
          ListTile(
            leading: const Icon(Icons.lock_outline_rounded),
            title: Text(video),
            subtitle: const Text('Somente amigos'),
          ),
      ],
    );
  }

  Widget _empty(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppPalette.mutedText(context)),
      ),
    ),
  );
}
