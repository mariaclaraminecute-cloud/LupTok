import 'package:flutter/material.dart';

import 'api_service.dart';
import 'app_preferences.dart';

class WorksScreen extends StatefulWidget {
  const WorksScreen({super.key});

  @override
  State<WorksScreen> createState() => _WorksScreenState();
}

class _WorksScreenState extends State<WorksScreen> {
  static const _types = [
    'Anime',
    'Dorama',
    'Filme',
    'Série',
    'Livro',
    'Mangá',
    'Jogo',
    'Outro',
  ];

  late Future<List<Map<String, dynamic>>> _works;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _works = ApiService.listarObras();
  }

  Future<void> _reload() async {
    setState(() => _works = ApiService.listarObras());
  }

  Future<void> _addWork() async {
    final titleController = TextEditingController();
    String? selectedType;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adicionar obra'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                maxLength: 150,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(labelText: 'Nome da obra'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                hint: const Text('Escolha o tipo'),
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: _types
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) {
                  setDialogState(() => selectedType = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed:
                  titleController.text.trim().isEmpty || selectedType == null
                  ? null
                  : () {
                      final title = titleController.text.trim();
                      final type = selectedType;
                      if (type != null) {
                        Navigator.pop(dialogContext, (title, type));
                      }
                    },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await ApiService.adicionarObra(titulo: result.$1, tipo: result.$2);
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setRating(int index, bool isFan) async {
    final works = await _works;
    final work = works[index];
    final previous = work['sou_fa'];
    setState(() => work['sou_fa'] = isFan);
    try {
      await ApiService.avaliarObra(id: work['id'], souFa: isFan);
    } catch (error) {
      if (mounted) {
        setState(() => work['sou_fa'] = previous);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    }
  }

  String _errorMessage(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      appBar: AppBar(
        title: const Text('Obras'),
        backgroundColor: AppPalette.background(context),
        foregroundColor: AppPalette.primaryText(context),
        actions: [
          IconButton(
            tooltip: 'Adicionar obra',
            onPressed: _saving ? null : _addWork,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _works,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Não foi possível carregar as obras: '
                      '${_errorMessage(snapshot.error!)}',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: _reload,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final works = snapshot.data!;
          if (works.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_stories_outlined,
                      size: 48,
                      color: AppPalette.mutedText(context),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'O catálogo ainda está vazio. Adicione uma obra para '
                      'começar a comparar gostos com outras pessoas.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _saving ? null : _addWork,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Adicionar primeira obra'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    'O catálogo é criado pelas pessoas que usam o LupTok. '
                    'Marque se você é fã para calcular compatibilidades.',
                  ),
                ),
                for (var index = 0; index < works.length; index++)
                  _WorkTile(
                    work: works[index],
                    onRate: (isFan) => _setRating(index, isFan),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saving ? null : _addWork,
        backgroundColor: AppPalette.button(context),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _WorkTile extends StatelessWidget {
  final Map<String, dynamic> work;
  final ValueChanged<bool> onRate;

  const _WorkTile({required this.work, required this.onRate});

  @override
  Widget build(BuildContext context) {
    final rating = work['sou_fa'];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppPalette.raisedSurface(context),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              work['titulo'] as String,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 3),
            Text(
              work['tipo'] as String,
              style: TextStyle(color: AppPalette.mutedText(context)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Sou fã'),
                  selected: rating == true,
                  onSelected: (_) => onRate(true),
                ),
                ChoiceChip(
                  label: const Text('Não sou fã'),
                  selected: rating == false,
                  onSelected: (_) => onRate(false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
