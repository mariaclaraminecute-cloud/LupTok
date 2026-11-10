// LupTok - rotas de perfil persistente (MySQL / Railway)
// Salve este conteúdo como backend/perfil_routes.js.
// Em backend/server.js, imediatamente ANTES da linha:
// function autenticarArquivoVideo(req, res, next) {
// adicione: require('./perfil_routes')(app, db, autenticar);

const multer = require('multer');

module.exports = function registrarRotasPerfil(app, db, autenticar) {
  // Criada automaticamente: nenhum SQL manual nem alteração de senha.
  let erroPreparacao = null;
  const pronta = db.execute(`
    CREATE TABLE IF NOT EXISTS usuario_perfil (
      id_usuario BIGINT UNSIGNED NOT NULL PRIMARY KEY,
      bio VARCHAR(160) NOT NULL DEFAULT '',
      assistindo VARCHAR(120) NOT NULL DEFAULT '',
      foto MEDIUMBLOB NULL,
      foto_mime VARCHAR(24) NULL,
      avatar_versao INT UNSIGNED NOT NULL DEFAULT 0,
      atualizado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  `).catch((error) => {
    erroPreparacao = error;
    console.error('Não foi possível preparar a tabela de perfil:', error.message);
  });

  async function preparar() {
    await pronta;
    if (erroPreparacao) throw erroPreparacao;
  }

  const selecionar = `
    SELECT u.id_usuario, u.nome, u.nome_usuario, u.email, u.foto_url,
           COALESCE(p.bio, '') AS bio,
           COALESCE(p.assistindo, '') AS assistindo,
           COALESCE(p.avatar_versao, 0) AS avatar_versao
    FROM usuario u
    LEFT JOIN usuario_perfil p ON p.id_usuario = u.id_usuario
    WHERE u.id_usuario = ? AND u.ativo = 1
    LIMIT 1
  `;

  async function meuPerfil(id) {
    const [rows] = await db.execute(selecionar, [id]);
    return rows[0] || null;
  }

  app.get('/api/me', autenticar, async (req, res) => {
    try {
      await preparar();
      const usuario = await meuPerfil(req.usuario.id_usuario);
      if (!usuario) return res.status(404).json({ erro: 'Conta não encontrada.' });
      return res.json({ usuario });
    } catch (error) {
      console.error('Erro ao consultar meu perfil:', error.message);
      return res.status(500).json({ erro: 'Não foi possível carregar o perfil.' });
    }
  });

  app.put('/api/me', autenticar, async (req, res) => {
    const { nome, nome_usuario, bio = '', assistindo = '' } = req.body || {};
    if (
      typeof nome !== 'string' || !nome.trim() || nome.trim().length > 100 ||
      typeof nome_usuario !== 'string' ||
      !/^[a-zA-Z0-9_.]{1,30}$/.test(nome_usuario.trim().replace(/^@/, '')) ||
      typeof bio !== 'string' || bio.length > 160 ||
      typeof assistindo !== 'string' || assistindo.length > 120
    ) {
      return res.status(400).json({ erro: 'Confira nome, @usuário e biografia.' });
    }
    const usuarioLimpo = nome_usuario.trim().replace(/^@/, '');
    let conexao;
    try {
      await preparar();
      conexao = await db.getConnection();
      await conexao.beginTransaction();
      const [existentes] = await conexao.execute(
        `SELECT id_usuario FROM usuario
         WHERE LOWER(nome_usuario) = LOWER(?) AND id_usuario <> ? LIMIT 1`,
        [usuarioLimpo, req.usuario.id_usuario],
      );
      if (existentes.length) {
        await conexao.rollback();
        return res.status(409).json({ erro: 'Esse nome de usuário já está em uso.' });
      }
      const [resultado] = await conexao.execute(
        'UPDATE usuario SET nome = ?, nome_usuario = ? WHERE id_usuario = ? AND ativo = 1',
        [nome.trim(), usuarioLimpo, req.usuario.id_usuario],
      );
      if (!resultado.affectedRows) {
        await conexao.rollback();
        return res.status(404).json({ erro: 'Conta não encontrada.' });
      }
      await conexao.execute(
        `INSERT INTO usuario_perfil (id_usuario, bio, assistindo)
         VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE bio = VALUES(bio), assistindo = VALUES(assistindo)`,
        [req.usuario.id_usuario, bio.trim(), assistindo.trim()],
      );
      await conexao.commit();
      const usuario = await meuPerfil(req.usuario.id_usuario);
      return res.json({ usuario, mensagem: 'Perfil atualizado com sucesso.' });
    } catch (error) {
      if (conexao) await conexao.rollback().catch(() => {});
      if (error.code === 'ER_DUP_ENTRY') {
        return res.status(409).json({ erro: 'Esse nome de usuário já está em uso.' });
      }
      console.error('Erro ao salvar perfil:', error.message);
      return res.status(500).json({ erro: 'Não foi possível salvar o perfil.' });
    } finally {
      if (conexao) conexao.release();
    }
  });

  const carregarFoto = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 500 * 1024 },
  }).single('foto');

  function mimeReal(bytes) {
    if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return 'image/jpeg';
    if (bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) return 'image/png';
    if (bytes.length >= 12 && bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP') return 'image/webp';
    return null;
  }

  app.post('/api/me/avatar', autenticar, (req, res, next) => {
    carregarFoto(req, res, (erro) => {
      if (erro) return res.status(400).json({ erro: 'Use uma foto JPG, PNG ou WEBP de até 500 KB.' });
      next();
    });
  }, async (req, res) => {
    if (!req.file?.buffer) return res.status(400).json({ erro: 'Selecione uma foto.' });
    const mime = mimeReal(req.file.buffer);
    if (!mime) return res.status(400).json({ erro: 'Formato de imagem inválido.' });
    let conexao;
    try {
      await preparar();
      conexao = await db.getConnection();
      await conexao.beginTransaction();
      await conexao.execute(
        `INSERT INTO usuario_perfil (id_usuario, foto, foto_mime, avatar_versao)
         VALUES (?, ?, ?, 1)
         ON DUPLICATE KEY UPDATE
           foto = VALUES(foto), foto_mime = VALUES(foto_mime),
           avatar_versao = avatar_versao + 1`,
        [req.usuario.id_usuario, req.file.buffer, mime],
      );
      const apiPublica = (process.env.PUBLIC_API_URL ||
        'https://extraordinary-forgiveness-production-36f9.up.railway.app').replace(/\/$/, '');
      await conexao.execute(
        'UPDATE usuario SET foto_url = ? WHERE id_usuario = ? AND ativo = 1',
        [`${apiPublica}/api/users/${req.usuario.id_usuario}/avatar`, req.usuario.id_usuario],
      );
      await conexao.commit();
      const usuario = await meuPerfil(req.usuario.id_usuario);
      return res.json({ usuario, mensagem: 'Foto atualizada.' });
    } catch (error) {
      if (conexao) await conexao.rollback().catch(() => {});
      console.error('Erro ao salvar foto:', error.message);
      return res.status(500).json({ erro: 'Não foi possível salvar a foto.' });
    } finally {
      if (conexao) conexao.release();
    }
  });

  app.delete('/api/me/avatar', autenticar, async (req, res) => {
    let conexao;
    try {
      await preparar();
      conexao = await db.getConnection();
      await conexao.beginTransaction();
      await conexao.execute(
        'UPDATE usuario_perfil SET foto = NULL, foto_mime = NULL, avatar_versao = avatar_versao + 1 WHERE id_usuario = ?',
        [req.usuario.id_usuario],
      );
      await conexao.execute('UPDATE usuario SET foto_url = NULL WHERE id_usuario = ?', [req.usuario.id_usuario]);
      await conexao.commit();
      return res.json({ usuario: await meuPerfil(req.usuario.id_usuario) });
    } catch (error) {
      if (conexao) await conexao.rollback().catch(() => {});
      console.error('Erro ao remover foto:', error.message);
      return res.status(500).json({ erro: 'Não foi possível remover a foto.' });
    } finally {
      if (conexao) conexao.release();
    }
  });

  // Público: imagem (e somente a imagem) do avatar, nunca os dados de login.
  app.get('/api/users/:id/avatar', async (req, res) => {
    if (!/^\d+$/.test(req.params.id)) return res.sendStatus(404);
    try {
      await preparar();
      const [rows] = await db.execute(
        `SELECT p.foto, p.foto_mime
         FROM usuario_perfil p JOIN usuario u ON u.id_usuario = p.id_usuario
         WHERE p.id_usuario = ? AND u.ativo = 1 LIMIT 1`,
        [req.params.id],
      );
      if (!rows.length || !rows[0].foto) return res.sendStatus(404);
      res.set('Cache-Control', 'no-store');
      res.set('X-Content-Type-Options', 'nosniff');
      res.type(rows[0].foto_mime);
      return res.send(rows[0].foto);
    } catch (error) {
      console.error('Erro ao carregar avatar:', error.message);
      return res.sendStatus(500);
    }
  });

  // Substitui as antigas rotas de consulta de usuários, preservando o formato
  // que a aba Pessoas já espera e acrescentando os dados persistentes.
  app.get('/api/users', autenticar, async (req, res) => {
    try {
      await preparar();
      const [linhas] = await db.execute(
        `SELECT u.id_usuario, u.nome, u.nome_usuario, u.foto_url,
                COALESCE(p.bio,'') AS bio, COALESCE(p.assistindo,'') AS assistindo,
                COALESCE(p.avatar_versao,0) AS avatar_versao,
                o.id_obra, o.titulo, o.tipo, uo.sou_fa
         FROM usuario u
         LEFT JOIN usuario_perfil p ON p.id_usuario = u.id_usuario
         LEFT JOIN usuario_obra uo ON uo.id_usuario = u.id_usuario
         LEFT JOIN obra o ON o.id_obra = uo.id_obra
         WHERE u.ativo = 1 AND u.id_usuario <> ?
         ORDER BY u.nome, o.titulo`,
        [req.usuario.id_usuario],
      );
      const usuarios = new Map();
      for (const linha of linhas) {
        const chave = String(linha.id_usuario);
        if (!usuarios.has(chave)) usuarios.set(chave, {
          id: linha.id_usuario,
          nome: linha.nome,
          nome_usuario: linha.nome_usuario,
          foto_url: linha.foto_url,
          bio: linha.bio,
          assistindo: linha.assistindo,
          avatar_versao: linha.avatar_versao,
          obras: [],
        });
        if (linha.id_obra !== null) usuarios.get(chave).obras.push({
          id: linha.id_obra,
          titulo: linha.titulo,
          tipo: linha.tipo,
          sou_fa: linha.sou_fa === null ? null : Boolean(linha.sou_fa),
        });
      }
      return res.json({ usuarios: [...usuarios.values()] });
    } catch (error) {
      console.error('Erro ao listar usuários:', error.message);
      return res.status(500).json({ erro: 'Não foi possível carregar as contas.' });
    }
  });

  app.get('/api/users/:id', autenticar, async (req, res) => {
    if (!/^\d+$/.test(req.params.id)) return res.status(404).json({ erro: 'Conta não encontrada.' });
    try {
      await preparar();
      const usuario = await meuPerfil(req.params.id);
      if (!usuario) return res.status(404).json({ erro: 'Conta não encontrada.' });
      const [obras] = await db.execute(
        `SELECT o.id_obra AS id, o.titulo, o.tipo, uo.sou_fa
         FROM usuario_obra uo JOIN obra o ON o.id_obra = uo.id_obra
         WHERE uo.id_usuario = ? ORDER BY o.titulo`,
        [req.params.id],
      );
      return res.json({ usuario: {
        id: usuario.id_usuario,
        nome: usuario.nome,
        nome_usuario: usuario.nome_usuario,
        foto_url: usuario.foto_url,
        bio: usuario.bio,
        assistindo: usuario.assistindo,
        avatar_versao: usuario.avatar_versao,
        obras: obras.map((o) => ({ ...o, sou_fa: o.sou_fa === null ? null : Boolean(o.sou_fa) })),
      } });
    } catch (error) {
      console.error('Erro ao consultar conta:', error.message);
      return res.status(500).json({ erro: 'Não foi possível carregar o perfil.' });
    }
  });
};