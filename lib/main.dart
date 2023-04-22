import 'package:flutter/material.dart';
import 'package:flutter_meedu_videoplayer/init_meedu_player.dart';
// import 'package:flutter_meedu_videoplayer/init_meedu_player.dart';
import 'package:provider/provider.dart';
import 'package:video_diary/domain/metadata.dart';
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
  // await DatabaseService().init();
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
 await initMeeduPlayer();
  await Native().init();
  await Setting().load();
  // await test();
}

Future<void> test() async {
  var metadata = Metadata(
    videoTitle: "My Video Title",
    timestamp: DateTime.now().millisecondsSinceEpoch,
    note: "My notes",
    tags: "tag1, tag2",
    thumbnail: "thumbnail.jpg",
  );

  // DatabaseService().store.box<Metadata>().put(metadata);
}
