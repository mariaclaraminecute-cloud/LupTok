import 'package:video_player/video_player.dart';

import 'local_video_player_stub.dart'
    if (dart.library.io) 'local_video_player_io.dart'
    as implementation;

VideoPlayerController createLocalVideoPlayerController(String path) =>
    implementation.createLocalVideoPlayerController(path);
