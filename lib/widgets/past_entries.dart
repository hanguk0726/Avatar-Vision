import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/widgets/play.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/event.dart';
import '../services/event_bus.dart';
import '../services/native.dart';

class PastEntries extends StatefulWidget {
  const PastEntries({super.key});
  @override
  PastEntriesState createState() => PastEntriesState();
}

class PastEntriesState extends State<PastEntries> with WindowListener {
  int selectedIndex = 0;

  Color backgroundColor = customBlack;
  Color textColor = Colors.white;
  bool _isVisible = false;
  double widnowHeight = 0.0;
  late StreamSubscription<Event> _eventSubscription;

  Future<void> setUp() async {
    widnowHeight = await windowManager.getSize().then((value) => value.height);
    setState(() {
      // do nothing
    });
  }

  @override
  void onWindowResize() {
    super.onWindowResize();
    setUp();
  }

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
    setUp();
    _eventSubscription = EventBus().onEvent.listen((event) {
      if (!_isVisible) {
        return;
      }
      switch (event) {
        case Event.keyboardControlArrowUp:
          if (selectedIndex > 0) {
            setState(() {
              selectedIndex--;
            });
            return;
          }
          break;
        case Event.keyboardControlArrowDown:
          if (selectedIndex < Native().files.length - 1) {
            setState(() {
              selectedIndex++;
            });
            return;
          }
          break;
        case Event.keyboardControlEnter:
          play();
          return;
        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _eventSubscription.cancel();
    super.dispose();
  }

  Widget pastEntry(String file, bool selected) {
    if (selected) {
      return Text(file,
          style:
              TextStyle(color: textColor, fontFamily: mainFont, fontSize: 16));
    }
    return Text(
      file,
      style: TextStyle(color: textColor, fontFamily: mainFont, fontSize: 16),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  void play() async {
    Native native = context.read<Native>();
    String fileName = native.files[selectedIndex];
    String filePath = "${native.filePathPrefix}/$fileName.mp4";
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => Play(
                filePath: filePath,
                fileName: fileName,
                onPlay: () {},
              )),
    );
  }

  @override
  build(BuildContext context) {
    Native native = context.watch<Native>();
    List<String> files = native.files;
    return VisibilityDetector(
        key: const Key('pastEntries'),
        onVisibilityChanged: (visibilityInfo) {
          if (mounted) {
            setState(() {
              _isVisible = visibilityInfo.visibleFraction > 0;
            });
          }
        },
        child: ClipRRect(
          child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor.withOpacity(0.2),
                  ),
                  constraints: BoxConstraints(
                      maxHeight: widnowHeight == 0
                          ? 0
                          : (widnowHeight - 150).clamp(0, double.infinity)),
                  child: SizedBox.expand(
                      child: Padding(
                          padding: const EdgeInsets.only(bottom: 16, top: 16),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const ClampingScrollPhysics(),
                            itemCount: files.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedIndex = index;
                                    });
                                  },
                                  onDoubleTap: () {
                                    setState(() {
                                      selectedIndex = index;
                                    });
                                    play();
                                  },
                                  child: Container(
                                      color: selectedIndex == index
                                          ? customSky.withOpacity(0.3)
                                          : Colors.transparent,
                                      child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 32,
                                            right: 32,
                                          ),
                                          child: pastEntry(files[index],
                                              selectedIndex == index))));
                            },
                          ))))),
        ));
  }
}
