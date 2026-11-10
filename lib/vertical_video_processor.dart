import 'package:camera/camera.dart';

import 'vertical_video_processor_stub.dart'
    if (dart.library.io) 'vertical_video_processor_io.dart'
    as implementation;
import 'vertical_video.dart';

Future<VerticalVideo> cropVideoToVertical(XFile video) =>
    implementation.cropVideoToVertical(video);
