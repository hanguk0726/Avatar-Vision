import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/pages/play.dart';
import 'package:video_diary/services/db.dart';
import 'package:video_diary/widgets/key_listener.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/event.dart';
import '../domain/result.dart';
import '../services/event_bus.dart';
import '../services/native.dart';

class PastEntries extends StatefulWidget {
  const PastEntries({super.key});
  @override
  PastEntriesState createState() => PastEntriesState();
}

class PastEntriesState extends State<PastEntries> {
  final selectedIndexSubject = BehaviorSubject<int>.seeded(0);

  Color backgroundColor = customBlack;
  Color textColor = Colors.white;
  late StreamSubscription<KeyEventPair> _eventSubscription;
  late StreamSubscription<int> _selectedIndexSubscription;
  final focusNode = FocusNode();
  int get selectedIndex => selectedIndexSubject.value;
  set selectedIndex(int value) => selectedIndexSubject.add(value);
  String eventKey = 'pastEntries';
  String allowedEventKey = 'tab';
  
  @override
  void initState() {
    super.initState();
    Native native = context.read<Native>();
    _selectedIndexSubscription = selectedIndexSubject.listen((index) {
      String fileName = native.files[selectedIndex];
      EventBus().fire(MetadataEvent(fileName), eventKey);
    });
    _eventSubscription = EventBus().onEvent.listen((event) {
      if (eventKey != event.key && allowedEventKey != event.key) {
        return;
      }
      switch (event.event) {
        case KeyboardEvent.keyboardControlArrowUp:
          if (selectedIndex > 0) {
            setState(() {
              selectedIndex--;
            });
            return;
          }
          break;
        case KeyboardEvent.keyboardControlArrowDown:
          if (selectedIndex < Native().files.length - 1) {
            setState(() {
              selectedIndex++;
            });
            return;
          }
          break;
        case KeyboardEvent.keyboardControlEnter:
          play();
          return;

        default:
          break;
      }
    });
    focusNode.requestFocus();
  }

  @override
  void dispose() {
    focusNode.dispose();
    _eventSubscription.cancel();
    _selectedIndexSubscription.cancel();
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
    focusNode.unfocus();
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
    return ClipRRect(
        child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
      child: Container(
          decoration: BoxDecoration(
            color: backgroundColor.withOpacity(0.2),
          ),
          constraints: const BoxConstraints(
            minHeight: 550,
          ),
          child: Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 16),
              child: keyListener(
                  eventKey,
                  focusNode,
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                          // # Reference note
                          // When GestureDetector has a onDoubleTap, it will add a short delay to wait for the potential second tap before deciding what to do. This is because tapping and double tapping are treated as exclusive actions. Unfortunatey, GestureDetector does not have a parameter to change this behaviour.
                          // There are some other issues where this problem is also discussed, though I can't find them right now.
                          // https://github.com/flutter/flutter/issues/121926
                          // so keyboard is faster.

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
                                  child: pastEntry(
                                      files[index], selectedIndex == index))));
                    },
                  )))),
    ));
  }
}
