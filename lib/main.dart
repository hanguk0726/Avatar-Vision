import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:video_diary/pages/video.dart';
import 'package:video_diary/services/native.dart';
import 'package:video_diary/services/video_process.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _inflateInstances();
  runApp(const Video());
}

Future<void> _inflateInstances() async {
  Native();
  VideoProcess();
  VideoProcess.textureId.add(await Native.initTextureId());
}
