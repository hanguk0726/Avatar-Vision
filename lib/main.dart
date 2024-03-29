import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:video_diary/pages/video.dart';
import 'package:video_diary/services/database.dart';
import 'package:video_diary/services/native.dart';
import 'package:video_diary/tools/custom_scroll_behavior.dart';
import 'package:window_manager/window_manager.dart';
import 'domain/app.dart';
import 'services/setting.dart';


// It has a warning from objectbox-dart when launching in debug mode currently.
// https://github.com/objectbox/objectbox-dart/issues/522
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setUp();
  
  //make sentry work only in release mode
  if (kReleaseMode) {
    await SentryFlutter.init((options) {
      // for crashlytics
      options.dsn =
          'https://d20454ad99764ab5b86598129afadb7a@o4505225350807552.ingest.sentry.io/4505225351659520';
      options.tracesSampleRate = 1.0;
    }, appRunner: () => runApp_());
  } else {
    runApp_();
  }
}

runApp_() {
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => Native()),
          ChangeNotifierProvider(create: (_) => Setting()),
          ChangeNotifierProvider(create: (_) => DatabaseService()),
        ],
        child: const App(),
      ),
    );
  }

final routeObserver = RouteObserver<ModalRoute<dynamic>>();

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Avatar Vision',
      scrollBehavior: CustomScrollBehavior(),
      home: const VideoPage(),
      navigatorObservers: [routeObserver],
    );
  }
}

Future<void> setUp() async {
  await Native()
      .init(); // Native init process **MUST NOT** be delayed by other init.
  await Setting().load();
  await DatabaseService().init();
  MediaKit.ensureInitialized();
  version = await getAppVersion();
  await setUpLast();
}

Future<void> setUpLast() async {
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(1280, 720),
    title: "Avatar Vision",
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
