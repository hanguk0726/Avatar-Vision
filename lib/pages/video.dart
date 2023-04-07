import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_diary/services/native.dart';
import 'package:video_diary/widgets/dropdown.dart';

import '../domain/writing_state.dart';
import '../widgets/saving_indicator.dart';
import '../widgets/media_conrtol_bar.dart';
import '../widgets/texture.dart';
import '../widgets/waveform.dart';

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
    final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: scaffoldKey,
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
          onChanged: (value) {
            Native().selectAudioDevice(value);
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
        if (scaffoldKey.currentState?.isEndDrawerOpen ?? false == false)
          mediaControlBar(
            recording: recording,
            onStart: () {
              Native().startRecording();
            },
            onStop: () {
              Native().stopRecording();
            },
          ),
      ]),
    );
  }
}

Widget drawer(
    {required BuildContext context,
    required String currentAudioDevice,
    required List<String> audioDevices,
    required Function(String) onChanged}) {
  bool audioActive = true;
  // WidgetsBinding.instance.addPostFrameCallback((_) {
  //   Native().observeAudioBuffer((samples) {
  //     if (samples.isNotEmpty || samples.every((element) => element == 0)) {
  //       audioActive = false;
  //     } else {
  //       audioActive = true;
  //     }
  //     print ("audioActive: $audioActive");
  //   });
  // });
  return Drawer(
    child: ListView(
      padding: EdgeInsets.zero,
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
            onChanged: onChanged,
            icon: const Icon(Icons.mic),
            textOnEmpty: "No audio input devices found",
            iconOnEmpty: const Icon(Icons.mic_off)),
        Waveform(
          audioActive: audioActive,
          height: 100,
          width: 300,
          durationMillis: 500,
        ),
      ],
    ),
  );
}
