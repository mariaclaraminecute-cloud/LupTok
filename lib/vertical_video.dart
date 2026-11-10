import 'package:camera/camera.dart';

class VerticalVideo {
  final XFile file;
  final Future<void> Function() _dispose;

  const VerticalVideo({
    required this.file,
    required Future<void> Function() dispose,
  }) : _dispose = dispose;

  Future<void> dispose() => _dispose();
}
