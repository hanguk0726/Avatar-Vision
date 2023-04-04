import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_diary/services/native.dart';

import '../domain/writing_state.dart';
import '../widgets/saving_indicator.dart';
import '../widgets/media_conrtol_bar.dart';
import '../widgets/texture.dart';

class Video extends StatelessWidget {
  const Video({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Native().observeAudioBuffer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final native = context.watch<Native>();
    final writingState = native.writingState;
    final recording = native.recording;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
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
