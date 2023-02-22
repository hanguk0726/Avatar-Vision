import 'package:video_diary/services/native.dart';

class VideoProcess {
  VideoProcess._privateConstructor();
  static final VideoProcess _instance = VideoProcess._privateConstructor();
  factory VideoProcess() {
    return _instance;
  }

  static final textureId = Native.initTextureId();
}
