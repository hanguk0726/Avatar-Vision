import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/domain/setting.dart';
import 'package:video_diary/services/native.dart';
import 'package:video_diary/widgets/dropdown.dart';
import 'package:video_diary/widgets/media_conrtol_bar.dart';

import '../domain/writing_state.dart';
import '../widgets/button.dart';
import '../widgets/indicator.dart';
import '../widgets/tab.dart';
import '../widgets/tabItem.dart';
import '../widgets/texture.dart';
import '../widgets/waveform.dart';

final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

class Video extends StatelessWidget {
  const Video({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Video Diary',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const VideoState(title: 'Video Page'),
    );
  }
}

class VideoState extends StatefulWidget {
  final String title;

  const VideoState({Key? key, required this.title}) : super(key: key);

  @override
  State<VideoState> createState() => _VideoStateState();
}

class _VideoStateState extends State<VideoState> {
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

    bool noWritingStateIndicator =
        writingState.toName() == WritingState.idle.toName() ||
            (writingState.toName() == WritingState.collecting.toName() &&
                rendering);

    return Consumer<Native>(builder: (context, provider, child) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: customBlack,
        drawerScrimColor: Colors.transparent,
        body: Stack(children: [
          Container(), //empty container for the background
          if (rendering) texture(width, height),
          if (currentCameraDevice.isEmpty)
            Center(
                child: Text("No camera devices found",
                    style: TextStyle(
                        color: Colors.white,
                        fontFamily: mainFont,
                        fontSize: 32))),
          if (!cameraHealthCheck)
            Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    message(
                        "The camera device has encountered an error.\nPlease pull out the usb and reconnect it.",
                        false,
                        false,
                        icon: Icon(
                          Icons.error_outline,
                          color: customOrange,
                          size: 100.0,
                        )),
                    Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(cameraHealthCheckErrorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontFamily: mainFont,
                                fontSize: 24)))
                  ]),
            ),
          Padding(
              padding: const EdgeInsets.only(top: 32, left: 32),
              child: recording
                  ? recordingIndicator()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tabs(
                          buttonLabels: const [
                            TabItem.mainCam,
                            TabItem.pastEntries,
                            TabItem.submut,
                            TabItem.settings,
                          ],
                          onTabSelected: (tabItem_) => tabItem.add(tabItem_),
                        ),
                        TabItemWidget(tabItem: tabItem)
                      ],
                    )),
          Positioned(
              bottom: 32,
              right: 32,
              child: mediaControlButton(context: context)),

          if (noWritingStateIndicator)
            const SizedBox()
          else if (renderingWhileEncoding)
            Positioned(
                top: 32,
                right: 32,
                child: SavingIndicator(
                  recording: recording,
                  writingState: writingState,
                ))
          else
            message(writingState.toName(), true, true)
        ]),
      );
    });
  }
}
