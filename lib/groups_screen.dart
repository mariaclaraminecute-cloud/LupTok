import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_preferences.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'work_compatibility.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late Future<List<Map<String, dynamic>>> _accounts;
  List<Map<String, dynamic>> _myWorks = [];

  @override
  void initState() {
    super.initState();
    _accounts = _loadAccounts();
  }

  Future<List<Map<String, dynamic>>> _loadAccounts() async {
    final results = await Future.wait([
      ApiService.listarContas(),
      ApiService.listarObras(),
    ]);
    _myWorks = results[1];
    final accounts = results[0];
    accounts.sort((first, second) {
      final firstWorks = first['obras'] as List<Map<String, dynamic>>;
      final secondWorks = second['obras'] as List<Map<String, dynamic>>;
      return workCompatibility(secondWorks, _myWorks).compareTo(
        workCompatibility(firstWorks, _myWorks),
      );
    });
    return accounts;
  }

  Future<void> _reload() async {
    setState(() => _accounts = _loadAccounts());
  }

  void _openProfile(Map<String, dynamic> account) {
    final username = account['nome_usuario'] as String;
    final works = account['obras'] as List<Map<String, dynamic>>;
    final accountId = account['id'];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          isOwner: false,
          publicUserId: accountId != null ? int.tryParse(accountId.toString()) : null,
          publicUsername: '@$username',
          publicName: account['nome'] as String,
          publicWorks: works,
          availableVideos: const [],
        ),
      ),
    );
  }

  Future<void> _iniciarChat(Map<String, dynamic> account) async {
    final id = account['id'];
    if (id == null) return;
    final nome = account['nome'] as String;
    final username = account['nome_usuario'] as String;
    final foto = account['foto_url'] as String?;

    try {
      final res = await ApiService.iniciarConversa(idDestinatario: id);
      final idConversa = res['id_conversa'] as int;
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatConversationScreen(
            conversaId: idConversa,
            recipientName: nome,
            recipientUsername: '@$username',
            recipientPhoto: foto,
            recipientId: id is int ? id : int.parse(id.toString()),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível abrir a conversa: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _accounts,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _message(
                context,
                'Não foi possível carregar as contas.',
                action: TextButton(
                  onPressed: _reload,
                  child: const Text('Tentar novamente'),
                ),
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final accounts = snapshot.data!;
            if (accounts.isEmpty) {
              return _message(
                context,
                'Ainda não há outras contas cadastradas. '
                'Quando alguém criar uma conta, ela aparecerá aqui.',
                action: TextButton(
                  onPressed: _reload,
                  child: const Text('Atualizar'),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pessoas',
                        style: TextStyle(
                          color: AppPalette.primaryText(context),
                          fontFamily: 'IMFellFrenchCanon',
                          fontSize: 30,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Mensagens',
                        icon: Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppPalette.primaryText(context),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ConversationsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Contas cadastradas, ordenadas pela compatibilidade das obras.',
                    style: TextStyle(color: AppPalette.mutedText(context)),
                  ),
                  const SizedBox(height: 16),
                  for (final account in accounts)
                    _AccountTile(
                      account: account,
                      myWorks: _myWorks,
                      onTap: () => _openProfile(account),
                      onChat: () => _iniciarChat(account),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _message(
    BuildContext context,
    String message, {
    Widget? action,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 48,
            color: AppPalette.mutedText(context),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.mutedText(context)),
          ),
          if (action != null) action,
        ],
      ),
    ),
  );
}

class _AccountTile extends StatelessWidget {
  final Map<String, dynamic> account;
  final List<Map<String, dynamic>> myWorks;
  final VoidCallback onTap;
  final VoidCallback onChat;

  const _AccountTile({
    required this.account,
    required this.myWorks,
    required this.onTap,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final name = account['nome'] as String;
    final username = account['nome_usuario'] as String;
    final works = account['obras'] as List<Map<String, dynamic>>;
    final percentage = workCompatibility(myWorks, works);
    final hasOpinions = myWorks.any((work) => work['sou_fa'] is bool) &&
        works.any((work) => work['sou_fa'] is bool);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppPalette.raisedSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppPalette.border(context).withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppPalette.isDark(context) ? 0.2 : 0.05,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppPalette.button(context),
                  foregroundColor: Colors.white,
                  child: Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: AppPalette.primaryText(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: TextStyle(
                          color: AppPalette.mutedText(context),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: hasOpinions
                              ? AppPalette.button(context).withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          hasOpinions
                              ? '$percentage% compatível'
                              : 'Sem obras em comum',
                          style: TextStyle(
                            color: hasOpinions
                                ? AppPalette.primaryText(context)
                                : AppPalette.mutedText(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Conversar',
                  icon: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppPalette.button(context),
                    size: 22,
                  ),
                  onPressed: onChat,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

