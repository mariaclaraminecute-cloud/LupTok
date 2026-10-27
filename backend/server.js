
require('dotenv').config();

const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');

const app = express();
const uploadsDirectory = path.join(__dirname, 'uploads');
fs.mkdirSync(uploadsDirectory, { recursive: true });

app.use(cors());
app.use(express.json({ limit: '1mb' }));

const db = mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10,
});

const upload = multer({
  storage: multer.diskStorage({
    destination: uploadsDirectory,
    filename: (req, file, callback) => {
      callback(null, `${randomUUID()}${path.extname(file.originalname).toLowerCase()}`);
    },
  }),
  limits: { fileSize: 250 * 1024 * 1024 },
  fileFilter: (req, file, callback) => {
    const extensao = path.extname(file.originalname).toLowerCase();
    if (!['.mp4', '.mov', '.m4v', '.webm'].includes(extensao)) {
      return callback(new Error('Envie um vídeo MP4, MOV, M4V ou WebM.'));
    }
    callback(null, true);
  },
});

function autenticar(req, res, next) {
  const authorization = req.get('authorization');
  const token = authorization?.startsWith('Bearer ')
    ? authorization.slice(7)
    : null;

  if (!token) {
    return res.status(401).json({ erro: 'Faça login para continuar.' });
  }
  if (!process.env.JWT_SECRET) {
    return res.status(500).json({ erro: 'A autenticação não está configurada.' });
  }

  try {
    req.usuario = jwt.verify(token, process.env.JWT_SECRET);
    return next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      return res.status(401).json({ erro: 'Sua sessão expirou. Entre novamente.' });
    }
    console.error('Erro ao validar sessão:', error.message);
    return res.status(500).json({ erro: 'Não foi possível validar a sessão.' });
  }
}

function autenticarArquivoVideo(req, res, next) {
  const token = req.query.access_token;
  if (token === undefined) return autenticar(req, res, next);
  if (typeof token !== 'string' || !process.env.JWT_SECRET) {
    return res.status(401).json({ erro: 'Link de vídeo inválido ou expirado.' });
  }

  try {
    const usuario = jwt.verify(token, process.env.JWT_SECRET);
    if (
      usuario.escopo !== 'video' ||
      String(usuario.video_id) !== req.params.id
    ) {
      return res.status(403).json({ erro: 'Este link não dá acesso ao vídeo.' });
    }
    req.usuario = usuario;
    return next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      return res.status(401).json({ erro: 'O link de vídeo expirou.' });
    }
    console.error('Erro ao validar link de vídeo:', error.message);
    return res.status(500).json({ erro: 'Não foi possível validar o link.' });
  }
}

function receberVideo(req, res, next) {
  upload.single('video')(req, res, (error) => {
    if (!error) return next();
    const status = error instanceof multer.MulterError
      ? (error.code === 'LIMIT_FILE_SIZE' ? 413 : 400)
      : 400;
    return res.status(status).json({ erro: error.message });
  });
}


app.get('/', (req, res) => {
  res.json({
    mensagem: 'API do LupTok funcionando!',
  });
});

app.get('/api/test-db', async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT DATABASE() AS banco'
    );

    res.json({
      conectado: true,
      banco: rows[0].banco,
    });
  } catch (error) {
    console.error('Erro ao consultar MySQL:', error.message);

    res.status(500).json({
      conectado: false,
      mensagem: 'Não foi possível consultar o banco.',
    });
  }
});

// CADASTRO DE USUÁRIO
app.post('/api/auth/register', async (req, res) => {
  try {
    const { nome, nome_usuario, email, senha } = req.body;

    if (
      typeof nome !== 'string' ||
      typeof nome_usuario !== 'string' ||
      typeof email !== 'string' ||
      typeof senha !== 'string'
    ) {
      return res.status(400).json({
        erro: 'Preencha todos os campos corretamente.',
      });
    }

    const nomeLimpo = nome.trim();
    const usuarioLimpo = nome_usuario.trim();
    const emailLimpo = email.trim().toLowerCase();

    if (
      !nomeLimpo ||
      nomeLimpo.length > 100 ||
      !usuarioLimpo ||
      usuarioLimpo.length > 30 ||
      !/^[a-zA-Z0-9_.]+$/.test(usuarioLimpo) ||
      !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(emailLimpo) ||
      emailLimpo.length > 254 ||
      senha.length < 8 ||
      senha.length > 72
    ) {
      return res.status(400).json({
        erro: 'Confira os dados. A senha deve ter entre 8 e 72 caracteres.',
      });
    }

    const [existentes] = await db.execute(
      `SELECT id_usuario
       FROM usuario
       WHERE email = ? OR nome_usuario = ?
       LIMIT 1`,
      [emailLimpo, usuarioLimpo]
    );

    if (existentes.length > 0) {
      return res.status(409).json({
        erro: 'Esse e-mail ou nome de usuário já está cadastrado.',
      });
    }

    const senhaHash = await bcrypt.hash(senha, 12);

    const [resultado] = await db.execute(
      `INSERT INTO usuario
       (nome, nome_usuario, email, senha_hash)
       VALUES (?, ?, ?, ?)`,
      [nomeLimpo, usuarioLimpo, emailLimpo, senhaHash]
    );

    return res.status(201).json({
      mensagem: 'Conta criada com sucesso!',
      usuario: {
        id_usuario: resultado.insertId,
        nome: nomeLimpo,
        nome_usuario: usuarioLimpo,
        email: emailLimpo,
      },
    });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        erro: 'Esse e-mail ou nome de usuário já está cadastrado.',
      });
    }

    console.error('Erro no cadastro:', error.message);

    return res.status(500).json({
      erro: 'Não foi possível criar a conta.',
    });
  }
});

// LOGIN COM JWT
app.post('/api/auth/login', async (req, res) => {
  try {
    const identificadorRecebido = req.body.identificador ?? req.body.email;
    const { senha } = req.body;

    if (
      typeof identificadorRecebido !== 'string' ||
      typeof senha !== 'string' ||
      !identificadorRecebido.trim() ||
      !senha ||
      senha.length > 72
    ) {
      return res.status(400).json({
        erro: 'Informe seu e-mail ou nome de usuário e a senha.',
      });
    }

    const identificador = identificadorRecebido.trim().toLowerCase();

    const [usuarios] = await db.execute(
      `SELECT id_usuario, nome, nome_usuario, email,
              senha_hash, role, ativo
       FROM usuario
       WHERE LOWER(email) = ? OR LOWER(nome_usuario) = ?
       LIMIT 1`,
      [identificador, identificador]
    );

    if (usuarios.length === 0) {
      return res.status(401).json({
        erro: 'E-mail/nome de usuário ou senha incorretos.',
      });
    }

    const usuario = usuarios[0];

    const senhaCorreta = await bcrypt.compare(
      senha,
      usuario.senha_hash
    );

    if (!usuario.ativo || !senhaCorreta) {
      return res.status(401).json({
        erro: 'E-mail/nome de usuário ou senha incorretos.',
      });
    }

    if (!process.env.JWT_SECRET) {
      throw new Error('JWT_SECRET não está configurado no .env.');
    }

    const token = jwt.sign(
      {
        id_usuario: usuario.id_usuario,
        role: usuario.role,
      },
      process.env.JWT_SECRET,
      {
        expiresIn: '2h',
      }
    );

    return res.json({
      mensagem: 'Login realizado com sucesso!',
      token,
      usuario: {
        id_usuario: usuario.id_usuario,
        nome: usuario.nome,
        nome_usuario: usuario.nome_usuario,
        email: usuario.email,
      },
    });
  } catch (error) {
    console.error('Erro no login:', error.message);

    return res.status(500).json({
      erro: 'Não foi possível realizar o login.',
    });
  }
});

const tiposDeObra = [
  'Anime',
  'Dorama',
  'Filme',
  'Série',
  'Livro',
  'Mangá',
  'Jogo',
  'Outro',
];

const termosIgnoradosBusca = new Set([
  'a', 'as', 'o', 'os', 'um', 'uma', 'de', 'do', 'da', 'dos', 'das',
  'e', 'em', 'no', 'na', 'nos', 'nas', 'com', 'por', 'para', 'que',
]);

function termosBusca(valor) {
  const normalizado = valor
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
  return [...new Set(
    normalizado
      .split(/\s+/)
      .filter((termo) => termo.length > 1 && !termosIgnoradosBusca.has(termo))
  )];
}

function erroTabelaCurtidasAusente(error) {
  const mensagem = String(error?.sqlMessage ?? error?.message ?? '');
  return error?.code === 'ER_NO_SUCH_TABLE' &&
    mensagem.includes('video_post_curtida');
}

function responderCurtidasNaoConfiguradas(res) {
  return res.status(503).json({
    codigo: 'MIGRATION_REQUIRED',
    erro: 'Curtidas indisponíveis: aplique a migration backend/migrations/20261027_video_engagement.sql no banco.',
  });
}

function validarListaMetadados(valor, campo) {
  if (!Array.isArray(valor) || valor.length > 30) {
    return { erro: `${campo} deve ser uma lista com até 30 itens.` };
  }
  const itens = [];
  const vistos = new Set();
  for (const item of valor) {
    if (typeof item !== 'string' || !item.trim() || item.trim().length > 80) {
      return { erro: `Cada item de ${campo} deve ter entre 1 e 80 caracteres.` };
    }
    const nome = item.trim().replace(/\s+/g, ' ');
    const normalizado = nome
      .normalize('NFD')
      .replace(/\p{Diacritic}/gu, '')
      .toLocaleLowerCase('pt-BR');
    if (!vistos.has(normalizado)) itens.push(nome);
    vistos.add(normalizado);
  }
  return { itens };
}

function clausulaBuscaObras(termos) {
  const params = [];
  const clausulas = termos.map((termo) => {
    const padrao = `%${termo}%`;
    params.push(padrao, padrao, padrao, padrao, padrao, padrao);
    return `(o.titulo_normalizado LIKE ? OR o.titulo LIKE ? OR
             COALESCE(o.descricao, '') LIKE ? OR o.tipo LIKE ? OR
             EXISTS (
               SELECT 1 FROM obra_genero og
               JOIN genero g ON g.id_genero = og.id_genero
               WHERE og.id_obra = o.id_obra AND g.nome LIKE ?
             ) OR EXISTS (
               SELECT 1 FROM obra_palavra_chave opc
               JOIN palavra_chave pc
                 ON pc.id_palavra_chave = opc.id_palavra_chave
               WHERE opc.id_obra = o.id_obra AND pc.nome LIKE ?
             ))`;
  });
  return { sql: clausulas.join(' AND '), params };
}

function clausulaBuscaVideos(termos) {
  const params = [];
  const clausulas = termos.map((termo) => {
    const padrao = `%${termo}%`;
    params.push(
      padrao, padrao, padrao, padrao, padrao, padrao, padrao, padrao,
    );
    return `(v.descricao LIKE ? OR v.tipo_conteudo LIKE ? OR
             o.titulo LIKE ? OR o.titulo_normalizado LIKE ? OR
             COALESCE(o.descricao, '') LIKE ? OR o.tipo LIKE ? OR
             EXISTS (
               SELECT 1 FROM obra_genero og
               JOIN genero g ON g.id_genero = og.id_genero
               WHERE og.id_obra = o.id_obra AND g.nome LIKE ?
             ) OR EXISTS (
               SELECT 1 FROM obra_palavra_chave opc
               JOIN palavra_chave pc
                 ON pc.id_palavra_chave = opc.id_palavra_chave
               WHERE opc.id_obra = o.id_obra AND pc.nome LIKE ?
             ))`;
  });
  return { sql: clausulas.join(' AND '), params };
}

async function obterMetadadosObras(idsObra, conexao = db) {
  const ids = [...new Set(idsObra.map(String))];
  if (ids.length === 0) return new Map();
  const placeholders = ids.map(() => '?').join(', ');
  const [generos] = await conexao.execute(
    `SELECT og.id_obra, g.nome
     FROM obra_genero og
     JOIN genero g ON g.id_genero = og.id_genero
     WHERE og.id_obra IN (${placeholders})
     ORDER BY g.nome`,
    ids,
  );
  const [palavrasChave] = await conexao.execute(
    `SELECT opc.id_obra, pc.nome
     FROM obra_palavra_chave opc
     JOIN palavra_chave pc
       ON pc.id_palavra_chave = opc.id_palavra_chave
     WHERE opc.id_obra IN (${placeholders})
     ORDER BY pc.nome`,
    ids,
  );
  const metadados = new Map(
    ids.map((id) => [id, { generos: [], palavras_chave: [] }]),
  );
  for (const genero of generos) {
    metadados.get(String(genero.id_obra))?.generos.push(genero.nome);
  }
  for (const palavra of palavrasChave) {
    metadados.get(String(palavra.id_obra))?.palavras_chave.push(palavra.nome);
  }
  return metadados;
}

async function salvarMetadadosObra(conexao, idObra, descricao, generos, palavrasChave) {
  await conexao.execute(
    'UPDATE obra SET descricao = ? WHERE id_obra = ?',
    [descricao, idObra],
  );
  await conexao.execute('DELETE FROM obra_genero WHERE id_obra = ?', [idObra]);
  await conexao.execute(
    'DELETE FROM obra_palavra_chave WHERE id_obra = ?',
    [idObra],
  );

  for (const nome of generos) {
    await conexao.execute(
      'INSERT INTO genero (nome) VALUES (?) ON DUPLICATE KEY UPDATE nome = VALUES(nome)',
      [nome],
    );
    const [rows] = await conexao.execute(
      'SELECT id_genero FROM genero WHERE nome = ? LIMIT 1',
      [nome],
    );
    await conexao.execute(
      'INSERT INTO obra_genero (id_obra, id_genero) VALUES (?, ?)',
      [idObra, rows[0].id_genero],
    );
  }

  for (const nome of palavrasChave) {
    await conexao.execute(
      'INSERT INTO palavra_chave (nome) VALUES (?) ON DUPLICATE KEY UPDATE nome = VALUES(nome)',
      [nome],
    );
    const [rows] = await conexao.execute(
      'SELECT id_palavra_chave FROM palavra_chave WHERE nome = ? LIMIT 1',
      [nome],
    );
    await conexao.execute(
      `INSERT INTO obra_palavra_chave (id_obra, id_palavra_chave)
       VALUES (?, ?)`,
      [idObra, rows[0].id_palavra_chave],
    );
  }
}

async function adicionarMetadadosObra(conexao, idObra, descricao, generos, palavrasChave) {
  await conexao.execute(
    `UPDATE obra
     SET descricao = CASE
       WHEN descricao IS NULL OR descricao = '' THEN ?
       ELSE descricao
     END
     WHERE id_obra = ?`,
    [descricao, idObra],
  );
  const metadadosExistentes = await obterMetadadosObras([idObra], conexao);
  const generosExistentes = new Set(metadadosExistentes.get(String(idObra)).generos);
  const palavrasExistentes = new Set(
    metadadosExistentes.get(String(idObra)).palavras_chave,
  );
  for (const nome of generos) {
    await conexao.execute(
      'INSERT INTO genero (nome) VALUES (?) ON DUPLICATE KEY UPDATE nome = VALUES(nome)',
      [nome],
    );
    const [rows] = await conexao.execute(
      'SELECT id_genero FROM genero WHERE nome = ? LIMIT 1',
      [nome],
    );
    if (!generosExistentes.has(nome)) {
      await conexao.execute(
        'INSERT IGNORE INTO obra_genero (id_obra, id_genero) VALUES (?, ?)',
        [idObra, rows[0].id_genero],
      );
    }
  }
  for (const nome of palavrasChave) {
    await conexao.execute(
      'INSERT INTO palavra_chave (nome) VALUES (?) ON DUPLICATE KEY UPDATE nome = VALUES(nome)',
      [nome],
    );
    const [rows] = await conexao.execute(
      'SELECT id_palavra_chave FROM palavra_chave WHERE nome = ? LIMIT 1',
      [nome],
    );
    if (!palavrasExistentes.has(nome)) {
      await conexao.execute(
        `INSERT IGNORE INTO obra_palavra_chave
         (id_obra, id_palavra_chave) VALUES (?, ?)`,
        [idObra, rows[0].id_palavra_chave],
      );
    }
  }
}

async function detalhesObra(idObra, idUsuario, conexao = db) {
  const [rows] = await conexao.execute(
    `SELECT o.id_obra, o.titulo, o.tipo, o.descricao, uo.sou_fa
     FROM obra o
     LEFT JOIN usuario_obra uo
       ON uo.id_obra = o.id_obra AND uo.id_usuario = ?
     WHERE o.id_obra = ?
     LIMIT 1`,
    [idUsuario, idObra],
  );
  if (rows.length === 0) return null;
  const metadata = await obterMetadadosObras([rows[0].id_obra], conexao);
  const tags = metadata.get(String(rows[0].id_obra));
  return {
    id: rows[0].id_obra,
    titulo: rows[0].titulo,
    tipo: rows[0].tipo,
    descricao: rows[0].descricao ?? '',
    generos: tags.generos,
    palavras_chave: tags.palavras_chave,
    sou_fa: rows[0].sou_fa === null ? null : Boolean(rows[0].sou_fa),
  };
}

app.get('/api/genres', autenticar, async (req, res) => {
  try {
    const [generos] = await db.execute(
      'SELECT id_genero AS id, nome FROM genero ORDER BY nome',
    );
    return res.json({ generos });
  } catch (error) {
    console.error('Erro ao listar gêneros:', error.message);
    return res.status(500).json({ erro: 'Não foi possível carregar os gêneros.' });
  }
});

app.get('/api/keywords', autenticar, async (req, res) => {
  try {
    const [palavrasChave] = await db.execute(
      `SELECT id_palavra_chave AS id, nome
       FROM palavra_chave
       ORDER BY nome`,
    );
    return res.json({ palavras_chave: palavrasChave });
  } catch (error) {
    console.error('Erro ao listar palavras-chave:', error.message);
    return res.status(500).json({
      erro: 'Não foi possível carregar as palavras-chave.',
    });
  }
});

app.get('/api/works', autenticar, async (req, res) => {
  const busca = req.query.q ?? '';
  if (typeof busca !== 'string' || busca.length > 120) {
    return res.status(400).json({ erro: 'A busca deve ter até 120 caracteres.' });
  }
  const termos = termosBusca(busca);
  if (busca.trim() && termos.length === 0) return res.json({ obras: [] });

  try {
    const buscaSql = clausulaBuscaObras(termos);
    const [obras] = await db.execute(
      `SELECT o.id_obra, o.titulo, o.tipo, o.descricao, uo.sou_fa
       FROM obra o
       LEFT JOIN usuario_obra uo
         ON uo.id_obra = o.id_obra AND uo.id_usuario = ?
       ${buscaSql.sql ? `WHERE ${buscaSql.sql}` : ''}
       ORDER BY CASE
         WHEN o.titulo_normalizado = ? THEN 0
         WHEN o.titulo_normalizado LIKE ? THEN 1
         ELSE 2
       END, o.titulo
       LIMIT 100`,
      [
        req.usuario.id_usuario,
        ...buscaSql.params,
        ...(
          termos.length > 0
            ? [termos.join(' '), `%${termos.join(' ')}%`]
            : ['', '%']
        ),
      ],
    );
    const metadata = await obterMetadadosObras(obras.map((obra) => obra.id_obra));
    return res.json({
      obras: obras.map((obra) => ({
        id: obra.id_obra,
        titulo: obra.titulo,
        tipo: obra.tipo,
        descricao: obra.descricao ?? '',
        generos: metadata.get(String(obra.id_obra)).generos,
        palavras_chave: metadata.get(String(obra.id_obra)).palavras_chave,
        sou_fa: obra.sou_fa === null
          ? null
          : Boolean(obra.sou_fa),
      })),
    });
  } catch (error) {
    console.error('Erro ao listar obras:', error.message);
    return res.status(500).json({ erro: 'Não foi possível carregar as obras.' });
  }
});

app.post('/api/works', autenticar, async (req, res) => {
  const {
    titulo,
    tipo,
    descricao = '',
    generos = [],
    palavras_chave = [],
  } = req.body ?? {};
  if (
    typeof titulo !== 'string' ||
    !titulo.trim() ||
    titulo.trim().length > 150 ||
    !tiposDeObra.includes(tipo) ||
    typeof descricao !== 'string' ||
    descricao.length > 2000
  ) {
    return res.status(400).json({ erro: 'Informe um título e tipo válidos.' });
  }
  const generosValidados = validarListaMetadados(generos, 'generos');
  const palavrasValidadas = validarListaMetadados(
    palavras_chave,
    'palavras_chave',
  );
  if (generosValidados.erro || palavrasValidadas.erro) {
    return res.status(400).json({
      erro: generosValidados.erro || palavrasValidadas.erro,
    });
  }

  const tituloLimpo = titulo.trim().replace(/\s+/g, ' ');
  const tituloNormalizado = tituloLimpo
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLocaleLowerCase('pt-BR');
  let conexao;
  try {
    conexao = await db.getConnection();
    await conexao.beginTransaction();
    await conexao.execute(
      `INSERT INTO obra (titulo, titulo_normalizado, tipo, criado_por)
       VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE id_obra = LAST_INSERT_ID(id_obra)`,
      [tituloLimpo, tituloNormalizado, tipo, req.usuario.id_usuario]
    );
    const [obras] = await conexao.execute(
      `SELECT id_obra, titulo, tipo
       FROM obra
       WHERE tipo = ? AND titulo_normalizado = ?
       LIMIT 1`,
      [tipo, tituloNormalizado]
    );
    const obra = obras[0];
    await adicionarMetadadosObra(
      conexao,
      obra.id_obra,
      descricao.trim(),
      generosValidados.itens,
      palavrasValidadas.itens,
    );
    await conexao.execute(
      `INSERT INTO usuario_obra (id_usuario, id_obra, sou_fa)
       VALUES (?, ?, NULL)
       ON DUPLICATE KEY UPDATE id_obra = VALUES(id_obra)`,
      [req.usuario.id_usuario, obra.id_obra]
    );
    await conexao.commit();
    const obraCompleta = await detalhesObra(
      obra.id_obra,
      req.usuario.id_usuario,
    );
    return res.status(201).json({
      obra: obraCompleta,
    });
  } catch (error) {
    if (conexao) await conexao.rollback();
    console.error('Erro ao adicionar obra:', error.message);
    return res.status(500).json({ erro: 'Não foi possível adicionar a obra.' });
  } finally {
    if (conexao) conexao.release();
  }
});

app.put('/api/works/:id/metadata', autenticar, async (req, res) => {
  if (!/^\d+$/.test(req.params.id)) {
    return res.status(404).json({ erro: 'Obra não encontrada.' });
  }
  const { descricao, generos, palavras_chave } = req.body ?? {};
  if (
    typeof descricao !== 'string' ||
    descricao.length > 2000 ||
    !Array.isArray(generos) ||
    !Array.isArray(palavras_chave)
  ) {
    return res.status(400).json({
      erro: 'Informe descrição, gêneros e palavras-chave válidos.',
    });
  }
  const generosValidados = validarListaMetadados(generos, 'generos');
  const palavrasValidadas = validarListaMetadados(
    palavras_chave,
    'palavras_chave',
  );
  if (generosValidados.erro || palavrasValidadas.erro) {
    return res.status(400).json({
      erro: generosValidados.erro || palavrasValidadas.erro,
    });
  }

  let conexao;
  try {
    conexao = await db.getConnection();
    await conexao.beginTransaction();
    const [obras] = await conexao.execute(
      'SELECT id_obra FROM obra WHERE id_obra = ? LIMIT 1',
      [req.params.id],
    );
    if (obras.length === 0) {
      await conexao.rollback();
      return res.status(404).json({ erro: 'Obra não encontrada.' });
    }
    await salvarMetadadosObra(
      conexao,
      obras[0].id_obra,
      descricao.trim(),
      generosValidados.itens,
      palavrasValidadas.itens,
    );
    await conexao.commit();
    const obra = await detalhesObra(
      obras[0].id_obra,
      req.usuario.id_usuario,
    );
    return res.json({ obra });
  } catch (error) {
    if (conexao) await conexao.rollback();
    console.error('Erro ao atualizar metadados da obra:', error.message);
    return res.status(500).json({
      erro: 'Não foi possível atualizar os dados da obra.',
    });
  } finally {
    if (conexao) conexao.release();
  }
});

app.put('/api/works/:id/rating', autenticar, async (req, res) => {
  const { sou_fa } = req.body;
  if (!/^\d+$/.test(req.params.id) || typeof sou_fa !== 'boolean') {
    return res.status(400).json({ erro: 'Informe uma avaliação válida.' });
  }

  try {
    const [obras] = await db.execute(
      'SELECT id_obra FROM obra WHERE id_obra = ? LIMIT 1',
      [req.params.id]
    );
    if (obras.length === 0) {
      return res.status(404).json({ erro: 'Obra não encontrada.' });
    }
    await db.execute(
      `INSERT INTO usuario_obra (id_usuario, id_obra, sou_fa)
       VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE sou_fa = VALUES(sou_fa)`,
      [req.usuario.id_usuario, req.params.id, sou_fa]
    );
    return res.json({ mensagem: 'Sua avaliação foi salva.' });
  } catch (error) {
    console.error('Erro ao avaliar obra:', error.message);
    return res.status(500).json({ erro: 'Não foi possível salvar a avaliação.' });
  }
});

app.get('/api/users', autenticar, async (req, res) => {
  try {
    const [linhas] = await db.execute(
      `SELECT u.id_usuario, u.nome, u.nome_usuario,
              o.id_obra, o.titulo, o.tipo, uo.sou_fa
       FROM usuario u
       LEFT JOIN usuario_obra uo ON uo.id_usuario = u.id_usuario
       LEFT JOIN obra o ON o.id_obra = uo.id_obra
       WHERE u.ativo = 1 AND u.id_usuario <> ?
       ORDER BY u.nome, o.titulo`,
      [req.usuario.id_usuario]
    );

    const usuarios = new Map();
    for (const linha of linhas) {
      let usuario = usuarios.get(String(linha.id_usuario));
      if (!usuario) {
        usuario = {
          id: linha.id_usuario,
          nome: linha.nome,
          nome_usuario: linha.nome_usuario,
          obras: [],
        };
        usuarios.set(String(linha.id_usuario), usuario);
      }
      if (linha.id_obra !== null) {
        usuario.obras.push({
          id: linha.id_obra,
          titulo: linha.titulo,
          tipo: linha.tipo,
          sou_fa: linha.sou_fa === null ? null : Boolean(linha.sou_fa),
        });
      }
    }

    return res.json({ usuarios: [...usuarios.values()] });
  } catch (error) {
    console.error('Erro ao listar contas:', error.message);
    return res.status(500).json({ erro: 'Não foi possível carregar as contas.' });
  }
});

app.get('/api/users/:id', autenticar, async (req, res) => {
  if (!/^\d+$/.test(req.params.id)) {
    return res.status(404).json({ erro: 'Conta não encontrada.' });
  }

  try {
    const [linhas] = await db.execute(
      `SELECT u.id_usuario, u.nome, u.nome_usuario,
              o.id_obra, o.titulo, o.tipo, uo.sou_fa
       FROM usuario u
       LEFT JOIN usuario_obra uo ON uo.id_usuario = u.id_usuario
       LEFT JOIN obra o ON o.id_obra = uo.id_obra
       WHERE u.ativo = 1 AND u.id_usuario = ?
       ORDER BY o.titulo`,
      [req.params.id]
    );
    if (linhas.length === 0) {
      return res.status(404).json({ erro: 'Conta não encontrada.' });
    }

    return res.json({
      usuario: {
        id: linhas[0].id_usuario,
        nome: linhas[0].nome,
        nome_usuario: linhas[0].nome_usuario,
        obras: linhas
          .filter((linha) => linha.id_obra !== null)
          .map((linha) => ({
            id: linha.id_obra,
            titulo: linha.titulo,
            tipo: linha.tipo,
            sou_fa: linha.sou_fa === null ? null : Boolean(linha.sou_fa),
          })),
      },
    });
  } catch (error) {
    console.error('Erro ao carregar perfil:', error.message);
    return res.status(500).json({ erro: 'Não foi possível carregar o perfil.' });
  }
});

app.get('/api/videos', autenticar, async (req, res) => {
  const busca = req.query.q ?? '';
  if (typeof busca !== 'string' || busca.length > 120) {
    return res.status(400).json({ erro: 'A busca deve ter até 120 caracteres.' });
  }
  const termos = termosBusca(busca);
  if (busca.trim() && termos.length === 0) return res.json({ videos: [] });

  try {
    const buscaSql = clausulaBuscaVideos(termos);
    const [videos] = await db.execute(
      `SELECT v.id_video, v.id_usuario, u.nome_usuario, v.descricao,
              v.tipo_conteudo, v.spoiler, v.privacidade, v.criado_em,
              o.id_obra, o.titulo AS obra_titulo, o.tipo AS obra_tipo,
              o.descricao AS obra_descricao,
              (SELECT COUNT(*)
               FROM video_post_curtida vc
               WHERE vc.id_video = v.id_video) AS curtidas,
              EXISTS (
                SELECT 1
                FROM video_post_curtida vc
                WHERE vc.id_video = v.id_video
                  AND vc.id_usuario = ?
              ) AS curtida_usuario
       FROM video_post v
       JOIN usuario u ON u.id_usuario = v.id_usuario
       LEFT JOIN obra o ON o.id_obra = v.id_obra
       WHERE (v.privacidade = 'Público' OR v.id_usuario = ?)
       ${buscaSql.sql ? `AND ${buscaSql.sql}` : ''}
       ORDER BY v.criado_em DESC
       LIMIT 200`,
      [req.usuario.id_usuario, req.usuario.id_usuario, ...buscaSql.params],
    );
    const metadata = await obterMetadadosObras(
      videos.map((video) => video.id_obra).filter((id) => id !== null),
    );

    return res.json({
      videos: videos.map((video) => {
        const tags = video.id_obra === null
          ? null
          : metadata.get(String(video.id_obra));
        return {
          id: video.id_video,
          id_usuario: video.id_usuario,
          autor: `@${video.nome_usuario}`,
          descricao: video.descricao,
          tipo_conteudo: video.tipo_conteudo,
          spoiler: video.spoiler,
          privacidade: video.privacidade,
          ...(String(video.id_usuario) === String(req.usuario.id_usuario)
            ? { curtidas: Number(video.curtidas) }
            : {}),
          curtida_usuario: Boolean(video.curtida_usuario),
          obra: video.id_obra === null
            ? null
            : {
                id: video.id_obra,
                titulo: video.obra_titulo,
                tipo: video.obra_tipo,
                descricao: video.obra_descricao ?? '',
                generos: tags.generos,
                palavras_chave: tags.palavras_chave,
              },
          url: `/api/videos/${video.id_video}/arquivo`,
          criado_em: video.criado_em,
        };
      }),
    });
  } catch (error) {
    console.error('Erro ao listar vídeos:', error.message);
    if (erroTabelaCurtidasAusente(error)) {
      return responderCurtidasNaoConfiguradas(res);
    }
    return res.status(500).json({ erro: 'Não foi possível carregar os vídeos.' });
  }
});

app.put('/api/videos/:id/like', autenticar, async (req, res) => {
  const { curtido } = req.body ?? {};
  if (!/^\d+$/.test(req.params.id) || typeof curtido !== 'boolean') {
    return res.status(400).json({ erro: 'Informe uma curtida válida.' });
  }

  let conexao;
  try {
    conexao = await db.getConnection();
    await conexao.beginTransaction();
    const [videos] = await conexao.execute(
      `SELECT id_video, id_usuario
       FROM video_post
       WHERE id_video = ?
         AND (privacidade = 'Público' OR id_usuario = ?)
       LIMIT 1`,
      [req.params.id, req.usuario.id_usuario],
    );
    if (videos.length === 0) {
      await conexao.rollback();
      return res.status(404).json({ erro: 'Vídeo não encontrado.' });
    }

    if (curtido) {
      await conexao.execute(
        `INSERT IGNORE INTO video_post_curtida (id_usuario, id_video)
         VALUES (?, ?)`,
        [req.usuario.id_usuario, req.params.id],
      );
    } else {
      await conexao.execute(
        `DELETE FROM video_post_curtida
         WHERE id_usuario = ? AND id_video = ?`,
        [req.usuario.id_usuario, req.params.id],
      );
    }
    const isOwner =
      String(videos[0].id_usuario) === String(req.usuario.id_usuario);
    let curtidas;
    if (isOwner) {
      const [[count]] = await conexao.execute(
        'SELECT COUNT(*) AS curtidas FROM video_post_curtida WHERE id_video = ?',
        [req.params.id],
      );
      curtidas = Number(count.curtidas);
    }
    await conexao.commit();
    return res.json({
      curtido,
      ...(curtidas === undefined ? {} : { curtidas }),
    });
  } catch (error) {
    if (conexao) await conexao.rollback();
    console.error('Erro ao atualizar curtida do vídeo:', error.message);
    if (erroTabelaCurtidasAusente(error)) {
      return responderCurtidasNaoConfiguradas(res);
    }
    return res.status(500).json({ erro: 'Não foi possível atualizar a curtida.' });
  } finally {
    if (conexao) conexao.release();
  }
});

const motivosDenunciaVideo = new Set([
  'Fora do propósito do LupTok',
  'Assédio ou bullying',
  'Conteúdo inadequado',
  'Spam',
  'Outro motivo',
]);

app.post('/api/videos/:id/report', autenticar, async (req, res) => {
  const { motivo, descricao = '' } = req.body ?? {};
  if (
    !/^\d+$/.test(req.params.id) ||
    typeof motivo !== 'string' ||
    !motivosDenunciaVideo.has(motivo) ||
    typeof descricao !== 'string' ||
    descricao.length > 500
  ) {
    return res.status(400).json({ erro: 'Confira os dados da denúncia.' });
  }

  try {
    const [videos] = await db.execute(
      `SELECT id_usuario
       FROM video_post
       WHERE id_video = ?
         AND (privacidade = 'Público' OR id_usuario = ?)
       LIMIT 1`,
      [req.params.id, req.usuario.id_usuario],
    );
    if (videos.length === 0) {
      return res.status(404).json({ erro: 'Vídeo não encontrado.' });
    }
    if (String(videos[0].id_usuario) === String(req.usuario.id_usuario)) {
      return res.status(400).json({ erro: 'Não é possível denunciar seu próprio vídeo.' });
    }

    await db.execute(
      `INSERT INTO denuncia
       (id_denunciante, id_usuario_denunciado, id_postagem, id_video,
        motivo, descricao, status, data_denuncia)
       VALUES (?, ?, NULL, ?, ?, ?, 'pendente', NOW())`,
      [
        req.usuario.id_usuario,
        videos[0].id_usuario,
        req.params.id,
        motivo,
        descricao.trim() || null,
      ],
    );
    return res.status(201).json({ mensagem: 'Denúncia enviada para análise.' });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({
        erro: 'Você já denunciou este vídeo.',
      });
    }
    console.error('Erro ao registrar denúncia de vídeo:', error.message);
    return res.status(500).json({ erro: 'Não foi possível enviar a denúncia.' });
  }
});

app.post('/api/videos', autenticar, receberVideo, async (req, res) => {
  const arquivo = req.file;
  if (!arquivo) {
    return res.status(400).json({ erro: 'Selecione um arquivo de vídeo.' });
  }

  const {
    descricao,
    tipo_conteudo,
    spoiler,
    privacidade,
    id_obra: idObraRecebido,
  } = req.body;
  const idObra = idObraRecebido === undefined || idObraRecebido === ''
    ? null
    : idObraRecebido;
  if (
    typeof descricao !== 'string' ||
    descricao.length > 240 ||
    !['Filme', 'Série', 'Livro'].includes(tipo_conteudo) ||
    !['nenhum', 'leve', 'muito'].includes(spoiler) ||
    !['Público', 'Somente amigos'].includes(privacidade) ||
    (idObra !== null &&
      (typeof idObra !== 'string' || !/^\d+$/.test(idObra)))
  ) {
    await fs.promises.unlink(arquivo.path);
    return res.status(400).json({ erro: 'Confira as informações do vídeo.' });
  }

  try {
    if (idObra !== null) {
      const [obras] = await db.execute(
        'SELECT id_obra FROM obra WHERE id_obra = ? LIMIT 1',
        [idObra],
      );
      if (obras.length === 0) {
        await fs.promises.unlink(arquivo.path);
        return res.status(404).json({ erro: 'Obra não encontrada.' });
      }
    }
    const [resultado] = await db.execute(
      `INSERT INTO video_post
       (id_usuario, nome_arquivo, descricao, tipo_conteudo, spoiler, privacidade, id_obra)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        req.usuario.id_usuario,
        arquivo.filename,
        descricao.trim(),
        tipo_conteudo,
        spoiler,
        privacidade,
        idObra,
      ]
    );
    const obra = idObra === null
      ? null
      : await detalhesObra(idObra, req.usuario.id_usuario);

    return res.status(201).json({
      mensagem: 'Vídeo publicado com sucesso!',
      video: {
        id: resultado.insertId,
        id_usuario: req.usuario.id_usuario,
        descricao: descricao.trim(),
        tipo_conteudo,
        spoiler,
        privacidade,
        id_obra: idObra,
        obra,
        url: `/api/videos/${resultado.insertId}/arquivo`,
      },
    });
  } catch (error) {
    try {
      await fs.promises.unlink(arquivo.path);
    } catch (cleanupError) {
      console.error('Não foi possível remover upload incompleto:', cleanupError.message);
    }
    console.error('Erro ao salvar vídeo:', error.message);
    return res.status(500).json({ erro: 'Não foi possível publicar o vídeo.' });
  }
});

app.get('/api/videos/:id/acesso', autenticar, async (req, res) => {
  if (!/^\d+$/.test(req.params.id)) {
    return res.status(404).json({ erro: 'Vídeo não encontrado.' });
  }

  try {
    const [videos] = await db.execute(
      `SELECT id_usuario, privacidade
       FROM video_post
       WHERE id_video = ?
       LIMIT 1`,
      [req.params.id]
    );
    if (videos.length === 0) {
      return res.status(404).json({ erro: 'Vídeo não encontrado.' });
    }

    const video = videos[0];
    if (
      video.privacidade !== 'Público' &&
      String(video.id_usuario) !== String(req.usuario.id_usuario)
    ) {
      return res.status(403).json({ erro: 'Você não tem acesso a este vídeo.' });
    }

    const token = jwt.sign(
      {
        id_usuario: req.usuario.id_usuario,
        video_id: req.params.id,
        escopo: 'video',
      },
      process.env.JWT_SECRET,
      { expiresIn: '10m' }
    );
    return res.json({
      url: `/api/videos/${req.params.id}/arquivo?access_token=${encodeURIComponent(token)}`,
    });
  } catch (error) {
    console.error('Erro ao gerar acesso ao vídeo:', error.message);
    return res.status(500).json({ erro: 'Não foi possível preparar o vídeo.' });
  }
});

app.get(
  '/api/videos/:id/arquivo',
  autenticarArquivoVideo,
  async (req, res) => {
    if (!/^\d+$/.test(req.params.id)) {
      return res.status(404).json({ erro: 'Vídeo não encontrado.' });
    }

    try {
      const [videos] = await db.execute(
        `SELECT id_usuario, nome_arquivo, privacidade
         FROM video_post
         WHERE id_video = ?
         LIMIT 1`,
        [req.params.id]
      );
      if (videos.length === 0) {
        return res.status(404).json({ erro: 'Vídeo não encontrado.' });
      }

      const video = videos[0];
      if (
        video.privacidade !== 'Público' &&
        String(video.id_usuario) !== String(req.usuario.id_usuario)
      ) {
        return res.status(403).json({ erro: 'Você não tem acesso a este vídeo.' });
      }

      const caminhoArquivo = path.join(uploadsDirectory, video.nome_arquivo);
      return res.sendFile(caminhoArquivo, (error) => {
        if (error && !res.headersSent) {
          return res.status(404).json({ erro: 'Arquivo de vídeo não encontrado.' });
        }
      });
    } catch (error) {
      console.error('Erro ao buscar arquivo de vídeo:', error.message);
      return res.status(500).json({ erro: 'Não foi possível carregar o vídeo.' });
    }
  }
);

// INICIALIZAÇÃO DO SERVIDOR
async function iniciarServidor() {
  try {
    const conexao = await db.getConnection();

    console.log('MySQL conectado com sucesso!');
    await db.execute(
      `CREATE TABLE IF NOT EXISTS video_post (
         id_video BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
         id_usuario BIGINT UNSIGNED NOT NULL,
         id_obra BIGINT UNSIGNED NULL,
         nome_arquivo VARCHAR(255) NOT NULL,
         descricao VARCHAR(240) NOT NULL DEFAULT '',
         tipo_conteudo VARCHAR(40) NOT NULL,
         spoiler VARCHAR(20) NOT NULL,
         privacidade VARCHAR(30) NOT NULL,
         criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
         INDEX idx_video_post_feed (privacidade, criado_em),
         INDEX idx_video_post_usuario (id_usuario, criado_em),
         INDEX idx_video_post_obra (id_obra)
       ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`
    );
    await db.execute(
       `CREATE TABLE IF NOT EXISTS obra (
          id_obra BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
          titulo VARCHAR(150) NOT NULL,
          titulo_normalizado VARCHAR(150) NOT NULL,
          tipo VARCHAR(20) NOT NULL,
          descricao TEXT NULL,
          criado_por BIGINT UNSIGNED NOT NULL,
          criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          UNIQUE KEY uq_obra_titulo_tipo (titulo_normalizado, tipo),
          INDEX idx_obra_criado_por (criado_por)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`
    );
    await db.execute(
      `CREATE TABLE IF NOT EXISTS genero (
         id_genero INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
         nome VARCHAR(80) NOT NULL,
         UNIQUE KEY uq_genero_nome (nome)
       ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
    );
    await db.execute(
      `CREATE TABLE IF NOT EXISTS palavra_chave (
         id_palavra_chave INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
         nome VARCHAR(80) NOT NULL,
         UNIQUE KEY uq_palavra_chave_nome (nome)
       ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
    );
    await db.execute(
      `CREATE TABLE IF NOT EXISTS obra_genero (
         id_obra BIGINT UNSIGNED NOT NULL,
         id_genero INT UNSIGNED NOT NULL,
         PRIMARY KEY (id_obra, id_genero),
         KEY idx_obra_genero_genero (id_genero),
         CONSTRAINT fk_obra_genero_obra
           FOREIGN KEY (id_obra) REFERENCES obra (id_obra) ON DELETE CASCADE,
         CONSTRAINT fk_obra_genero_genero
           FOREIGN KEY (id_genero) REFERENCES genero (id_genero) ON DELETE CASCADE
       ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
    );
    await db.execute(
      `CREATE TABLE IF NOT EXISTS obra_palavra_chave (
         id_obra BIGINT UNSIGNED NOT NULL,
         id_palavra_chave INT UNSIGNED NOT NULL,
         PRIMARY KEY (id_obra, id_palavra_chave),
         KEY idx_obra_palavra_chave_chave (id_palavra_chave),
         CONSTRAINT fk_obra_palavra_chave_obra
           FOREIGN KEY (id_obra) REFERENCES obra (id_obra) ON DELETE CASCADE,
         CONSTRAINT fk_obra_palavra_chave_palavra
           FOREIGN KEY (id_palavra_chave)
           REFERENCES palavra_chave (id_palavra_chave) ON DELETE CASCADE
       ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`,
    );
    await db.execute(
       `CREATE TABLE IF NOT EXISTS usuario_obra (
          id_usuario BIGINT UNSIGNED NOT NULL,
          id_obra BIGINT UNSIGNED NOT NULL,
          sou_fa BOOLEAN NULL DEFAULT NULL,
          PRIMARY KEY (id_usuario, id_obra),
          INDEX idx_usuario_obra_obra (id_obra)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`
    );

    for (const [table, column, parentTable, parentColumn, constraint, onDelete] of [
      ['obra_genero', 'id_obra', 'obra', 'id_obra', 'fk_obra_genero_obra', 'CASCADE'],
      ['obra_genero', 'id_genero', 'genero', 'id_genero', 'fk_obra_genero_genero', 'CASCADE'],
      ['obra_palavra_chave', 'id_obra', 'obra', 'id_obra', 'fk_obra_palavra_chave_obra', 'CASCADE'],
      ['obra_palavra_chave', 'id_palavra_chave', 'palavra_chave', 'id_palavra_chave', 'fk_obra_palavra_chave_palavra', 'CASCADE'],
      ['video_post', 'id_obra', 'obra', 'id_obra', 'fk_video_post_obra', 'SET NULL'],
    ]) {
      const [foreignKeys] = await db.execute(
        `SELECT CONSTRAINT_NAME
         FROM information_schema.KEY_COLUMN_USAGE
         WHERE TABLE_SCHEMA = DATABASE()
           AND TABLE_NAME = ?
           AND COLUMN_NAME = ?
           AND REFERENCED_TABLE_NAME = ?
           AND REFERENCED_COLUMN_NAME = ?
         LIMIT 1`,
        [table, column, parentTable, parentColumn],
      );
      if (foreignKeys.length === 0) {
        await db.query(
          `ALTER TABLE \`${table}\`
           ADD CONSTRAINT \`${constraint}\`
           FOREIGN KEY (\`${column}\`)
           REFERENCES \`${parentTable}\` (\`${parentColumn}\`)
           ON DELETE ${onDelete}`,
        );
      }
    }

    conexao.release();

    const porta = Number(process.env.PORT) || 3000;

    app.listen(porta, '0.0.0.0', () => {
      console.log(`API do LupTok rodando na porta ${porta}`);
    });
  } catch (error) {
    console.error('Não foi possível conectar ao MySQL.');
    console.error(error.message);
    process.exit(1);
  }
}

iniciarServidor();
