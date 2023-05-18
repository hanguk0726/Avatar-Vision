import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/services/event_bus.dart';
import 'package:video_diary/services/native.dart';
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
import '../widgets/tabItem.dart';
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
  Timer? _timer;
  Duration recordingTime = Duration.zero;
  bool showTipContent = false;
  @override
  void initState() {
    super.initState();
    tabItem.add(RuntimeData().currentTab);
    _eventSubscription = EventBus().onEvent.listen((event) {
      if (event.key != "pastEntries" && event.key != "tab") {
        return;
      }
      if (event.event is KeyboardEvent) {
        if (event.event == KeyboardEvent.keyboardControlSpace) {
          final recording = context.read<Native>().recording;
          clearUi(recording, !isMovedAway);
          return;
        }
      }
      if (event.event is MetadataEvent) {
        MetadataEvent casted = event.event as MetadataEvent;
        // add data
        int timestamp = casted.timestamp;
        final queryResult =
            DatabaseService().findByOsFileName(gererateFileName(timestamp));
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
      }
    });
  }

  void startTimter() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        recordingTime = recordingTime + const Duration(seconds: 1);
      });
    });
  }

  @override
  void dispose() {
    tabItem.close();
    _eventSubscription.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final native = context.watch<Native>();
    final writingState = native.writingState;
    final recording = native.recording;
    final rendering = native.rendering;
    final currentCameraDevice = native.currentCameraDevice;
    final cameraHealthCheck = native.cameraHealthCheck;
    final cameraHealthCheckErrorMessage = native.cameraHealthCheckErrorMessage;
    final width = native.currentResolutionWidth;
    final height = native.currentResolutionHeight;
    final recordingHealthCheck = native.recordingHealthCheck;

    List<CustomError> errors = [
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
            width: width,
            height: height,
            child: Stack(children: [
              Container(), //empty container for the background
              AnimatedOpacity(
                  duration: const Duration(milliseconds: 700),
                  opacity: rendering ? 1 : 0,
                  child: texture(width, height)),
              if (currentCameraDevice.isEmpty) messageNoCameraFound(),
              if (recording) recordingInfo(),
              about(),
              tip(),
              showMessageOnError(errors),
              menuTaps(recording: recording),
              _mediaControlButton(),
              pastEntryMetadata(recording: recording),
              writingStateMessage(
                  writingState: writingState,
                  recording: recording,
                  rendering: rendering),
              if (showTipContent)
                Positioned(
                  top: 82,
                  right: 82,
                  child: tipContent(),
                )
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
    var setting = Setting();
    if (!setting.tip) return const SizedBox();
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
      child: mediaControlButton(
          context: context,
          onRecordStart: startTimter,
          onRecordStop: () {
            _timer?.cancel();
            setState(() {
              recordingTime = Duration.zero;
            });
          }),
    );
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

  Widget showMessageOnError(List<CustomError> errors) {
    if (errors.any((error) => error.occurred)) {
      return messageOnError(
          error: errors.firstWhere((error) => error.occurred));
    } else {
      return const SizedBox();
    }
  }

  Widget pastEntryMetadata({required bool recording}) {
    if (recording || selectedMetadata == null) {
      return const SizedBox();
    } else {
      return Positioned(
          top: 32,
          right: 32,
          child: MetadataWidget(
            metadata: selectedMetadata!,
          ));
    }
  }

  Widget writingStateMessage(
      {required WritingState writingState,
      required bool recording,
      required bool rendering}) {
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

    // return Positioned(
    //     top: 32,
    //     right: 32,
    //     child: SavingIndicator(
    //       recording: recording,
    //       writingState: writingState,
    //     ));
  }

  Widget messageNoCameraFound() {
    return Center(
        child: Text("No camera devices found",
            style: TextStyle(
                color: Colors.white, fontFamily: mainFont, fontSize: 32)));
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
