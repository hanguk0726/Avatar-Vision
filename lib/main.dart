import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_diary/pages/video.dart';
import 'package:video_diary/services/native.dart';

import 'domain/setting.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Native().init();
  await Setting().load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Native()),
        ChangeNotifierProvider(create: (_) => Setting()),
      ],
      child: const Video(),
    ),
  );
}
