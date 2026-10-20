# LupTok

Aplicativo Flutter do LupTok com API em Node.js, Express e MySQL.

## API e autenticação

O backend usa as variáveis `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`,
`DB_NAME`, `JWT_SECRET` e, opcionalmente, `PORT` no arquivo `backend/.env`.
Inicie a API dentro de `backend/` com `npm install` e `node server.js`.
As contas são autenticadas por JWT; a tabela de publicações de vídeo é criada
automaticamente no banco na inicialização do backend.

## Obras e compatibilidade

O catálogo de obras começa vazio e é preenchido pelas próprias pessoas. Ao
adicionar uma obra, escolha seu tipo e marque “Sou fã” ou “Não sou fã”.
Compatibilidade considera 70% de concordância nas mesmas obras avaliadas e 30%
de tipos de obra em comum entre as obras marcadas como favoritas. Obras iguais
com avaliações diferentes diminuem a pontuação. Títulos repetidos do mesmo
tipo são reunidos no mesmo item do catálogo.

Na área “Pessoas”, aparecem apenas outras contas ativas cadastradas. Se ainda
não houver contas, a tela informa que a lista está vazia.

## Publicar vídeos

Vídeos são enviados para `backend/uploads/` e os dados da publicação são
guardados no MySQL. O limite por arquivo é 250 MB. Essa pasta é ignorada pelo
Git; em hospedagens com disco temporário, configure armazenamento persistente
antes de publicar o backend.

O app usa `http://10.0.2.2:3000` por padrão no Android e
`http://localhost:3000` na web. Para outro ambiente, informe a URL da API ao
iniciar o Flutter, por exemplo:
`flutter run --dart-define=API_BASE_URL=http://localhost:3000`.

A opção de privacidade “Somente amigos” fica visível apenas para quem publicou
até existir uma relação de amizade implementada no backend.
