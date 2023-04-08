import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/services/native.dart';
import 'package:video_diary/widgets/dropdown.dart';

import '../domain/writing_state.dart';
import '../widgets/saving_indicator.dart';
import '../widgets/media_conrtol_bar.dart';
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
      home: const MyHomePage(title: 'Video Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({Key? key, required this.title}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    final native = context.watch<Native>();
    final writingState = native.writingState;
    final recording = native.recording;
    final currentAudioDevice = native.currentAudioDevice;
    final audioDevices = native.audioDevices;
    final currentCameraDevice = native.currentCameraDevice;
    final cameraDevices = native.cameraDevices;

    return Consumer<Native>(builder: (context, provider, child) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('My App'),
          actions: <Widget>[
            if (recording)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Icon(Icons.do_not_disturb),
              )
            else
              Builder(
                builder: (BuildContext context) {
                  return IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      Scaffold.of(context).openEndDrawer();
                    },
                  );
                },
              ),
          ],
        ),
        endDrawer: drawer(
            context: context,
            currentAudioDevice: currentAudioDevice,
            audioDevices: audioDevices,
            onChangedAudioDevice: (value) {
              Native().selectAudioDevice(value);
            },
            currentCameraDevice: currentCameraDevice,
            cameraDevices: cameraDevices,
            onChangedCameraDevice: (value) {
              Native().selectCameraDevice(value);
            }),
        drawerScrimColor: Colors.transparent,
        body: Stack(children: [
          texture(),
          if (!recording && writingState != WritingState.idle)
            Positioned(
                top: 8,
                left: 16,
                child: SavingIndicator(
                  recording: recording,
                  writingState: writingState,
                )),
          if (recording)
            const Positioned(
              top: 8,
              right: 16,
              child: Text(
                "REC",
                style: TextStyle(color: Colors.red),
              ),
            ),
          if (currentCameraDevice.isNotEmpty)
            mediaControlBar(
              recording: recording,
              onStart: () {
                Native().startRecording();
              },
              onStop: () {
                Native().stopRecording();
              },
            ),
          if (currentCameraDevice.isEmpty)
            const Center(child: Text("No camera devices found")),
        ]),
      );
    });
  }
}

Widget drawer(
    {required BuildContext context,
    required String currentAudioDevice,
    required List<String> audioDevices,
    required Function(String) onChangedAudioDevice,
    required String currentCameraDevice,
    required List<String> cameraDevices,
    required Function(String) onChangedCameraDevice}) {
  BehaviorSubject<bool> hasAudio = BehaviorSubject.seeded(false);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Native().observeAudioBuffer((hasAudio_) {
      hasAudio.add(hasAudio_);
    });
  });
  return Drawer(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        DrawerHeader(
          decoration: const BoxDecoration(
            color: Colors.blue,
          ),
          child: Row(
            children: [
              const Text(
                'Drawer Header',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () async {
                    await Native().queryDevices();
                  }),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.pop(context);
                  })
            ],
          ),
        ),
        dropdown(
            value: currentAudioDevice,
            items: audioDevices,
            onChanged: onChangedAudioDevice,
            icon: const Icon(Icons.mic),
            textOnEmpty: "No audio input devices found",
            iconOnEmpty: const Icon(Icons.mic_off)),
        Waveform(
          hasAudio: hasAudio,
          height: 100,
          width: 270,
          durationMillis: 500,
        ),
        dropdown(
            value: currentCameraDevice,
            items: cameraDevices,
            onChanged: onChangedCameraDevice,
            icon: const Icon(Icons.camera_alt),
            textOnEmpty: "No camera devices found",
            iconOnEmpty: const Icon(Icons.no_photography)),
      ],
    ),
  );
}
