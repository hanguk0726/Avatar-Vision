import 'dart:isolate';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/services/native.dart';

class VideoProcess {
  VideoProcess._privateConstructor();
  static final VideoProcess _instance = VideoProcess._privateConstructor();
  factory VideoProcess() {
    return _instance;
  }

  static BehaviorSubject<int?> textureId = BehaviorSubject<int?>.seeded(null);

  final ReceivePort _receivePort = ReceivePort();
  Isolate? _isolate;

//TODO : case - kill isolate

  // Future<void> launchIsolate() async {
  //   _isolate = await Isolate.spawn(_runIsolate, [_receivePort.sendPort]);
  //   _receivePort.listen(_handleMessage);
  //   debugPrint("isolate done");
  // }

  // void _handleMessage(dynamic data) {
  //   _receivePort.close();
  //   _isolate?.kill(priority: Isolate.immediate);
  //   _isolate = null;
  // }
}

Future<void> _runIsolate(List<dynamic> arguments) async {
  SendPort sendPort = arguments[0];
// this called from isolate which means not shared thread.
  sendPort.send("data to the _handleMessage");
}
