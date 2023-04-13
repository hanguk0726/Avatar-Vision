import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/widgets/waveform.dart';

import '../domain/assets.dart';
import '../domain/setting.dart';
import '../services/native.dart';
import 'dropdown.dart';

class TabItemWidget extends StatefulWidget {
  final BehaviorSubject<TabItem> tabItem;

  const TabItemWidget({
    Key? key,
    required this.tabItem,
  }) : super(key: key);

  @override
  TabItemWidgetState createState() => TabItemWidgetState();
}

class TabItemWidgetState extends State<TabItemWidget> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TabItem>(
      stream: widget.tabItem,
      initialData: TabItem.mainCam,
      builder: (context, snapshot) {
        final tabItem = snapshot.data;
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildTabItem(tabItem, context),
        );
      },
    );
  }
}

Widget _buildTabItem(TabItem? tabItem, BuildContext context) {
  switch (tabItem) {
    case TabItem.mainCam:
      return _recordingIndicator(context);
    case TabItem.settings:
      return _settings(context);
    default:
      return _recordingIndicator(context);
  }
}

Widget _recordingIndicator(BuildContext context) {
  // final native = Provider.of<Native>(context);
  // final recording = native.recording;
  // if (!recording) {
  //   return const SizedBox();
  // }
  Color seeThroughBlue = Colors.transparent;

  Color vividBlue = Color.fromARGB(255, 255, 49, 56).withOpacity(0.8);
  return FittedBox(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          "REC",
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: mainFont,
              fontSize: 24),
        ),
        const SizedBox(width: 8),
        //circle clip
        ClipOval(
          child: Container(
            width: 24,
            height: 24,
            color: vividBlue,
            foregroundDecoration: BoxDecoration(
              color: seeThroughBlue,
              backgroundBlendMode: BlendMode.hardLight,
            ),
          ),
        )
      ],
    ),
  );
}

Widget _settings(BuildContext context) {
  const width = 500.0;
  const color = Colors.white;
  const spacer = SizedBox(height: 24);
  final native = Provider.of<Native>(context);
  final setting = Provider.of<Setting>(context);
  final currentCameraDevice = native.currentCameraDevice;
  final currentAudioDevice = native.currentAudioDevice;
  final audioDevices = native.audioDevices;
  final cameraDevices = native.cameraDevices;
  Color backgroundColor = customSky;
  onChangedAudioDevice(value) {
    Native().selectAudioDevice(value);
  }

  onChangedCameraDevice(value) {
    Native().selectCameraDevice(value);
  }

  return SizedBox(
      width: width,
      child: ClipRRect(
          child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor.withOpacity(0.2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                        child: Row(
                          children: [
                            IconButton(
                                icon: const Icon(Icons.refresh),
                                color: color,
                                onPressed: () async {
                                  await Native().queryDevices();
                                }),
                            const Spacer(),
                          ],
                        ),
                      ),
                      spacer,
                      dropdown(
                          value: currentAudioDevice,
                          items: audioDevices,
                          onChanged: onChangedAudioDevice,
                          icon: const Icon(
                            Icons.mic,
                            color: color,
                          ),
                          textOnEmpty: "No audio input devices found",
                          iconOnEmpty: const Icon(Icons.mic_off, color: color),
                          textColor: color),
                      if (currentAudioDevice.isNotEmpty)
                        Waveform(
                          height: 100,
                          width: 300,
                          durationMillis: 500,
                        ),
                      spacer,
                      dropdown(
                          value: currentCameraDevice,
                          items: cameraDevices,
                          onChanged: onChangedCameraDevice,
                          icon: const Icon(Icons.camera_alt, color: color),
                          textOnEmpty: "No camera devices found",
                          iconOnEmpty:
                              const Icon(Icons.no_photography, color: color),
                          textColor: color),
                      spacer,
                      spacer,
                      Tooltip(
                          message:
                              'Depending on the cpu specification, This may increase encoding time',
                          preferBelow: true,
                          child: Padding(
                            padding:
                                const EdgeInsets.only(left: 16.0, right: 16.0),
                            child: Row(
                              children: [
                                const Text("Render while recording",
                                    style:
                                        TextStyle(color: color, fontSize: 16)),
                                const Spacer(),
                                Switch(
                                  value: setting.renderingWhileEncoding,
                                  activeColor: customSky,
                                  onChanged: (value) {
                                    setting.toggleRenderingWhileEncoding();
                                  },
                                ),
                              ],
                            ),
                          )),
                    ],
                  )))));
}

enum TabItem {
  mainCam('MAIN CAM'),
  pastEntries('PAST ENTRIES'),
  submut('SUBMIT'),
  settings('SETTINGS');

  final String name;

  const TabItem(this.name);
}
