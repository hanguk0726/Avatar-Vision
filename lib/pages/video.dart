import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/services/native.dart';
import 'package:video_diary/widgets/dropdown.dart';

import '../domain/writing_state.dart';
import '../widgets/media_conrtol_bar.dart';
import '../widgets/saving_indicator.dart';
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
    final rendering = native.rendering;
    final currentAudioDevice = native.currentAudioDevice;
    final audioDevices = native.audioDevices;
    final currentCameraDevice = native.currentCameraDevice;
    final cameraDevices = native.cameraDevices;

    bool showSavingIndicator =
        rendering && !recording && writingState != WritingState.idle;
    bool showRenderButton = writingState == WritingState.idle &&
        !rendering &&
        currentCameraDevice.isNotEmpty;
    bool showMediaControlButton = currentCameraDevice.isNotEmpty && rendering;

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
        endDrawer: _drawer(
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
          if (rendering)
            texture()
          else if (writingState != WritingState.idle)
            loadingIndicator(writingState
                .toName()),  
          if (showSavingIndicator)
            _savingIndicator(
              recording: recording,
              writingState: writingState,
            ),
          if (recording) _recordingIndicator(),
          if (showRenderButton) _renderButton(),
          if (showMediaControlButton)
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

Widget _recordingIndicator() {
  return const Positioned(
    top: 8,
    right: 16,
    child: Text(
      "REC",
      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
    ),
  );
}

Widget _drawer(
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
