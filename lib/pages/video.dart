import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/domain/setting.dart';
import 'package:video_diary/services/event_bus.dart';
import 'package:video_diary/services/native.dart';
import 'package:video_diary/widgets/media_conrtol_bar.dart';
import 'package:video_diary/widgets/message.dart';

import '../domain/error.dart';
import '../domain/event.dart';
import '../domain/writing_state.dart';
import '../tools/custom_scroll_behavior.dart';
import '../widgets/indicator.dart';
import '../widgets/tab.dart';
import '../widgets/tabItem.dart';
import '../widgets/texture.dart';

final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKey: (event) {
        var e = rawKeyEventToEvent(event);
        if (e != null) {
          EventBus().fire(e);
        }
      },
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Video Diary',
        scrollBehavior: CustomScrollBehavior(),

        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const Video(),
      ),
    );
  }
}

class Video extends StatefulWidget {
  const Video({super.key});

  @override
  State<Video> createState() => _VideoState();
}

class _VideoState extends State<Video> {
  BehaviorSubject<TabItem> tabItem = BehaviorSubject<TabItem>();

  @override
  void dispose() {
    tabItem.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final native = context.watch<Native>();
    final setting = context.watch<Setting>();
    final writingState = native.writingState;
    final recording = native.recording;
    final rendering = native.rendering;
    final currentCameraDevice = native.currentCameraDevice;
    final cameraHealthCheck = native.cameraHealthCheck;
    final cameraHealthCheckErrorMessage = native.cameraHealthCheckErrorMessage;
    final renderingWhileEncoding = setting.renderingWhileEncoding;
    final width = native.currentResolutionWidth;
    final height = native.currentResolutionHeight;
    final recordingHealthCheck = native.recordingHealthCheck;

    bool noWritingStateIndicator = writingState == WritingState.idle ||
        (writingState == WritingState.collecting && rendering);

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
      body: Center(
          child: SizedBox(
        width: width,
        height: height,
        child: Stack(children: [
          Container(), //empty container for the background
          if (rendering) texture(width, height),
          if (currentCameraDevice.isEmpty) messageNoCameraFound(),
          showMessageOnError(errors),
          menuTaps(recording: recording),
          _mediaControlButton(),
          writingStateMessage(
              writingState: writingState,
              recording: recording,
              renderingWhileEncoding: renderingWhileEncoding,
              noWritingStateIndicator: noWritingStateIndicator),
        ]),
      )),
    );
  }

  Widget _mediaControlButton() {
    return Positioned(
        bottom: 32, right: 32, child: mediaControlButton(context: context));
  }

  Widget showMessageOnError(List<CustomError> errors) {
    if (errors.any((error) => error.occurred)) {
      return messageOnError(
          error: errors.firstWhere((error) => error.occurred));
    } else {
      return const SizedBox();
    }
  }

  Widget writingStateMessage(
      {required WritingState writingState,
      required bool recording,
      required bool renderingWhileEncoding,
      required bool noWritingStateIndicator}) {
    if (noWritingStateIndicator) {
      return const SizedBox();
    } else if (renderingWhileEncoding) {
      return Positioned(
          top: 32,
          right: 32,
          child: SavingIndicator(
            recording: recording,
            writingState: writingState,
          ));
    } else {
      return messageWidget(writingState.toName(), true, true);
    }
  }

  Widget messageNoCameraFound() {
    return Center(
        child: Text("No camera devices found",
            style: TextStyle(
                color: Colors.white, fontFamily: mainFont, fontSize: 32)));
  }

  Widget menuTaps({required bool recording}) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, left: 32),
      child: recording
          ? recordingIndicator()
          : SingleChildScrollView(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Tabs(
                  buttonLabels: const [
                    TabItem.mainCam,
                    TabItem.pastEntries,
                    TabItem.submit,
                    TabItem.settings,
                  ],
                  onTabSelected: (tabItem_) => tabItem.add(tabItem_),
                ),
                TabItemWidget(tabItem: tabItem),
              ],
            )),
    );
  }
}
