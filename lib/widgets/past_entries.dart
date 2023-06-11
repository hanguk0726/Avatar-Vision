import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/pages/play.dart';
import 'package:video_diary/services/database.dart';
import 'package:video_diary/widgets/key_listener.dart';
import 'package:video_diary/widgets/search.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/event.dart';
import '../domain/metadata.dart';
import '../main.dart';
import '../services/event_bus.dart';
import '../services/native.dart';
import '../services/setting.dart';
import '../tools/time.dart';
import 'context_menu.dart';

class PastEntries extends StatefulWidget {
  const PastEntries({super.key});
  @override
  PastEntriesState createState() => PastEntriesState();
}

class PastEntriesState extends State<PastEntries>
    with WindowListener, RouteAware {
  final selectedIndexSubject = BehaviorSubject<int>.seeded(0);
  final selectedIndicesSubject = BehaviorSubject<List<int>>.seeded([]);
  List<int> get selectedIndices => selectedIndicesSubject.value;

  set selectedIndices(List<int> value) => selectedIndicesSubject.value = value;
  // Color backgroundColor = customBlack;
  Color backgroundColor = customOcean;
  Color textColor = Colors.white;
  late StreamSubscription<KeyEventPair> _eventSubscription;
  final focusNode = FocusNode();
  late StreamSubscription<int> _selectedIndexSubscription;
  int get selectedIndex => selectedIndexSubject.value;
  set selectedIndex(int value) => selectedIndexSubject.add(value);
  String eventKey = 'pastEntries';
  List<String> allowedEventKeys = ['tab', 'pastEntries', 'system'];
  double? screenHeight;
  double? screenWidth;
  final _native = Native();
  bool multiSelectMode = false;
  late StreamSubscription<List<int>> _selectedIndicesSubscription;
  final ScrollController _thumbnailViewScrollController = ScrollController();

  @override
  void onWindowResize() async {
    await setWindowSize();
  }

  @override
  void onWindowMaximize() async {
    await setWindowSize();
  }

  @override
  void onWindowUnmaximize() async {
    await setWindowSize();
  }

  @override
  void onWindowEnterFullScreen() async {
    await setWindowSize();
  }

  @override
  void onWindowLeaveFullScreen() async {
    await setWindowSize();
  }

  Future<void> setWindowSize() async {
    var size = await windowManager.getSize();
    // The texture widget can't be bigger than the resolution.
    final currentResolutionHeight = _native.currentResolutionHeight;
    final currentResolutionWidth = _native.currentResolutionWidth;
    setState(() {
      screenHeight = min(currentResolutionHeight, size.height);
      screenWidth = min(currentResolutionWidth, size.width);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    var db = context.read<DatabaseService>();
    List<Metadata> entries = db.uiStatePastEntries;
    if (entries.isNotEmpty) {
      // when data was modified at 'play' page, the selected index is not updated
      int timestamp = entries[selectedIndex].timestamp;
      EventBus().fire(MetadataEvent(timestamp), eventKey);
    }
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    setWindowSize();
    var db = context.read<DatabaseService>();
    var setting = context.read<Setting>();
    _selectedIndicesSubscription = selectedIndicesSubject.listen((indices) {
      final timestamps = context
          .read<DatabaseService>()
          .uiStatePastEntries
          .asMap()
          .entries
          .where((entry) => indices.contains(entry.key))
          .map((e) => e.value.timestamp)
          .toList();
      EventBus().fire(FileEvent(timestamps, FileEvent.selected), eventKey);
    });
    _selectedIndexSubscription = selectedIndexSubject.listen((index) {
      List<Metadata> entries = db.uiStatePastEntries;
      if (entries.isNotEmpty && index < entries.length) {
        int timestamp = entries[index].timestamp;
        EventBus().fire(MetadataEvent(timestamp), eventKey);
        if (setting.thumbnailView) {
          int itemsPerRow = ((screenWidth ?? 1280) * 0.43) ~/ 250;
          double offset = (index ~/ itemsPerRow) * (250.0 + 16.0);
          _thumbnailViewScrollController.animateTo(offset,
              duration: const Duration(milliseconds: 500), curve: Curves.ease);
        }
      }
    });
    _eventSubscription = EventBus().onEvent.listen((event) {
      if (!allowedEventKeys.contains(event.key)) {
        return;
      }
      if (event.event is FileEvent) {
        FileEvent casted = event.event as FileEvent;
        switch (casted.command) {
          case FileEvent.cancel:
            selectedIndices = [];
            multiSelectMode = false;
            setState(() {});
            break;
        }
      }

      switch (event.event) {
        case KeyboardEvent.keyboardControlArrowUp:
          if (multiSelectMode) return;
          if (selectedIndex > 0) {
            setState(() {
              selectedIndex = selectedIndex - 1;
            });
            return;
          }
          break;
        case KeyboardEvent.keyboardControlArrowDown:
          if (multiSelectMode) return;
          if (selectedIndex < db.uiStatePastEntries.length - 1) {
            setState(() {
              selectedIndex = selectedIndex + 1;
            });
            return;
          }
          break;
        case KeyboardEvent.keyboardControlEnter:
          if (multiSelectMode) return;
          play();
          return;
        case KeyboardEvent.keyboardControlEscape:
          if (multiSelectMode) {
            setState(() {
              multiSelectMode = false;
              selectedIndices = [];
            });
            return;
          }
          break;
        case KeyboardEvent.keyboardControlBackspace:
          if (multiSelectMode) {
            setState(() {
              multiSelectMode = false;
              selectedIndices = [];
            });
            return;
          }
          break;
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
    _selectedIndicesSubscription.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  Widget pastEntry(String text, bool selected) {
    if (selected) {
      return Text(text,
          style:
              TextStyle(color: textColor, fontFamily: mainFont, fontSize: 16));
    }
    return Text(
      text,
      style: TextStyle(color: textColor, fontFamily: mainFont, fontSize: 16),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  void play() async {
    var native = Native();
    var db = context.read<DatabaseService>();
    List<Metadata> entries = db.uiStatePastEntries;
    int timestamp = entries[selectedIndex].timestamp;
    String fileName = osFileName(timestamp);
    String filePath = "${native.filePathPrefix}/$fileName.mp4";
    focusNode.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => Play(
                filePath: filePath,
                fileName: fileName,
                timestamp: timestamp,
                onPlay: () {},
              )),
    );
  }

  @override
  build(BuildContext context) {
    DatabaseService db = context.watch<DatabaseService>();
    List<Metadata> entries = db.uiStatePastEntries;
    int itemsPerRow = ((screenWidth ?? 1280) * 0.43) ~/ 250;
    double width;
    if (itemsPerRow == 2) {
      width = 550;
    } else {
      width = 816;
    }
    return ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: (screenHeight ?? 720) - 150, maxWidth: width),
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
                  child: keyListener(
                    eventKey,
                    focusNode,
                    Stack(
                      children: [
                        entries.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(top: 70),
                                child: SizedBox.expand(
                                    child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text('No entries yet',
                                      style: TextStyle(
                                          color: textColor,
                                          fontFamily: mainFont,
                                          fontSize: 16)),
                                )))
                            : Padding(
                                padding: const EdgeInsets.only(top: 70),
                                child: Setting().thumbnailView
                                    ? thumbnailView(width, itemsPerRow)
                                    : listView(),
                              ),
                        statusBar(),
                      ],
                    ),
                  ),
                ))));
  }

  Widget statusBar() {
    DatabaseService db = context.watch<DatabaseService>();
    List<Metadata> entries = db.uiStatePastEntries;
    return Container(
      decoration: BoxDecoration(
        color: customOcean.withOpacity(0.6),
        border: Border(
          top: BorderSide(width: 2.0, color: customSky.withOpacity(0.6)),
          bottom: BorderSide(width: 2.0, color: customSky.withOpacity(0.6)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(width: 16),
          if (entries.length > selectedIndex && !multiSelectMode)
            Text(timestampToMonthDay(entries[selectedIndex].timestamp, true),
                style: TextStyle(
                    color: Colors.white, fontFamily: subFont, fontSize: 22)),
          const Spacer(),
          const DateSearchBar()
        ],
      ),
    );
  }

  Widget thumbnailView(double width, int itemsPerRow) {
    var native = Native();
    var db = context.watch<DatabaseService>();
    List<Metadata> entries = db.uiStatePastEntries;

    return SizedBox(
        width: width,
        child: GridView.builder(
          controller: _thumbnailViewScrollController,
          padding: const EdgeInsets.only(left: 16, right: 16),
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: entries.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: itemsPerRow,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 250),
          itemBuilder: (context, index) {
            bool selected = false;
            if (multiSelectMode) {
              selected = selectedIndices.contains(index);
            } else {
              selected = selectedIndex == index;
            }
            return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: GestureDetector(
                    key: ValueKey<double>(width),
                    onTap: () {
                      if (multiSelectMode) {
                        if (selectedIndices.contains(index)) {
                          selectedIndices.remove(index);
                          // make stream distinct
                          selectedIndices = List.from(selectedIndices);
                        } else {
                          selectedIndices.add(index);
                          selectedIndices = List.from(selectedIndices);
                        }
                        setState(() {});
                      } else {
                        setState(() {
                          selectedIndex = index;
                          focusNode.requestFocus();
                        });
                      }
                    },
                    onLongPress: () {
                      if (!multiSelectMode) {
                        multiSelectMode = true;
                        selectedIndices = [index];
                        setState(() {});
                      }
                    },
                    onDoubleTap: () {
                      if (multiSelectMode) return;
                      setState(() {
                        selectedIndex = index;
                      });
                      play();
                    },
                    child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? customSky.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.1),
                          border: selected
                              ? Border.all(
                                  color: customSky.withOpacity(0.6),
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            native.getThumbnail(entries[index].timestamp),
                            const SizedBox(height: 16),
                            Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Row(children: [
                                  Text(
                                      formatTimestamp(
                                          timestamp: entries[index].timestamp),
                                      style: TextStyle(
                                          color: selected
                                              ? Colors.white
                                              : textColor,
                                          fontFamily: mainFont,
                                          fontSize: 16)),
                                  if (selectedIndex == index &&
                                      !multiSelectMode) ...[
                                    const Spacer(),
                                    contextMenu(
                                        entries[index].timestamp, eventKey,
                                        iconSize: 24.0),
                                    const SizedBox(
                                      width: 8,
                                    ),
                                  ]
                                ])),
                            const SizedBox(height: 8),
                            Padding(
                                padding:
                                    const EdgeInsets.only(left: 16, right: 16),
                                child: Text(entries[index].title,
                                    maxLines: 2,
                                    style: TextStyle(
                                        color:
                                            selected ? Colors.white : textColor,
                                        fontFamily: mainFont,
                                        fontSize: 16,
                                        overflow: TextOverflow.ellipsis))),
                          ],
                        ))));
          },
        ));
  }

  Widget listView() {
    var db = context.watch<DatabaseService>();
    List<Metadata> entries = db.uiStatePastEntries;
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        bool selected = false;
        if (multiSelectMode) {
          selected = selectedIndices.contains(index);
        } else {
          selected = selectedIndex == index;
        }
        return GestureDetector(
            // # Reference note
            // When GestureDetector has a onDoubleTap, it will add a short delay to wait for the potential second tap before deciding what to do. This is because tapping and double tapping are treated as exclusive actions. Unfortunatey, GestureDetector does not have a parameter to change this behaviour.
            // There are some other issues where this problem is also discussed, though I can't find them right now.
            // https://github.com/flutter/flutter/issues/121926
            // so keyboard is faster.

            onTap: () {
              if (multiSelectMode) {
                if (selectedIndices.contains(index)) {
                  selectedIndices.remove(index);
                  selectedIndices = List.from(selectedIndices);
                } else {
                  selectedIndices.add(index);
                  selectedIndices = List.from(selectedIndices);
                }
                setState(() {});
              } else {
                setState(() {
                  selectedIndex = index;
                  focusNode.requestFocus();
                });
              }
            },
            onLongPress: () {
              if (!multiSelectMode) {
                multiSelectMode = true;
                selectedIndices = [index];
                setState(() {});
              }
            },
            onDoubleTap: () {
              if (multiSelectMode) return;
              setState(() {
                selectedIndex = index;
              });
              play();
            },
            child: Container(
                color:
                    selected ? customSky.withOpacity(0.3) : Colors.transparent,
                child: Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                    ),
                    child: Row(
                      children: [
                        pastEntry(
                            formatTimestamp(
                                timestamp: entries[index].timestamp),
                            selected),
                        const Spacer(),
                        if (selectedIndex == index && !multiSelectMode) ...[
                          contextMenu(entries[index].timestamp, eventKey,
                              iconSize: 16.0)
                        ]
                      ],
                    ))));
      },
    );
  }
}
