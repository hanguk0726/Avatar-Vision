import 'package:flutter/material.dart';
import 'package:video_diary/pages/video.dart';
import 'package:video_diary/services/native.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Native().init();
  runApp(const Video());
}
