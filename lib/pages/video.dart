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
    final writingState = native.writingState;
    final recording = native.recording;
    final rendering = native.rendering;
    final currentCameraDevice = native.currentCameraDevice;
    final currentAudioDevice = native.currentAudioDevice;
    final audioDevices = native.audioDevices;
    final cameraDevices = native.cameraDevices;
    final cameraHealthCheck = native.cameraHealthCheck;

    bool showSavingIndicator =
        rendering && !recording && writingState != WritingState.idle;
    bool showRenderButton = writingState == WritingState.idle &&
        !rendering &&
        currentCameraDevice.isNotEmpty;
    bool showMediaControlButton = currentCameraDevice.isNotEmpty && rendering;

    return Consumer<Native>(builder: (context, provider, child) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: customNavy,
        drawerScrimColor: Colors.transparent,
        body: Stack(children: [
          //empty container for the background
          Container(),
          if (rendering) texture(),
          // else if (writingState != WritingState.idle)
          //   message(writingState.toName(), true, true),
          // if (showSavingIndicator)
          //   _savingIndicator(
          //     recording: recording,
          //     writingState: writingState,
          //   ),
          // if (currentCameraDevice.isEmpty)
          //   const Center(child: Text("No camera devices found")),
          // if (!cameraHealthCheck)
          //   Center(
          //     child: message(
          //         "The camera device has encountered an error.\nPlease pull out the usb and reconnect it.",
          //         false,
          //         false,
          //         icon: Icon(
          //           Icons.error_outline,
          //           color: customGrey,
          //           size: 100.0,
          //         )),
          //   ),
          Padding(
              padding: const EdgeInsets.only(top: 32, left: 32),
              child: Column(
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
              child: mediaControlButton(context: context))
        ]),
      );
    });
  }
}

Widget _savingIndicator(
    {required bool recording, required WritingState writingState}) {
  return Positioned(
      top: 8,
      left: 16,
      child: SavingIndicator(
        recording: recording,
        writingState: writingState,
      ));
}

Widget _renderButton() {
  return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Center(
          child: ElevatedButton(
        onPressed: Native().startCamera,
        child: const Text('Render'),
      )));
}
