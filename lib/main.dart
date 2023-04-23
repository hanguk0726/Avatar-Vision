import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:video_diary/pages/video.dart';
import 'package:video_diary/services/db.dart';
import 'package:video_diary/services/native.dart';
import 'package:window_manager/window_manager.dart';

import 'services/setting.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setUp();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Native()),
        ChangeNotifierProvider(create: (_) => Setting()),
      ],
      child: const App(),
    ),
  );
}

Future<void> setUp() async {
  await Native()
      .init(); // Native init process must not be delayed by other init (ex: UI init process)
  await Setting().load();
  await DatabaseService().init();
  MediaKit.ensureInitialized();
  await test();
  await setUpLast();
}

Future<void> setUpLast() async {
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(1280, 720),
    title: "Video Diary",
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

Future<void> test() async {
  // var metadata = Metadata(
  //   videoTitle: "My Video Title",
  //   timestamp: DateTime.now().millisecondsSinceEpoch,
  //   note: "My notes",
  //   tags: "tag1, tag2",
  //   thumbnail: "thumbnail.jpg",
  // );
  // final box = DatabaseService().store.box<Metadata>();
  // final id = box.put(metadata);
  // print("db id: ${box.getAll().first.note}");
}
