import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_preferences.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

/// Página principal da aba Conversas. O histórico fica visível imediatamente.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  int _section = 0;

  Future<void> _novaConversa() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const _NewConversationScreen()),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppPalette.primaryText(context);
    final accent = AppPalette.button(context);
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              child: Row(children: [
                Expanded(child: Text('Conversas', style: TextStyle(
                  color: primary, fontFamily: 'IMFellFrenchCanon', fontSize: 30,
                ))),
                IconButton(
                  tooltip: 'Nova conversa',
                  onPressed: _novaConversa,
                  icon: Icon(Icons.edit_square, color: primary),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _tab('Mensagens', 0, accent, primary),
                const SizedBox(width: 10),
                _tab('Comunidades', 1, accent, primary),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(child: _section == 0
              ? ConversationsScreen(key: ValueKey(_section), embedded: true)
              : _communities()),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, int index, Color accent, Color primary) {
    final active = _section == index;
    return Expanded(child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _section = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.20) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? accent : AppPalette.border(context).withValues(alpha: 0.25)),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(
          color: primary, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        )),
      ),
    ));
  }

  Widget _communities() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.groups_rounded, size: 56, color: AppPalette.button(context)),
        const SizedBox(height: 18),
        Text('Comunidades', style: TextStyle(
          fontSize: 23, fontWeight: FontWeight.w700,
          color: AppPalette.primaryText(context),
        )),
        const SizedBox(height: 10),
        Text('Em breve, você poderá encontrar comunidades para conversar sobre seus livros, filmes e séries favoritos.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppPalette.mutedText(context), height: 1.5)),
      ]),
    ));
  }
}

/// A busca por pessoas fica acessível somente ao iniciar uma nova conversa.
class _NewConversationScreen extends StatefulWidget {
  const _NewConversationScreen();

  @override
  State<_NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<_NewConversationScreen> {
  late final Future<List<Map<String, dynamic>>> _accounts = ApiService.listarContas();
  String _query = '';
  bool _opening = false;

  Future<void> _openChat(Map<String, dynamic> account) async {
    if (_opening) return;
    final id = account['id'];
    if (id == null) return;
    setState(() => _opening = true);
    try {
      final result = await ApiService.iniciarConversa(idDestinatario: id);
      final rawId = result['id_conversa'];
      final conversationId = rawId is int ? rawId : int.tryParse('$rawId');
      if (conversationId == null) throw Exception('Conversa sem identificador.');
      if (!mounted) return;
      final name = account['nome']?.toString() ?? 'Usuário';
      final username = account['nome_usuario']?.toString() ?? '';
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => ChatConversationScreen(
          conversaId: conversationId,
          recipientName: name,
          recipientUsername: username.isEmpty ? '' : '@$username',
          recipientPhoto: account['foto_url'] as String?,
          recipientId: id is int ? id : int.tryParse('$id') ?? 0,
        ),
      ));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Não foi possível iniciar a conversa: ${e.toString().replaceFirst('Exception: ', '')}'),
      ));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppPalette.primaryText(context);
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      appBar: AppBar(
        title: const Text('Nova conversa'),
        backgroundColor: AppPalette.background(context),
        foregroundColor: primary,
      ),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(
          onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Pesquisar por nome ou @usuário',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: AppPalette.raisedSurface(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        )),
        Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _accounts,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Não foi possível carregar os usuários.', style: TextStyle(color: primary)));
            }
            final accounts = (snapshot.data ?? []).where((account) {
              final name = account['nome']?.toString().toLowerCase() ?? '';
              final username = account['nome_usuario']?.toString().toLowerCase() ?? '';
              return name.contains(_query) || username.contains(_query);
            }).toList();
            if (accounts.isEmpty) {
              return Center(child: Text('Nenhum usuário encontrado.', style: TextStyle(color: primary)));
            }
            return ListView.builder(
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                final name = account['nome']?.toString() ?? 'Usuário';
                final username = account['nome_usuario']?.toString() ?? '';
                final photo = ApiService.urlImagemPerfil(account['foto_url'] as String?);
                return ListTile(
                  enabled: !_opening,
                  leading: CircleAvatar(
                    backgroundColor: AppPalette.button(context),
                    foregroundImage: photo == null ? null : NetworkImage(photo),
                    child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(name, style: TextStyle(color: primary)),
                  subtitle: Text('@$username', style: TextStyle(color: AppPalette.mutedText(context))),
                  trailing: Icon(Icons.chat_bubble_outline_rounded, color: AppPalette.button(context)),
                  onTap: () => _openChat(account),
                );
              },
            );
          },
        )),
      ]),
    );
  }
}
