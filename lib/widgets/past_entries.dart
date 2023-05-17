import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/pages/play.dart';
import 'package:video_diary/services/database.dart';
import 'package:video_diary/widgets/key_listener.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/event.dart';
import '../domain/metadata.dart';
import '../services/event_bus.dart';
import '../services/native.dart';
import '../services/setting.dart';
import '../tools/time.dart';

class PastEntries extends StatefulWidget {
  const PastEntries({super.key});
  @override
  PastEntriesState createState() => PastEntriesState();
}

class PastEntriesState extends State<PastEntries> with WindowListener {
  final selectedIndexSubject = BehaviorSubject<int>.seeded(0);

  // Color backgroundColor = customBlack;
  Color backgroundColor = customOcean;
  Color textColor = Colors.white;
  late StreamSubscription<KeyEventPair> _eventSubscription;
  final focusNode = FocusNode();
  late StreamSubscription<int> _selectedIndexSubscription;
  int get selectedIndex => selectedIndexSubject.value;
  set selectedIndex(int value) => selectedIndexSubject.add(value);
  String eventKey = 'pastEntries';
  String allowedEventKey = 'tab';
  double? screenHeight;
  final ScrollController _thumbnailViewScrollController = ScrollController();
  @override
  void onWindowResize() async {
    await setWindowSize();
  }

  Future<void> setWindowSize() async {
    var size = await windowManager.getSize();
    setState(() {
      screenHeight = size.height;
    });
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    setWindowSize();
    var db = context.read<DatabaseService>();
    List<Metadata> entries = db.pastEntries;

    _selectedIndexSubscription = selectedIndexSubject.listen((index) {
      if (entries.isNotEmpty) {
        int timestamp = entries[index].timestamp;
        EventBus().fire(MetadataEvent(timestamp), eventKey);
        double offset = (index ~/ 2) * 250.0 ;
        _thumbnailViewScrollController.animateTo(offset,
            duration: const Duration(milliseconds: 500), curve: Curves.ease);
      }
    });
    _eventSubscription = EventBus().onEvent.listen((event) {
      if (eventKey != event.key && allowedEventKey != event.key) {
        return;
      }
      switch (event.event) {
        case KeyboardEvent.keyboardControlArrowUp:
          if (selectedIndex > 0) {
            setState(() {
              selectedIndex = selectedIndex - 1;
            });
            return;
          }
          break;
        case KeyboardEvent.keyboardControlArrowDown:
          if (selectedIndex < Native().files.length - 2) {
            setState(() {
              selectedIndex = selectedIndex + 1;
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
    windowManager.removeListener(this);
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
    var native = Native();
    var db = context.watch<DatabaseService>();
    List<Metadata> entries = db.pastEntries;
    int timestamp = entries[selectedIndex].timestamp;
    String fileName = gererateFileName(timestamp);
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
    DatabaseService db = context.watch<DatabaseService>();
    List<Metadata> entries = db.pastEntries;

    return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: (screenHeight ?? 720) - 150),
        child: ClipRRect(
            child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Container(
              decoration: BoxDecoration(
                color: backgroundColor.withOpacity(0.2),
              ),
              constraints: const BoxConstraints(
                minHeight: 570,
              ),
              child: Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 16),
                  child: entries.isEmpty
                      ? SizedBox.expand(
                          child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('No entries yet',
                              style: TextStyle(
                                  color: textColor,
                                  fontFamily: mainFont,
                                  fontSize: 16)),
                        ))
                      : keyListener(
                          eventKey,
                          focusNode,
                          Setting().thumbnailView
                              ? thumbnailView()
                              : listView(),
                        ))),
        )));
  }

  Widget thumbnailView() {
    var native = Native();
    var db = context.watch<DatabaseService>();
    List<Metadata> entries = db.pastEntries;
    return GridView.builder(
      controller: _thumbnailViewScrollController,
      padding: const EdgeInsets.only(left: 16, right: 16),
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: entries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          mainAxisExtent: 250),
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
                // color: selectedIndex == index
                //     ? customSky.withOpacity(0.3)
                //     : Colors.grey.withOpacity(0.1),
                     decoration: BoxDecoration(
                  color: selectedIndex == index
                    ? customSky.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1),
                  border:  selectedIndex == index ?Border.all(
                    color:  customSky.withOpacity(0.6),
                    width: 2,
                  ) : null,
                  // borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        native.getThumbnail(entries[index].timestamp),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Text(
                              timestampToMonthDay(
                                  entries[index].timestamp, true),
                              style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: subFont,
                                  fontSize: 22)),
                        )
                      ],
                    ),
                    const SizedBox(height: 16),
                    Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16),
                        child: Text(entries[index].title,
                            style: TextStyle(
                                color: selectedIndex == index
                                    ? Colors.white
                                    : textColor,
                                fontFamily: mainFont,
                                fontSize: 16))),
                    const SizedBox(height: 8),
                    if (entries[index].note?.isNotEmpty ?? false)
                      Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16),
                          child: Text(entries[index].note!,
                              maxLines: 2,
                              style: TextStyle(
                                  color: selectedIndex == index
                                      ? Colors.white
                                      : textColor,
                                  fontFamily: mainFont,
                                  fontSize: 16,
                                  overflow: TextOverflow.ellipsis))),
                  ],
                )));
      },
    );
  }

  Widget listView() {
    var db = context.watch<DatabaseService>();
    List<Metadata> entries = db.pastEntries;
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: entries.length,
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
                      left: 16,
                      right: 32,
                    ),
                    child: Row(
                      children: [
                        Text(
                            timestampToMonthDay(
                                entries[index].timestamp, false),
                            style: TextStyle(
                                color: textColor,
                                fontFamily: mainFont,
                                fontSize: 16)),
                        const SizedBox(width: 16),
                        pastEntry(entries[index].title, selectedIndex == index)
                      ],
                    ))));
      },
    );
  }
}
