import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'app_preferences.dart';

class VideoRecorderScreen extends StatefulWidget {
  const VideoRecorderScreen({super.key});

  @override
  State<VideoRecorderScreen> createState() => _VideoRecorderScreenState();
}

class _VideoRecorderScreenState extends State<VideoRecorderScreen> {
  CameraController? _cameraController;
  XFile? _recordedVideo;
  String? _error;
  bool _isRecording = false;
  bool _loading = true;
  bool _savingVideo = false;
  bool _gallerySaved = false;
  String? _saveError;
  bool _recordAudio = true;
  bool _autoSave = true;
  bool _hdRecording = true;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  int _maxDuration = 60;
  int _countdownDuration = 0;
  int _countdown = 0;
  int _elapsedSeconds = 0;
  bool _startingRecording = false;
  bool _flashOn = false;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _prepareCamera();
  }

  Future<void> _prepareCamera() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    _recordAudio = preferences.getBool('settings_record_audio') ?? true;
    _autoSave = preferences.getBool('settings_auto_save_video') ?? true;
    _hdRecording = preferences.getBool('settings_hd_recording') ?? true;
    await _initializeCamera();
  }

  Future<void> _initializeCamera({int? cameraIndex}) async {
    final supported =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!supported) {
      setState(() {
        _loading = false;
        _error = 'A gravação está disponível no Android, iOS e web.';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('Nenhuma câmera foi encontrada.');
      final frontCameraIndex = cameras.indexWhere(
        (item) => item.lensDirection == CameraLensDirection.front,
      );
      final selectedIndex =
          cameraIndex ?? (frontCameraIndex < 0 ? 0 : frontCameraIndex);
      final camera = cameras[selectedIndex.clamp(0, cameras.length - 1)];
      final controller = CameraController(
        camera,
        _hdRecording ? ResolutionPreset.high : ResolutionPreset.medium,
        enableAudio: _recordAudio,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameras = cameras;
        _cameraIndex = selectedIndex;
        _cameraController = controller;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível abrir a câmera: $error';
      });
    }
  }

  Future<void> _alternarGravacao() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      if (_isRecording) {
        _recordingTimer?.cancel();
        final video = await controller.stopVideoRecording();
        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _startingRecording = false;
          _recordedVideo = video;
          _gallerySaved = false;
          _saveError = null;
        });
        if (_autoSave) unawaited(_salvarNaGaleria(video));
        if (!mounted) return;
        final publicado = await Navigator.of(context).push<PublishedVideo>(
          MaterialPageRoute<PublishedVideo>(
            builder: (_) => VideoPreviewScreen(video: video),
          ),
        );
        if (!mounted) return;
        if (publicado == null) {
          setState(() {
            _recordedVideo = null;
            _gallerySaved = false;
            _saveError = null;
          });
        } else {
          Navigator.of(context).pop(publicado);
        }
      } else {
        setState(() => _startingRecording = true);
        for (var remaining = _countdownDuration; remaining > 0; remaining--) {
          if (!mounted) return;
          setState(() => _countdown = remaining);
          await Future.delayed(const Duration(seconds: 1));
        }
        if (!mounted) return;
        setState(() {
          _countdown = 0;
          _elapsedSeconds = 0;
        });
        await controller.startVideoRecording();
        if (mounted) {
          setState(() {
            _isRecording = true;
            _startingRecording = false;
            _recordedVideo = null;
            _gallerySaved = false;
            _saveError = null;
          });
        }
        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          if (_elapsedSeconds + 1 >= _maxDuration) {
            timer.cancel();
            _alternarGravacao();
          } else {
            setState(() => _elapsedSeconds++);
          }
        });
      }
    } catch (error) {
      if (!mounted) return;
      _recordingTimer?.cancel();
      setState(() {
        _isRecording = false;
        _startingRecording = false;
        _countdown = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível gravar o vídeo: $error')),
      );
    }
  }

  Future<void> _trocarCamera() async {
    if (_cameras.length < 2 || _isRecording || _startingRecording) return;
    final nextIndex = (_cameraIndex + 1) % _cameras.length;
    final current = _cameraController;
    setState(() {
      _loading = true;
      _error = null;
      _cameraController = null;
      _flashOn = false;
    });
    await current?.dispose();
    if (mounted) await _initializeCamera(cameraIndex: nextIndex);
  }

  Future<void> _alternarFlash() async {
    final controller = _cameraController;
    if (controller == null || _isRecording) return;
    try {
      final turnOn = !_flashOn;
      await controller.setFlashMode(turnOn ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _flashOn = turnOn);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flash indisponível nesta câmera.')),
      );
    }
  }

  void _alternarTemporizador() {
    const options = [0, 3, 10];
    final index = options.indexOf(_countdownDuration);
    setState(() => _countdownDuration = options[(index + 1) % options.length]);
  }

  void _alternarDuracao() {
    setState(() => _maxDuration = _maxDuration == 15 ? 60 : 15);
  }

  Future<void> _salvarNaGaleria([XFile? video]) async {
    final arquivo = video ?? _recordedVideo;
    if (!mounted || arquivo == null || _savingVideo || kIsWeb) return;

    setState(() {
      _savingVideo = true;
      _saveError = null;
    });
    try {
      var autorizado = await Gal.hasAccess(toAlbum: true);
      if (!autorizado) {
        autorizado = await Gal.requestAccess(toAlbum: true);
      }
      if (!mounted) return;
      if (!autorizado) {
        setState(() => _saveError = 'Permita acesso à galeria para salvar.');
        return;
      }

      await Gal.putVideo(arquivo.path, album: 'Luptok');
      if (mounted) setState(() => _gallerySaved = true);
    } catch (error) {
      if (mounted) setState(() => _saveError = 'Falha ao salvar: $error');
    } finally {
      if (mounted) setState(() => _savingVideo = false);
    }
  }

  Future<void> _compartilharVideo() async {
    final video = _recordedVideo;
    if (video == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [video],
        subject: 'Vídeo do Luptok',
        text: 'Vídeo gravado no Luptok',
      ),
    );
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _cameraController?.dispose();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    final cameraBackground = AppPalette.isDark(context)
        ? AppPalette.darkBackground
        : const Color(0xFF171313);
    return PopScope(
      canPop: !_isRecording && !_startingRecording,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pare a gravação antes de sair.')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: cameraBackground,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (!_loading &&
                _error == null &&
                _recordedVideo == null &&
                controller != null &&
                controller.value.isInitialized &&
                controller.value.previewSize != null)
              ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.previewSize!.height,
                    height: controller.value.previewSize!.width,
                    child: CameraPreview(controller),
                  ),
                ),
              )
            else
              ColoredBox(color: cameraBackground),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99000000),
                    Colors.transparent,
                    Color(0xCC000000),
                  ],
                  stops: [0, 0.42, 1],
                ),
              ),
            ),
            if (_loading)
              Center(
                child: CircularProgressIndicator(
                  color: AppPalette.accent(context),
                ),
              ),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.no_photography_outlined,
                        color: Colors.white70,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _initializeCamera(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_recordedVideo != null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _gallerySaved
                          ? Icons.check_circle_outline
                          : Icons.video_file_outlined,
                      color: _gallerySaved
                          ? const Color(0xFFFFB7BA)
                          : Colors.white70,
                      size: 64,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _gallerySaved
                          ? 'Vídeo salvo na galeria'
                          : 'Vídeo gravado',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: _isRecording
                              ? 'Parar gravação'
                              : 'Fechar câmera',
                          onPressed: _startingRecording
                              ? null
                              : _isRecording
                              ? _alternarGravacao
                              : () => Navigator.of(context).maybePop(),
                          icon: Icon(
                            _isRecording
                                ? Icons.stop_circle_outlined
                                : Icons.close_rounded,
                          ),
                          color: Colors.white,
                        ),
                        const Spacer(),
                        if (_isRecording)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '● REC  ${_formatDuration(_elapsedSeconds)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          TextButton(
                            onPressed: _recordedVideo == null
                                ? _alternarDuracao
                                : null,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: AppPalette.isDark(context)
                                  ? AppPalette.darkButton
                                  : Colors.black38,
                            ),
                            child: Text('$_maxDuration s'),
                          ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child:
                            _recordedVideo == null &&
                                !_loading &&
                                _error == null
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_cameras.length > 1)
                                    _cameraTool(
                                      icon: Icons.flip_camera_android_rounded,
                                      label: 'Virar',
                                      onTap: _startingRecording || _isRecording
                                          ? null
                                          : _trocarCamera,
                                    ),
                                  if (controller?.description.lensDirection ==
                                      CameraLensDirection.back)
                                    _cameraTool(
                                      icon: _flashOn
                                          ? Icons.flash_on_rounded
                                          : Icons.flash_off_rounded,
                                      label: 'Flash',
                                      onTap: _startingRecording || _isRecording
                                          ? null
                                          : _alternarFlash,
                                    ),
                                  _cameraTool(
                                    icon: Icons.timer_outlined,
                                    label: _countdownDuration == 0
                                        ? 'Temporizador'
                                        : '${_countdownDuration}s',
                                    onTap: _startingRecording || _isRecording
                                        ? null
                                        : _alternarTemporizador,
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: _recordedVideo != null
                        ? _buildRecordedActions()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_countdown > 0)
                                Text(
                                  '$_countdown',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 54,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              else
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [_recordingButton()],
                                ),
                              const SizedBox(height: 10),
                              Text(
                                _isRecording
                                    ? '${_formatDuration(_elapsedSeconds)} / ${_maxDuration}s'
                                    : 'Toque para gravar',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';

  Widget _cameraTool({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          IconButton.filledTonal(
            onPressed: onTap,
            style: IconButton.styleFrom(
              backgroundColor: AppPalette.isDark(context)
                  ? AppPalette.surface(context)
                  : Colors.black45,
              foregroundColor: Colors.white,
              fixedSize: const Size(46, 46),
            ),
            icon: Icon(icon, size: 21),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _recordingButton() {
    return GestureDetector(
      onTap: _loading || _error != null || _startingRecording
          ? null
          : _alternarGravacao,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 78,
        height: 78,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _isRecording
                ? AppPalette.isDark(context)
                      ? AppPalette.darkButton
                      : const Color(0xFFFF4D67)
                : Colors.white,
            borderRadius: BorderRadius.circular(_isRecording ? 10 : 40),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordedActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_savingVideo)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Salvando na galeria...',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else if (_gallerySaved)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Vídeo salvo no álbum Luptok',
              style: TextStyle(color: Colors.white70),
            ),
          )
        else if (_saveError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _saveError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _recordedVideo = null;
                _gallerySaved = false;
                _saveError = null;
              }),
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Gravar outro'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            ),
            if (!_gallerySaved && !kIsWeb)
              OutlinedButton.icon(
                onPressed: _savingVideo ? null : _salvarNaGaleria,
                icon: const Icon(Icons.save_alt_rounded),
                label: const Text('Salvar'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              ),
            FilledButton.icon(
              onPressed: _compartilharVideo,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Compartilhar'),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.button(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class PublishedVideo {
  final String videoPath;
  final String description;
  final String contentType;
  final String spoiler;
  final String privacy;

  const PublishedVideo({
    required this.videoPath,
    required this.description,
    required this.contentType,
    required this.spoiler,
    required this.privacy,
  });
}

class VideoPreviewScreen extends StatelessWidget {
  final XFile video;

  const VideoPreviewScreen({super.key, required this.video});

  Future<void> _continueToPost(BuildContext context) async {
    final published = await Navigator.of(context).push<PublishedVideo>(
      MaterialPageRoute<PublishedVideo>(
        builder: (_) => VideoPostScreen(video: video),
      ),
    );
    if (published != null && context.mounted) {
      Navigator.of(context).pop(published);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.isDark(context)
          ? AppPalette.darkBackground
          : const Color(0xFF171313),
      appBar: AppBar(
        backgroundColor: AppPalette.isDark(context)
            ? AppPalette.darkBackground
            : const Color(0xFF171313),
        foregroundColor: Colors.white,
        title: const Text('Prévia do vídeo'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                    maxHeight: 560,
                  ),
                  child: _PlayableVideo(path: video.path),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Descartar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _continueToPost(context),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Continuar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.button(context),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPostScreen extends StatefulWidget {
  final XFile video;

  const VideoPostScreen({super.key, required this.video});

  @override
  State<VideoPostScreen> createState() => _VideoPostScreenState();
}

class _VideoPostScreenState extends State<VideoPostScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  String? _contentType;
  String? _spoiler;
  String _privacy = 'Público';

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _publish() {
    if (_contentType == null || _spoiler == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione o tipo de conteúdo e o nível de spoiler.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      PublishedVideo(
        videoPath: widget.video.path,
        description: _descriptionController.text.trim(),
        contentType: _contentType!,
        spoiler: _spoiler!,
        privacy: _privacy,
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        color: AppPalette.primaryText(context),
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background(context),
      appBar: AppBar(
        backgroundColor: AppPalette.background(context),
        foregroundColor: AppPalette.primaryText(context),
        title: const Text('POSTAR'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: _PlayableVideo(path: widget.video.path),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('Descrição'),
                    TextField(
                      controller: _descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 240,
                      decoration: InputDecoration(
                        hintText: 'O que você achou?',
                        filled: true,
                        fillColor: AppPalette.input(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppPalette.border(context),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: AppPalette.border(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _sectionTitle('Adicionar conteúdo *'),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final type in ['Filme', 'Série', 'Livro'])
                          ChoiceChip(
                            label: Text(type),
                            selected: _contentType == type,
                            onSelected: (_) =>
                                setState(() => _contentType = type),
                            selectedColor: AppPalette.surface(context),
                            side: BorderSide(color: AppPalette.border(context)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Nível de spoiler *'),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final level in [
                          ('nenhum', 'Sem spoiler'),
                          ('leve', 'Leve'),
                          ('muito', 'Muito'),
                        ])
                          ChoiceChip(
                            label: Text(level.$2),
                            selected: _spoiler == level.$1,
                            onSelected: (_) =>
                                setState(() => _spoiler = level.$1),
                            selectedColor: AppPalette.surface(context),
                            side: BorderSide(color: AppPalette.border(context)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Privacidade'),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'Público',
                          label: Text('Público'),
                          icon: Icon(Icons.public_rounded),
                        ),
                        ButtonSegment(
                          value: 'Somente amigos',
                          label: Text('Amigos'),
                          icon: Icon(Icons.people_outline_rounded),
                        ),
                      ],
                      selected: {_privacy},
                      onSelectionChanged: (selection) =>
                          setState(() => _privacy = selection.first),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _publish,
                  icon: const Icon(Icons.publish_rounded),
                  label: const Text('Publicar vídeo'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.button(context),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayableVideo extends StatefulWidget {
  final String path;

  const _PlayableVideo({required this.path});

  @override
  State<_PlayableVideo> createState() => _PlayableVideoState();
}

class _PlayableVideoState extends State<_PlayableVideo> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialize;

  @override
  void initState() {
    super.initState();
    final uri = kIsWeb ? Uri.parse(widget.path) : Uri.file(widget.path);
    _controller = VideoPlayerController.networkUrl(uri);
    _initialize = _controller.initialize().then((_) {
      _controller.setLooping(true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialize,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Icon(
              Icons.video_file_outlined,
              color: Colors.white70,
              size: 48,
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF4D67)),
          );
        }
        return GestureDetector(
          onTap: () => setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          }),
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoPlayer(_controller),
                if (!_controller.value.isPlaying)
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white70,
                      size: 56,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
