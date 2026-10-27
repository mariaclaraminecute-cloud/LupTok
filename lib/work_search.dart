class SearchableWork {
  final String title;
  final String type;
  final String description;
  final List<String> genres;
  final List<String> keywords;
  final String? cover;

  const SearchableWork({
    required this.title,
    required this.type,
    required this.description,
    required this.genres,
    required this.keywords,
    this.cover,
  });

  String get searchableText =>
      '$title $type $description ${genres.join(' ')} ${keywords.join(' ')}';
}

const searchableWorks = <SearchableWork>[
  SearchableWork(
    title: '20th Century Girl',
    type: 'Filme',
    description: 'Romance adolescente e amizade ambientados nos anos 1990.',
    genres: ['romance', 'drama', 'adolescente'],
    keywords: ['colegial', 'escola', 'juventude', 'coreano'],
    cover: 'assets/images/capa1.jpg',
  ),
  SearchableWork(
    title: 'Teen Wolf',
    type: 'Série',
    description:
        'Mistério sobrenatural e aventuras de estudantes do ensino médio.',
    genres: ['fantasia', 'terror', 'mistério', 'ação'],
    keywords: ['colegial', 'escola', 'estudante', 'lobisomem', 'adolescente'],
    cover: 'assets/images/capa2.jpg',
  ),
  SearchableWork(
    title: 'Pretty Little Liars',
    type: 'Série',
    description: 'Mistérios e segredos entre amigas de uma cidade pequena.',
    genres: ['mistério', 'suspense', 'drama'],
    keywords: ['colegial', 'escola', 'estudante', 'adolescente', 'amigas'],
    cover: 'assets/images/capa3.jpg',
  ),
  SearchableWork(
    title: 'Culpa Minha',
    type: 'Filme',
    description: 'Romance e drama adolescente com conflitos familiares.',
    genres: ['romance', 'drama'],
    keywords: ['adolescente', 'jovem', 'espanhol'],
    cover: 'assets/images/capa4.jpg',
  ),
  SearchableWork(
    title: 'Powerless',
    type: 'Livro',
    description: 'Fantasia romântica em um reino dividido por poderes.',
    genres: ['fantasia', 'romance', 'aventura'],
    keywords: ['magia', 'jovem adulto', 'ficção'],
    cover: 'assets/images/capa5.jpg',
  ),
  SearchableWork(
    title: 'The Walking Dead',
    type: 'Série',
    description: 'Sobrevivência e drama em um mundo tomado por zumbis.',
    genres: ['terror', 'drama', 'ação'],
    keywords: ['apocalipse', 'zumbi', 'sobrevivência', 'pós-apocalíptico'],
    cover: 'assets/images/capa6.jpg',
  ),
  SearchableWork(
    title: 'Naruto',
    type: 'Anime',
    description: 'Aventura de um jovem ninja em busca de reconhecimento.',
    genres: ['anime', 'ação', 'aventura', 'fantasia'],
    keywords: ['ninja', 'animação', 'shonen', 'amizade'],
    cover: 'assets/images/capa7.jpg',
  ),
  SearchableWork(
    title: 'Twinkling Watermelon',
    type: 'Dorama',
    description:
        'Jovens, música e viagem no tempo em uma história de amadurecimento.',
    genres: ['romance', 'drama', 'fantasia', 'música'],
    keywords: ['coreano', 'k-drama', 'colegial', 'escola', 'adolescente'],
    cover: 'assets/images/capa8.jpg',
  ),
  SearchableWork(
    title: 'Quarta Asa',
    type: 'Livro',
    description:
        'Fantasia romântica em uma escola militar de cavaleiros de dragões.',
    genres: ['fantasia', 'romance', 'ação'],
    keywords: ['dragão', 'escola', 'academia', 'militar', 'colegial'],
    cover: 'assets/images/capa9.jpg',
  ),
  SearchableWork(
    title: 'A Cinco Passos de Você',
    type: 'Filme',
    description:
        'Romance e drama sobre dois jovens que se conhecem no hospital.',
    genres: ['romance', 'drama'],
    keywords: ['adolescente', 'jovem', 'doença', 'emocionante'],
    cover: 'assets/images/capa10.jpg',
  ),
  SearchableWork(
    title: 'Minions',
    type: 'Filme',
    description: 'Animação de comédia e aventura para toda a família.',
    genres: ['comédia', 'animação', 'aventura'],
    keywords: ['engraçado', 'família', 'infantil'],
    cover: 'assets/images/capa11.jpg',
  ),
  SearchableWork(
    title: 'True Beauty',
    type: 'Dorama',
    description: 'Romance e comédia sobre autoestima e vida escolar.',
    genres: ['romance', 'comédia', 'drama'],
    keywords: ['coreano', 'k-drama', 'colegial', 'escola', 'estudante'],
    cover: 'assets/images/capa12.jpg',
  ),
  SearchableWork(
    title: 'Para Todos os Garotos que Já Amei',
    type: 'Filme',
    description:
        'Comédia romântica adolescente sobre cartas e primeiros amores.',
    genres: ['romance', 'comédia'],
    keywords: ['colegial', 'escola', 'adolescente', 'jovem'],
    cover: 'assets/images/capa13.jpg',
  ),
  SearchableWork(
    title: 'Shatter Me',
    type: 'Livro',
    description: 'Romance distópico sobre uma jovem com um poder perigoso.',
    genres: ['ficção científica', 'fantasia', 'romance', 'distopia'],
    keywords: ['jovem adulto', 'poderes', 'sobrenatural'],
    cover: 'assets/images/capa14.jpg',
  ),
  SearchableWork(
    title: 'É Assim que Acaba',
    type: 'Livro',
    description: 'Romance dramático sobre relacionamentos e recomeços.',
    genres: ['romance', 'drama'],
    keywords: ['emocionante', 'relacionamento', 'contemporâneo'],
    cover: 'assets/images/capa15.jpg',
  ),
  SearchableWork(
    title: 'Vingadores: Guerra Infinita',
    type: 'Filme',
    description:
        'Ação e ficção científica com heróis enfrentando uma ameaça cósmica.',
    genres: ['ação', 'aventura', 'ficção científica'],
    keywords: ['super-herói', 'marvel', 'quadrinhos', 'fantasia'],
    cover: 'assets/images/capa16.jpg',
  ),
  SearchableWork(
    title: 'The Glory',
    type: 'Dorama',
    description: 'Suspense e drama coreano sobre trauma e busca por justiça.',
    genres: ['suspense', 'drama'],
    keywords: ['coreano', 'k-drama', 'vingança', 'escola', 'bullying'],
    cover: 'assets/images/capa17.jpg',
  ),
  SearchableWork(
    title: 'Frozen',
    type: 'Filme',
    description:
        'Animação musical de fantasia sobre irmãs e aventuras no gelo.',
    genres: ['animação', 'fantasia', 'aventura', 'musical'],
    keywords: ['família', 'infantil', 'princesa', 'magia'],
    cover: 'assets/images/capa18.jpg',
  ),
  SearchableWork(
    title: 'Titanic',
    type: 'Filme',
    description: 'Romance e drama histórico a bordo de um transatlântico.',
    genres: ['romance', 'drama', 'histórico'],
    keywords: ['navio', 'trágico', 'emocionante'],
    cover: 'assets/images/capa19.jpg',
  ),
  SearchableWork(
    title: 'Wandinha',
    type: 'Série',
    description:
        'Mistério e comédia sombria em uma escola para jovens especiais.',
    genres: ['mistério', 'fantasia', 'comédia', 'terror'],
    keywords: ['colegial', 'escola', 'estudante', 'sobrenatural', 'gótico'],
    cover: 'assets/images/capa20.jpg',
  ),
  SearchableWork(
    title: 'Homem-Aranha: Sem Volta Para Casa',
    type: 'Filme',
    description: 'Aventura de super-herói com ação e ficção científica.',
    genres: ['ação', 'aventura', 'ficção científica'],
    keywords: ['super-herói', 'marvel', 'quadrinhos'],
    cover: 'assets/images/capa21.jpg',
  ),
  SearchableWork(
    title: 'Sociedade dos Poetas Mortos',
    type: 'Filme',
    description: 'Drama sobre estudantes, poesia e um professor inspirador.',
    genres: ['drama'],
    keywords: ['colegial', 'escola', 'estudante', 'poesia', 'amizade'],
    cover: 'assets/images/capa23.jpg',
  ),
  SearchableWork(
    title: 'Crepúsculo',
    type: 'Filme',
    description: 'Romance sobrenatural entre uma jovem e um vampiro.',
    genres: ['romance', 'fantasia', 'drama'],
    keywords: ['vampiro', 'adolescente', 'sobrenatural'],
    cover: 'assets/images/capa25.jpg',
  ),
  SearchableWork(
    title: 'Matilda',
    type: 'Livro',
    description:
        'Fantasia infantil sobre uma menina inteligente que ama livros.',
    genres: ['fantasia', 'infantil', 'comédia'],
    keywords: ['escola', 'criança', 'magia', 'leitura'],
    cover: 'assets/images/capa26.jpg',
  ),
  SearchableWork(
    title: 'O Diário de Anne Frank',
    type: 'Livro',
    description: 'Relato histórico e autobiográfico escrito durante a guerra.',
    genres: ['histórico', 'biografia'],
    keywords: ['guerra', 'memórias', 'história'],
    cover: 'assets/images/capa27.jpg',
  ),
  SearchableWork(
    title: 'Extraordinário',
    type: 'Livro',
    description:
        'Drama sobre empatia, amizade e a experiência de um menino na escola.',
    genres: ['drama', 'família'],
    keywords: ['colegial', 'escola', 'estudante', 'amizade', 'superação'],
    cover: 'assets/images/capa29.jpg',
  ),
  SearchableWork(
    title: 'O Mundo de Sofia',
    type: 'Livro',
    description: 'Mistério e aventura que apresentam a história da filosofia.',
    genres: ['mistério', 'aventura', 'filosofia'],
    keywords: ['educativo', 'reflexão', 'conhecimento'],
    cover: 'assets/images/capa30.jpg',
  ),
  SearchableWork(
    title: 'O Pequeno Príncipe',
    type: 'Livro',
    description: 'Fábula de aventura sobre amizade, imaginação e descobertas.',
    genres: ['aventura', 'fantasia', 'fábula'],
    keywords: ['infantil', 'filosofia', 'amizade', 'viagem'],
    cover: 'assets/images/capa31.jpg',
  ),
  SearchableWork(
    title: 'Tomorrow',
    type: 'Dorama',
    description:
        'Fantasia e drama coreano sobre uma equipe com uma missão incomum.',
    genres: ['fantasia', 'drama'],
    keywords: ['coreano', 'k-drama', 'sobrenatural'],
    cover: 'assets/images/capa33.jpg',
  ),
];

const _stopWords = {
  'a',
  'as',
  'o',
  'os',
  'um',
  'uma',
  'de',
  'do',
  'da',
  'dos',
  'das',
  'e',
  'em',
  'no',
  'na',
  'nos',
  'nas',
  'com',
  'por',
  'para',
  'que',
  'sobre',
  'me',
  'quero',
  'quais',
  'qual',
  'tem',
};

const _searchSynonyms = <String, List<String>>{
  'dorama': ['dorama', 'kdrama'],
  'kdrama': ['dorama', 'kdrama'],
  'series': ['serie', 'dorama'],
  'filmes': ['filme', 'cinema'],
  'livros': ['livro', 'leitura'],
  'colegial': ['colegial', 'escola', 'estudante', 'adolescente'],
  'escolar': ['colegial', 'escola', 'estudante', 'adolescente'],
  'escola': ['colegial', 'escola', 'estudante', 'adolescente'],
  'estudante': ['colegial', 'escola', 'estudante', 'adolescente'],
  'adolescente': ['colegial', 'escola', 'estudante', 'adolescente'],
  'filme': ['filme', 'cinema'],
  'cinema': ['filme', 'cinema'],
  'serie': ['serie', 'dorama'],
  'livro': ['livro', 'leitura'],
  'leitura': ['livro', 'leitura'],
  'engracado': ['comedia', 'engracado'],
  'divertido': ['comedia', 'engracado'],
  'chorar': ['drama', 'emocionante'],
  'triste': ['drama', 'emocionante'],
  'medo': ['terror', 'suspense'],
  'assustador': ['terror', 'suspense'],
  'sci-fi': ['ficcao', 'ciencia', 'distopia'],
  'espacial': ['ficcao', 'ciencia', 'aventura'],
};

String normalizeSearchText(String value) {
  var normalized = value.toLowerCase().trim();
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'õ': 'o',
    'ô': 'o',
    'ö': 'o',
    'ú': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  for (final entry in replacements.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll('k drama', 'dorama');
}

int searchRelevance(String query, Iterable<String> fields) {
  final normalizedQuery = normalizeSearchText(query);
  final terms = normalizedQuery
      .split(' ')
      .where((term) => term.length > 1 && !_stopWords.contains(term))
      .toSet();
  if (terms.isEmpty) return 0;

  final normalizedFields = fields.map(normalizeSearchText).toList();
  final searchableText = normalizedFields.join(' ');
  var score = 0;
  for (final term in terms) {
    final alternatives = _searchSynonyms[term] ?? [term];
    final matches = alternatives.any((alternative) {
      return normalizedFields.any((field) {
        return field
            .split(' ')
            .any((word) => word == alternative || word.startsWith(alternative));
      });
    });
    if (!matches) return 0;

    if (normalizedFields.any((field) => field.split(' ').contains(term))) {
      score += 5;
    } else {
      score += 2;
    }
    if (normalizedFields.isNotEmpty && normalizedFields.first.contains(term)) {
      score += 4;
    }
  }

  if (searchableText.contains(normalizedQuery)) score += 8;
  return score;
}

List<SearchableWork> searchWorks(String query) {
  final ranked = searchableWorks
      .map(
        (work) => (
          work: work,
          score: searchRelevance(query, [
            work.title,
            work.type,
            work.description,
            ...work.genres,
            ...work.keywords,
          ]),
        ),
      )
      .where((result) => result.score > 0)
      .toList();
  ranked.sort((first, second) => second.score.compareTo(first.score));
  return ranked.map((result) => result.work).toList();
}
