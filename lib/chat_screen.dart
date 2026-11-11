import 'dart:async';



import 'package:flutter/material.dart';



import 'api_service.dart';

import 'app_preferences.dart';



/// Tela com a lista de conversas ativas do usuário.


Widget _chatAvatar(String? url, String inicial, double radius) {
  final resolved = ApiService.urlImagemPerfil(url);
  return CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFB8787C),
    foregroundImage: resolved == null ? null : NetworkImage(resolved),
    child: Text(inicial, style: TextStyle(color: Colors.white, fontSize: radius * 0.75)),
  );
}

class ConversationsScreen extends StatefulWidget {

  const ConversationsScreen({super.key, this.embedded = false});

  final bool embedded;



  @override

  State<ConversationsScreen> createState() => _ConversationsScreenState();

}



class _ConversationsScreenState extends State<ConversationsScreen> {

  late Future<List<Map<String, dynamic>>> _conversasFuture;



  @override

  void initState() {

    super.initState();

    _recarregar();

  }



  void _recarregar() {

    setState(() {

      _conversasFuture = ApiService.listarConversas();

    });

  }



  void _abrirConversa(Map<String, dynamic> c) async {

    final idConversa = c['id_conversa'] as int;

    final nome = (c['nome'] as String?) ?? 'Conversa';

    final usuario = c['nome_usuario'] as String?;

    final foto = c['foto_url'] as String?;

    final outroId = c['outro_id'] as int? ?? 0;



    await Navigator.of(context).push(

      MaterialPageRoute<void>(

        builder: (_) => ChatConversationScreen(

          conversaId: idConversa,

          recipientName: nome,

          recipientUsername: usuario != null ? '@$usuario' : '',

          recipientPhoto: foto,

          recipientId: outroId,

        ),

      ),

    );

    _recarregar();

  }



  String _formatarData(dynamic dataRaw) {

    if (dataRaw == null) return '';

    try {

      final dt = DateTime.parse(dataRaw.toString()).toLocal();

      final now = DateTime.now();

      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {

        final hora = dt.hour.toString().padLeft(2, '0');

        final min = dt.minute.toString().padLeft(2, '0');

        return '$hora:$min';

      }

      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';

    } catch (_) {

      return '';

    }

  }



  @override

  Widget build(BuildContext context) {

    final dark = AppPalette.isDark(context);

    final bg = AppPalette.background(context);

    final primary = AppPalette.primaryText(context);



    return Scaffold(

      backgroundColor: bg,

      appBar: widget.embedded ? null : AppBar(

        backgroundColor: bg,

        foregroundColor: primary,

        elevation: 0,

        title: Text(

          'Mensagens',

          style: TextStyle(

            color: primary,

            fontFamily: 'IMFellFrenchCanon',

            fontSize: 22,

            fontWeight: FontWeight.w600,

          ),

        ),

        actions: [

          IconButton(

            tooltip: 'Atualizar',

            icon: const Icon(Icons.refresh_rounded),

            onPressed: _recarregar,

          ),

        ],

      ),

      body: FutureBuilder<List<Map<String, dynamic>>>(

        future: _conversasFuture,

        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {

            return const Center(child: CircularProgressIndicator());

          }

          if (snapshot.hasError) {

            return Center(

              child: Padding(

                padding: const EdgeInsets.all(32),

                child: Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    Icon(

                      Icons.error_outline_rounded,

                      size: 46,

                      color: AppPalette.mutedText(context),

                    ),

                    const SizedBox(height: 14),

                    Text(

                      'Não foi possível carregar as conversas.\n${snapshot.error.toString().replaceFirst('Exception: ', '')}',

                      textAlign: TextAlign.center,

                      style: TextStyle(color: AppPalette.mutedText(context)),

                    ),

                    const SizedBox(height: 16),

                    FilledButton(

                      onPressed: _recarregar,

                      child: const Text('Tentar novamente'),

                    ),

                  ],

                ),

              ),

            );

          }



          final conversas = snapshot.data ?? [];

          if (conversas.isEmpty) {

            return Center(

              child: Padding(

                padding: const EdgeInsets.symmetric(horizontal: 40),

                child: Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    Container(

                      width: 76,

                      height: 76,

                      decoration: BoxDecoration(

                        shape: BoxShape.circle,

                        color: AppPalette.button(context).withValues(alpha: 0.12),

                      ),

                      child: Icon(

                        Icons.chat_bubble_outline_rounded,

                        size: 38,

                        color: AppPalette.button(context),

                      ),

                    ),

                    const SizedBox(height: 18),

                    Text(

                      'Nenhuma conversa ainda',

                      style: TextStyle(

                        color: primary,

                        fontSize: 18,

                        fontWeight: FontWeight.w700,

                        fontFamily: 'IMFellFrenchCanon',

                      ),

                    ),

                    const SizedBox(height: 8),

                    Text(

                      'Toque no botão de nova conversa para enviar sua primeira mensagem.',

                      textAlign: TextAlign.center,

                      style: TextStyle(

                        color: AppPalette.mutedText(context),

                        fontSize: 14,

                        height: 1.4,

                      ),

                    ),

                  ],

                ),

              ),

            );

          }



          return RefreshIndicator(

            onRefresh: () async => _recarregar(),

            child: ListView.separated(

              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

              itemCount: conversas.length,

              separatorBuilder: (_, _) => Divider(

                height: 1,

                color: AppPalette.border(context).withValues(alpha: 0.15),

              ),

              itemBuilder: (context, index) {

                final c = conversas[index];

                final nome = (c['nome'] as String?) ?? 'Usuário';

                final usuario = c['nome_usuario'] as String?;

                final ultimaMsg = (c['ultima_mensagem'] as String?) ?? '';

                final dataFmt = _formatarData(c['ultima_data']);

                final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';



                return Material(

                  color: Colors.transparent,

                  borderRadius: BorderRadius.circular(14),

                  child: InkWell(

                    borderRadius: BorderRadius.circular(14),

                    onTap: () => _abrirConversa(c),

                    child: Padding(

                      padding: const EdgeInsets.symmetric(

                        horizontal: 10,

                        vertical: 12,

                      ),

                      child: Row(

                        children: [

                          _chatAvatar(c['foto_url'] as String?, inicial, 25),
                            const SizedBox(width: 14),

                          Expanded(

                            child: Column(

                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [

                                Row(

                                  mainAxisAlignment:

                                      MainAxisAlignment.spaceBetween,

                                  children: [

                                    Flexible(

                                      child: Text(

                                        nome,

                                        maxLines: 1,

                                        overflow: TextOverflow.ellipsis,

                                        style: TextStyle(

                                          color: primary,

                                          fontWeight: FontWeight.w700,

                                          fontSize: 15,

                                        ),

                                      ),

                                    ),

                                    const SizedBox(width: 8),

                                    Text(

                                      dataFmt,

                                      style: TextStyle(

                                        color: AppPalette.mutedText(context),

                                        fontSize: 11,

                                      ),

                                    ),

                                  ],

                                ),

                                if (usuario != null && usuario.isNotEmpty) ...[

                                  const SizedBox(height: 2),

                                  Text(

                                    '@$usuario',

                                    style: TextStyle(

                                      color: AppPalette.mutedText(context),

                                      fontSize: 12,

                                    ),

                                  ),

                                ],

                                const SizedBox(height: 4),

                                Text(

                                  ultimaMsg.isEmpty

                                      ? 'Toque para conversar'

                                      : ultimaMsg,

                                  maxLines: 1,

                                  overflow: TextOverflow.ellipsis,

                                  style: TextStyle(

                                    color: ultimaMsg.isEmpty

                                        ? AppPalette.mutedText(context)

                                              .withValues(alpha: 0.6)

                                        : AppPalette.text(context)

                                              .withValues(alpha: 0.85),

                                    fontSize: 13,

                                  ),

                                ),

                              ],

                            ),

                          ),

                        ],

                      ),

                    ),

                  ),

                );

              },

            ),

          );

        },

      ),

    );

  }

}



/// Tela de uma conversa individual entre dois usuários.

class ChatConversationScreen extends StatefulWidget {

  final int conversaId;

  final String recipientName;

  final String recipientUsername;

  final String? recipientPhoto;

  final int recipientId;



  const ChatConversationScreen({

    super.key,

    required this.conversaId,

    required this.recipientName,

    required this.recipientUsername,

    this.recipientPhoto,

    required this.recipientId,

  });



  @override

  State<ChatConversationScreen> createState() => _ChatConversationScreenState();

}



class _ChatConversationScreenState extends State<ChatConversationScreen> {

  final TextEditingController _textCtrl = TextEditingController();

  final ScrollController _scrollCtrl = ScrollController();

  final List<Map<String, dynamic>> _mensagens = [];



  bool _carregandoInicial = true;

  bool _enviando = false;

  String? _erro;

  Timer? _pollingTimer;



  @override

  void initState() {

    super.initState();

    _carregarMensagens(primeiraVez: true);

    // Polling a cada 2.5s para receber novas mensagens

    _pollingTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {

      _carregarMensagens(primeiraVez: false);

    });

  }



  @override

  void dispose() {

    _pollingTimer?.cancel();

    _textCtrl.dispose();

    _scrollCtrl.dispose();

    super.dispose();

  }



  Future<void> _carregarMensagens({bool primeiraVez = false}) async {

    try {

      final msgs = await ApiService.listarMensagens(

        idConversa: widget.conversaId,

      );

      if (!mounted) return;

      final mudou = msgs.length != _mensagens.length;

      setState(() {

        _mensagens

          ..clear()

          ..addAll(msgs);

        _carregandoInicial = false;

        _erro = null;

      });

      if (primeiraVez || mudou) {

        _scrollToBottom();

      }

    } catch (e) {

      if (!mounted) return;

      if (primeiraVez) {

        setState(() {

          _erro = e.toString().replaceFirst('Exception: ', '');

          _carregandoInicial = false;

        });

      }

    }

  }



  void _scrollToBottom() {

    WidgetsBinding.instance.addPostFrameCallback((_) {

      if (_scrollCtrl.hasClients) {

        _scrollCtrl.animateTo(

          _scrollCtrl.position.maxScrollExtent + 60,

          duration: const Duration(milliseconds: 250),

          curve: Curves.easeOut,

        );

      }

    });

  }



  Future<void> _enviar() async {

    final texto = _textCtrl.text.trim();

    if (texto.isEmpty || _enviando) return;



    _textCtrl.clear();

    setState(() => _enviando = true);



    try {

      final res = await ApiService.enviarMensagem(

        idConversa: widget.conversaId,

        texto: texto,

      );

      if (!mounted) return;

      final msg = res['mensagem'];

      if (msg is Map<String, dynamic>) {

        setState(() {

          _mensagens.add(msg);

        });

        _scrollToBottom();

      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(

          content: Text(

            'Erro ao enviar mensagem: ${e.toString().replaceFirst('Exception: ', '')}',

          ),

        ),

      );

    } finally {

      if (mounted) setState(() => _enviando = false);

    }

  }



  String _formatarHora(dynamic dataRaw) {

    if (dataRaw == null) return '';

    try {

      final dt = DateTime.parse(dataRaw.toString()).toLocal();

      final hora = dt.hour.toString().padLeft(2, '0');

      final min = dt.minute.toString().padLeft(2, '0');

      return '$hora:$min';

    } catch (_) {

      return '';

    }

  }



  @override

  Widget build(BuildContext context) {

    final bg = AppPalette.background(context);

    final primary = AppPalette.primaryText(context);

    final inicial = widget.recipientName.isNotEmpty

        ? widget.recipientName[0].toUpperCase()

        : '?';



    return Scaffold(

      backgroundColor: bg,

      appBar: AppBar(

        backgroundColor: bg,

        foregroundColor: primary,

        elevation: 0,

        titleSpacing: 0,

        title: Row(

          children: [

            _chatAvatar(widget.recipientPhoto, inicial, 19),
            const SizedBox(width: 10),

            Expanded(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    widget.recipientName,

                    maxLines: 1,

                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(

                      color: primary,

                      fontSize: 16,

                      fontWeight: FontWeight.w700,

                    ),

                  ),

                  if (widget.recipientUsername.isNotEmpty)

                    Text(

                      widget.recipientUsername,

                      style: TextStyle(

                        color: AppPalette.mutedText(context),

                        fontSize: 12,

                      ),

                    ),

                ],

              ),

            ),

          ],

        ),

      ),

      body: SafeArea(

        child: Column(

          children: [

            Expanded(

              child: _carregandoInicial

                  ? const Center(child: CircularProgressIndicator())

                  : _erro != null

                  ? Center(

                      child: Padding(

                        padding: const EdgeInsets.all(24),

                        child: Text(

                          _erro!,

                          textAlign: TextAlign.center,

                          style: TextStyle(color: AppPalette.mutedText(context)),

                        ),

                      ),

                    )

                  : _mensagens.isEmpty

                  ? Center(

                      child: Padding(

                        padding: const EdgeInsets.all(32),

                        child: Column(

                          mainAxisSize: MainAxisSize.min,

                          children: [

                            Icon(

                              Icons.chat_bubble_outline_rounded,

                              size: 44,

                              color: AppPalette.mutedText(context),

                            ),

                            const SizedBox(height: 12),

                            Text(

                              'Inicie a conversa!',

                              style: TextStyle(

                                color: primary,

                                fontSize: 16,

                                fontWeight: FontWeight.w600,

                              ),

                            ),

                            const SizedBox(height: 4),

                            Text(

                              'Diga um oi para ${widget.recipientName}.',

                              style: TextStyle(

                                color: AppPalette.mutedText(context),

                                fontSize: 13,

                              ),

                            ),

                          ],

                        ),

                      ),

                    )

                  : ListView.builder(

                      controller: _scrollCtrl,

                      padding: const EdgeInsets.symmetric(

                        horizontal: 14,

                        vertical: 16,

                      ),

                      itemCount: _mensagens.length,

                      itemBuilder: (context, index) {

                        final msg = _mensagens[index];

                        final porMim = msg['enviado_por_mim'] == true;

                        final texto = (msg['texto'] as String?) ?? '';

                        final hora = _formatarHora(msg['data_envio']);



                        return Align(

                          alignment: porMim

                              ? Alignment.centerRight

                              : Alignment.centerLeft,

                          child: Container(

                            constraints: BoxConstraints(

                              maxWidth: MediaQuery.of(context).size.width * 0.74,

                            ),

                            margin: const EdgeInsets.only(bottom: 8),

                            padding: const EdgeInsets.symmetric(

                              horizontal: 14,

                              vertical: 10,

                            ),

                            decoration: BoxDecoration(

                              color: porMim

                                  ? AppPalette.button(context)

                                  : AppPalette.raisedSurface(context),

                              borderRadius: BorderRadius.only(

                                topLeft: const Radius.circular(16),

                                topRight: const Radius.circular(16),

                                bottomLeft: Radius.circular(porMim ? 16 : 4),

                                bottomRight: Radius.circular(porMim ? 4 : 16),

                              ),

                              boxShadow: [

                                BoxShadow(

                                  color: Colors.black.withValues(alpha: 0.06),

                                  blurRadius: 6,

                                  offset: const Offset(0, 2),

                                ),

                              ],

                            ),

                            child: Column(

                              crossAxisAlignment: porMim

                                  ? CrossAxisAlignment.end

                                  : CrossAxisAlignment.start,

                              mainAxisSize: MainAxisSize.min,

                              children: [

                                Text(

                                  texto,

                                  style: TextStyle(

                                    color: porMim

                                        ? Colors.white

                                        : AppPalette.text(context),

                                    fontSize: 14.5,

                                    height: 1.35,

                                  ),

                                ),

                                const SizedBox(height: 3),

                                Text(

                                  hora,

                                  style: TextStyle(

                                    color: porMim

                                        ? Colors.white70

                                        : AppPalette.mutedText(context),

                                    fontSize: 10,

                                  ),

                                ),

                              ],

                            ),

                          ),

                        );

                      },

                    ),

            ),

            _buildInputBar(),

          ],

        ),

      ),

    );

  }



  Widget _buildInputBar() {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),

      decoration: BoxDecoration(

        color: AppPalette.background(context),

        border: Border(

          top: BorderSide(

            color: AppPalette.border(context).withValues(alpha: 0.2),

          ),

        ),

      ),

      child: Row(

        children: [

          Expanded(

            child: Container(

              decoration: BoxDecoration(

                color: AppPalette.raisedSurface(context),

                borderRadius: BorderRadius.circular(24),

                border: Border.all(

                  color: AppPalette.border(context).withValues(alpha: 0.25),

                ),

              ),

              child: TextField(

                controller: _textCtrl,

                textCapitalization: TextCapitalization.sentences,

                minLines: 1,

                maxLines: 4,

                style: TextStyle(

                  color: AppPalette.text(context),

                  fontSize: 14.5,

                ),

                decoration: InputDecoration(

                  hintText: 'Escreva uma mensagem...',

                  hintStyle: TextStyle(

                    color: AppPalette.mutedText(context).withValues(alpha: 0.65),

                    fontSize: 14,

                  ),

                  border: InputBorder.none,

                  contentPadding: const EdgeInsets.symmetric(

                    horizontal: 16,

                    vertical: 10,

                  ),

                ),

                onSubmitted: (_) => _enviar(),

              ),

            ),

          ),

          const SizedBox(width: 8),

          Material(

            color: AppPalette.button(context),

            shape: const CircleBorder(),

            child: InkWell(

              customBorder: const CircleBorder(),

              onTap: _enviando ? null : _enviar,

              child: Padding(

                padding: const EdgeInsets.all(11),

                child: _enviando

                    ? const SizedBox(

                        width: 20,

                        height: 20,

                        child: CircularProgressIndicator(

                          strokeWidth: 2,

                          color: Colors.white,

                        ),

                      )

                    : const Icon(

                        Icons.send_rounded,

                        color: Colors.white,

                        size: 20,

                      ),

              ),

            ),

          ),

        ],

      ),

    );

  }

}
