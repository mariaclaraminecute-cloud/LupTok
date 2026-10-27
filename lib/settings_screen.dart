import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'app_preferences.dart';
import 'login_screen.dart';

enum _PreferenceKind { toggle, choice }

class _PreferenceOption {
  final String title;
  final String subtitle;
  final _PreferenceKind kind;
  final List<String> choices;
  final String key;
  final String? effectKey;
  final String? initialValue;
  final bool initialToggle;

  const _PreferenceOption.toggle(
    this.title,
    this.subtitle, {
    required this.key,
    this.effectKey,
    this.initialToggle = false,
  }) : kind = _PreferenceKind.toggle,
       choices = const [],
       initialValue = null;

  const _PreferenceOption.choice(
    this.title,
    this.subtitle,
    this.choices, {
    required this.key,
    this.initialValue,
  }) : kind = _PreferenceKind.choice,
       effectKey = null,
       initialToggle = false;
}

class _SettingsCategory {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<_PreferenceOption> options;

  const _SettingsCategory(this.title, this.subtitle, this.icon, this.options);
}

const _settingsCategories = [
  _SettingsCategory(
    'Aparência',
    'Personalize como o aplicativo aparece',
    Icons.palette_outlined,
    [
      _PreferenceOption.choice(
        'Tema',
        'Aparência do aplicativo',
        ['Claro', 'Escuro', 'Seguir dispositivo'],
        key: 'setting_Aparência_Tema',
        initialValue: 'Claro',
      ),
      _PreferenceOption.choice(
        'Tamanho do texto',
        'Ajuste a leitura',
        ['Pequeno', 'Padrão', 'Grande'],
        key: 'setting_Aparência_Tamanho do texto',
        initialValue: 'Padrão',
      ),
    ],
  ),
  _SettingsCategory(
    'Conteúdo',
    'Ajuste a exibição dos vídeos',
    Icons.play_circle_outline,
    [
      _PreferenceOption.toggle(
        'Ocultar avisos de spoiler',
        'Esconde o nível de spoiler nas publicações',
        key: 'setting_Conteúdo_Ocultar avisos de spoiler',
        effectKey: 'settings_hide_spoilers',
      ),
    ],
  ),
  _SettingsCategory(
    'Gravação',
    'Preferências para seus vídeos',
    Icons.videocam_outlined,
    [
      _PreferenceOption.toggle(
        'Gravar com áudio',
        'Inclui o som do microfone',
        key: 'setting_Gravação_Gravar com áudio',
        effectKey: 'settings_record_audio',
        initialToggle: true,
      ),
      _PreferenceOption.toggle(
        'Salvar na galeria automaticamente',
        'Guarda clipes no álbum LupTok',
        key: 'setting_Gravação_Salvar na galeria automaticamente',
        effectKey: 'settings_auto_save_video',
        initialToggle: true,
      ),
      _PreferenceOption.toggle(
        'Qualidade alta',
        'Usa resolução maior na câmera',
        key: 'setting_Gravação_Qualidade alta',
        effectKey: 'settings_hd_recording',
        initialToggle: true,
      ),
    ],
  ),
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
                leading: Icon(category.icon, color: AppPalette.accent(context)),
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
  await ApiService.encerrarSessao();
  if (!context.mounted) return;
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
  final Map<String, String> _choiceValues = {};

  @override
  void initState() {
    super.initState();
    _loadValues();
  }

  Future<void> _loadValues() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    for (final option in widget.category.options) {
      if (option.kind == _PreferenceKind.toggle) {
        _toggleValues[option.key] =
            preferences.getBool(option.effectKey ?? option.key) ??
            option.initialToggle;
      } else {
        _choiceValues[option.key] =
            preferences.getString(option.key) ??
            option.initialValue ??
            option.choices.first;
      }
    }
    setState(() {});
  }

  Future<void> _setToggle(_PreferenceOption option, bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(option.key, value);
    if (option.effectKey != null) {
      await preferences.setBool(option.effectKey!, value);
    }
    if (mounted) setState(() => _toggleValues[option.key] = value);
  }

  Future<void> _choose(_PreferenceOption option) async {
    final current =
        _choiceValues[option.key] ??
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

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(option.key, selected);
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
    if (mounted) setState(() => _choiceValues[option.key] = selected);
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
            if (option.kind == _PreferenceKind.toggle)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppPalette.button(context),
                title: Text(option.title),
                subtitle: Text(option.subtitle),
                value: _toggleValues[option.key] ?? option.initialToggle,
                onChanged: (value) => _setToggle(option, value),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(option.title),
                subtitle: Text(
                  _choiceValues[option.key] ??
                      option.initialValue ??
                      option.choices.first,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _choose(option),
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
    if (mounted) {
      setState(() {
        _toggleValues.clear();
      });
    }
  }
}
