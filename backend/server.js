
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
const uploadsDirectory = process.env.UPLOADS_DIR || (process.env.RAILWAY_ENVIRONMENT ? '/app/uploads' : path.join(__dirname, 'uploads'));
fs.mkdirSync(uploadsDirectory, { recursive: true });

app.use(cors());
app.use(express.json({ limit: '1mb' }));

app.use((req, res, next) => {
  console.log(`📩 [REQUISIÇÃO] ${req.method} ${req.path}`);

  res.on('finish', () => {
    console.log(`📤 [RESPOSTA] ${req.method} ${req.path} - Status: ${res.statusCode}`);
  });

  next();
});
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



// Imagens do perfil: armazenadas no mesmo volume persistente configurado para uploads.
const profileImageUpload = multer({
  storage: multer.diskStorage({
    destination: uploadsDirectory,
    filename: (_req, file, cb) => cb(null, `${randomUUID()}${path.extname(file.originalname).toLowerCase()}`),
  }),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, ['.jpg', '.jpeg', '.png', '.webp'].includes(ext));
  },
});

function validarAssinaturaImagem(bytes) {
  if (bytes.length < 12) return false;
  return (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) ||
    (bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]))) ||
    (bytes.toString('ascii',0,4) === 'RIFF' && bytes.toString('ascii',8,12) === 'WEBP');
}

app.get('/api/profile/me', autenticar, async (req, res) => {
  try {
    const [[usuario]] = await db.execute(
      'SELECT nome, nome_usuario, bio, foto_url, capa_url, atividade, obra_atual FROM usuario WHERE id_usuario = ? LIMIT 1',
      [req.usuario.id_usuario],
    );
    if (!usuario) return res.status(404).json({ erro: 'Perfil não encontrado.' });
    return res.json(usuario);
  } catch (error) {
    console.error('Erro ao consultar perfil:', error.message);
    return res.status(500).json({ erro: 'Não foi possível carregar o perfil.' });
  }
});

app.put('/api/profile/me', autenticar, async (req, res) => {
  const { nome, nome_usuario, bio, atividade, obra_atual } = req.body ?? {};
  if (typeof nome !== 'string' || !nome.trim() || nome.trim().length > 100 ||
      typeof nome_usuario !== 'string' || !/^[a-zA-Z0-9_.]{1,30}$/.test(nome_usuario) ||
      typeof bio !== 'string' || bio.length > 160 ||
      !['Assistindo', 'Lendo'].includes(atividade) ||
      typeof obra_atual !== 'string' || obra_atual.length > 150) {
    return res.status(400).json({ erro: 'Confira o nome, usuário, biografia e atividade.' });
  }
  try {
    await db.execute(
      `UPDATE usuario SET nome = ?, nome_usuario = ?, bio = ?, atividade = ?, obra_atual = ? WHERE id_usuario = ?`,
      [nome.trim(), nome_usuario, bio.trim(), atividade, obra_atual.trim(), req.usuario.id_usuario],
    );
    return res.json({ nome: nome.trim(), nome_usuario, bio: bio.trim(), atividade, obra_atual: obra_atual.trim() });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') return res.status(409).json({ erro: 'Esse nome de usuário já está em uso.' });
    console.error('Erro ao salvar perfil:', error.message);
    return res.status(500).json({ erro: 'Não foi possível salvar o perfil.' });
  }
});

app.delete('/api/profile/me/:tipo', autenticar, async (req, res) => {
  const campo = req.params.tipo === 'foto' ? 'foto_url' : req.params.tipo === 'capa' ? 'capa_url' : null;
  if (!campo) return res.status(404).json({ erro: 'Imagem inválida.' });
  try {
    const [[usuario]] = await db.execute(`SELECT ${campo} FROM usuario WHERE id_usuario = ?`, [req.usuario.id_usuario]);
    if (!usuario) return res.status(404).json({ erro: 'Conta não encontrada.' });
    await db.execute(`UPDATE usuario SET ${campo} = NULL WHERE id_usuario = ?`, [req.usuario.id_usuario]);
    const antiga = usuario[campo];
    if (typeof antiga === 'string' && antiga.startsWith('/api/profile/images/')) {
      await fs.promises.unlink(path.join(uploadsDirectory, path.basename(antiga))).catch(() => {});
    }
    return res.json({ [campo]: null });
  } catch (error) {
    console.error('Erro ao remover imagem:', error.message);
    return res.status(500).json({ erro: 'Não foi possível remover a imagem.' });
  }
});

app.delete('/api/works/:id/my-interest', autenticar, async (req, res) => {
  if (!/^\d+$/.test(req.params.id)) return res.status(400).json({ erro: 'Obra inválida.' });
  try {
    await db.execute('DELETE FROM usuario_obra WHERE id_usuario = ? AND id_obra = ?',
      [req.usuario.id_usuario, req.params.id]);
    return res.json({ mensagem: 'Obra removida dos seus interesses.' });
  } catch (error) {
    console.error('Erro ao remover interesse:', error.message);
    return res.status(500).json({ erro: 'Não foi possível remover o interesse.' });
  }
});

app.post('/api/profile/me/:tipo', autenticar, (req,res,next) => {
  if (!['foto','capa'].includes(req.params.tipo)) return res.status(404).json({ erro: 'Tipo de imagem inválido.' });
  profileImageUpload.single('imagem')(req,res,(error) => {
    if (error) return res.status(error.code === 'LIMIT_FILE_SIZE' ? 413 : 400).json({ erro: 'Imagem inválida ou maior que 5 MB.' });
    next();
  });
}, async (req,res) => {
  if (!req.file) return res.status(400).json({ erro: 'Escolha uma imagem JPG, PNG ou WebP.' });
  try {
    const bytes = await fs.promises.readFile(req.file.path);
    if (!validarAssinaturaImagem(bytes)) {
      await fs.promises.unlink(req.file.path);
      return res.status(400).json({ erro: 'O arquivo não é uma imagem válida.' });
    }
    const campo = req.params.tipo === 'foto' ? 'foto_url' : 'capa_url';
    const url = `/api/profile/images/${req.file.filename}`;
    const [[anterior]] = await db.execute(`SELECT ${campo} FROM usuario WHERE id_usuario = ?`, [req.usuario.id_usuario]);
    await db.execute(`UPDATE usuario SET ${campo} = ? WHERE id_usuario = ?`, [url, req.usuario.id_usuario]);
    const antiga = anterior?.[campo];
    if (typeof antiga === 'string' && antiga.startsWith('/api/profile/images/')) {
      const nome = path.basename(antiga);
      await fs.promises.unlink(path.join(uploadsDirectory, nome)).catch(() => {});
    }
    return res.json({ [campo]: url });
  } catch (error) {
    await fs.promises.unlink(req.file.path).catch(() => {});
    console.error('Erro ao salvar imagem:', error.message);
    return res.status(500).json({ erro: 'Não foi possível salvar a imagem.' });
  }
});

app.get('/api/profile/images/:filename', async (req,res) => {
  const filename = req.params.filename;
  if (!/^[a-f0-9-]{36}\.(jpg|jpeg|png|webp)$/i.test(filename)) return res.sendStatus(404);
  return res.sendFile(path.join(uploadsDirectory, filename), (error) => {
    if (error && !res.headersSent) res.status(404).json({ erro: 'Imagem não encontrada.' });
  });
});

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

const lupezInstrucoes =
  'Você é Lupez, assistente do LupTok. Ajude com filmes, séries, livros e animes, incluindo recomendações. Responda em português brasileiro, de forma natural, acolhedora e útil. Se não tiver certeza sobre uma informação, diga isso claramente.';

function extrairTextoGemini(dados) {
  const partes = dados?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(partes)) return '';
  return partes
    .map((parte) =>
      parte?.thought !== true && typeof parte?.text === 'string'
        ? parte.text
        : '',
    )
    .join('')
    .trim();
}


// Modelos alternativos e pausa temporária para evitar chamadas repetidas em falha.
const lupezPausas = new Map();

async function consultarGemini({ apiKey, model, mensagem, historico }) {
  const modelos = [...new Set([
    model,
    ...(process.env.GEMINI_FALLBACK_MODELS || 'gemini-3.1-flash-lite')
      .split(',').map(item => item.trim()).filter(Boolean),
  ])].map(item => item.replace(/^models\//, '')).slice(0, 2);
  const contents = [
    ...historico.slice(-8).map(({ role, content }) => ({
      role: role === 'assistant' ? 'model' : 'user',
      parts: [{ text: content }],
    })),
    { role: 'user', parts: [{ text: mensagem }] },
  ];
  const prazo = Date.now() + 22000;
  let ultimoStatus = 503;

  for (const modelo of modelos) {
    if ((lupezPausas.get(modelo) || 0) > Date.now()) continue;
    const restante = prazo - Date.now();
    if (restante < 1000) break;
    const inicio = Date.now();
    try {
      const generationConfig = { maxOutputTokens: 1200 };
      if (/^gemini-3\..*flash-lite$/.test(modelo)) {
        generationConfig.thinkingConfig = { thinkingLevel: 'MINIMAL' };
      } else if (/^gemini-2\.5-flash(?:-lite)?$/.test(modelo)) {
        generationConfig.thinkingConfig = { thinkingBudget: 0 };
      }
      const respostaApi = await fetch(
        'https://generativelanguage.googleapis.com/v1beta/models/' +
          encodeURIComponent(modelo) + ':generateContent',
        {
          method: 'POST',
          headers: { 'x-goog-api-key': apiKey, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: lupezInstrucoes }] },
            contents,
            generationConfig,
          }),
          signal: AbortSignal.timeout(Math.min(10000, restante)),
        }
      );
      const dados = await respostaApi.json().catch(error => {
        if (error.name === 'TimeoutError' || error.name === 'AbortError') throw error;
        return {};
      });
      if (!respostaApi.ok) {
        const erro = new Error('Gemini HTTP ' + respostaApi.status);
        erro.status = respostaApi.status;
        const retry = respostaApi.headers.get('retry-after');
        const segundos = retry === null ? NaN : Number(retry);
        erro.pausa = Number.isFinite(segundos) ? segundos * 1000 :
          (retry ? Date.parse(retry) - Date.now() : 0);
        console.warn(`[Lupez] ${modelo}: HTTP ${erro.status}; ${dados?.error?.status || ''}`);
        throw erro;
      }
      const texto = extrairTextoGemini(dados);
      if (!texto) {
        const erro = new Error('A Lupez não retornou texto. Tente reformular a mensagem.');
        erro.status = 422;
        throw erro;
      }
      console.info(`[Lupez] ${modelo}: sucesso em ${Date.now() - inicio} ms`);
      return texto;
    } catch (error) {
      const timeout = ['TimeoutError', 'AbortError'].includes(error.name);
      const status = timeout ? 504 : (error.status || 502);
      ultimoStatus = status;
      console.warn(`[Lupez] ${modelo}: falha ${status} em ${Date.now() - inicio} ms`);
      if (![404, 408, 429, 500, 502, 503, 504].includes(status)) {
        const erro = new Error(status === 422 ? error.message : 'Não foi possível consultar a Lupez. Verifique a configuração no servidor.');
        erro.status = status === 422 ? 422 : 502;
        throw erro;
      }
      const pausa = status === 429 ? 60000 : status === 404 ? 300000 : 15000;
      lupezPausas.set(modelo, Date.now() + Math.max(pausa, error.pausa || 0));
    }
  }
  const erro = new Error(ultimoStatus === 429
    ? 'A Lupez atingiu o limite de consultas. Tente novamente mais tarde.'
    : 'A Lupez está temporariamente indisponível. Tente novamente em instantes.');
  erro.status = ultimoStatus === 429 ? 429 : ultimoStatus === 504 ? 504 : 503;
  throw erro;
}


async function consultarGroq({ apiKey, model, mensagem, historico }) {
  const inicio = Date.now();
  const chavePausa = 'groq:' + model;
  if ((lupezPausas.get(chavePausa) || 0) > inicio) {
    const erro = new Error('Groq em pausa temporária.');
    erro.status = 503;
    throw erro;
  }
  try {
    const corpo = {
      model,
      messages: [
        { role: 'system', content: lupezInstrucoes },
        ...historico.slice(-6).map(({ role, content }) => ({ role, content })),
        { role: 'user', content: mensagem },
      ],
      max_completion_tokens: 1500,
      temperature: 0.6,
    };
    if (/^openai\/gpt-oss-/.test(model)) {
      corpo.reasoning_effort = 'low';
      corpo.reasoning_format = 'hidden';
    }
    const resposta = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(corpo),
      signal: AbortSignal.timeout(8000),
    });
    const dados = await resposta.json();
    if (!resposta.ok) {
      const erro = new Error('Groq HTTP ' + resposta.status);
      erro.status = resposta.status;
      const retry = resposta.headers.get('retry-after');
      erro.pausa = retry && Number.isFinite(Number(retry)) ? Number(retry) * 1000 : 0;
      throw erro;
    }
    const texto = dados?.choices?.[0]?.message?.content;
    if (typeof texto !== 'string' || !texto.trim()) throw new Error('Groq sem texto.');
    console.info(`[Lupez] Groq ${model}: sucesso em ${Date.now() - inicio} ms`);
    return texto.trim();
  } catch (erro) {
    const status = ['TimeoutError', 'AbortError'].includes(erro.name) ? 504 : (erro.status || 502);
    console.warn(`[Lupez] Groq ${model}: falha ${status} em ${Date.now() - inicio} ms`);
    lupezPausas.set(chavePausa, Date.now() + Math.max(status === 429 ? 60000 : 15000, erro.pausa || 0));
    const falha = new Error('Groq indisponível.');
    falha.status = status;
    throw falha;
  }
}

app.post('/api/lupez/chat', autenticar, async (req, res) => {
  console.info('Requisição recebida: POST /api/lupez/chat');
  if (!req.body || typeof req.body !== 'object' || Array.isArray(req.body)) {
    return res.status(400).json({ erro: 'Envie os dados da conversa.' });
  }

  const { mensagem, historico } = req.body;

  if (
    typeof mensagem !== 'string' ||
    !mensagem.trim() ||
    mensagem.length > 4000 ||
    !Array.isArray(historico) ||
    historico.length > 20
  ) {
    return res.status(400).json({
      erro: 'Envie uma mensagem válida e até 20 mensagens de histórico.',
    });
  }

  const mensagensValidas = historico.every(
    (item) =>
      item &&
      typeof item === 'object' &&
      !Array.isArray(item) &&
      ['user', 'assistant'].includes(item.role) &&
      typeof item.content === 'string' &&
      item.content.trim() &&
      item.content.length <= 4000,
  );
  if (!mensagensValidas) {
    return res.status(400).json({ erro: 'O histórico da conversa é inválido.' });
  }

  const apiKey = process.env.GEMINI_API_KEY?.trim();
  const model = process.env.GEMINI_MODEL?.trim() || 'gemini-3.5-flash-lite';
  const groqKey = process.env.GROQ_API_KEY?.trim();
  const groqModel = process.env.GROQ_MODEL?.trim() || 'openai/gpt-oss-20b';
  if (!apiKey && !groqKey) {
    return res.status(503).json({ erro: 'A Lupez ainda não está configurada.' });
  }

  try {
    if (groqKey) {
      try {
        const resposta = await consultarGroq({ apiKey: groqKey, model: groqModel, mensagem: mensagem.trim(), historico });
        return res.json({ resposta });
      } catch (erro) {
        console.warn('[Lupez] Groq indisponível; tentando Gemini se configurado.');
        if (!apiKey) throw erro;
      }
    }
    const resposta = await consultarGemini({ apiKey, model, mensagem: mensagem.trim(), historico });
    return res.json({ resposta });
  } catch (error) {
    console.error('[Lupez] Falha final:', error.status || 502);
    return res.status(error.status || 502).json({
      erro: error.status === 422 ? error.message : 'A Lupez está temporariamente indisponível. Tente novamente em instantes.',
    });
  }
});

app.all('/api/lupez/chat', (req, res) => {
  res.set('Allow', 'POST');
  return res.status(405).json({
    erro: 'Use POST em /api/lupez/chat com Authorization Bearer.',
  });
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
      .map((termo) => ({doramas:'dorama', filmes:'filme', series:'serie', livros:'livro', animes:'anime', colegiais:'colegial', escolares:'escolar', romanticos:'romance', romanticas:'romance', dramas:'drama'}[termo] || termo))
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

// Seguidores: vínculos persistentes por conta.
app.get('/api/social/:id', autenticar, async (req, res) => {
  const id = req.params.id === 'me' ? req.usuario.id_usuario : req.params.id;
  if (req.usuario.escopo || !req.usuario.id_usuario) return res.sendStatus(403);
  if (!/^\d{1,20}$/.test(String(id))) return res.status(400).json({erro:'Usuário inválido.'});
  try {
    const [[alvo]] = await db.execute('SELECT id_usuario FROM usuario WHERE id_usuario = ? AND ativo = 1', [id]);
    if (!alvo) return res.status(404).json({erro:'Usuário não encontrado.'});
    const [seguidores] = await db.execute(`SELECT u.id_usuario AS id, u.nome, u.nome_usuario, u.foto_url
      FROM luptok_seguidor s JOIN usuario u ON u.id_usuario = s.seguidor_id
      WHERE s.seguido_id = ? AND u.ativo = 1 ORDER BY u.nome`, [id]);
    const [seguindo] = await db.execute(`SELECT u.id_usuario AS id, u.nome, u.nome_usuario, u.foto_url
      FROM luptok_seguidor s JOIN usuario u ON u.id_usuario = s.seguido_id
      WHERE s.seguidor_id = ? AND u.ativo = 1 ORDER BY u.nome`, [id]);
    return res.json({seguidores, seguindo, segue: seguidores.some(u => String(u.id) === String(req.usuario.id_usuario))});
  } catch (error) {
    console.error('Seguidores:', error.message);
    return res.status(500).json({erro:'Não foi possível carregar seguidores.'});
  }
});
app.put('/api/social/:id/follow', autenticar, async (req, res) => {
  const id = req.params.id;
  const eu = req.usuario.id_usuario;
  const seguir = req.body?.seguir;
  if (req.usuario.escopo || !eu) return res.sendStatus(403);
  if (!/^\d{1,20}$/.test(id) || String(eu) === id || typeof seguir !== 'boolean') return res.status(400).json({erro:'Dados inválidos.'});
  try {
    const [[alvo]] = await db.execute('SELECT id_usuario FROM usuario WHERE id_usuario = ? AND ativo = 1', [id]);
    if (!alvo || String(alvo.id_usuario) === String(eu)) return res.status(404).json({erro:'Usuário indisponível.'});
    if (seguir) await db.execute('INSERT INTO luptok_seguidor (seguidor_id, seguido_id) VALUES (?, ?) ON DUPLICATE KEY UPDATE seguido_id = VALUES(seguido_id)', [eu,id]);
    else await db.execute('DELETE FROM luptok_seguidor WHERE seguidor_id = ? AND seguido_id = ?', [eu,id]);
    return res.json({segue:seguir});
  } catch (error) {
    console.error('Seguir:', error.message);
    return res.status(500).json({erro:'Não foi possível atualizar o vínculo.'});
  }
});

app.get('/api/users', autenticar, async (req, res) => {
  try {
    const [linhas] = await db.execute(
      `SELECT u.id_usuario, u.nome, u.nome_usuario, u.bio, u.foto_url, u.capa_url, u.atividade, u.obra_atual,
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
          bio: linha.bio,
          foto_url: linha.foto_url,
          capa_url: linha.capa_url,
          atividade: linha.atividade,
          obra_atual: linha.obra_atual,
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
      `SELECT u.id_usuario, u.nome, u.nome_usuario, u.bio, u.foto_url, u.capa_url, u.atividade, u.obra_atual,
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
        bio: linhas[0].bio,
        foto_url: linhas[0].foto_url,
        capa_url: linhas[0].capa_url,
        atividade: linhas[0].atividade,
        obra_atual: linhas[0].obra_atual,
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

app.get('/api/saved-videos', autenticar, async (req, res) => {
  try {
    const [videos] = await db.execute(`SELECT v.id_video AS id,
      COALESCE(NULLIF(o.titulo,''), NULLIF(v.descricao,''), 'Recomendação') AS titulo,
      v.privacidade, v.tipo_conteudo
      FROM luptok_video_salvo s JOIN video_post v ON v.id_video = s.id_video
      LEFT JOIN obra o ON o.id_obra = v.id_obra
      WHERE s.id_usuario = ? AND (v.privacidade = 'Público' OR v.id_usuario = ?)
      ORDER BY s.criado_em DESC, s.id_video DESC`, [req.usuario.id_usuario, req.usuario.id_usuario]);
    return res.json({videos});
  } catch (e) { console.error('Salvos:', e.message); return res.status(500).json({erro:'Não foi possível carregar os salvos.'}); }
});
app.put('/api/saved-videos/:id', autenticar, async (req, res) => {
  const id = req.params.id;
  const salvo = req.body?.salvo;
  if (!/^\d{1,20}$/.test(id) || typeof salvo !== 'boolean') return res.status(400).json({erro:'Dados inválidos.'});
  try {
    if (salvo) {
      const [rows] = await db.execute("SELECT id_video FROM video_post WHERE id_video = ? AND (privacidade = 'Público' OR id_usuario = ?)", [id, req.usuario.id_usuario]);
      if (!rows.length) return res.status(404).json({erro:'Vídeo indisponível.'});
      await db.execute('INSERT INTO luptok_video_salvo (id_usuario,id_video) VALUES (?,?) ON DUPLICATE KEY UPDATE id_video = id_video', [req.usuario.id_usuario,id]);
    } else {
      await db.execute('DELETE FROM luptok_video_salvo WHERE id_usuario = ? AND id_video = ?', [req.usuario.id_usuario,id]);
    }
    return res.json({salvo});
  } catch (e) { console.error('Salvar vídeo:', e.message); return res.status(500).json({erro:'Não foi possível atualizar os salvos.'}); }
});

// Exclusão de publicação: somente o autor, com transação no banco.
app.delete('/api/videos/:id', autenticar, async (req, res) => {
  const id = req.params.id;
  if (req.usuario.escopo || !req.usuario.id_usuario) return res.status(403).json({ erro: 'Sessão inválida.' });
  if (!/^\d{1,20}$/.test(id)) return res.status(400).json({ erro: 'Vídeo inválido.' });
  let conn;
  let video;
  try {
    conn = await db.getConnection();
    await conn.beginTransaction();
    const [[row]] = await conn.execute('SELECT id_usuario, nome_arquivo FROM video_post WHERE id_video = ? FOR UPDATE', [id]);
    if (!row || String(row.id_usuario) !== String(req.usuario.id_usuario)) {
      await conn.rollback();
      return res.status(404).json({ erro: 'Vídeo não encontrado ou sem permissão.' });
    }
    video = row;
    for (const table of ['video_avaliacao', 'video_post_curtida', 'luptok_video_salvo']) {
      await conn.execute(`DELETE FROM ${table} WHERE id_video = ?`, [id]);
    }
    // Preserva denúncias para moderação quando não impedem a exclusão.
    // Se houver FK restritiva, a transação falha sem apagar parcialmente.
    await conn.execute('DELETE FROM video_post WHERE id_video = ? AND id_usuario = ?', [id, req.usuario.id_usuario]);
    await conn.commit();
  } catch (error) {
    if (conn) await conn.rollback().catch(() => {});
    console.error('Erro ao excluir vídeo:', error.message);
    return res.status(500).json({ erro: 'Não foi possível excluir o vídeo.' });
  } finally {
    if (conn) conn.release();
  }
  let arquivoRemovido = false;
  if (/^[a-f0-9-]{36}\.(mp4|mov|m4v|webm)$/i.test(video.nome_arquivo)) {
    try {
      await fs.promises.unlink(path.join(uploadsDirectory, video.nome_arquivo));
      arquivoRemovido = true;
    } catch (error) {
      arquivoRemovido = error.code === 'ENOENT';
      if (!arquivoRemovido) console.error('Limpeza de vídeo pendente:', video.nome_arquivo, error.message);
    }
  }
  return res.json({ mensagem: 'Vídeo excluído.', arquivo_removido: arquivoRemovido });
});

app.get('/api/videos', autenticar, async (req, res) => {
  const busca = req.query.q ?? '';
  const idObraFiltro = req.query.id_obra ?? null;
  if (typeof busca !== 'string' || busca.length > 120) {
    return res.status(400).json({ erro: 'A busca deve ter até 120 caracteres.' });
  }
  const termos = termosBusca(busca);
  if (busca.trim() && termos.length === 0) return res.json({ videos: [] });

  try {
    const buscaSql = clausulaBuscaVideos(termos);
    const condicoes = ["(v.privacidade = 'Público' OR v.id_usuario = ?)"];
    const params = [req.usuario.id_usuario, req.usuario.id_usuario];

    if (idObraFiltro && /^\d+$/.test(String(idObraFiltro))) {
      condicoes.push('v.id_obra = ?');
      params.push(Number(idObraFiltro));
    }

    if (buscaSql.sql) {
      condicoes.push(buscaSql.sql);
      params.push(...buscaSql.params);
    }

    let orderByClause = 'ORDER BY v.criado_em DESC';
    if (busca.trim()) {
      const buscaNorm = busca
        .trim()
        .normalize('NFD')
        .replace(/\p{Diacritic}/gu, '')
        .toLowerCase();
      const buscaExata = busca.trim().toLowerCase();
      orderByClause = `ORDER BY 
        CASE 
          WHEN LOWER(o.titulo_normalizado) = ? THEN 0
          WHEN LOWER(o.titulo) = ? THEN 1
          WHEN LOWER(o.titulo_normalizado) LIKE ? THEN 2
          WHEN LOWER(o.titulo) LIKE ? THEN 3
          ELSE 4
        END, v.criado_em DESC`;
      params.push(buscaNorm, buscaExata, `%${buscaNorm}%`, `%${buscaExata}%`);
    }

    const [videos] = await db.execute(
      `SELECT v.id_video, v.id_usuario, u.nome_usuario, u.foto_url, v.descricao,
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
       WHERE ${condicoes.join(' AND ')}
       ${orderByClause}
       LIMIT 200`,
      params,
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
          foto_url: video.foto_url,
          descricao: video.descricao,
          tipo_conteudo: video.tipo_conteudo,
          spoiler: video.spoiler,
          privacidade: video.privacidade,
          curtidas: Number(video.curtidas),
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
    const [[count]] = await conexao.execute(
      'SELECT COUNT(*) AS curtidas FROM video_post_curtida WHERE id_video = ?',
      [req.params.id],
    );
    await conexao.commit();
    return res.json({
      curtido,
      curtidas: Number(count.curtidas),
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

// ══════════════════════════════════════════════════════════════════
// CHAT ENTRE USUÁRIOS
// ══════════════════════════════════════════════════════════════════

app.get('/api/conversas', autenticar, async (req, res) => {
  try {
    const idUsuario = req.usuario.id_usuario;
    const [conversas] = await db.execute(
      `SELECT c.id_conversa, c.tipo, c.nome, c.foto_url, c.data_criacao,
              u_outro.id_usuario AS outro_id,
              u_outro.nome AS outro_nome,
              u_outro.nome_usuario AS outro_usuario,
              u_outro.foto_url AS outro_foto,
              (SELECT m.texto FROM mensagem m WHERE m.id_conversa = c.id_conversa ORDER BY m.data_envio DESC, m.id_mensagem DESC LIMIT 1) AS ultima_mensagem,
              (SELECT m.data_envio FROM mensagem m WHERE m.id_conversa = c.id_conversa ORDER BY m.data_envio DESC, m.id_mensagem DESC LIMIT 1) AS ultima_data,
              (SELECT m.id_remetente FROM mensagem m WHERE m.id_conversa = c.id_conversa ORDER BY m.data_envio DESC, m.id_mensagem DESC LIMIT 1) AS ultimo_remetente
       FROM conversa c
       JOIN conversa_membro cm ON cm.id_conversa = c.id_conversa AND cm.id_usuario = ?
       LEFT JOIN conversa_membro m_outro ON m_outro.id_conversa = c.id_conversa AND m_outro.id_usuario != ?
       LEFT JOIN usuario u_outro ON u_outro.id_usuario = m_outro.id_usuario
       ORDER BY COALESCE(ultima_data, c.data_criacao) DESC`,
      [idUsuario, idUsuario]
    );

    return res.json({
      conversas: conversas.map((c) => ({
        id_conversa: c.id_conversa,
        tipo: c.tipo,
        nome: c.tipo === 'direta' ? (c.outro_nome || c.outro_usuario || 'Usuário') : (c.nome || 'Conversa'),
        nome_usuario: c.tipo === 'direta' ? c.outro_usuario : null,
        outro_id: c.outro_id,
        foto_url: c.tipo === 'direta' ? c.outro_foto : c.foto_url,
        data_criacao: c.data_criacao,
        ultima_mensagem: c.ultima_mensagem || '',
        ultima_data: c.ultima_data || c.data_criacao,
        ultimo_remetente: c.ultimo_remetente,
      })),
    });
  } catch (error) {
    console.error('Erro ao listar conversas:', error.message);
    return res.status(500).json({ erro: 'Não foi possível carregar as conversas.' });
  }
});

app.post('/api/conversas', autenticar, async (req, res) => {
  const { id_destinatario } = req.body ?? {};
  if (!id_destinatario || !/^\d+$/.test(String(id_destinatario))) {
    return res.status(400).json({ erro: 'Informe um destinatário válido.' });
  }

  const idUsuario = req.usuario.id_usuario;
  const idDestinatarioNum = Number(id_destinatario);

  if (Number(idUsuario) === idDestinatarioNum) {
    return res.status(400).json({ erro: 'Você não pode iniciar uma conversa consigo mesmo.' });
  }

  let conexao;
  try {
    conexao = await db.getConnection();
    const [usuarios] = await conexao.execute(
      'SELECT id_usuario, nome, nome_usuario, foto_url FROM usuario WHERE id_usuario = ? AND ativo = 1 LIMIT 1',
      [idDestinatarioNum]
    );
    if (usuarios.length === 0) {
      return res.status(404).json({ erro: 'Usuário não encontrado.' });
    }
    const destinatario = usuarios[0];

    const [existentes] = await conexao.execute(
      `SELECT c.id_conversa
       FROM conversa c
       JOIN conversa_membro cm1 ON cm1.id_conversa = c.id_conversa AND cm1.id_usuario = ?
       JOIN conversa_membro cm2 ON cm2.id_conversa = c.id_conversa AND cm2.id_usuario = ?
       WHERE c.tipo = 'direta'
       LIMIT 1`,
      [idUsuario, idDestinatarioNum]
    );

    if (existentes.length > 0) {
      return res.json({
        id_conversa: existentes[0].id_conversa,
        destinatario: {
          id: destinatario.id_usuario,
          nome: destinatario.nome,
          nome_usuario: destinatario.nome_usuario,
          foto_url: destinatario.foto_url,
        },
      });
    }

    await conexao.beginTransaction();
    const [resConversa] = await conexao.execute(
      `INSERT INTO conversa (tipo, id_criador, data_criacao) VALUES ('direta', ?, NOW())`,
      [idUsuario]
    );
    const idConversa = resConversa.insertId;

    await conexao.execute(
      `INSERT INTO conversa_membro (id_conversa, id_usuario, data_entrada) VALUES (?, ?, NOW()), (?, ?, NOW())`,
      [idConversa, idUsuario, idConversa, idDestinatarioNum]
    );

    await conexao.commit();

    return res.status(201).json({
      id_conversa: idConversa,
      destinatario: {
        id: destinatario.id_usuario,
        nome: destinatario.nome,
        nome_usuario: destinatario.nome_usuario,
        foto_url: destinatario.foto_url,
      },
    });
  } catch (error) {
    if (conexao) await conexao.rollback();
    console.error('Erro ao iniciar conversa:', error.message);
    return res.status(500).json({ erro: 'Não foi possível iniciar a conversa.' });
  } finally {
    if (conexao) conexao.release();
  }
});

app.get('/api/conversas/:id/mensagens', autenticar, async (req, res) => {
  if (!/^\d+$/.test(req.params.id)) {
    return res.status(400).json({ erro: 'ID de conversa inválido.' });
  }

  const idConversa = Number(req.params.id);
  const idUsuario = req.usuario.id_usuario;

  try {
    const [membros] = await db.execute(
      'SELECT 1 FROM conversa_membro WHERE id_conversa = ? AND id_usuario = ? LIMIT 1',
      [idConversa, idUsuario]
    );
    if (membros.length === 0) {
      return res.status(403).json({ erro: 'Você não tem acesso a esta conversa.' });
    }

    const [mensagens] = await db.execute(
      `SELECT m.id_mensagem, m.id_conversa, m.id_remetente,
              u.nome, u.nome_usuario, u.foto_url,
              m.texto, m.tipo, m.arquivo_url, m.data_envio
       FROM mensagem m
       JOIN usuario u ON u.id_usuario = m.id_remetente
       WHERE m.id_conversa = ?
       ORDER BY m.data_envio ASC, m.id_mensagem ASC
       LIMIT 300`,
      [idConversa]
    );

    return res.json({
      mensagens: mensagens.map((m) => ({
        id_mensagem: m.id_mensagem,
        id_conversa: m.id_conversa,
        id_remetente: m.id_remetente,
        nome: m.nome,
        nome_usuario: m.nome_usuario,
        foto_url: m.foto_url,
        texto: m.texto,
        tipo: m.tipo,
        arquivo_url: m.arquivo_url,
        data_envio: m.data_envio,
        enviado_por_mim: Number(m.id_remetente) === Number(idUsuario),
      })),
    });
  } catch (error) {
    console.error('Erro ao listar mensagens:', error.message);
    return res.status(500).json({ erro: 'Não foi possível carregar as mensagens.' });
  }
});

app.post('/api/conversas/:id/mensagens', autenticar, async (req, res) => {
  if (!/^\d+$/.test(req.params.id)) {
    return res.status(400).json({ erro: 'ID de conversa inválido.' });
  }

  const { texto } = req.body ?? {};
  if (typeof texto !== 'string' || !texto.trim() || texto.trim().length > 2000) {
    return res.status(400).json({ erro: 'A mensagem deve ter entre 1 e 2000 caracteres.' });
  }

  const idConversa = Number(req.params.id);
  const idUsuario = req.usuario.id_usuario;

  try {
    const [membros] = await db.execute(
      'SELECT 1 FROM conversa_membro WHERE id_conversa = ? AND id_usuario = ? LIMIT 1',
      [idConversa, idUsuario]
    );
    if (membros.length === 0) {
      return res.status(403).json({ erro: 'Você não tem permissão para enviar mensagens nesta conversa.' });
    }

    const [resultado] = await db.execute(
      `INSERT INTO mensagem (id_conversa, id_remetente, texto, tipo, data_envio)
       VALUES (?, ?, ?, 'texto', NOW())`,
      [idConversa, idUsuario, texto.trim()]
    );

    const [linhas] = await db.execute(
      `SELECT m.id_mensagem, m.id_conversa, m.id_remetente,
              u.nome, u.nome_usuario, u.foto_url,
              m.texto, m.tipo, m.arquivo_url, m.data_envio
       FROM mensagem m
       JOIN usuario u ON u.id_usuario = m.id_remetente
       WHERE m.id_mensagem = ? LIMIT 1`,
      [resultado.insertId]
    );

    const m = linhas[0];
    return res.status(201).json({
      mensagem: {
        id_mensagem: m.id_mensagem,
        id_conversa: m.id_conversa,
        id_remetente: m.id_remetente,
        nome: m.nome,
        nome_usuario: m.nome_usuario,
        foto_url: m.foto_url,
        texto: m.texto,
        tipo: m.tipo,
        arquivo_url: m.arquivo_url,
        data_envio: m.data_envio,
        enviado_por_mim: true,
      },
    });
  } catch (error) {
    console.error('Erro ao enviar mensagem:', error.message);
    return res.status(500).json({ erro: 'Não foi possível enviar a mensagem.' });
  }
});

// INICIALIZAÇÃO DO SERVIDOR

// Avaliações persistentes por vídeo (nota de 1 a 5).
app.get('/api/videos/:id/reviews', autenticar, async (req, res) => {
  if (!/^\d+$/.test(req.params.id)) return res.status(400).json({ erro: 'Vídeo inválido.' });
  try {
    const [videos] = await db.execute('SELECT id_video FROM video_post WHERE id_video = ? AND (privacidade = ? OR id_usuario = ?) LIMIT 1', [req.params.id, 'Público', req.usuario.id_usuario]);
    if (!videos.length) return res.status(404).json({ erro: 'Vídeo não encontrado.' });
    const [avaliacoes] = await db.execute(`SELECT a.id_avaliacao AS id, a.id_usuario, u.nome_usuario, u.foto_url, a.nota, a.texto, a.criado_em
      FROM video_avaliacao a JOIN usuario u ON u.id_usuario = a.id_usuario
      WHERE a.id_video = ? ORDER BY a.criado_em DESC, a.id_avaliacao DESC LIMIT 200`, [req.params.id]);
    return res.json({ avaliacoes });
  } catch (e) { console.error('Erro avaliações:', e); return res.status(500).json({ erro: 'Não foi possível carregar avaliações.' }); }
});

app.post('/api/videos/:id/reviews', autenticar, async (req, res) => {
  const { texto, nota } = req.body ?? {};
  if (!/^\d+$/.test(req.params.id) || typeof texto !== 'string' || !texto.trim() || texto.trim().length > 2000 || !Number.isInteger(nota) || nota < 1 || nota > 5)
    return res.status(400).json({ erro: 'Escreva uma opinião (até 2000 caracteres) e escolha de 1 a 5 estrelas.' });
  try {
    const [videos] = await db.execute('SELECT id_video FROM video_post WHERE id_video = ? AND (privacidade = ? OR id_usuario = ?) LIMIT 1', [req.params.id, 'Público', req.usuario.id_usuario]);
    if (!videos.length) return res.status(404).json({ erro: 'Vídeo não encontrado.' });
    const [result] = await db.execute('INSERT INTO video_avaliacao (id_video, id_usuario, nota, texto) VALUES (?, ?, ?, ?)', [req.params.id, req.usuario.id_usuario, nota, texto.trim()]);
    return res.status(201).json({ id: result.insertId, mensagem: 'Avaliação publicada!' });
  } catch (e) { console.error('Erro ao avaliar:', e); return res.status(500).json({ erro: 'Não foi possível salvar a avaliação.' }); }
});

app.delete('/api/videos/:id/reviews/:reviewId', autenticar, async (req, res) => {
  if (!/^\d+$/.test(req.params.id) || !/^\d+$/.test(req.params.reviewId)) return res.status(400).json({ erro: 'Identificador inválido.' });
  try {
    const [result] = await db.execute('DELETE FROM video_avaliacao WHERE id_avaliacao = ? AND id_video = ? AND id_usuario = ?', [req.params.reviewId, req.params.id, req.usuario.id_usuario]);
    if (!result.affectedRows) return res.status(404).json({ erro: 'Avaliação não encontrada ou sem permissão.' });
    return res.json({ mensagem: 'Avaliação excluída.' });
  } catch (e) { console.error('Erro ao excluir avaliação:', e); return res.status(500).json({ erro: 'Não foi possível excluir avaliação.' }); }
});


// Comunidades: acesso autenticado, participantes e mensagens persistidas no MySQL.
app.get('/api/comunidades', autenticar, async (req, res) => {
  try {
    const [rows] = await db.execute(`SELECT c.id_comunidade AS id, c.nome, c.descricao, c.criador_id, c.foto_url,
      COUNT(m.id_usuario) AS membros,
      MAX(CASE WHEN m.id_usuario = ? THEN 1 ELSE 0 END) AS participando, (c.criador_id = ?) AS proprietario
      FROM comunidade c LEFT JOIN comunidade_membro m ON m.id_comunidade = c.id_comunidade
      GROUP BY c.id_comunidade ORDER BY c.criada_em DESC`, [req.usuario.id_usuario, req.usuario.id_usuario]);
    res.json({ comunidades: rows });
  } catch (e) { console.error('Comunidades:', e); res.status(500).json({erro:'Não foi possível carregar as comunidades.'}); }
});
app.post('/api/comunidades', autenticar, (req, res, next) => {
  if (req.usuario.escopo || !req.usuario.id_usuario) return res.status(403).json({erro:'Sessão inválida.'});
  if (!req.is('multipart/form-data')) return next();
  profileImageUpload.single('imagem')(req, res, error => {
    if (error) return res.status(error.code === 'LIMIT_FILE_SIZE' ? 413 : 400).json({erro:'Imagem inválida ou maior que 5 MB.'});
    if (!req.file) return res.status(400).json({erro:'Escolha uma imagem JPG, PNG ou WebP.'});
    next();
  });
}, async (req, res) => {
  let cx, committed = false;
  try {
    const nome = typeof req.body?.nome === 'string' ? req.body.nome.trim() : '';
    const descricao = typeof req.body?.descricao === 'string' ? req.body.descricao.trim() : '';
    if (nome.length < 3 || nome.length > 60 || descricao.length > 300) return res.status(400).json({erro:'Nome deve ter de 3 a 60 caracteres e descrição até 300.'});
    if (req.file && !validarAssinaturaImagem(await fs.promises.readFile(req.file.path))) return res.status(400).json({erro:'O arquivo não é uma imagem válida.'});
    const foto_url = req.file ? `/api/profile/images/${req.file.filename}` : null;
    cx = await db.getConnection();
    await cx.beginTransaction();
    const [r] = await cx.execute('INSERT INTO comunidade (nome, descricao, criador_id, foto_url) VALUES (?, ?, ?, ?)', [nome, descricao, req.usuario.id_usuario, foto_url]);
    await cx.execute('INSERT INTO comunidade_membro (id_comunidade,id_usuario) VALUES (?,?)', [r.insertId, req.usuario.id_usuario]);
    await cx.commit();
    committed = true;
    return res.status(201).json({comunidade:{id:r.insertId,nome,descricao,foto_url,membros:1,participando:1}});
  } catch(e) {
    if (cx && !committed) await cx.rollback().catch(() => {});
    console.error('Criar comunidade:',e);
    return res.status(500).json({erro:'Não foi possível criar a comunidade.'});
  } finally {
    if (cx) cx.release();
    if (!committed && req.file) await fs.promises.unlink(req.file.path).catch(() => {});
  }
});

// Gerenciamento: somente o criador pode modificar ou excluir.
function sessaoComunidade(req,res,next) {
  if (req.usuario.escopo || !req.usuario.id_usuario) return res.status(403).json({erro:'Sessão inválida.'});
  if (!/^\d{1,20}$/.test(req.params.id)) return res.status(400).json({erro:'Comunidade inválida.'});
  next();
}
app.put('/api/comunidades/:id', autenticar, sessaoComunidade, (req,res,next) => {
  if (!req.is('multipart/form-data')) return next();
  profileImageUpload.single('imagem')(req,res,error => {
    if (error || !req.file) return res.status(400).json({erro:'Imagem inválida ou maior que 5 MB.'});
    next();
  });
}, async (req,res) => {
  let cx, committed = false;
  try {
    const nome = typeof req.body?.nome === 'string' ? req.body.nome.trim() : '';
    const descricao = typeof req.body?.descricao === 'string' ? req.body.descricao.trim() : '';
    const remover = req.body?.remover_foto === true || req.body?.remover_foto === 'true';
    if (nome.length < 3 || nome.length > 60 || descricao.length > 300) return res.status(400).json({erro:'Confira o nome e a descrição.'});
    if (req.file && !validarAssinaturaImagem(await fs.promises.readFile(req.file.path))) return res.status(400).json({erro:'Imagem inválida.'});
    cx = await db.getConnection(); await cx.beginTransaction();
    const [[c]] = await cx.execute('SELECT criador_id,foto_url FROM comunidade WHERE id_comunidade=? FOR UPDATE',[req.params.id]);
    if (!c || String(c.criador_id) !== String(req.usuario.id_usuario)) return res.status(403).json({erro:'Somente o criador pode editar.'});
    const foto_url = req.file ? `/api/profile/images/${req.file.filename}` : remover ? null : c.foto_url;
    await cx.execute('UPDATE comunidade SET nome=?,descricao=?,foto_url=? WHERE id_comunidade=?',[nome,descricao,foto_url,req.params.id]);
    await cx.commit(); committed = true;
    return res.json({comunidade:{id:req.params.id,nome,descricao,foto_url,proprietario:1}});
  } catch(e) { console.error('Editar comunidade:',e.message); return res.status(500).json({erro:'Não foi possível editar a comunidade.'}); }
  finally { if(cx){if(!committed) await cx.rollback().catch(()=>{});cx.release();} if(!committed && req.file) await fs.promises.unlink(req.file.path).catch(()=>{}); }
});
app.delete('/api/comunidades/:id', autenticar, sessaoComunidade, async(req,res)=>{
  let cx, committed=false;
  try {
    cx=await db.getConnection(); await cx.beginTransaction();
    const [[c]]=await cx.execute('SELECT criador_id FROM comunidade WHERE id_comunidade=? FOR UPDATE',[req.params.id]);
    if(!c || String(c.criador_id)!==String(req.usuario.id_usuario)) return res.status(403).json({erro:'Somente o criador pode excluir.'});
    await cx.execute('DELETE FROM comunidade_mensagem WHERE id_comunidade=?',[req.params.id]);
    await cx.execute('DELETE FROM comunidade_membro WHERE id_comunidade=?',[req.params.id]);
    await cx.execute('DELETE FROM comunidade WHERE id_comunidade=?',[req.params.id]);
    await cx.commit(); committed=true; return res.json({mensagem:'Comunidade excluída.'});
  } catch(e){console.error('Excluir comunidade:',e.message);return res.status(500).json({erro:'Não foi possível excluir a comunidade.'});}
  finally{if(cx){if(!committed)await cx.rollback().catch(()=>{});cx.release();}}
});

app.post('/api/comunidades/:id/entrar', autenticar, async (req,res) => {
  if (!/^\d+$/.test(req.params.id)) return res.status(400).json({erro:'Comunidade inválida.'});
  try {
    const [r] = await db.execute('INSERT IGNORE INTO comunidade_membro (id_comunidade,id_usuario) VALUES (?,?)', [req.params.id,req.usuario.id_usuario]);
    res.json({participando:true});
  } catch(e) { if(e.code === 'ER_NO_REFERENCED_ROW_2') return res.status(404).json({erro:'Comunidade não encontrada.'}); res.status(500).json({erro:'Não foi possível entrar na comunidade.'}); }
});
app.get('/api/comunidades/:id/mensagens', autenticar, async(req,res)=>{
  if (!/^\d+$/.test(req.params.id)) return res.status(400).json({erro:'Comunidade inválida.'});
  try {
    const [[member]] = await db.execute('SELECT 1 FROM comunidade_membro WHERE id_comunidade=? AND id_usuario=?',[req.params.id,req.usuario.id_usuario]);
    if (!member) return res.status(403).json({erro:'Entre na comunidade para ver as mensagens.'});
    const [rows] = await db.execute(`SELECT cm.id_mensagem AS id,cm.texto,cm.criada_em,u.nome,u.id_usuario,
      (cm.id_usuario = ?) AS enviado_por_mim FROM comunidade_mensagem cm
      JOIN usuario u ON u.id_usuario=cm.id_usuario WHERE cm.id_comunidade=? ORDER BY cm.criada_em ASC,cm.id_mensagem ASC LIMIT 200`,[req.usuario.id_usuario,req.params.id]);
    res.json({mensagens:rows});
  } catch(e) { console.error('Mensagens comunidade:',e);res.status(500).json({erro:'Não foi possível carregar mensagens.'}); }
});
app.post('/api/comunidades/:id/mensagens', autenticar, async(req,res)=>{
  const texto = typeof req.body?.texto === 'string' ? req.body.texto.trim() : '';
  if (!/^\d+$/.test(req.params.id) || !texto || texto.length > 2000) return res.status(400).json({erro:'Mensagem inválida (máximo 2000 caracteres).'});
  try {
    const [[member]] = await db.execute('SELECT 1 FROM comunidade_membro WHERE id_comunidade=? AND id_usuario=?',[req.params.id,req.usuario.id_usuario]);
    if (!member) return res.status(403).json({erro:'Entre na comunidade para enviar mensagens.'});
    const [r] = await db.execute('INSERT INTO comunidade_mensagem (id_comunidade,id_usuario,texto) VALUES (?,?,?)',[req.params.id,req.usuario.id_usuario,texto]);
    res.status(201).json({id:r.insertId});
  } catch(e) {console.error('Enviar comunidade:',e);res.status(500).json({erro:'Não foi possível enviar a mensagem.'});}
});

// Usa o tipo real da chave primária existente no banco, inclusive UNSIGNED.
// Evita incompatibilidades entre instalações antigas e tabelas novas.
async function tipoChaveEstrangeira(tabela, coluna) {
  const [linhas] = await db.execute(
    `SELECT COLUMN_TYPE FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ? LIMIT 1`,
    [tabela, coluna],
  );
  if (linhas.length === 0) {
    throw new Error(`Coluna de referência ausente: ${tabela}.${coluna}`);
  }
  const tipo = String(linhas[0].COLUMN_TYPE).toUpperCase();
  // Somente tipos inteiros são aceitos; nunca interpolar SQL arbitrário.
  if (!/^(TINYINT|SMALLINT|MEDIUMINT|INT|INTEGER|BIGINT)(\(\d+\))?( UNSIGNED)?$/.test(tipo)) {
    throw new Error(`Tipo de chave não suportado em ${tabela}.${coluna}: ${tipo}`);
  }
  return tipo;
}

// Catálogo inicial: acrescenta metadados sem substituir descrições ou vínculos existentes.
const catalogoInicialBusca = [
  [
    "True Beauty",
    "Dorama",
    [
      "Beleza Verdadeira",
      "여신강림"
    ],
    [
      "Romance",
      "Comédia",
      "Drama"
    ],
    [
      "colegial",
      "escolar",
      "escola",
      "maquiagem",
      "autoestima",
      "bullying",
      "triângulo amoroso",
      "k-drama",
      "coreano"
    ],
    "Uma estudante aprende a lidar com a aparência, a amizade e o amor."
  ],
  [
    "Lovely Runner",
    "Dorama",
    [
      "Adorável Corredora"
    ],
    [
      "Romance",
      "Fantasia",
      "Drama"
    ],
    [
      "colegial",
      "escolar",
      "viagem no tempo",
      "ídolo",
      "k-drama",
      "coreano"
    ],
    "Uma fã viaja no tempo para tentar mudar o destino de seu ídolo."
  ],
  [
    "Twinkling Watermelon",
    "Dorama",
    [
      "Melancia Cintilante"
    ],
    [
      "Romance",
      "Fantasia",
      "Drama"
    ],
    [
      "colegial",
      "escolar",
      "música",
      "viagem no tempo",
      "família",
      "amizade",
      "k-drama"
    ],
    "Um jovem músico viaja ao passado e conhece seus pais adolescentes."
  ],
  [
    "Boys Over Flowers",
    "Dorama",
    [
      "Meninos Antes de Flores",
      "Boys Before Flowers"
    ],
    [
      "Romance",
      "Drama",
      "Comédia"
    ],
    [
      "colegial",
      "escolar",
      "escola",
      "ricos",
      "triângulo amoroso",
      "k-drama"
    ],
    "Uma estudante de origem humilde entra em uma escola de elite."
  ],
  [
    "The Heirs",
    "Dorama",
    [
      "Os Herdeiros",
      "Inheritors"
    ],
    [
      "Romance",
      "Drama"
    ],
    [
      "colegial",
      "escolar",
      "escola",
      "ricos",
      "família",
      "k-drama"
    ],
    "Jovens herdeiros enfrentam conflitos familiares e amorosos."
  ],
  [
    "Extraordinary You",
    "Dorama",
    [
      "Extraordinária Você"
    ],
    [
      "Romance",
      "Fantasia",
      "Comédia"
    ],
    [
      "colegial",
      "escolar",
      "quadrinhos",
      "destino",
      "k-drama"
    ],
    "Uma estudante descobre que vive dentro de uma história em quadrinhos."
  ],
  [
    "All of Us Are Dead",
    "Dorama",
    [
      "Estamos Todos Mortos"
    ],
    [
      "Terror",
      "Suspense",
      "Drama"
    ],
    [
      "colegial",
      "escolar",
      "zumbis",
      "sobrevivência",
      "apocalipse",
      "k-drama"
    ],
    "Estudantes tentam sobreviver a um surto de zumbis na escola."
  ],
  [
    "Business Proposal",
    "Dorama",
    [
      "Pretendente Surpresa"
    ],
    [
      "Romance",
      "Comédia"
    ],
    [
      "trabalho",
      "encontro às cegas",
      "identidade secreta",
      "k-drama"
    ],
    "Uma funcionária acaba em um encontro com seu próprio chefe."
  ],
  [
    "Crash Landing on You",
    "Dorama",
    [
      "Pousando no Amor"
    ],
    [
      "Romance",
      "Drama"
    ],
    [
      "coreia",
      "amor proibido",
      "militar",
      "k-drama"
    ],
    "Uma empresária sul-coreana conhece um oficial norte-coreano após um acidente."
  ],
  [
    "Goblin",
    "Dorama",
    [
      "Guardian: The Lonely and Great God",
      "O Guardião"
    ],
    [
      "Romance",
      "Fantasia",
      "Drama"
    ],
    [
      "imortalidade",
      "destino",
      "sobrenatural",
      "k-drama"
    ],
    "Um ser imortal busca alguém capaz de encerrar sua maldição."
  ],
  [
    "Twenty-Five Twenty-One",
    "Dorama",
    [
      "Vinte e Cinco Vinte e Um",
      "2521"
    ],
    [
      "Romance",
      "Drama"
    ],
    [
      "colegial",
      "escolar",
      "esgrima",
      "esporte",
      "amadurecimento",
      "k-drama"
    ],
    "Uma jovem atleta busca seus sonhos em tempos de crise."
  ],
  [
    "A Cinco Passos de Você",
    "Filme",
    [
      "Five Feet Apart"
    ],
    [
      "Romance",
      "Drama"
    ],
    [
      "hospital",
      "doença",
      "fibrose cística",
      "amor impossível",
      "emocionante"
    ],
    "Dois adolescentes com fibrose cística se aproximam apesar das restrições médicas."
  ],
  [
    "Titanic",
    "Filme",
    [],
    [
      "Romance",
      "Drama"
    ],
    [
      "navio",
      "tragédia",
      "amor proibido",
      "histórico",
      "clássico"
    ],
    "Dois passageiros de classes sociais diferentes se apaixonam a bordo do Titanic."
  ],
  [
    "Interestelar",
    "Filme",
    [
      "Interstellar"
    ],
    [
      "Ficção científica",
      "Drama",
      "Aventura"
    ],
    [
      "espaço",
      "astronomia",
      "universo",
      "viagem no tempo",
      "família",
      "clássico"
    ],
    "Exploradores procuram um novo lar para a humanidade."
  ],
  [
    "Jogos Vorazes",
    "Filme",
    [
      "The Hunger Games"
    ],
    [
      "Ação",
      "Ficção científica",
      "Aventura"
    ],
    [
      "distopia",
      "sobrevivência",
      "rebelião",
      "adaptação literária",
      "romance"
    ],
    "Uma jovem participa de uma competição mortal imposta pelo governo."
  ],
  [
    "Harry Potter e a Pedra Filosofal",
    "Filme",
    [
      "Harry Potter and the Philosopher's Stone",
      "Harry Potter and the Sorcerer's Stone"
    ],
    [
      "Fantasia",
      "Aventura"
    ],
    [
      "magia",
      "escola",
      "amizade",
      "bruxos",
      "clássico",
      "adaptação literária"
    ],
    "Um garoto descobre que é bruxo e entra em uma escola de magia."
  ],
  [
    "Crepúsculo",
    "Filme",
    [
      "Twilight"
    ],
    [
      "Romance",
      "Fantasia",
      "Drama"
    ],
    [
      "vampiros",
      "colegial",
      "escolar",
      "amor proibido",
      "sobrenatural",
      "adaptação literária"
    ],
    "Uma adolescente se apaixona por um vampiro."
  ],
  [
    "O Diário de uma Paixão",
    "Filme",
    [
      "The Notebook",
      "Diário de uma Paixão"
    ],
    [
      "Romance",
      "Drama"
    ],
    [
      "amor",
      "memória",
      "reencontro",
      "clássico",
      "adaptação literária"
    ],
    "Uma história de amor atravessa diferentes momentos da vida de um casal."
  ],
  [
    "Orgulho e Preconceito",
    "Filme",
    [
      "Pride and Prejudice"
    ],
    [
      "Romance",
      "Drama"
    ],
    [
      "época",
      "romance histórico",
      "enemies to lovers",
      "adaptação literária",
      "clássico"
    ],
    "Elizabeth Bennet e Darcy enfrentam seus próprios preconceitos."
  ],
  [
    "Meninas Malvadas",
    "Filme",
    [
      "Mean Girls"
    ],
    [
      "Comédia"
    ],
    [
      "colegial",
      "escolar",
      "escola",
      "popularidade",
      "amizade",
      "clássico"
    ],
    "Uma nova estudante conhece as regras sociais de uma escola americana."
  ],
  [
    "As Branquelas",
    "Filme",
    [
      "White Chicks"
    ],
    [
      "Comédia"
    ],
    [
      "disfarce",
      "policial",
      "amizade",
      "clássico"
    ],
    "Dois agentes assumem identidades falsas em uma missão."
  ],
  [
    "Shrek",
    "Filme",
    [],
    [
      "Animação",
      "Comédia",
      "Fantasia"
    ],
    [
      "conto de fadas",
      "amizade",
      "romance",
      "família",
      "clássico"
    ],
    "Um ogro embarca em uma aventura para resgatar uma princesa."
  ],
  [
    "O Rei Leão",
    "Filme",
    [
      "The Lion King"
    ],
    [
      "Animação",
      "Aventura",
      "Drama"
    ],
    [
      "família",
      "animais",
      "amadurecimento",
      "clássico",
      "disney"
    ],
    "Um jovem leão precisa assumir seu lugar no reino."
  ],
  [
    "Procurando Nemo",
    "Filme",
    [
      "Finding Nemo"
    ],
    [
      "Animação",
      "Aventura",
      "Comédia"
    ],
    [
      "oceano",
      "família",
      "amizade",
      "clássico",
      "pixar"
    ],
    "Um peixe atravessa o oceano procurando seu filho."
  ],
  [
    "O Auto da Compadecida",
    "Filme",
    [],
    [
      "Comédia",
      "Drama"
    ],
    [
      "brasileiro",
      "nordeste",
      "amizade",
      "religião",
      "clássico"
    ],
    "João Grilo e Chicó vivem aventuras no sertão nordestino."
  ],
  [
    "Cidade de Deus",
    "Filme",
    [
      "City of God"
    ],
    [
      "Drama",
      "Crime"
    ],
    [
      "brasileiro",
      "violência",
      "sociedade",
      "rio de janeiro",
      "clássico"
    ],
    "A trajetória de jovens em uma comunidade do Rio de Janeiro."
  ],
  [
    "O Senhor dos Anéis: A Sociedade do Anel",
    "Filme",
    [
      "The Lord of the Rings: The Fellowship of the Ring"
    ],
    [
      "Fantasia",
      "Aventura"
    ],
    [
      "magia",
      "jornada",
      "amizade",
      "clássico",
      "adaptação literária"
    ],
    "Um hobbit parte em missão para destruir um anel poderoso."
  ],
  [
    "De Volta para o Futuro",
    "Filme",
    [
      "Back to the Future"
    ],
    [
      "Ficção científica",
      "Comédia",
      "Aventura"
    ],
    [
      "viagem no tempo",
      "família",
      "clássico"
    ],
    "Um adolescente viaja ao passado e precisa preservar sua própria existência."
  ],
  [
    "Matrix",
    "Filme",
    [
      "The Matrix"
    ],
    [
      "Ficção científica",
      "Ação"
    ],
    [
      "realidade virtual",
      "tecnologia",
      "inteligência artificial",
      "distopia",
      "clássico"
    ],
    "Um hacker descobre a verdadeira natureza do mundo em que vive."
  ],
  [
    "Coraline e o Mundo Secreto",
    "Filme",
    [
      "Coraline"
    ],
    [
      "Animação",
      "Fantasia",
      "Terror"
    ],
    [
      "mundo paralelo",
      "mistério",
      "família",
      "adaptação literária"
    ],
    "Uma garota encontra uma porta para um mundo aparentemente perfeito."
  ],
  [
    "Olhos da Justiça",
    "Filme",
    [
      "Secret in Their Eyes"
    ],
    [
      "Suspense",
      "Drama",
      "Crime"
    ],
    [
      "investigação",
      "mistério",
      "vingança",
      "policial"
    ],
    "Investigadores revisitam um crime que marcou suas vidas."
  ],
  [
    "Stranger Things",
    "Série",
    [],
    [
      "Ficção científica",
      "Terror",
      "Suspense"
    ],
    [
      "adolescentes",
      "escolar",
      "amizade",
      "sobrenatural",
      "anos 80",
      "mistério"
    ],
    "Amigos investigam acontecimentos sobrenaturais em uma pequena cidade."
  ],
  [
    "Friends",
    "Série",
    [],
    [
      "Comédia",
      "Romance"
    ],
    [
      "amizade",
      "vida adulta",
      "cotidiano",
      "sitcom",
      "clássico"
    ],
    "Seis amigos compartilham desafios cotidianos em Nova York."
  ],
  [
    "The Office",
    "Série",
    [],
    [
      "Comédia"
    ],
    [
      "trabalho",
      "escritório",
      "sitcom",
      "falso documentário"
    ],
    "Funcionários de um escritório vivem situações cômicas no trabalho."
  ],
  [
    "Breaking Bad",
    "Série",
    [],
    [
      "Drama",
      "Crime",
      "Suspense"
    ],
    [
      "química",
      "crime",
      "anti-herói",
      "família",
      "clássico"
    ],
    "Um professor de química entra no mundo do crime."
  ],
  [
    "Anne with an E",
    "Série",
    [
      "Anne com E"
    ],
    [
      "Drama"
    ],
    [
      "época",
      "escolar",
      "colegial",
      "amizade",
      "família",
      "amadurecimento"
    ],
    "Uma órfã imaginativa encontra um novo lar."
  ],
  [
    "Gilmore Girls",
    "Série",
    [
      "Tal Mãe, Tal Filha"
    ],
    [
      "Comédia",
      "Drama",
      "Romance"
    ],
    [
      "família",
      "escolar",
      "colegial",
      "cidade pequena",
      "amizade"
    ],
    "Mãe e filha compartilham a vida em uma pequena cidade."
  ],
  [
    "Wandinha",
    "Série",
    [
      "Wednesday"
    ],
    [
      "Fantasia",
      "Mistério",
      "Comédia"
    ],
    [
      "colegial",
      "escolar",
      "escola",
      "sobrenatural",
      "investigação"
    ],
    "Wandinha Addams investiga mistérios em sua nova escola."
  ],
  [
    "Naruto",
    "Anime",
    [],
    [
      "Ação",
      "Aventura",
      "Fantasia"
    ],
    [
      "ninja",
      "amizade",
      "superação",
      "shonen",
      "clássico"
    ],
    "Um jovem ninja sonha em liderar sua aldeia."
  ],
  [
    "Death Note",
    "Anime",
    [],
    [
      "Suspense",
      "Mistério",
      "Fantasia"
    ],
    [
      "investigação",
      "psicológico",
      "sobrenatural",
      "crime",
      "clássico"
    ],
    "Um estudante encontra um caderno com poderes letais."
  ],
  [
    "Attack on Titan",
    "Anime",
    [
      "Shingeki no Kyojin",
      "Ataque dos Titãs"
    ],
    [
      "Ação",
      "Fantasia",
      "Drama"
    ],
    [
      "sobrevivência",
      "guerra",
      "distopia",
      "mistério"
    ],
    "A humanidade luta para sobreviver diante de titãs."
  ],
  [
    "One Piece",
    "Anime",
    [],
    [
      "Aventura",
      "Ação",
      "Fantasia"
    ],
    [
      "piratas",
      "amizade",
      "tesouro",
      "shonen",
      "clássico"
    ],
    "Um jovem pirata reúne uma tripulação em busca de um tesouro lendário."
  ],
  [
    "A Viagem de Chihiro",
    "Anime",
    [
      "Spirited Away",
      "Sen to Chihiro no Kamikakushi"
    ],
    [
      "Fantasia",
      "Aventura",
      "Animação"
    ],
    [
      "mundo espiritual",
      "amadurecimento",
      "studio ghibli",
      "clássico"
    ],
    "Uma menina precisa salvar seus pais em um mundo de espíritos."
  ],
  [
    "Your Name",
    "Anime",
    [
      "Kimi no Na wa"
    ],
    [
      "Romance",
      "Fantasia",
      "Drama"
    ],
    [
      "colegial",
      "escolar",
      "troca de corpos",
      "destino",
      "viagem no tempo"
    ],
    "Dois jovens descobrem uma ligação inexplicável entre suas vidas."
  ],
  [
    "O Pequeno Príncipe",
    "Livro",
    [
      "The Little Prince",
      "Le Petit Prince"
    ],
    [
      "Fantasia",
      "Fábula"
    ],
    [
      "amizade",
      "filosofia",
      "infância",
      "clássico"
    ],
    "Um pequeno viajante reflete sobre o amor e a natureza humana."
  ],
  [
    "Dom Casmurro",
    "Livro",
    [],
    [
      "Romance",
      "Drama"
    ],
    [
      "brasileiro",
      "ciúme",
      "literatura brasileira",
      "clássico"
    ],
    "Bentinho revisita sua vida e seu relacionamento com Capitu."
  ],
  [
    "Capitães da Areia",
    "Livro",
    [],
    [
      "Drama",
      "Ficção"
    ],
    [
      "brasileiro",
      "sociedade",
      "amizade",
      "salvador",
      "clássico"
    ],
    "Um grupo de meninos vive nas ruas de Salvador."
  ],
  [
    "1984",
    "Livro",
    [
      "Nineteen Eighty-Four"
    ],
    [
      "Ficção científica",
      "Distopia"
    ],
    [
      "vigilância",
      "totalitarismo",
      "política",
      "clássico"
    ],
    "Um homem vive sob um regime que controla a informação e o pensamento."
  ],
  [
    "A Revolução dos Bichos",
    "Livro",
    [
      "Animal Farm"
    ],
    [
      "Sátira",
      "Fábula"
    ],
    [
      "política",
      "revolução",
      "sociedade",
      "clássico"
    ],
    "Animais de uma fazenda se rebelam contra seus donos."
  ],
  [
    "Orgulho e Preconceito",
    "Livro",
    [
      "Pride and Prejudice"
    ],
    [
      "Romance"
    ],
    [
      "época",
      "romance histórico",
      "enemies to lovers",
      "clássico"
    ],
    "Elizabeth Bennet e Darcy confrontam expectativas sociais e preconceitos."
  ],
  [
    "A Culpa é das Estrelas",
    "Livro",
    [
      "The Fault in Our Stars"
    ],
    [
      "Romance",
      "Drama"
    ],
    [
      "doença",
      "adolescentes",
      "emocionante",
      "amor"
    ],
    "Dois adolescentes se conhecem em um grupo de apoio a pacientes com câncer."
  ],
  [
    "A Hipótese do Amor",
    "Livro",
    [
      "The Love Hypothesis"
    ],
    [
      "Romance",
      "Comédia"
    ],
    [
      "universidade",
      "ciência",
      "namoro falso",
      "romance contemporâneo"
    ],
    "Uma pesquisadora entra em um relacionamento de mentira."
  ],
  [
    "Percy Jackson e o Ladrão de Raios",
    "Livro",
    [
      "The Lightning Thief",
      "Percy Jackson"
    ],
    [
      "Fantasia",
      "Aventura"
    ],
    [
      "mitologia grega",
      "amizade",
      "semideuses",
      "juvenil"
    ],
    "Um garoto descobre sua ligação com os deuses gregos."
  ],
  [
    "Harry Potter e a Pedra Filosofal",
    "Livro",
    [
      "Harry Potter and the Philosopher's Stone",
      "Harry Potter and the Sorcerer's Stone"
    ],
    [
      "Fantasia",
      "Aventura"
    ],
    [
      "magia",
      "escola",
      "amizade",
      "bruxos",
      "clássico"
    ],
    "Um garoto descobre seus poderes e começa a estudar magia."
  ],
  [
    "Jogos Vorazes",
    "Livro",
    [
      "The Hunger Games"
    ],
    [
      "Distopia",
      "Aventura",
      "Ficção científica"
    ],
    [
      "sobrevivência",
      "rebelião",
      "romance",
      "juvenil"
    ],
    "Katniss enfrenta uma competição mortal em uma sociedade distópica."
  ]
];

async function prepararCatalogoBusca(conexao) {
  await conexao.execute(`CREATE TABLE IF NOT EXISTS luptok_migracao_catalogo (
    versao VARCHAR(80) PRIMARY KEY, aplicada_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
  const versao = 'catalogo_busca_v1';
  const [feito] = await conexao.execute('SELECT versao FROM luptok_migracao_catalogo WHERE versao = ?', [versao]);
  if (feito.length) return;
  const [usuarios] = await conexao.execute('SELECT id_usuario FROM usuario WHERE ativo = 1 ORDER BY id_usuario LIMIT 1');
  if (!usuarios.length) { console.warn('Catálogo inicial: nenhum usuário ativo para registrar autoria.'); return; }
  const normalizar = t => t.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase().trim();
  await conexao.beginTransaction();
  try {
    for (const [titulo, tipo, aliases, generos, tags, descricao] of catalogoInicialBusca) {
      const nomes = [...new Set([titulo, ...aliases].map(normalizar))];
      const tipos = tipo === 'Dorama' ? ['Dorama', 'Série'] : tipo === 'Anime' ? ['Anime', 'Série'] : [tipo];
      const [existentes] = await conexao.execute(
        `SELECT id_obra FROM obra WHERE tipo IN (${tipos.map(() => '?').join(',')}) AND titulo_normalizado IN (${nomes.map(() => '?').join(',')})`,
        [...tipos, ...nomes]);
      let ids = existentes.map(o => o.id_obra);
      if (!ids.length) {
        await conexao.execute(`INSERT INTO obra (titulo, titulo_normalizado, tipo, criado_por) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE id_obra = LAST_INSERT_ID(id_obra)`, [titulo, normalizar(titulo), tipo, usuarios[0].id_usuario]);
        const [[obra]] = await conexao.execute('SELECT id_obra FROM obra WHERE titulo_normalizado = ? AND tipo = ?', [normalizar(titulo), tipo]);
        ids = [obra.id_obra];
      }
      for (const id of ids) await adicionarMetadadosObra(conexao, id, descricao, generos, [...new Set([titulo, tipo, ...aliases, ...tags])]);
    }
    await conexao.execute('INSERT INTO luptok_migracao_catalogo (versao) VALUES (?)', [versao]);
    await conexao.commit();
    console.log('Catálogo inicial de busca preparado:', catalogoInicialBusca.length, 'obras.');
  } catch (error) {
    await conexao.rollback();
    throw error;
  }
}

async function iniciarServidor() {
  try {
    const conexao = await db.getConnection();

    console.log('MySQL conectado com sucesso!');
    const tipoIdUsuario = await tipoChaveEstrangeira('usuario', 'id_usuario');
    await db.execute(`CREATE TABLE IF NOT EXISTS luptok_seguidor (
      seguidor_id ${tipoIdUsuario} NOT NULL,
      seguido_id ${tipoIdUsuario} NOT NULL,
      PRIMARY KEY (seguidor_id, seguido_id),
      INDEX idx_luptok_seguido (seguido_id),
      FOREIGN KEY (seguidor_id) REFERENCES usuario(id_usuario) ON DELETE CASCADE,
      FOREIGN KEY (seguido_id) REFERENCES usuario(id_usuario) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
    await db.execute(`CREATE TABLE IF NOT EXISTS comunidade (
      id_comunidade BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      nome VARCHAR(60) NOT NULL, descricao VARCHAR(300) NOT NULL DEFAULT '',
      criador_id ${tipoIdUsuario} NOT NULL, criada_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (criador_id) REFERENCES usuario(id_usuario) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
    const [fotoComunidade] = await db.execute(
      "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'comunidade' AND COLUMN_NAME = 'foto_url'"
    );
    if (!fotoComunidade.length) await db.execute('ALTER TABLE comunidade ADD COLUMN foto_url VARCHAR(500) NULL');
    await db.execute(`CREATE TABLE IF NOT EXISTS comunidade_membro (
      id_comunidade BIGINT UNSIGNED NOT NULL, id_usuario ${tipoIdUsuario} NOT NULL,
      PRIMARY KEY(id_comunidade,id_usuario),
      FOREIGN KEY (id_comunidade) REFERENCES comunidade(id_comunidade) ON DELETE CASCADE,
      FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
    await db.execute(`CREATE TABLE IF NOT EXISTS comunidade_mensagem (
      id_mensagem BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
      id_comunidade BIGINT UNSIGNED NOT NULL, id_usuario ${tipoIdUsuario} NOT NULL,
      texto VARCHAR(2000) NOT NULL, criada_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_comunidade_msg(id_comunidade,criada_em),
      FOREIGN KEY (id_comunidade) REFERENCES comunidade(id_comunidade) ON DELETE CASCADE,
      FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
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
    await db.execute(`CREATE TABLE IF NOT EXISTS luptok_video_salvo (
      id_usuario BIGINT UNSIGNED NOT NULL,
      id_video BIGINT UNSIGNED NOT NULL,
      criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id_usuario, id_video)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
    await db.execute(
      `CREATE TABLE IF NOT EXISTS video_post_curtida (
         id_usuario BIGINT UNSIGNED NOT NULL,
         id_video BIGINT UNSIGNED NOT NULL,
         criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
         PRIMARY KEY (id_usuario, id_video),
         INDEX idx_video_post_curtida_video (id_video)
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

    const tipoIdVideo = await tipoChaveEstrangeira('video_post', 'id_video');
    await db.execute(`CREATE TABLE IF NOT EXISTS video_avaliacao (
      id_avaliacao BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
     id_video ${tipoIdVideo} NOT NULL,
     id_usuario ${tipoIdUsuario} NOT NULL,
      nota TINYINT UNSIGNED NOT NULL,
      texto VARCHAR(2000) NOT NULL,
      criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_avaliacao_video (id_video, criado_em),
      INDEX idx_avaliacao_usuario (id_usuario),
      CONSTRAINT fk_avaliacao_video FOREIGN KEY (id_video) REFERENCES video_post(id_video) ON DELETE CASCADE,
      CONSTRAINT fk_avaliacao_usuario FOREIGN KEY (id_usuario) REFERENCES usuario(id_usuario) ON DELETE CASCADE,
      CONSTRAINT chk_video_avaliacao_nota CHECK (nota BETWEEN 1 AND 5)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`);
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

    // Colunas opcionais para personalização do perfil (migração aditiva).
    for (const [coluna, definicao] of [
      ['capa_url', 'VARCHAR(500) NULL'],
      ['bio', "VARCHAR(160) NOT NULL DEFAULT ''"],
      ['atividade', "VARCHAR(20) NOT NULL DEFAULT 'Assistindo'"],
      ['obra_atual', "VARCHAR(150) NOT NULL DEFAULT ''"],
    ]) {
      const [colunas] = await db.execute(
        `SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usuario' AND COLUMN_NAME = ?`,
        [coluna],
      );
      if (colunas.length === 0) await db.query(`ALTER TABLE usuario ADD COLUMN ${coluna} ${definicao}`);
    }
    try { await prepararCatalogoBusca(conexao); }
    catch (error) { console.error('Não foi possível preparar o catálogo inicial:', error.message); }
    conexao.release();

    app.use((req, res) => {
      console.error('Rota não encontrada:', req.method, req.originalUrl);
      return res.status(404).json({
        erro: `Rota ${req.method} ${req.path} não encontrada.`,
      });
    });

    const porta = Number(process.env.PORT) || 3000;

    app.listen(porta, '0.0.0.0', () => {
      console.log(`API do LupTok rodando na porta ${porta}`);
    });
  } catch (error) {
    console.error('Falha ao inicializar o backend ou preparar o banco de dados.');
    console.error(error);
    process.exit(1);
  }
}

iniciarServidor();
