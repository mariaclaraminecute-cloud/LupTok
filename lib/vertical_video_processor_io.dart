import 'dart:io';

import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:flutter/foundation.dart';

import 'vertical_video.dart';

Future<VerticalVideo> cropVideoToVertical(XFile video) async {
  final workspace = await Directory.systemTemp.createTemp('luptok_vertical_');
  final output = '${workspace.path}${Platform.pathSeparator}video_vertical.mp4';

  try {
    final encoder = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'h264_mediacodec',
      TargetPlatform.iOS || TargetPlatform.macOS => 'h264_videotoolbox',
      _ => 'mpeg4',
    };
    final session = await FFmpegKit.executeWithArguments([
      '-i',
      video.path,
      '-map',
      '0:v:0',
      '-map',
      '0:a?',
      '-vf',
      'scale=720:1280:force_original_aspect_ratio=increase,'
          'crop=720:1280,setsar=1',
      '-c:v',
      encoder,
      '-b:v',
      '3M',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-b:a',
      '128k',
      '-movflags',
      '+faststart',
      '-y',
      output,
    ]);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getOutput();
      throw Exception(
        'Não foi possível converter o vídeo para o formato vertical.'
        '${logs == null || logs.isEmpty ? '' : ' $logs'}',
      );
    }

    return VerticalVideo(
      file: XFile(output, mimeType: 'video/mp4'),
      dispose: () async {
        try {
          await workspace.delete(recursive: true);
        } on FileSystemException catch (error) {
          debugPrint('Não foi possível remover o vídeo temporário: $error');
        }
      },
    );
  } catch (_) {
    try {
      await workspace.delete(recursive: true);
    } on FileSystemException catch (error) {
      debugPrint('Não foi possível remover o vídeo temporário: $error');
    }
    rethrow;
  }
}
