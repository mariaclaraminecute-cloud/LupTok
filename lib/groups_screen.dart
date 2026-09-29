import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'interest_utils.dart';

class GroupsScreen extends StatelessWidget {
  final List<String> interests;

  const GroupsScreen({super.key, required this.interests});

  static const _groups = [
    _InterestGroup(
      id: 'sci_fi',
      title: 'Ficção sem fronteiras',
      subtitle: 'Viagens no tempo, universos e teorias',
      image: 'assets/images/ficcao.png',
      interests: ['Ficção', 'Ficção Científica', 'Filmes', 'Séries'],
      members: 128,
      messages: [
        'Qual final de ficção científica mais ficou na cabeça de vocês?',
        'Interstellar ainda rende teoria pra semana inteira.',
      ],
    ),
    _InterestGroup(
      id: 'doramas',
      title: 'Clube dos doramas',
      subtitle: 'Indicações sem spoiler e maratonas',
      image: 'assets/images/dorama.png',
      interests: ['Dorama', 'Romance', 'Drama', 'Séries'],
      members: 86,
      messages: [
        'Uma indicação curtinha para começar?',
        'Estou procurando algo leve para o fim de semana.',
      ],
    ),
    _InterestGroup(
      id: 'book_club',
      title: 'Entre páginas',
      subtitle: 'Livros, adaptações e leituras coletivas',
      image: 'assets/images/livro.png',
      interests: ['Livros', 'Fantasia', 'Romance', 'Histórico'],
      members: 54,
      messages: [
        'Qual livro merecia uma adaptação melhor?',
        'Começamos uma leitura coletiva este mês?',
      ],
    ),
    _InterestGroup(
      id: 'anime',
      title: 'Anime sem pressa',
      subtitle: 'Do episódio da semana aos clássicos',
      image: 'assets/images/anime.png',
      interests: ['Anime', 'Ação', 'Fantasia', 'Aventura'],
      members: 203,
      messages: [
        'O que vocês estão acompanhando nesta temporada?',
        'Quero uma história fechada para maratonar.',
      ],
    ),
  ];

  int _compatibility(List<String> groupInterests) {
    if (interests.isEmpty) return 0;
    final user = interests.map(normalizeInterest).toSet();
    final group = groupInterests.map(normalizeInterest).toSet();
    final shared = user.intersection(group).length;
    final score = (shared / group.length * 100).round();
    return score.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final sortedGroups = [..._groups]
      ..sort(
        (a, b) =>
            _compatibility(b.interests).compareTo(_compatibility(a.interests)),
      );

    return Scaffold(
      backgroundColor: const Color(0xFFFFE9E9),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Grupos',
                    style: TextStyle(
                      color: Color(0xFF7D171D),
                      fontFamily: 'IMFellFrenchCanon',
                      fontSize: 30,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Convidar pessoas',
                  onPressed: () => _showPeople(context),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  color: const Color(0xFF7D171D),
                ),
              ],
            ),
            Text(
              'Conversas alinhadas com o que você curte',
              style: TextStyle(
                color: const Color(0xFF7D171D).withOpacity(0.65),
              ),
            ),
            const SizedBox(height: 20),
            if (interests.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Escolha gêneros no onboarding para personalizar a compatibilidade dos grupos.',
                ),
              ),
            for (final group in sortedGroups)
              _GroupCard(
                group: group,
                compatibility: _compatibility(group.interests),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _GroupChatScreen(group: group),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Pessoas para conhecer',
              style: TextStyle(
                color: Color(0xFF7D171D),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            for (final person in _people)
              _PersonCard(
                person: person,
                compatibility: _compatibility(person.interests),
                onInvite: () => _invite(context, person),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Conversas e convites ficam salvos neste aparelho nesta versão. Para conversar com outras pessoas, o LupTok precisa de um serviço online.',
                style: TextStyle(fontSize: 12, color: Color(0xFF7D171D)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPeople(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFFF7F7),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Convide alguém',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolha uma pessoa com gostos parecidos e abra uma conversa de demonstração.',
              ),
              const SizedBox(height: 16),
              for (final person in _people)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(person.name.substring(0, 1)),
                  ),
                  title: Text(person.name),
                  subtitle: Text('@${person.username}'),
                  onTap: () {
                    Navigator.pop(context);
                    _invite(context, person);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _invite(BuildContext context, _GroupPerson person) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _GroupChatScreen(
          group: _InterestGroup(
            id: 'person_${person.username}',
            title: person.name,
            subtitle: 'Conversa individual de demonstração',
            image: '',
            interests: person.interests,
            members: 2,
            messages: [
              'Oi! Vi que a gente gosta de ${person.interests.take(2).join(' e ')}.',
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final _InterestGroup group;
  final int compatibility;
  final VoidCallback onTap;

  const _GroupCard({
    required this.group,
    required this.compatibility,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white.withValues(alpha: 0.82),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 50,
            height: 50,
            child: Image.asset(
              group.image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFFFFD6D8),
                child: Icon(Icons.groups_rounded, color: Color(0xFF7D171D)),
              ),
            ),
          ),
        ),
        title: Text(
          group.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${group.subtitle}\n${group.members} membros · $compatibility% compatível',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final _GroupPerson person;
  final int compatibility;
  final VoidCallback onInvite;

  const _PersonCard({
    required this.person,
    required this.compatibility,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFBB7575),
        child: Text(
          person.name.substring(0, 1),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(person.name),
      subtitle: Text('@${person.username} · $compatibility% compatível'),
      trailing: IconButton(
        tooltip: 'Convidar para conversar',
        onPressed: onInvite,
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        color: const Color(0xFF7D171D),
      ),
    );
  }
}

class _GroupChatScreen extends StatefulWidget {
  final _InterestGroup group;

  const _GroupChatScreen({required this.group});

  @override
  State<_GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<_GroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late List<String> _messages = [...widget.group.messages];
  bool _loading = true;

  String get _storageKey => 'group_messages_${widget.group.id}';

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _messages = preferences.getStringList(_storageKey) ?? _messages;
      _loading = false;
    });
  }

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    final nextMessages = [..._messages, message];
    setState(() {
      _messages = nextMessages;
      _controller.clear();
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_storageKey, nextMessages);
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE9E9),
      appBar: AppBar(
        title: Text(widget.group.title),
        backgroundColor: const Color(0xFFFFE9E9),
        foregroundColor: const Color(0xFF7D171D),
        actions: [
          IconButton(
            tooltip: 'Detalhes do grupo',
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: widget.group.title,
              children: [Text(widget.group.subtitle)],
            ),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => Align(
                      alignment: index.isEven
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: index.isEven
                              ? Colors.white
                              : const Color(0xFFBB7575),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _messages[index],
                          style: TextStyle(
                            color: index.isEven
                                ? const Color(0xFF493333)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Escreva uma mensagem',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sendMessage,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFBB7575),
                    ),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestGroup {
  final String id;
  final String title;
  final String subtitle;
  final String image;
  final List<String> interests;
  final int members;
  final List<String> messages;

  const _InterestGroup({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.image,
    required this.interests,
    required this.members,
    required this.messages,
  });
}

class _GroupPerson {
  final String name;
  final String username;
  final List<String> interests;

  const _GroupPerson(this.name, this.username, this.interests);
}

const _people = [
  _GroupPerson('Marina Costa', 'marina.livros', [
    'Livros',
    'Fantasia',
    'Romance',
  ]),
  _GroupPerson('Gabriel Lima', 'gui.scifi', ['Ficção', 'Filmes', 'Séries']),
  _GroupPerson('Júlia Santos', 'julia.dorama', ['Dorama', 'Romance', 'Drama']),
];
