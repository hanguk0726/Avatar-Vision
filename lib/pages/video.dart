import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/services/event_bus.dart';
import 'package:video_diary/services/native.dart';
import 'package:video_diary/widgets/dialog.dart';
import 'package:video_diary/widgets/file_command.dart';
import 'package:video_diary/widgets/media_conrtol_bar.dart';
import 'package:video_diary/widgets/message.dart';
import 'package:video_diary/widgets/metadata_widget.dart';
import 'package:video_diary/widgets/tip_content.dart';

import '../domain/app.dart';
import '../domain/error.dart';
import '../domain/event.dart';
import '../domain/metadata.dart';
import '../domain/result.dart';
import '../domain/tab_item.dart';
import '../domain/writing_state.dart';
import '../services/database.dart';
import '../services/runtime_data.dart';
import '../services/setting.dart';
import '../tools/time.dart';
import '../widgets/tab.dart';
import '../widgets/tab_item.dart';
import '../widgets/texture.dart';

final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

class VideoPage extends StatefulWidget {
  const VideoPage({super.key});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  BehaviorSubject<TabItem> tabItem = BehaviorSubject<TabItem>();
  Metadata? selectedMetadata;
  String metadataQueryErrorMessage = '';
  late StreamSubscription<KeyEventPair> _eventSubscription;
  String eventKey = 'video';
  bool isMovedAway = false;
  final runtimeData = RuntimeData();
  Timer? _recordingTimer;
  Duration recordingTime = Duration.zero;
  bool showTipContent = false;
  bool isFullscreen = false;
  DialogEvent? dialog;
  List<int> selectedFileTimetamps = [];

  @override
  void initState() {
    super.initState();
    tabItem.add(RuntimeData().currentTab);
    _eventSubscription = EventBus().onEvent.listen((event) {
      handleEvent(event);
    });
  }

  void handleEvent(KeyEventPair event) {
    if (event.key != "pastEntries" &&
        event.key != "tab" &&
        event.key != "system") {
      return;
    }
    if (event.event is DialogEvent) {
      DialogEvent casted = event.event as DialogEvent;
      if (casted == DialogEvent.dismiss) {
        setState(() {
          dialog = null;
        });
      } else {
        setState(() {
          dialog = casted;
        });
      }
    }

    if (event.event is KeyboardEvent) {
      if (event.event == KeyboardEvent.keyboardControlTab) {
        final recording = context.read<Native>().recording;
        clearUi(recording, !isMovedAway);
        return;
      }
      if (event.event == KeyboardEvent.keyboardControlF) {
        FullScreenWindow.setFullScreen(!isFullscreen);
        isFullscreen = !isFullscreen;
        setState(() {});
        return;
      }
    }
    if (event.event is MetadataEvent) {
      MetadataEvent casted = event.event as MetadataEvent;
      // add data
      int timestamp = casted.timestamp;
      final queryResult =
          DatabaseService().findByOsFileName(osFileName(timestamp));
      if (queryResult is Success) {
        setState(() {
          selectedMetadata = (queryResult as Success<Metadata>).value;
          metadataQueryErrorMessage = '';
        });
      } else {
        setState(() {
          selectedMetadata = null;
          metadataQueryErrorMessage = (queryResult as Error).message;
        });
      }
      return;
    }
    if (event.event is FileEvent) {
      FileEvent casted = event.event as FileEvent;
      switch (casted.command) {
        case FileEvent.cancel:
          selectedFileTimetamps = [];
          setState(() {});
          break;
        case FileEvent.selected:
          selectedFileTimetamps = casted.timestamps;
          setState(() {});
          break;
        case FileEvent.sendFileToDesktop:
          EventBus().fire(
            DialogEvent(
              text: 'Sending to Desktop',
              eventKey: 'system',
              automaticTask: () {
                var native = Native();
                for (var timestamp in casted.timestamps) {
                  native.sendFileToDesktop(timestamp);
                }
                return Future.value();
              },
            ),
            'system',
          );
          EventBus().fire(const FileEvent([], FileEvent.cancel), 'system');
          break;
        case FileEvent.delete:
          EventBus().fire(
            DialogEvent(
              text: 'Proceed to delete?',
              eventKey: 'system',
              buttonSky: 'Yes',
              buttonSkyTask: () {
                var native = Native();
                for (var timestamp in casted.timestamps) {
                  native.deleteFile(timestamp);
                }
                EventBus()
                    .fire(const FileEvent([], FileEvent.cancel), 'system');
                return Future.value();
              },
              buttonOrange: 'No',
              buttonOrangeTask: () => Future.microtask(() {
                EventBus().fire(DialogEvent.dismiss, 'system');
                EventBus()
                    .fire(const FileEvent([], FileEvent.cancel), 'system');
              }),
            ),
            'system',
          );
          break;
      }
    }
  }

  void startTimter() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        recordingTime = recordingTime + const Duration(seconds: 1);
      });
    });
  }

  @override
  void dispose() {
    tabItem.close();
    _eventSubscription.cancel();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final native = context.watch<Native>();
    final setting = Setting();
    final writingState = native.writingState;
    final recording = native.recording;
    final rendering = native.rendering;
    final cameraDevices = native.cameraDevices;
    final audioDevices = native.audioDevices;
    final cameraHealthCheck = native.cameraHealthCheck;
    final cameraHealthCheckErrorMessage = native.cameraHealthCheckErrorMessage;
    final width = native.currentResolutionWidth;
    final height = native.currentResolutionHeight;
    final recordingHealthCheck = native.recordingHealthCheck;
    final showTip = setting.tip && !recording;

    List<CustomError> errors = [
      CustomError(
        occurred: cameraDevices.isEmpty || audioDevices.isEmpty,
        message:
            "Need to connect the camera and microphone devices.\nPlease connect the devices and restart the app.",
        subMessage: '',
      ),
      CustomError(
        occurred: !cameraHealthCheck,
        message:
            "The camera device has encountered an error.\nPlease pull out the usb and reconnect it.",
        subMessage: cameraHealthCheckErrorMessage,
      ),
      CustomError(
        occurred: !recordingHealthCheck,
        message:
            "The directory for saving the video does not have permission for writing.\nPlease check the directory permission.",
        subMessage: "path: ${native.filePathPrefix}",
      ),
    ];

    return Scaffold(
        key: _scaffoldKey,
        backgroundColor: customBlack,
        drawerScrimColor: Colors.transparent,
        body: Listener(
          child: Center(
              child: SizedBox(
            width: width == 0 ? 1280 : width,
            height: height == 0 ? 720 : height,
            child: Stack(children: [
              Container(), //empty container for the background
              AnimatedOpacity(
                  duration: const Duration(milliseconds: 700),
                  opacity: rendering ? 1 : 0,
                  child: texture(width, height)),
              if (recording) recordingInfo(),
              about(),

              if (showTip) tip(),
              if (errors.any((error) => error.occurred))
                messageOnError(
                    error: errors.firstWhere((error) => error.occurred)),

              menuTaps(recording: recording),
              _mediaControlButton(),
              _customDialog(),
              if (selectedFileTimetamps.isEmpty)
                if (!recording && selectedMetadata != null)
                  pastEntryMetadata()
                else
                  Container()
              else
                Positioned(
                  top: 32,
                  right: 32,
                  child: fileCommandWidget(selectedFileTimetamps),
                ),
              writingStateMessage(
                  writingState: writingState, rendering: rendering),
              if (showTipContent && setting.tip)
                Positioned(
                  top: 82,
                  right: 82,
                  child: tipContent(),
                ),
            ]),
          )),
          onPointerSignal: (PointerSignalEvent event) {
            if (event is PointerScrollEvent) {
              if (event.scrollDelta.dy < 0) {
                clearUi(recording, true);
              } else {
                // scrolled up
                clearUi(recording, false);
              }
            }
          },
        ));
  }

  void clearUi(bool recording, bool isMovedAway) {
    setState(() {
      if (runtimeData.tabIndex == 0 || recording) {
        this.isMovedAway = isMovedAway;
        EventBus().clearUiMode = isMovedAway;
      }
    });
  }

  Widget tip() {
    return StreamBuilder<TabItem>(
        stream: tabItem,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != TabItem.pastEntries) {
            return buildAnimatedPositioned(
              isMovedAway: isMovedAway,
              top: 32,
              right: 32,
              child: MouseRegion(
                  onHover: (event) {
                    setState(() {
                      showTipContent = true;
                    });
                  },
                  onExit: (event) {
                    setState(() {
                      showTipContent = false;
                    });
                  },
                  child: Center(
                      child: Icon(Icons.help_center_sharp,
                          size: 50, color: customSky.withOpacity(0.4)))),
            );
          } else {
            return Container();
          }
        });
  }

  Widget about() {
    //stream builder for tabImdex
    return StreamBuilder<TabItem>(
        stream: tabItem,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data == TabItem.settings) {
            return Positioned(
                bottom: 8,
                left: 8,
                child: Tooltip(
                    message: "Version $version",
                    decoration: BoxDecoration(
                      color: customOcean.withOpacity(0.8),
                    ),
                    textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: mainFont),
                    preferBelow: false,
                    child: Text(version,
                        style: TextStyle(
                            color: Colors.grey.withOpacity(0.8),
                            fontSize: 16,
                            fontFamily: mainFont))));
          } else {
            return Container();
          }
        });
  }

  Widget _mediaControlButton() {
    return buildAnimatedPositioned(
        isMovedAway: isMovedAway,
        bottom: 32,
        right: 32,
        child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 1.0),
                  end: const Offset(0.0, 0.0),
                ).animate(animation),
                child: child,
              );
            },
            child: dialog == null
                ? mediaControlButton(
                    context: context,
                    onRecordStart: startTimter,
                    onRecordStop: () {
                      _recordingTimer?.cancel();
                      setState(() {
                        recordingTime = Duration.zero;
                      });
                    },
                  )
                : const SizedBox()));
  }

  Widget _customDialog() {
    // AnimatedSwitcher between dialog and mediaControlButton has some position issue
    return Positioned(
        bottom: 32,
        right: 32,
        child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 1.0),
                  end: const Offset(0.0, 0.0),
                ).animate(animation),
                child: child,
              );
            },
            child: dialog != null
                ? CustomDialog(
                    text: dialog!.text,
                    eventKey: dialog!.eventKey,
                    buttonSky: dialog!.buttonSky,
                    buttonSkyTask: dialog!.buttonSkyTask,
                    buttonOrange: dialog!.buttonOrange,
                    buttonOrangeTask: dialog!.buttonOrangeTask,
                    automaticTask: dialog!.automaticTask,
                  )
                : const SizedBox()));
  }

  Widget recordingInfo() {
    var db = DatabaseService();
    return buildAnimatedPositioned(
      isMovedAway: isMovedAway,
      bottom: 32,
      left: 32,
      child: Text.rich(
        TextSpan(
          style: TextStyle(
              color: customSky,
              fontSize: 26,
              fontFamily: subFont,
              fontWeight: FontWeight.w600),
          text: 'LOG ENTRY:  ${formatInt(db.pastEntries.length + 1)}\n',
          children: <TextSpan>[
            TextSpan(
              text: 'TIME:  ${formatDuration(recordingTime)}\n',
            ),
            TextSpan(
              text: 'DATE:  ${DateFormat('MM/dd/yyyy').format(DateTime.now())}',
            ),
          ],
        ),
      ),
    );
  }

  Widget pastEntryMetadata() {
    return Positioned(
        top: 32,
        right: 32,
        child: MetadataWidget(
          metadata: selectedMetadata!,
        ));
  }

  Widget writingStateMessage(
      {required WritingState writingState, required bool rendering}) {
    bool showMessage = writingState != WritingState.idle && !rendering;
    return AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: showMessage
            ? messageWidget(writingState.toName(), true, true)
            : const SizedBox());
  }


  Widget menuTaps({required bool recording}) {
    return buildAnimatedPositioned(
        isMovedAway: isMovedAway,
        top: 32.0,
        left: 32.0,
        child: recording
            ? recordingIndicator()
            : SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tabs(
                      buttonLabels: const [
                        TabItem.mainCam,
                        TabItem.pastEntries,
                        TabItem.settings,
                      ],
                      onTabSelected: (tabItem_) {
                        tabItem.add(tabItem_);
                        if (tabItem_ != TabItem.pastEntries) {
                          setState(() {
                            selectedMetadata = null;
                          });
                        }
                      },
                    ),
                    TabItemWidget(tabItem: tabItem),
                  ],
                ),
              ));
  }
}

Widget buildAnimatedPositioned({
  required bool isMovedAway,
  required Widget child,
  Duration duration = const Duration(milliseconds: 500),
  Curve curve = Curves.easeInOut,
  double? top,
  double? bottom,
  double? left,
  double? right,
}) {
  const double offset = 200;
  return AnimatedPositioned(
    duration: duration,
    curve: curve,
    top: top != null ? (isMovedAway ? top - offset : top) : null,
    left: left != null ? (isMovedAway ? left - offset : left) : null,
    right: right != null ? (isMovedAway ? right - offset : right) : null,
    bottom: bottom != null ? (isMovedAway ? bottom - offset : bottom) : null,
    child: child,
  );
}
