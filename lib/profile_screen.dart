import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'api_service.dart';
import 'app_preferences.dart';
import 'chat_screen.dart';
import 'work_compatibility.dart';
import 'works_screen.dart';
class ProfileScreen extends StatefulWidget {
  final bool isOwner;
  final VoidCallback? onOpenSettings;
  final int? publicUserId;
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
    this.publicUserId,
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
  String _activity = 'Assistindo';
  String? _avatarUrl;
  String? _coverUrl;
  bool _uploadingPhoto = false;
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
    Map<String, dynamic>? remote;
    try {
      remote = _isOwner ? await ApiService.meuPerfil() :
        widget.publicUserId == null ? null : await ApiService.obterConta(widget.publicUserId!);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      if (remote != null) {
        _avatarUrl = ApiService.urlImagemPerfil(remote['foto_url']);
        _coverUrl = ApiService.urlImagemPerfil(remote['capa_url']);
      }
      _name = _isOwner ? (remote?['nome'] as String? ?? preferences.getString('perfil_nome') ?? _name) : _name;
      _username = _isOwner ? '@${remote?['nome_usuario'] ?? (preferences.getString('perfil_usuario') ?? _username).replaceFirst('@', '')}' : _username;
      _bio = remote?['bio'] as String? ?? (_isOwner ? preferences.getString('perfil_bio') ?? _bio : '');
      _watching = preferences.getString('perfil_assistindo') ?? '';
      _activity = remote?['atividade'] is String ? remote!['atividade'] as String : (_isOwner ? preferences.getString('perfil_atividade') ?? 'Assistindo' : 'Assistindo');
      _watching = remote?['obra_atual'] is String ? remote!['obra_atual'] as String : (_isOwner ? _watching : '');
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
    if (!_isOwner || !mounted) return;
    final name = TextEditingController(text: _name);
    final username = TextEditingController(text: _username.replaceFirst('@', ''));
    final bio = TextEditingController(text: _bio);
    final watching = TextEditingController(text: _watching);
    var activity = _activity == 'Lendo' ? 'Lendo' : 'Assistindo';
    var avatar = _avatarUrl;
    var cover = _coverUrl;
    Uint8List? avatarPreview;
    Uint8List? coverPreview;
    XFile? avatarFile;
    XFile? coverFile;
    var removeAvatar = false;
    var removeCover = false;
    var saving = false;
    String? message;
    final accent = AppPalette.accent(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppPalette.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) {
          Future<void> choosePhoto(bool isCover) async {
            // Abrir o seletor diretamente a partir do toque do usuário é
            // importante especialmente no Chrome / Flutter Web.
            try {
              refresh(() => message = null);
              final file = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 1600,
                imageQuality: 82,
              );
              if (file == null) return;
              final bytes = await file.readAsBytes();
              if (bytes.length > 5 * 1024 * 1024) {
                refresh(() => message = 'Escolha uma imagem com até 5 MB.');
                return;
              }
              if (!sheetContext.mounted) return;
              refresh(() {
                if (isCover) {
                  coverFile = file;
                  coverPreview = bytes;
                  removeCover = false;
                } else {
                  avatarFile = file;
                  avatarPreview = bytes;
                  removeAvatar = false;
                }
              });
            } catch (error) {
              if (sheetContext.mounted) {
                refresh(() => message =
                    'Não foi possível abrir a galeria: ${error.toString().replaceFirst('Exception: ', '')}');
              }
            }
          }

          Widget sectionTitle(String title, String subtitle) => Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 12, color: AppPalette.mutedText(sheetContext))),
              ],
            ]),
          );

          InputDecoration fieldDecoration(String label, IconData icon, {String? hint}) =>
              InputDecoration(
                labelText: label,
                hintText: hint,
                prefixIcon: Icon(icon, size: 21, color: accent),
                filled: true,
                fillColor: AppPalette.raisedSurface(sheetContext),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: accent.withValues(alpha: .13))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(17), borderSide: BorderSide(color: accent, width: 1.5)),
              );

          return FractionallySizedBox(
            heightFactor: .94,
            child: Column(children: [
              Container(
                width: 38, height: 4,
                margin: const EdgeInsets.only(top: 11, bottom: 9),
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: .45), borderRadius: BorderRadius.circular(10)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 5, 14, 12),
                child: Row(children: [
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Editar perfil', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                  ])),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: saving ? null : () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ]),
              ),
              Expanded(child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // As duas imagens são alteradas exclusivamente neste editor.
                  Stack(clipBehavior: Clip.none, children: [
                    Container(
                      height: 185,
                      margin: const EdgeInsets.only(bottom: 53),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(23),
                        gradient: LinearGradient(
                          colors: Theme.of(sheetContext).brightness == Brightness.dark
                              ? [const Color(0xFF4A161A), AppPalette.darkBackground]
                              : [const Color(0xFF7D171D), const Color(0xFFB8787C), const Color(0xFFFFD6D8)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        image: coverPreview != null
                            ? DecorationImage(image: MemoryImage(coverPreview!), fit: BoxFit.cover)
                            : cover != null && !removeCover
                                ? DecorationImage(image: NetworkImage(cover!), fit: BoxFit.cover)
                                : null,
                      ),
                      child: Align(alignment: Alignment.topRight, child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: FilledButton.tonalIcon(
                          onPressed: saving ? null : () => choosePhoto(true),
                          icon: const Icon(Icons.wallpaper_rounded, size: 18),
                          label: const Text('Alterar capa'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: .64),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      )),
                    ),
                    Positioned(left: 18, bottom: 0, child: InkWell(
                      borderRadius: BorderRadius.circular(52),
                      onTap: saving ? null : () => choosePhoto(false),
                      child: Stack(children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: AppPalette.background(sheetContext), shape: BoxShape.circle),
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: AppPalette.button(sheetContext),
                            backgroundImage: avatarPreview != null
                                ? MemoryImage(avatarPreview!) as ImageProvider
                                : avatar != null && !removeAvatar ? NetworkImage(avatar!) : null,
                            child: avatarPreview == null && (avatar == null || removeAvatar)
                                ? const Icon(Icons.person_rounded, size: 45, color: Colors.white)
                                : null,
                          ),
                        ),
                        Positioned(right: 1, bottom: 1, child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: accent, shape: BoxShape.circle,
                            border: Border.all(color: AppPalette.background(sheetContext), width: 2)),
                          child: const Icon(Icons.edit_rounded, color: Colors.white, size: 15),
                        )),
                      ]),
                    )),
                  ]),
                  Row(children: [
                    if (avatar != null || avatarPreview != null)
                      TextButton(onPressed: saving ? null : () => refresh(() {
                        avatarPreview = null; avatarFile = null; removeAvatar = true;
                      }), child: const Text('Remover foto')),
                    const Spacer(),
                    if (cover != null || coverPreview != null)
                      TextButton(onPressed: saving ? null : () => refresh(() {
                        coverPreview = null; coverFile = null; removeCover = true;
                      }), child: const Text('Restaurar capa')),
                  ]),
                  sectionTitle('Suas informações', ''),
                  TextField(controller: name, maxLength: 100,
                    decoration: fieldDecoration('Nome', Icons.person_outline_rounded)),
                  const SizedBox(height: 8),
                  TextField(controller: username, maxLength: 30,
                    decoration: fieldDecoration('Nome de usuário', Icons.alternate_email_rounded)),
                  const SizedBox(height: 8),
                  TextField(controller: bio, maxLength: 160, minLines: 2, maxLines: 4,
                    decoration: fieldDecoration('Biografia', Icons.edit_note_rounded,
                      hint: 'Conte um pouco sobre você')),
                  sectionTitle('O que você está curtindo?', ''),
                  Row(children: [
                    for (final option in ['Assistindo', 'Lendo'])
                      Expanded(child: Padding(
                        padding: EdgeInsets.only(right: option == 'Assistindo' ? 6 : 0,
                          left: option == 'Lendo' ? 6 : 0),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(17),
                          onTap: saving ? null : () => refresh(() => activity = option),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 8),
                            decoration: BoxDecoration(
                              color: activity == option ? accent.withValues(alpha: .15) : AppPalette.raisedSurface(sheetContext),
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(color: activity == option ? accent : accent.withValues(alpha: .12), width: activity == option ? 1.7 : 1),
                            ),
                            child: Column(children: [
                              Icon(option == 'Lendo' ? Icons.menu_book_rounded : Icons.movie_creation_outlined,
                                color: activity == option ? accent : AppPalette.mutedText(sheetContext), size: 27),
                              const SizedBox(height: 8),
                              Text(option == 'Lendo' ? 'Lendo agora' : 'Assistindo agora',
                                style: TextStyle(fontSize: 12.5, fontWeight: activity == option ? FontWeight.w800 : FontWeight.w500)),
                              const SizedBox(height: 4),
                              Icon(activity == option ? Icons.check_circle_rounded : Icons.circle_outlined,
                                size: 16, color: activity == option ? accent : Colors.grey),
                            ]),
                          ),
                        ),
                      )),
                  ]),
                  const SizedBox(height: 15),
                  TextField(controller: watching, maxLength: 150,
                    decoration: fieldDecoration(
                      activity == 'Lendo' ? 'Qual livro você está lendo?' : 'O que você está assistindo?',
                      activity == 'Lendo' ? Icons.book_outlined : Icons.play_circle_outline_rounded,
                      hint: activity == 'Lendo' ? 'Ex.: A hipótese do amor' : 'Ex.: Minha série favorita',
                    )),
                  if (message != null) Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(message!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                ]),
              )),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                decoration: BoxDecoration(
                  color: AppPalette.background(sheetContext),
                  border: Border(top: BorderSide(color: accent.withValues(alpha: .12))),
                ),
                child: SizedBox(width: double.infinity, height: 54,
                  child: FilledButton.icon(
                    onPressed: saving ? null : () async {
                      final cleanName = name.text.trim();
                      final cleanUsername = username.text.trim().replaceFirst(RegExp(r'^@+'), '');
                      if (cleanName.isEmpty || !RegExp(r'^[a-zA-Z0-9_.]{1,30}$').hasMatch(cleanUsername)) {
                        refresh(() => message = 'Confira o nome e o @usuário (letras, números, ponto ou _).');
                        return;
                      }
                      refresh(() { saving = true; message = null; });
                      try {
                        // Primeiro salvar os textos, depois enviar imagens pendentes.
                        await ApiService.salvarPerfil(
                          nome: cleanName, nomeUsuario: cleanUsername,
                          bio: bio.text.trim(), atividade: activity,
                          obraAtual: watching.text.trim(),
                        );
                        if (removeAvatar) await ApiService.removerImagemPerfil('foto');
                        if (removeCover) await ApiService.removerImagemPerfil('capa');
                        if (avatarFile != null) {
                          final result = await ApiService.enviarImagemPerfil(arquivo: avatarFile!, tipo: 'foto');
                          avatar = ApiService.urlImagemPerfil(result['foto_url']);
                        }
                        if (coverFile != null) {
                          final result = await ApiService.enviarImagemPerfil(arquivo: coverFile!, tipo: 'capa');
                          cover = ApiService.urlImagemPerfil(result['capa_url']);
                        }
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('perfil_nome', cleanName);
                        await prefs.setString('perfil_usuario', '@$cleanUsername');
                        await prefs.setString('perfil_bio', bio.text.trim());
                        await prefs.setString('perfil_assistindo', watching.text.trim());
                        await prefs.setString('perfil_atividade', activity);
                        if (!mounted) return;
                        setState(() {
                          _name = cleanName; _username = '@$cleanUsername';
                          _bio = bio.text.trim(); _watching = watching.text.trim();
                          _activity = activity;
                          _avatarUrl = removeAvatar ? null : avatar;
                          _coverUrl = removeCover ? null : cover;
                        });
                        // Confirma que os dados estão disponíveis no servidor.
                        final confirmado = await ApiService.meuPerfil();
                        final fotoConfirmada = ApiService.urlImagemPerfil(confirmado['foto_url']);
                        final capaConfirmada = ApiService.urlImagemPerfil(confirmado['capa_url']);
                        if (!mounted) return;
                        setState(() {
                          _name = (confirmado['nome'] as String?) ?? cleanName;
                          _username = '@${confirmado['nome_usuario'] ?? cleanUsername}';
                          _bio = (confirmado['bio'] as String?) ?? bio.text.trim();
                          _activity = (confirmado['atividade'] as String?) ?? activity;
                          _watching = (confirmado['obra_atual'] as String?) ?? watching.text.trim();
                          _avatarUrl = fotoConfirmada;
                          _coverUrl = capaConfirmada;
                        });
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Seu perfil foi atualizado!')),
                        );
                      } catch (error) {
                        if (sheetContext.mounted) refresh(() => message =
                          'Erro ao salvar: ${error.toString().replaceFirst('Exception: ', '')}');
                      } finally {
                        if (sheetContext.mounted) refresh(() => saving = false);
                      }
                    },
                    icon: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded),
                    label: Text(saving ? 'Salvando alterações...' : 'Salvar meu perfil',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                    ),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Future<String?> _pickAndUploadPhoto(String type) async {
    if (_uploadingPhoto) return null;
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 82);
    if (image == null || !mounted) return null;
    setState(() => _uploadingPhoto = true);
    try {
      final result = await ApiService.enviarImagemPerfil(arquivo: image, tipo: type);
      final url = ApiService.urlImagemPerfil(result[type == 'foto' ? 'foto_url' : 'capa_url']);
      if (!mounted) return null;
      setState(() { if (type == 'foto') { _avatarUrl = url; } else { _coverUrl = url; } });
      return url;
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível enviar a imagem: $error')));
      return null;
    } finally { if (mounted) setState(() => _uploadingPhoto = false); }
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
  Future<void> _abrirChat() async {
    final recipientId = widget.publicUserId;
    if (recipientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não é possível iniciar conversa com este usuário.'),
        ),
      );
      return;
    }
    try {
      final res = await ApiService.iniciarConversa(idDestinatario: recipientId);
      final idConversa = res['id_conversa'] as int;
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatConversationScreen(
            conversaId: idConversa,
            recipientName: _shownName,
            recipientUsername: _shownUsername,
            recipientId: recipientId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao abrir conversa: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
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
    final dark = AppPalette.isDark(context);
    final bg = AppPalette.background(context);
    final primary = AppPalette.primaryText(context);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(dark, primary),
              _buildProfileDetails(primary),
              _buildInterestsSection(primary),
              const SizedBox(height: 16),
              _buildVideosSection(primary),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildHeader(bool dark, Color primary) {
    final initial = _shownName.isEmpty ? '?' : _shownName[0].toUpperCase();
    final canPop = Navigator.of(context).canPop();
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // Capa / Banner estilizada
        Container(
          height: 170,
          margin: const EdgeInsets.only(bottom: 49),
          decoration: BoxDecoration(
            image: _coverUrl == null ? null : DecorationImage(
              image: NetworkImage(_coverUrl!), fit: BoxFit.cover,
            ),
            gradient: _coverUrl == null ? LinearGradient(
              colors: dark
                  ? [const Color(0xFF4A161A), AppPalette.darkBackground]
                  : [
                      const Color(0xFF7D171D),
                      const Color(0xFFB8787C),
                      const Color(0xFFFFD6D8),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ) : null,
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canPop)
                  IconButton(
                    tooltip: 'Voltar',
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                else
                  const SizedBox(width: 48),
                if (_isOwner)
                  IconButton(
                    tooltip: 'Configurações',
                    onPressed: widget.onOpenSettings,
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white,
                    ),
                  )
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
        ),
        // Avatar com borda destacada e sombra suave
        Positioned(
          bottom: 0,
          child: GestureDetector(
            onTap: null,
            child: Container(
            width: 102,
            height: 102,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppPalette.background(context),
              border: Border.all(color: AppPalette.accent(context), width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
              child: CircleAvatar(
                radius: 47,
                backgroundColor: AppPalette.button(context),
                backgroundImage: _avatarUrl == null ? null : NetworkImage(_avatarUrl!),
                child: _avatarUrl != null ? null : Text(
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
        ),
      ],
    );
  }
  Widget _buildProfileDetails(Color primary) {
    final username = _shownUsername;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        children: [
          Text(
            _shownName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: primary,
              fontFamily: 'IMFellFrenchCanon',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            username,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.mutedText(context),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_watching.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppPalette.button(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppPalette.border(context).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      _activity == 'Lendo' ? Icons.menu_book_rounded : Icons.play_circle_fill_rounded,
                    size: 14,
                    color: AppPalette.button(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_activity · $_watching',
                    style: TextStyle(
                      color: AppPalette.primaryText(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _bio,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.text(context),
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Estatísticas do perfil
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isOwner) ...[
                _stat(_following.length.toString(), 'seguindo'),
                _dividerDot(),
              ],
              _stat(
                _shownWorks
                    .where((work) => work['sou_fa'] == true)
                    .length
                    .toString(),
                'favoritas',
              ),
              _dividerDot(),
              _stat(widget.profileVideos.length.toString(), 'vídeos'),
            ],
          ),
          const SizedBox(height: 18),
          // Botões de Ação
          if (_isOwner)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _editProfile,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('Editar perfil'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(
                        color: AppPalette.border(
                          context,
                        ).withValues(alpha: 0.45),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _manageWorks,
                    icon: const Icon(Icons.bookmarks_outlined, size: 17),
                    label: const Text('Minhas obras'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.button(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _toggleFollow,
                    icon: Icon(
                      _following.contains(username)
                          ? Icons.check_rounded
                          : Icons.person_add_rounded,
                      size: 17,
                    ),
                    label: Text(
                      _following.contains(username) ? 'Seguindo' : 'Seguir',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _following.contains(username)
                          ? AppPalette.raisedSurface(context)
                          : AppPalette.button(context),
                      foregroundColor: _following.contains(username)
                          ? primary
                          : Colors.white,
                      side: _following.contains(username)
                          ? BorderSide(color: AppPalette.border(context))
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _abrirChat,
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 17,
                    ),
                    label: const Text('Mensagem'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(color: AppPalette.button(context)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                if (_hasCompatibilityData) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.raisedSurface(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppPalette.border(
                          context,
                        ).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFD166),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_compatibility()}%',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
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
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppPalette.primaryText(context),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: AppPalette.mutedText(context),
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
  Widget _dividerDot() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(
      '·',
      style: TextStyle(
        fontSize: 20,
        color: AppPalette.mutedText(context).withValues(alpha: 0.5),
      ),
    ),
  );
  // ── Seção de Interesses e Obras ─────────────────────────────────────
  Widget _buildInterestsSection(Color primary) {
    final works = _shownWorks;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.raisedSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppPalette.border(context).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppPalette.isDark(context) ? 0.2 : 0.04,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: AppPalette.button(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isOwner ? 'Interesses & Obras' : 'Obras & Afinidades',
                    style: TextStyle(
                      color: primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (_isOwner)
                GestureDetector(
                  onTap: _manageWorks,
                  child: Text(
                    'Gerenciar',
                    style: TextStyle(
                      color: AppPalette.button(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_worksError != null && _isOwner)
            Text(
              'Não foi possível carregar as obras: $_worksError',
              style: TextStyle(color: AppPalette.mutedText(context)),
            )
          else if (works.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _isOwner
                    ? 'Você ainda não adicionou obras aos seus interesses. Toque em "Gerenciar" para catalogar filmes, séries e livros que você ama!'
                    : 'Esta pessoa ainda não adicionou obras ao perfil.',
                style: TextStyle(
                  color: AppPalette.mutedText(context),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: works.map((work) {
                final titulo = work['titulo'] as String? ?? 'Sem título';
                final tipo = work['tipo'] as String? ?? '';
                final isFa = work['sou_fa'] == true;
                final isNotFa = work['sou_fa'] == false;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isFa
                        ? AppPalette.button(context).withValues(alpha: 0.12)
                        : AppPalette.background(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFa
                          ? AppPalette.button(context).withValues(alpha: 0.4)
                          : AppPalette.border(context).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isFa)
                        const Padding(
                          padding: EdgeInsets.only(right: 5),
                          child: Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFD166),
                            size: 15,
                          ),
                        )
                      else if (isNotFa)
                        const Padding(
                          padding: EdgeInsets.only(right: 5),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.grey,
                            size: 14,
                          ),
                        ),
                      Text(
                        titulo,
                        style: TextStyle(
                          color: primary,
                          fontSize: 12.5,
                          fontWeight: isFa ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      if (tipo.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Text(
                          '· $tipo',
                          style: TextStyle(
                            color: AppPalette.mutedText(context),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
  // ── Seção de Vídeos e Publicações ───────────────────────────────────
  Widget _buildVideosSection(Color primary) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          labelColor: primary,
          unselectedLabelColor: AppPalette.mutedText(context),
          indicatorColor: AppPalette.button(context),
          indicatorWeight: 3,
          dividerColor: AppPalette.border(context).withValues(alpha: 0.2),
          tabs: const [
            Tab(text: 'Vídeos'),
            Tab(text: 'Salvos'),
            Tab(text: 'Privados'),
          ],
        ),
        SizedBox(
          height: 380,
          child: TabBarView(
            controller: _tabs,
            children: [
              _buildVideosGrid(widget.profileVideos),
              _buildSavedList(),
              _buildPrivateList(),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildVideosGrid(List<ProfileVideo> videos) {
    if (videos.isEmpty) {
      return _empty(
        _isOwner
            ? 'Você ainda não publicou vídeos.\nUse o botão de câmera para gravar sua primeira recomendação!'
            : 'Nenhum vídeo publicado ainda.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: videos.length,
      physics: const ClampingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        final video = videos[index];
        return Material(
          color: AppPalette.raisedSurface(context),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openProfileVideo(video),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ProfileVideoThumbnail(video: video),
                Center(
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
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
  Widget _buildSavedList() {
    if (!_isOwner) return _empty('Os vídeos salvos são privados.');
    if (_savedIndices.isEmpty) {
      return _empty('Seus vídeos salvos aparecem aqui.');
    }
    final items = _savedIndices
        .where((index) => index >= 0 && index < widget.availableVideos.length)
        .map((index) => widget.availableVideos[index])
        .toList();
    if (items.isEmpty) return _empty('Seus vídeos salvos aparecem aqui.');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: items.length,
      physics: const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        return Card(
          color: AppPalette.raisedSurface(context),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              Icons.bookmark_rounded,
              color: AppPalette.button(context),
            ),
            title: Text(
              items[index],
              style: TextStyle(
                color: AppPalette.primaryText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildPrivateList() {
    if (!_isOwner) return _empty('Este espaço é privado.');
    if (widget.privateVideos.isEmpty) {
      return _empty('Seus vídeos privados aparecem aqui.');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: widget.privateVideos.length,
      physics: const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        final video = widget.privateVideos[index];
        return Card(
          color: AppPalette.raisedSurface(context),
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () => _openProfileVideo(video),
            leading: Icon(
              Icons.lock_rounded,
              color: AppPalette.mutedText(context),
            ),
            title: Text(
              video.title,
              style: TextStyle(
                color: AppPalette.primaryText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text('Somente amigos'),
            trailing: const Icon(Icons.play_circle_outline_rounded),
          ),
        );
      },
    );
  }
  Widget _empty(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 40,
            color: AppPalette.mutedText(context).withValues(alpha: 0.6),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.mutedText(context),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
  );
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
            final sourceAspectRatio = controller.value.aspectRatio;
            final sourceDisplayAspectRatio =
                controller.value.rotationCorrection % 180 == 0
                ? sourceAspectRatio
                : 1 / sourceAspectRatio;
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
                aspectRatio: 9 / 16,
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: sourceDisplayAspectRatio,
                      height: 1,
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
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
// Miniatura real do vídeo, sem alterar upload, banco ou feed.
class _ProfileVideoThumbnail extends StatefulWidget {
  final ProfileVideo video;
  const _ProfileVideoThumbnail({required this.video});
  @override
  State<_ProfileVideoThumbnail> createState() => _ProfileVideoThumbnailState();
}
class _ProfileVideoThumbnailState extends State<_ProfileVideoThumbnail> {
  VideoPlayerController? _controller;
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    VideoPlayerController? controller;
    try {
      final path = widget.video.videoPath;
      if (path == null || path.isEmpty) return;
      final videoId = widget.video.videoId;
      final Uri uri;
      if (kIsWeb && videoId != null && videoId.isNotEmpty) {
        uri = Uri.parse(await ApiService.urlArquivoVideoWeb(videoId));
      } else {
        final parsed = Uri.tryParse(path);
        if (parsed == null || (parsed.scheme != 'http' && parsed.scheme != 'https')) {
          return;
        }
        uri = parsed;
      }
      if (!mounted) return;
      controller = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: kIsWeb || widget.video.videoToken == null
            ? const {}
            : {'Authorization': 'Bearer ${widget.video.videoToken}'},
      );
      _controller = controller;
      await controller.initialize();
      await controller.setVolume(0);
      final duration = controller.value.duration;
      final position = duration > const Duration(seconds: 1)
          ? const Duration(seconds: 1)
          : Duration.zero;
      await controller.seekTo(position);
      await controller.pause();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      // Se a mídia estiver indisponível, mantém a capa padrão.
    }
  }
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Stack(
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
        if (_ready && controller != null && controller.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
      ],
    );
  }
}
