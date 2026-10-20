import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_preferences.dart';
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          isOwner: false,
          publicUsername: '@$username',
          publicName: account['nome'] as String,
          publicWorks: works,
          availableVideos: const [],
        ),
      ),
    );
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
                  Text(
                    'Pessoas',
                    style: TextStyle(
                      color: AppPalette.primaryText(context),
                      fontFamily: 'IMFellFrenchCanon',
                      fontSize: 30,
                    ),
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

  const _AccountTile({
    required this.account,
    required this.myWorks,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = account['nome'] as String;
    final username = account['nome_usuario'] as String;
    final works = account['obras'] as List<Map<String, dynamic>>;
    final percentage = workCompatibility(myWorks, works);
    final hasOpinions = myWorks.any((work) => work['sou_fa'] is bool) &&
        works.any((work) => work['sou_fa'] is bool);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppPalette.raisedSurface(context),
      elevation: 0,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppPalette.button(context),
          foregroundColor: Colors.white,
          child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
        ),
        title: Text(name),
        subtitle: Text(
          '@$username · ${hasOpinions ? '$percentage% compatível' : 'adicione obras para comparar'}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
