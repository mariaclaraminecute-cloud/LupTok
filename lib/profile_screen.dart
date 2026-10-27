import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'api_service.dart';
import 'app_preferences.dart';
import 'work_compatibility.dart';
import 'works_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isOwner;
  final VoidCallback? onOpenSettings;
  final String? publicUsername;
  final String? publicName;
  final List<Map<String, dynamic>> publicWorks;
  final List<String> availableVideos;
  final List<ProfileVideo> profileVideos;
  final List<ProfileVideo> privateVideos;

  const ProfileScreen({
    super.key,
    this.isOwner = true,
    this.onOpenSettings,
    this.publicUsername,
    this.publicName,
    this.publicWorks = const [],
    this.availableVideos = const [],
    this.profileVideos = const [],
    this.privateVideos = const [],
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class ProfileVideo {
  final String title;
  final String? videoPath;
  final String? videoToken;
  final String? videoId;
  final String privacy;
  final String contentType;

  const ProfileVideo({
    required this.title,
    required this.videoPath,
    required this.videoToken,
    required this.videoId,
    required this.privacy,
    required this.contentType,
  });
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _name = '';
  String _username = '';
  String _bio = '';
  String _watching = '';
  List<Map<String, dynamic>> _works = [];
  String? _worksError;
  Set<String> _following = {};
  Set<int> _savedIndices = {};
  bool _loading = true;

  bool get _isOwner => widget.isOwner;
  String get _shownUsername =>
      _isOwner ? _username : widget.publicUsername ?? '';
  String get _shownName =>
      _isOwner ? _name : widget.publicName ?? _nameFromUsername(_shownUsername);
  List<Map<String, dynamic>> get _shownWorks => _isOwner
      ? _works.where((work) => work['sou_fa'] is bool).toList()
      : widget.publicWorks;

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
    List<Map<String, dynamic>> works = _works;
    String? worksError;
    try {
      works = await ApiService.listarObras();
    } catch (error) {
      worksError = error.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return;
    setState(() {
      _name = preferences.getString('perfil_nome') ?? _name;
      _username = preferences.getString('perfil_usuario') ?? _username;
      _bio = preferences.getString('perfil_bio') ?? _bio;
      _watching = preferences.getString('perfil_assistindo') ?? '';
      _works = works;
      _worksError = worksError;
      _following = Set<String>.from(followedUsernames.value);
      _savedIndices = Set<int>.from(savedVideoIndices.value);
      _loading = false;
    });
  }

  int _compatibility() {
    return workCompatibility(_works, widget.publicWorks);
  }

  bool get _hasCompatibilityData =>
      _works.any((work) => work['sou_fa'] is bool) &&
      widget.publicWorks.any((work) => work['sou_fa'] is bool);

  Future<void> _manageWorks() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const WorksScreen()));
    await _loadProfile();
  }

  Future<void> _editProfile() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final name = TextEditingController(text: _name);
    final username = TextEditingController(
      text: _username.replaceFirst('@', ''),
    );
    final bio = TextEditingController(text: _bio);
    final watching = TextEditingController(text: _watching);
    final updated =
        await showModalBottomSheet<(String, String, String, String)>(
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
                          if (name.text.trim().isEmpty ||
                              cleanUsername.isEmpty) {
                            return;
                          }
                          Navigator.pop(sheetContext, (
                            name.text.trim(),
                            '@$cleanUsername',
                            bio.text.trim(),
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
    watching.dispose();
    if (updated == null) return;
    await preferences.setString('perfil_nome', updated.$1);
    await preferences.setString('perfil_usuario', updated.$2);
    await preferences.setString('perfil_bio', updated.$3);
    await preferences.setString('perfil_assistindo', updated.$4);
    if (!mounted) return;
    setState(() {
      _name = updated.$1;
      _username = updated.$2;
      _bio = updated.$3;
      _watching = updated.$4;
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
            expandedHeight: 264,
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
              background: LayoutBuilder(
                builder: (context, constraints) {
                  final showAvatar = constraints.maxHeight >= 180;
                  return Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned.fill(
                        bottom: 58,
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
                      if (showAvatar)
                        Positioned(
                          bottom: 0,
                          child: Container(
                            width: 116,
                            height: 116,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppPalette.background(context),
                              border: Border.all(
                                color: AppPalette.accent(context),
                                width: 3,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 48,
                              backgroundColor: AppPalette.button(context),
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (showAvatar && _watching.isNotEmpty)
                        Positioned(
                          left: constraints.maxWidth / 2 + 64,
                          right: 12,
                          bottom: 34,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.surface(
                                context,
                              ).withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppPalette.border(
                                  context,
                                ).withValues(alpha: 0.4),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              'Assistindo agora · $_watching',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppPalette.primaryText(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildProfileDetails(username)),
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
                children: [_videosTab(), _savedTab(), _privateTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetails(String username) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                if (_hasCompatibilityData)
                  Chip(
                    avatar: Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: AppPalette.primaryText(context),
                    ),
                    label: Text('${_compatibility()}% compatível'),
                    backgroundColor: AppPalette.surface(context),
                  )
                else
                  const Chip(label: Text('Compatibilidade indisponível')),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isOwner) ...[
                _stat(_following.length.toString(), 'seguindo'),
                const SizedBox(width: 30),
              ],
              _stat(
                _shownWorks
                    .where((work) => work['sou_fa'] == true)
                    .length
                    .toString(),
                'obras favoritas',
              ),
              const SizedBox(width: 30),
              _stat(widget.profileVideos.length.toString(), 'vídeos'),
            ],
          ),
          const SizedBox(height: 14),
          if (_isOwner && _bio.isNotEmpty)
            Text(
              _bio,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.text(context), height: 1.4),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _isOwner ? 'Obras' : 'Obras e afinidades',
                  style: TextStyle(
                    color: AppPalette.primaryText(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_isOwner)
                TextButton.icon(
                  onPressed: _manageWorks,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Gerenciar'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            LinearProgressIndicator(color: AppPalette.accent(context))
          else if (_worksError != null && _isOwner)
            Text(
              'Não foi possível carregar suas obras: $_worksError',
              style: TextStyle(color: AppPalette.mutedText(context)),
            )
          else if (_shownWorks.isEmpty)
            Text(
              _isOwner
                  ? 'O catálogo ainda está vazio. Adicione obras para começar a comparar gostos.'
                  : 'Esta pessoa ainda não adicionou obras ao perfil.',
              style: TextStyle(color: AppPalette.mutedText(context)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _shownWorks.map((work) {
                final myRating = _works
                    .where(
                      (mine) => mine['id'].toString() == work['id'].toString(),
                    )
                    .firstOrNull;
                final sameOpinion =
                    !_isOwner &&
                    myRating != null &&
                    myRating['sou_fa'] is bool &&
                    myRating['sou_fa'] == work['sou_fa'];
                final rating = work['sou_fa'];
                return Chip(
                  avatar: Icon(
                    rating == true
                        ? Icons.favorite_rounded
                        : rating == false
                        ? Icons.thumb_down_alt_outlined
                        : Icons.help_outline_rounded,
                    size: 16,
                  ),
                  label: Text(
                    '${work['titulo']} · ${work['tipo']}'
                    '${rating == true
                        ? ' · Fã'
                        : rating == false
                        ? ' · Não é fã'
                        : ' · Sem avaliação'}',
                  ),
                  backgroundColor: sameOpinion
                      ? AppPalette.surface(context)
                      : AppPalette.raisedSurface(context),
                  side: BorderSide(
                    color: AppPalette.border(context).withValues(alpha: 0.3),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

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

  Widget _savedTab() {
    if (!_isOwner) {
      return _empty('Os vídeos salvos são privados.');
    }
    if (_savedIndices.isEmpty) {
      return _empty('Seus vídeos salvos aparecem aqui.');
    }
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
            title: Text(video.title),
            subtitle: const Text('Somente amigos'),
          ),
      ],
    );
  }

  Widget _videosTab() {
    if (widget.profileVideos.isEmpty) {
      return _empty('Ainda não há vídeos publicados neste perfil.');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(3),
      itemCount: widget.profileVideos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        childAspectRatio: 0.7,
      ),
      itemBuilder: (context, index) {
        final video = widget.profileVideos[index];
        final isPrivate = video.privacy == 'Somente amigos';
        return Material(
          color: AppPalette.raisedSurface(context),
          child: InkWell(
            onTap: () => _openProfileVideo(video),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppPalette.button(context),
                        AppPalette.raisedSurface(context),
                        AppPalette.background(context),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.movie_creation_outlined,
                        color: AppPalette.primaryText(
                          context,
                        ).withValues(alpha: 0.7),
                        size: 17,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        video.contentType,
                        style: TextStyle(
                          color: AppPalette.primaryText(context),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.32),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                if (isPrivate)
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 17,
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xD9000000)],
                      ),
                    ),
                    child: Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openProfileVideo(ProfileVideo video) async {
    final path = video.videoPath;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este vídeo não está disponível.')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ProfileVideoScreen(video: video),
      ),
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

class _ProfileVideoScreen extends StatefulWidget {
  final ProfileVideo video;

  const _ProfileVideoScreen({required this.video});

  @override
  State<_ProfileVideoScreen> createState() => _ProfileVideoScreenState();
}

class _ProfileVideoScreenState extends State<_ProfileVideoScreen> {
  VideoPlayerController? _controller;
  late final Future<void> _initialize;

  @override
  void initState() {
    super.initState();
    _initialize = _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final video = widget.video;
    final path = video.videoPath!;
    final parsedUri = Uri.tryParse(path);
    final isNetworkUri =
        parsedUri != null &&
        (parsedUri.scheme == 'http' || parsedUri.scheme == 'https');
    final uri = kIsWeb && video.videoId != null
        ? Uri.parse(await ApiService.urlArquivoVideoWeb(video.videoId!))
        : isNetworkUri
        ? parsedUri
        : Uri.file(path);
    if (!mounted) return;
    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: kIsWeb || video.videoToken == null
          ? const {}
          : {'Authorization': 'Bearer ${video.videoToken}'},
    );
    _controller = controller;
    await controller.initialize();
    await controller.setLooping(true);
    await controller.play();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.video.title),
      ),
      body: Center(
        child: FutureBuilder<void>(
          future: _initialize,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Não foi possível reproduzir este vídeo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const CircularProgressIndicator(color: Colors.white);
            }
            final controller = _controller!;
            return GestureDetector(
              onTap: () {
                if (controller.value.isPlaying) {
                  controller.pause();
                } else {
                  controller.play();
                }
                setState(() {});
              },
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(controller),
                    if (!controller.value.isPlaying)
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 64,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
