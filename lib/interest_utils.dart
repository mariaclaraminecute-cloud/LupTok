String normalizeInterest(String value) {
  var normalized = value.toLowerCase().trim();
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'é': 'e',
    'ê': 'e',
    'í': 'i',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ç': 'c',
  };
  for (final entry in replacements.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return switch (normalized) {
    'filmes' => 'filme',
    'livros' => 'livro',
    'series' => 'serie',
    'k-drama' || 'kdrama' => 'dorama',
    'ficcao cientifica' || 'sci-fi' => 'ficcao',
    _ => normalized,
  };
}

String displayInterest(String value) => switch (normalizeInterest(value)) {
  'filme' => 'Filmes',
  'serie' => 'Séries',
  'livro' => 'Livros',
  'ficcao' => 'Ficção',
  'dorama' => 'Dorama',
  'acao' => 'Ação',
  'comedia' => 'Comédia',
  'misterio' => 'Mistério',
  'historico' => 'Histórico',
  final label =>
    label.isEmpty ? label : '${label[0].toUpperCase()}${label.substring(1)}',
};
