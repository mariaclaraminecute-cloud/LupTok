import 'dart:async';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'app_preferences.dart';
import 'chat_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});
  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}
class _GroupsScreenState extends State<GroupsScreen> {
  int _section = 0, _revision = 0;
  String _query = '';
  bool _busy = false;
  Future<List<Map<String,dynamic>>>? _communities;
  Future<void> _reload() async {
    final next = ApiService.listarComunidades();
    if (!mounted) return;
    setState(() { _communities = next; });
    try { await next; } catch (_) {}
  }
  void _error(Object e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); }
  Future<void> _newChat() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _NewConversationScreen()));
    if (mounted) setState(() { _revision++; });
  }
  Future<void> _create() async {
    if (_busy) return;
    setState(() { _busy = true; });
    try {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(builder: (_) => const _CreateCommunityScreen()),
      );
      if (result == true && mounted) await _reload();
    } catch (e) { _error(e); }
    finally { if (mounted) setState(() { _busy = false; }); }
  }
  bool _member(Map<String,dynamic> c) => c['participando'] == true || '${c['participando']}' == '1';
  Future<void> _open(Map<String,dynamic> c) async {
    if (_busy || c['id'] == null) return;
    if (!_member(c)) {
      final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text('Entrar em ${c['nome']}?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx,false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx,true), child: const Text('Entrar'))]));
      if (yes != true || !mounted) return;
    }
    if (!mounted || _busy) return;
    setState(() { _busy = true; });
    try {
      if (!_member(c)) await ApiService.entrarComunidade(c['id']);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _CommunityChat(id: c['id'], name: '${c['nome']}', photo: ApiService.urlImagemPerfil(c['foto_url']), community: c)));
      await _reload();
    } catch(e) { _error(e); } finally { if(mounted) setState(() { _busy = false; }); }
  }
  @override
  Widget build(BuildContext context) {
    final primary = AppPalette.primaryText(context), accent = AppPalette.button(context);
    return Scaffold(backgroundColor: AppPalette.background(context), body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20,16,12,10), child: Row(children: [
        Expanded(child: Text('Conversas', style: TextStyle(color: primary,fontFamily:'IMFellFrenchCanon',fontSize:30))),
        IconButton(tooltip: _section == 0 ? 'Nova conversa' : 'Criar comunidade', onPressed: _section == 0 ? _newChat : (_busy ? null : _create), icon: Icon(_section == 0 ? Icons.edit_square : Icons.add_rounded,color:primary)),
      ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal:16), child: Row(children: [
        for (final i in [0,1]) ...[if(i == 1) const SizedBox(width:10), Expanded(child: InkWell(borderRadius:BorderRadius.circular(14),onTap:(){setState((){_section=i;}); if(i==1) _reload();},child: AnimatedContainer(duration:const Duration(milliseconds:180),padding:const EdgeInsets.symmetric(vertical:12),decoration:BoxDecoration(color:_section==i?accent.withValues(alpha:.20):Colors.transparent,borderRadius:BorderRadius.circular(14),border:Border.all(color:_section==i?accent:AppPalette.border(context).withValues(alpha:.25))),child:Text(i==0?'Mensagens':'Comunidades',textAlign:TextAlign.center,style:TextStyle(color:primary,fontWeight:_section==i?FontWeight.w700:FontWeight.w500)))))]
      ])),
      const SizedBox(height:8),
      Expanded(child: _section==0 ? ConversationsScreen(key:ValueKey(_revision),embedded:true) : _communityList()),
    ])));
  }
  Widget _communityList() => Column(children: [
    Padding(padding:const EdgeInsets.fromLTRB(16,8,16,8),child:TextField(onChanged:(v)=>setState((){_query=v.trim().toLowerCase();}),decoration:InputDecoration(hintText:'Buscar comunidades',prefixIcon:const Icon(Icons.search_rounded),filled:true,fillColor:AppPalette.raisedSurface(context),border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none)))),
    Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_busy?null:_create,icon:const Icon(Icons.add_rounded),label:const Text('Criar comunidade'),style:FilledButton.styleFrom(backgroundColor:AppPalette.button(context),foregroundColor:Colors.white)))),
    Expanded(child:FutureBuilder<List<Map<String,dynamic>>>(future:_communities,builder:(context,snapshot){
      if(snapshot.connectionState==ConnectionState.waiting) return const Center(child:CircularProgressIndicator());
      if(snapshot.hasError) return Center(child:TextButton(onPressed:_reload,child:const Text('Não foi possível carregar. Tentar novamente')));
      final items=(snapshot.data??[]).where((c)=> '${c['nome']} ${c['descricao']}'.toLowerCase().contains(_query)).toList();
      items.sort((a,b)=>(_member(b)?1:0).compareTo(_member(a)?1:0));
      return RefreshIndicator(onRefresh:_reload,child:ListView(physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.all(16),children:[
        if(items.isEmpty) const Padding(padding:EdgeInsets.all(24),child:Text('Nenhuma comunidade encontrada.',textAlign:TextAlign.center)),
        for(final c in items) Card(color:AppPalette.raisedSurface(context),elevation:0,child:ListTile(leading:_communityAvatar(context, ApiService.urlImagemPerfil(c['foto_url'])),title:Text('${c['nome']}'),subtitle:Text('${c['descricao']??''}\n${c['membros']??0} membros',maxLines:3,overflow:TextOverflow.ellipsis),isThreeLine:true,trailing:_member(c)?null:TextButton(onPressed:_busy?null:()=>_open(c),child:const Text('Entrar')),onTap:_busy?null:()=>_open(c))),
      ]));
    })),
  ]);
}
class _NewConversationScreen extends StatefulWidget {
  const _NewConversationScreen();
  @override
  State<_NewConversationScreen> createState()=>_NewConversationScreenState();
}
class _NewConversationScreenState extends State<_NewConversationScreen>{
  late final Future<List<Map<String,dynamic>>> _accounts=ApiService.listarContas();
  String _query=''; bool _opening=false;
  Future<void> _open(Map<String,dynamic> a) async {
    final id=int.tryParse('${a['id']}'); if(id==null||_opening)return;
    setState((){_opening=true;});
    try{final r=await ApiService.iniciarConversa(idDestinatario:id); final cid=int.tryParse('${r['id_conversa']}'); if(cid==null)throw Exception('Conversa inválida.'); if(!mounted)return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>ChatConversationScreen(conversaId:cid,recipientId:id,recipientName:'${a['nome']??'Usuário'}',recipientUsername:'@${a['nome_usuario']??''}',recipientPhoto:a['foto_url']?.toString())));
      if(mounted)Navigator.pop(context);
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted)setState((){_opening=false;});}
  }
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:AppPalette.background(context),appBar:AppBar(title:const Text('Nova conversa')),body:Column(children:[
    Padding(padding:const EdgeInsets.all(16),child:TextField(onChanged:(v)=>setState((){_query=v.trim().toLowerCase().replaceFirst('@','');}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search_rounded),hintText:'Pesquisar por nome ou @usuário'))),
    Expanded(child:FutureBuilder<List<Map<String,dynamic>>>(future:_accounts,builder:(context,s){if(s.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());if(s.hasError)return const Center(child:Text('Não foi possível carregar os usuários.'));final items=(s.data??[]).where((a)=>'${a['nome']} ${a['nome_usuario']}'.toLowerCase().contains(_query)).toList();if(items.isEmpty)return const Center(child:Text('Nenhum usuário encontrado.'));return ListView.builder(itemCount:items.length,itemBuilder:(context,i){final a=items[i];final photo=ApiService.urlImagemPerfil(a['foto_url']);return ListTile(enabled:!_opening,leading:CircleAvatar(foregroundImage:photo==null?null:NetworkImage(photo),child:const Icon(Icons.person_outline)),title:Text('${a['nome']}'),subtitle:Text('@${a['nome_usuario']}'),trailing:const Icon(Icons.chat_bubble_outline),onTap:()=>_open(a));});})),
  ]));
}
class _CommunityChat extends StatefulWidget {
  final Object id; final String name; final String? photo;
  final Map<String,dynamic> community;
  const _CommunityChat({required this.id,required this.name,this.photo,required this.community});
  @override State<_CommunityChat> createState()=>_CommunityChatState();
}
class _CommunityChatState extends State<_CommunityChat>{
  final _text=TextEditingController(); final _scroll=ScrollController();
  List<Map<String,dynamic>> _messages=[]; Timer? _timer; bool _loading=true,_fetching=false,_sending=false; String? _error;
  @override void initState(){super.initState();_load();_timer=Timer.periodic(const Duration(seconds:4),(_)=>_load());}
  @override void dispose(){_timer?.cancel();_text.dispose();_scroll.dispose();super.dispose();}
  Future<void> _load() async {if(_fetching)return;_fetching=true;try{final list=await ApiService.listarMensagensComunidade(widget.id);if(!mounted)return;final changed=_messages.length!=list.length;setState((){_messages=list;_loading=false;_error=null;});if(changed)WidgetsBinding.instance.addPostFrameCallback((_){if(mounted&&_scroll.hasClients)_scroll.jumpTo(_scroll.position.maxScrollExtent);});}catch(e){if(mounted)setState((){_loading=false;_error='$e';});}finally{_fetching=false;}}
  Future<void> _send() async {final value=_text.text.trim();if(value.isEmpty||_sending)return;setState((){_sending=true;});try{await ApiService.enviarMensagemComunidade(widget.id,value);if(!mounted)return;if(_text.text.trim()==value)_text.clear();await _load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted)setState((){_sending=false;});}}
  late Map<String,dynamic> _community = Map<String,dynamic>.from(widget.community);
  bool _managing = false;
  bool get _owner => _community['proprietario'] == true || '${_community['proprietario']}' == '1';
  Future<void> _manage(String action) async {
    if (_managing) return;
    setState(() { _managing = true; });
    try {
      if (action == 'edit') {
        final result = await Navigator.of(context).push<Map<String,dynamic>>(MaterialPageRoute(builder: (_) => _CreateCommunityScreen(community: _community)));
        if (result != null && mounted) setState(() { _community = {..._community, ...result}; });
      } else {
        final yes = await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Excluir comunidade?'),content:const Text('A comunidade e todas as mensagens serão apagadas para todos os integrantes. Esta ação não pode ser desfeita.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Excluir',style:TextStyle(color:Colors.redAccent)))]));
        if (yes != true || !mounted) return;
        await ApiService.excluirComunidade(widget.id);
        if(mounted) Navigator.of(context).pop();
      }
    } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e'))); }
    finally { if(mounted) setState(() { _managing = false; }); }
  }
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:AppPalette.background(context),appBar:AppBar(title:Row(children:[_communityAvatar(context, ApiService.urlImagemPerfil(_community['foto_url'])), const SizedBox(width:10), Expanded(child:Text('${_community['nome']}', overflow:TextOverflow.ellipsis))]),actions:[if(_owner) PopupMenuButton<String>(enabled:!_managing,onSelected:_manage,itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:ListTile(leading:Icon(Icons.edit_outlined),title:Text('Editar comunidade'))),PopupMenuItem(value:'delete',child:ListTile(leading:Icon(Icons.delete_outline,color:Colors.redAccent),title:Text('Excluir comunidade',style:TextStyle(color:Colors.redAccent))))])]),body:SafeArea(child:Column(children:[
    Expanded(child:_loading?const Center(child:CircularProgressIndicator()):_error!=null?Center(child:TextButton(onPressed:_load,child:Text('$_error\nTentar novamente'))):_messages.isEmpty?const Center(child:Text('Ainda não há mensagens.')):ListView.builder(controller:_scroll,padding:const EdgeInsets.all(16),itemCount:_messages.length,itemBuilder:(context,i){final m=_messages[i];final own=m['enviado_por_mim']==true||'${m['enviado_por_mim']}'=='1';return Align(alignment:own?Alignment.centerRight:Alignment.centerLeft,child:Container(constraints:BoxConstraints(maxWidth:MediaQuery.sizeOf(context).width*.76),margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:own?AppPalette.button(context):AppPalette.raisedSurface(context),borderRadius:BorderRadius.circular(16)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[if(!own)Text('${m['nome']??'Usuário'}',style:TextStyle(fontWeight:FontWeight.bold,color:AppPalette.button(context))),Text('${m['texto']??''}',style:TextStyle(color:own?Colors.white:AppPalette.primaryText(context)))])));})),
    Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:TextField(controller:_text,maxLength:2000,maxLines:3,minLines:1,decoration:const InputDecoration(hintText:'Escreva uma mensagem...',counterText:''))),IconButton(onPressed:_sending?null:_send,icon:Icon(Icons.send_rounded,color:AppPalette.button(context)))])),
  ])));
}

Widget _communityAvatar(BuildContext context, String? photo) => CircleAvatar(backgroundColor: AppPalette.button(context), foregroundImage: photo == null ? null : NetworkImage(photo), child: const Icon(Icons.groups_rounded, color: Colors.white));

class _CreateCommunityScreen extends StatefulWidget {
  final Map<String,dynamic>? community;
  const _CreateCommunityScreen({this.community});
  @override
  State<_CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}
class _CreateCommunityScreenState extends State<_CreateCommunityScreen> {
  late final _name = TextEditingController(text: widget.community?['nome']?.toString() ?? '');
  late final _description = TextEditingController(text: widget.community?['descricao']?.toString() ?? '');
  bool _removePhoto = false;
  bool get _editing => widget.community != null;
  String? get _existingPhoto => _removePhoto ? null : ApiService.urlImagemPerfil(widget.community?['foto_url']);
  XFile? _photo;
  Uint8List? _preview;
  bool _picking = false, _saving = false;
  String? _error;
  @override
  void dispose() { _name.dispose(); _description.dispose(); super.dispose(); }
  Future<void> _pick() async {
    setState(() { _picking = true; _error = null; });
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000, imageQuality: 85);
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024 || !RegExp(r'\.(jpg|jpeg|png|webp)$', caseSensitive: false).hasMatch(file.name)) {
        setState(() { _error = 'Escolha JPG, PNG ou WebP de até 5 MB.'; }); return;
      }
      setState(() { _photo = file; _preview = bytes; _removePhoto = false; });
    } catch (e) { if (mounted) setState(() { _error = 'Não foi possível abrir a imagem.'; }); }
    finally { if (mounted) setState(() { _picking = false; }); }
  }
  Future<void> _save() async {
    if (_saving || _picking) return;
    final name = _name.text.trim(), description = _description.text.trim();
    if (name.length < 3) { setState(() { _error = 'Informe pelo menos 3 caracteres no nome.'; }); return; }
    setState(() { _saving = true; _error = null; });
    try {
      if (_editing) {
        final result = await ApiService.editarComunidade(widget.community!['id'], name, description, foto: _photo, removerFoto: _removePhoto);
        if (mounted) Navigator.of(context).pop(Map<String,dynamic>.from(result['comunidade'] as Map));
      } else {
        await ApiService.criarComunidade(name, description, foto: _photo);
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) { if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); }); }
    finally { if (mounted) setState(() { _saving = false; }); }
  }
  @override
  Widget build(BuildContext context) {
    final accent = AppPalette.button(context);
    final busy = _saving || _picking;
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      appBar: AppBar(title: Text(_editing ? 'Editar comunidade' : 'Criar comunidade'), backgroundColor: AppPalette.background(context), foregroundColor: AppPalette.primaryText(context)),
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: ListView(padding: const EdgeInsets.all(24), children: [
        Center(child: InkWell(onTap: busy ? null : _pick, borderRadius: BorderRadius.circular(55), child: ClipOval(child: SizedBox(width: 110, height: 110, child: _preview == null ? (_existingPhoto != null ? Image.network(_existingPhoto!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)) : ColoredBox(color: accent, child: const Icon(Icons.add_a_photo_outlined, color: Colors.white, size: 38))) : Image.memory(_preview!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)))))),
        TextButton(onPressed: busy ? null : _pick, child: Text(_preview == null && _existingPhoto == null ? 'Adicionar foto (opcional)' : 'Alterar foto')),
        if (_preview != null || _existingPhoto != null) TextButton(onPressed: busy ? null : () => setState(() { _photo = null; _preview = null; _removePhoto = true; }), child: const Text('Remover foto')),
        const SizedBox(height: 20),
        TextField(controller: _name, enabled: !busy, maxLength: 60, decoration: const InputDecoration(labelText: 'Nome da comunidade', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _description, enabled: !busy, maxLength: 300, maxLines: 4, decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder())),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
        const SizedBox(height: 16),
        FilledButton(onPressed: busy ? null : _save, style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, minimumSize: const Size(0, 50)), child: Text(_saving ? 'Salvando...' : _editing ? 'Salvar alterações' : 'Criar comunidade')),
      ])))),
    );
  }
}
