import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_diary/services/native.dart';

import '../widgets/dashbord.dart';
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
  final ValueNotifier<bool> writingNotifier = ValueNotifier(Native().writing);
  final ValueNotifier<bool> recordingNotifier =
      ValueNotifier(Native().recording);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {});
  }

  void _onNativeChange() {
    // Update the notifiers with the new values
    writingNotifier.value = Native().writing;
    recordingNotifier.value = Native().recording;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(children: [
        texture(),
        if (context.watch<Native>().writing)
          const Positioned(
            top: 8,
            left: 16,
            child: SavingIndicator(),
          ),
        if (context.watch<Native>().recording)
          const Positioned(
            top: 8,
            right: 16,
            child: Text(
              "REC",
              style: TextStyle(color: Colors.red),
            ),
          ),
        mediaControlBar(
          onStart: () {
            Native().startRecording();
          },
          onStop: () {
            Native().stopRecording();
            Native().reset();
          },
        ),
      ]),
    );
  }
}
