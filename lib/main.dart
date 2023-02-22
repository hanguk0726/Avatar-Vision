import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:video_diary/pages/video.dart';
import 'package:video_diary/services/native.dart';
import 'package:video_diary/services/video_process.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _inflateInstances();
  runApp(const Video());
}

void _inflateInstances() {
  Get.put(VideoProcess());
  Get.put(Native());
}
