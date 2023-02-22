import 'dart:isolate';

import 'package:flutter/cupertino.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/services/native.dart';

class VideoProcessor {
  VideoProcessor._privateConstructor();
  static final VideoProcessor _instance = VideoProcessor._privateConstructor();
  factory VideoProcessor() {
    return _instance;
  }

  static BehaviorSubject<int?> textureId = BehaviorSubject<int?>.seeded(null);

  final ReceivePort _receivePort = ReceivePort();
  Isolate? _isolate;
}
