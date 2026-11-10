import 'package:video_player/video_player.dart';

VideoPlayerController createLocalVideoPlayerController(String path) =>
    VideoPlayerController.networkUrl(Uri.parse(path));
