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

  const ProfileScreen({
    super.key,
    this.isOwner = true,
    this.onOpenSettings,
    this.publicUsername,
    this.publicInterests = const [],
    this.availableVideos = const [],
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
          backgroundColor: const Color(0xFFFFF7F7),
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
                          backgroundColor: const Color(0xFFBB7575),
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
      backgroundColor: const Color(0xFFFFE9E9),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerScrolled) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: const Color(0xFFFFE9E9),
            foregroundColor: const Color(0xFF7D171D),
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
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
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
                    bottom: -43,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFE9E9),
                        border: Border.all(
                          color: const Color(0xFFBB7575),
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 43,
                        backgroundColor: const Color(0xFFBB7575),
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
              labelColor: const Color(0xFF7D171D),
              unselectedLabelColor: const Color(0xFF9B7072),
              indicatorColor: const Color(0xFFBB7575),
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
                  _empty(
                    _isOwner
                        ? 'Seus vídeos privados aparecem aqui.'
                        : 'Este espaço é privado.',
                  ),
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
      padding: const EdgeInsets.fromLTRB(20, 54, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  _shownName,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7D171D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  username,
                  style: TextStyle(
                    color: const Color(0xFF7D171D).withOpacity(0.64),
                  ),
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
                  foregroundColor: const Color(0xFF7D171D),
                  side: const BorderSide(color: Color(0xFFBB7575)),
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
                      backgroundColor: const Color(0xFFBB7575),
                    ),
                    child: Text(
                      _following.contains(username) ? 'Seguindo' : 'Seguir',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Chip(
                  avatar: const Icon(
                    Icons.favorite_rounded,
                    size: 16,
                    color: Color(0xFF7D171D),
                  ),
                  label: Text('${_compatibility()}% compatível'),
                  backgroundColor: const Color(0xFFFFD6D8),
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
          if (_watching.isNotEmpty) ...[
            const SizedBox(height: 12),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFBB7575).withValues(alpha: 0.24),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Text(
                    'Assistindo agora · $_watching',
                    style: const TextStyle(
                      color: Color(0xFF7D171D),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (_isOwner && _bio.isNotEmpty)
            Text(
              _bio,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF493333), height: 1.4),
            ),
          if (_isOwner && _favorite.isNotEmpty) ...[
            const SizedBox(height: 14),
            _favoriteLine(),
          ],
          const SizedBox(height: 16),
          Text(
            _isOwner ? 'Gostos' : 'Gostos em comum',
            style: const TextStyle(
              color: Color(0xFF7D171D),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const LinearProgressIndicator(color: Color(0xFFBB7575))
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
                      ? const Color(0xFFFFD6D8)
                      : Colors.white.withValues(alpha: 0.8),
                  side: BorderSide(
                    color: const Color(0xFFBB7575).withValues(alpha: 0.24),
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
      const Icon(Icons.bookmark_rounded, color: Color(0xFFBB7575)),
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
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF7D171D),
        ),
      ),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF8F696C)),
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
      errorBuilder: (_, __, ___) => const Icon(
        Icons.favorite_border_rounded,
        size: 16,
        color: Color(0xFFBB7575),
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

  Widget _empty(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF80686A)),
      ),
    ),
  );
}
