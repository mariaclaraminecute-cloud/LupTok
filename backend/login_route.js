// LOGIN COM JWT — aceita e-mail ou nome de usuário
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
    const senhaCorreta = await bcrypt.compare(senha, usuario.senha_hash);

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
      { expiresIn: '2h' }
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
