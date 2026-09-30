import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_preferences.dart';
import 'login_screen.dart';

enum _SettingKind { toggle, choice, text, action }

class _SettingOption {
  final String title;
  final String subtitle;
  final _SettingKind kind;
  final List<String> choices;
  final String? initialValue;

  const _SettingOption.toggle(this.title, this.subtitle)
    : kind = _SettingKind.toggle,
      choices = const [],
      initialValue = null;

  const _SettingOption.choice(
    this.title,
    this.subtitle,
    this.choices, {
    this.initialValue,
  }) : kind = _SettingKind.choice;

  const _SettingOption.text(this.title, this.subtitle)
    : kind = _SettingKind.text,
      choices = const [],
      initialValue = null;

  const _SettingOption.action(this.title, this.subtitle)
    : kind = _SettingKind.action,
      choices = const [],
      initialValue = null;
}

class _SettingsCategory {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_SettingOption> options;

  const _SettingsCategory(this.title, this.subtitle, this.icon, this.options);
}

const _settingsCategories = [
  _SettingsCategory('Conta', 'Seus dados e acesso', Icons.person_outline, [
    _SettingOption.text('Nome', 'Nome exibido no seu perfil'),
    _SettingOption.action('Editar perfil', 'Atualize nome, usuário e bio'),
    _SettingOption.text('Nome de usuário', 'Como as pessoas encontram você'),
    _SettingOption.text('E-mail', 'Endereço associado à conta'),
    _SettingOption.action('Senha', 'Alteração exige autenticação configurada'),
    _SettingOption.text('Número de telefone', 'Telefone associado à conta'),
    _SettingOption.action(
      'Foto de perfil',
      'Escolha uma imagem para seu perfil',
    ),
    _SettingOption.action('Contas vinculadas', 'Google e outros provedores'),
    _SettingOption.action(
      'Desativar conta',
      'Oculta temporariamente seu perfil',
    ),
    _SettingOption.action('Excluir conta', 'Remoção permanente da conta'),
  ]),
  _SettingsCategory(
    'Privacidade',
    'Controle o que outras pessoas veem',
    Icons.lock_outline,
    [
      _SettingOption.choice('Visibilidade da conta', 'Pública ou privada', [
        'Pública',
        'Privada',
      ], initialValue: 'Pública'),
      _SettingOption.choice('Quem pode seguir você', 'Permissão para seguir', [
        'Todos',
        'Pessoas aprovadas',
        'Ninguém',
      ], initialValue: 'Todos'),
      _SettingOption.choice(
        'Quem pode enviar mensagens',
        'Controle mensagens recebidas',
        ['Todos', 'Pessoas que sigo', 'Ninguém'],
        initialValue: 'Todos',
      ),
      _SettingOption.choice(
        'Quem pode comentar',
        'Permissão em suas publicações',
        ['Todos', 'Pessoas que sigo', 'Ninguém'],
        initialValue: 'Todos',
      ),
      _SettingOption.choice('Quem pode marcar você', 'Controle marcações', [
        'Todos',
        'Pessoas que sigo',
        'Ninguém',
      ], initialValue: 'Todos'),
      _SettingOption.choice('Quem pode mencionar você', 'Controle menções', [
        'Todos',
        'Pessoas que sigo',
        'Ninguém',
      ], initialValue: 'Todos'),
      _SettingOption.toggle(
        'Mostrar atividade online',
        'Exibe quando você está ativo',
      ),
      _SettingOption.action(
        'Histórico de visualizações',
        'Gerencie seu histórico local',
      ),
      _SettingOption.action(
        'Usuários bloqueados',
        'Gerencie contas bloqueadas',
      ),
    ],
  ),
  _SettingsCategory(
    'Notificações',
    'Escolha o que deseja receber',
    Icons.notifications_outlined,
    [
      _SettingOption.toggle(
        'Todas as notificações',
        'Ativa ou pausa os avisos',
      ),
      _SettingOption.toggle('Curtidas', 'Avisos de curtidas nas publicações'),
      _SettingOption.toggle('Comentários', 'Avisos de novos comentários'),
      _SettingOption.toggle(
        'Novos seguidores',
        'Avisos quando alguém seguir você',
      ),
      _SettingOption.toggle(
        'Solicitações de amizade',
        'Avisos de novas solicitações',
      ),
      _SettingOption.toggle('Mensagens', 'Avisos de mensagens recebidas'),
      _SettingOption.toggle('Recomendações', 'Sugestões de obras e perfis'),
      _SettingOption.toggle(
        'Atualizações do LupTok',
        'Novidades sobre o aplicativo',
      ),
    ],
  ),
  _SettingsCategory(
    'Aparência',
    'Personalize como o app aparece',
    Icons.palette_outlined,
    [
      _SettingOption.choice('Tema', 'Aparência do aplicativo', [
        'Claro',
        'Escuro',
        'Seguir dispositivo',
      ], initialValue: 'Claro'),
      _SettingOption.choice('Tamanho do texto', 'Ajuste a leitura', [
        'Pequeno',
        'Padrão',
        'Grande',
      ], initialValue: 'Padrão'),
    ],
  ),
  _SettingsCategory(
    'Conteúdo e reprodução',
    'Preferências para o Loop',
    Icons.play_circle_outline,
    [
      _SettingOption.action(
        'Preferências de conteúdo',
        'Edite gêneros e tipos favoritos',
      ),
      _SettingOption.action(
        'Gêneros favoritos',
        'Personalize suas recomendações',
      ),
      _SettingOption.choice('Tipos de conteúdo', 'Filmes, séries e livros', [
        'Filmes',
        'Séries',
        'Livros',
        'Todos',
      ], initialValue: 'Todos'),
      _SettingOption.action(
        'Histórico de visualizações',
        'Veja conteúdos assistidos',
      ),
      _SettingOption.action('Histórico de pesquisas', 'Veja buscas recentes'),
      _SettingOption.action(
        'Limpar histórico',
        'Apaga históricos armazenados localmente',
      ),
      _SettingOption.toggle(
        'Reprodução automática',
        'Avança o feed automaticamente',
      ),
      _SettingOption.toggle(
        'Ocultar avisos de spoiler',
        'Esconde classificações de spoiler',
      ),
    ],
  ),
  _SettingsCategory(
    'Interações',
    'Gerencie comentários e compartilhamentos',
    Icons.forum_outlined,
    [
      _SettingOption.toggle(
        'Permitir comentários',
        'Permissão para comentar publicações',
      ),
      _SettingOption.text(
        'Filtros de comentários',
        'Palavras separadas por vírgula',
      ),
      _SettingOption.text(
        'Palavras bloqueadas',
        'Comentários com estes termos serão ocultados',
      ),
      _SettingOption.toggle(
        'Permitir compartilhamento',
        'Compartilhamento de publicações',
      ),
      _SettingOption.toggle(
        'Permitir marcações',
        'Outras pessoas podem marcar você',
      ),
      _SettingOption.toggle(
        'Permitir menções',
        'Outras pessoas podem mencionar você',
      ),
    ],
  ),
  _SettingsCategory('Segurança', 'Proteja sua conta', Icons.shield_outlined, [
    _SettingOption.action('Alterar senha', 'Exige um serviço de autenticação'),
    _SettingOption.toggle(
      'Autenticação em duas etapas',
      'Requer backend de autenticação',
    ),
    _SettingOption.action('Dispositivos conectados', 'Sessões da sua conta'),
    _SettingOption.action(
      'Atividade da conta',
      'Acessos e alterações recentes',
    ),
    _SettingOption.toggle('Alertas de login', 'Avisos de novos acessos'),
    _SettingOption.action(
      'Sair de todos os dispositivos',
      'Encerra outras sessões',
    ),
  ]),
  _SettingsCategory(
    'Dados e armazenamento',
    'Gerencie seus dados locais',
    Icons.storage_outlined,
    [
      _SettingOption.toggle('Economia de dados', 'Reduz o uso de dados móveis'),
      _SettingOption.action('Limpar cache', 'Remove arquivos temporários'),
      _SettingOption.action('Baixar seus dados', 'Exportação requer backend'),
      _SettingOption.action(
        'Histórico de atividades',
        'Atividades recentes da conta',
      ),
    ],
  ),
  _SettingsCategory(
    'Gravação',
    'Preferências para seus vídeos',
    Icons.videocam_outlined,
    [
      _SettingOption.toggle('Gravar com áudio', 'Inclui o som do microfone'),
      _SettingOption.toggle(
        'Salvar na galeria automaticamente',
        'Guarda clipes no álbum Luptok',
      ),
      _SettingOption.toggle('Qualidade alta', 'Usa resolução maior na câmera'),
    ],
  ),
  _SettingsCategory('Suporte', 'Ajuda e informações', Icons.help_outline, [
    _SettingOption.action('Central de ajuda', 'Ajuda do LupTok'),
    _SettingOption.action(
      'Reportar um problema',
      'Envie detalhes para o suporte',
    ),
    _SettingOption.action('Enviar feedback', 'Compartilhe sua opinião'),
    _SettingOption.action('Termos de uso', 'Termos do aplicativo'),
    _SettingOption.action(
      'Política de privacidade',
      'Como os dados são tratados',
    ),
    _SettingOption.action(
      'Sobre o LupTok',
      'Versão e informações do aplicativo',
    ),
  ]),
];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: AppPalette.background(context),
        foregroundColor: AppPalette.primaryText(context),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          for (final category in _settingsCategories)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: AppPalette.raisedSurface(context).withValues(alpha: 0.88),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: AppPalette.border(context).withValues(alpha: 0.3),
                ),
              ),
              child: ListTile(
                leading: Icon(
                  category.icon,
                  color: AppPalette.accent(context),
                ),
                title: Text(
                  category.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(category.subtitle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _SettingsCategoryScreen(category: category),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => _sairDaConta(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sair da conta'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.primaryText(context),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showAccountAction(context, 'Excluir minha conta'),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Excluir minha conta'),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.primaryText(context),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _sairDaConta(BuildContext context) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Sair da conta?'),
      content: const Text('Você poderá entrar novamente com outra conta.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Sair'),
        ),
      ],
    ),
  );
  if (confirmar != true || !context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}

class _SettingsCategoryScreen extends StatefulWidget {
  final _SettingsCategory category;

  const _SettingsCategoryScreen({required this.category});

  @override
  State<_SettingsCategoryScreen> createState() =>
      _SettingsCategoryScreenState();
}

class _SettingsCategoryScreenState extends State<_SettingsCategoryScreen> {
  final Map<String, bool> _toggleValues = {};
  final Map<String, String> _savedValues = {};

  String _key(_SettingOption option) =>
      'setting_${widget.category.title}_${option.title}';

  @override
  void initState() {
    super.initState();
    _loadSavedValues();
  }

  Future<void> _loadSavedValues() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    for (final option in widget.category.options) {
      if (option.kind == _SettingKind.toggle) {
        _toggleValues[option.title] =
            preferences.getBool(_key(option)) ?? _defaultToggle(option);
      } else if (option.kind == _SettingKind.choice) {
        final value = preferences.getString(_key(option));
        if (value != null) _savedValues[option.title] = value;
      } else if (option.kind == _SettingKind.text) {
        final value = preferences.getString(_key(option));
        if (value != null) _savedValues[option.title] = value;
      }
    }
    if (widget.category.title == 'Conta') {
      final name = preferences.getString('perfil_nome');
      final username = preferences.getString('perfil_usuario');
      if (name != null) _savedValues['Nome'] ??= name;
      if (username != null) _savedValues['Nome de usuário'] ??= username;
    }
    setState(() {});
  }

  bool _defaultToggle(_SettingOption option) {
    if (widget.category.title == 'Notificações') return true;
    if (option.title == 'Todas as notificações' ||
        option.title == 'Permitir comentários' ||
        option.title == 'Permitir compartilhamento' ||
        option.title == 'Permitir marcações' ||
        option.title == 'Permitir menções') {
      return true;
    }
    if (option.title == 'Gravar com áudio' ||
        option.title == 'Salvar na galeria automaticamente' ||
        option.title == 'Qualidade alta') {
      return true;
    }
    return false;
  }

  Future<void> _setToggle(_SettingOption option, bool value) async {
    final preferences = await SharedPreferences.getInstance();
    final notificationOptions = widget.category.title == 'Notificações'
        ? widget.category.options
              .where((item) => item.kind == _SettingKind.toggle)
              .toList()
        : const <_SettingOption>[];
    if (option.title == 'Todas as notificações') {
      for (final item in notificationOptions) {
        await preferences.setBool(_key(item), value);
        _toggleValues[item.title] = value;
      }
    } else {
      await preferences.setBool(_key(option), value);
      _toggleValues[option.title] = value;
      if (notificationOptions.isNotEmpty) {
        final children = notificationOptions
            .where((item) => item.title != 'Todas as notificações')
            .toList();
        final allEnabled = children.every(
          (item) => item.title == option.title
              ? value
              : _toggleValues[item.title] ?? _defaultToggle(item),
        );
        _toggleValues['Todas as notificações'] = allEnabled;
        await preferences.setBool(_key(notificationOptions.first), allEnabled);
      }
    }
    if (option.title == 'Ocultar avisos de spoiler') {
      await preferences.setBool('settings_hide_spoilers', value);
    } else if (option.title == 'Gravar com áudio') {
      await preferences.setBool('settings_record_audio', value);
    } else if (option.title == 'Salvar na galeria automaticamente') {
      await preferences.setBool('settings_auto_save_video', value);
    } else if (option.title == 'Qualidade alta') {
      await preferences.setBool('settings_hd_recording', value);
    }
    if (mounted) setState(() {});
  }

  Future<void> _openOption(_SettingOption option) async {
    if (option.kind == _SettingKind.choice) {
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      final current =
          _savedValues[option.title] ??
          preferences.getString(_key(option)) ??
          option.initialValue ??
          option.choices.first;
      final selected = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(option.title),
          children: [
            RadioGroup<String>(
              groupValue: current,
              onChanged: (value) => Navigator.pop(context, value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final choice in option.choices)
                    RadioListTile<String>(value: choice, title: Text(choice)),
                ],
              ),
            ),
          ],
        ),
      );
      if (selected == null) return;
      await preferences.setString(_key(option), selected);
      if (option.title == 'Tema') {
        appThemeMode.value = switch (selected) {
          'Escuro' => ThemeMode.dark,
          'Seguir dispositivo' => ThemeMode.system,
          _ => ThemeMode.light,
        };
      } else if (option.title == 'Tamanho do texto') {
        appTextScale.value = switch (selected) {
          'Pequeno' => 0.9,
          'Grande' => 1.15,
          _ => 1.0,
        };
      }
      if (mounted) setState(() => _savedValues[option.title] = selected);
      return;
    }

    if (option.kind == _SettingKind.text) {
      await _editTextOption(option);
      return;
    }

    if (option.title == 'Editar perfil') {
      await _editarPerfil();
      return;
    }
    await _showAccountAction(context, option.title, option.subtitle);
  }

  Future<void> _editarPerfil() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final nameController = TextEditingController(
      text: preferences.getString('perfil_nome') ?? '',
    );
    final usernameController = TextEditingController(
      text: (preferences.getString('perfil_usuario') ?? '').replaceFirst(
        '@',
        '',
      ),
    );
    final bioController = TextEditingController(
      text: preferences.getString('perfil_bio') ?? '',
    );
    final saved = await showDialog<(String, String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar perfil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Nome de usuário',
                  prefixText: '@',
                ),
              ),
              TextField(
                controller: bioController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Bio'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final username = usernameController.text.trim().replaceFirst(
                RegExp(r'^@+'),
                '',
              );
              if (name.isEmpty || username.isEmpty) return;
              Navigator.pop(context, (
                name,
                '@$username',
                bioController.text.trim(),
              ));
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    nameController.dispose();
    usernameController.dispose();
    bioController.dispose();
    if (saved == null) return;
    await preferences.setString('perfil_nome', saved.$1);
    await preferences.setString('perfil_usuario', saved.$2);
    await preferences.setString('perfil_bio', saved.$3);
    if (mounted) {
      setState(() {
        _savedValues['Nome'] = saved.$1;
        _savedValues['Nome de usuário'] = saved.$2;
      });
    }
  }

  Future<void> _editTextOption(_SettingOption option) async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final controller = TextEditingController(
      text:
          _savedValues[option.title] ??
          preferences.getString(_key(option)) ??
          (option.title == 'Nome'
              ? preferences.getString('perfil_nome')
              : option.title == 'Nome de usuário'
              ? preferences.getString('perfil_usuario')?.replaceFirst('@', '')
              : null) ??
          '',
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(option.title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: option.subtitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    var displayValue = value;
    if (option.title == 'Nome') {
      await preferences.setString('perfil_nome', value);
    } else if (option.title == 'Nome de usuário') {
      final username = value.startsWith('@') ? value : '@$value';
      displayValue = username;
      await preferences.setString('perfil_usuario', username);
    }
    await preferences.setString(_key(option), displayValue);
    if (mounted) setState(() => _savedValues[option.title] = displayValue);
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      appBar: AppBar(
        title: Text(category.title),
        backgroundColor: AppPalette.background(context),
        foregroundColor: AppPalette.primaryText(context),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          for (final option in category.options)
            if (option.kind == _SettingKind.toggle)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppPalette.button(context),
                title: Text(option.title),
                subtitle: Text(option.subtitle),
                value: _toggleValues[option.title] ?? _defaultToggle(option),
                onChanged: (value) => _setToggle(option, value),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(option.title),
                subtitle: Text(
                  _savedValues[option.title] ?? option.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openOption(option),
              ),
          if (category.title == 'Gravação') ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _resetRecording,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Restaurar padrões'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _resetRecording() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove('setting_Gravação_Gravar com áudio'),
      preferences.remove('setting_Gravação_Salvar na galeria automaticamente'),
      preferences.remove('setting_Gravação_Qualidade alta'),
      preferences.remove('settings_record_audio'),
      preferences.remove('settings_auto_save_video'),
      preferences.remove('settings_hd_recording'),
    ]);
    if (mounted) setState(_toggleValues.clear);
  }
}

Future<void> _showAccountAction(
  BuildContext context,
  String title, [
  String? description,
]) async {
  final destructive =
      title.toLowerCase().contains('excluir') ||
      title.toLowerCase().contains('desativar');
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(
        description ??
            (destructive
                ? 'Esta ação ainda precisa de uma conta autenticada e de um serviço de backend. Nenhuma conta foi alterada.'
                : 'Esta função precisa de autenticação e de um serviço de backend. Nenhuma conta foi alterada.'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    ),
  );
}
