import 'package:flutter/material.dart';
import 'package:video_diary/services/native.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Stack(children: [
        texture(),
        mediaControlBar(
          onStart: () {
            Native()
              ..openCameraStream()
              ..renderTexture()
              ..startAudioRecord()
              ..startEncoding();
          },
          onStop: () {
            Native().stopAudioRecord();
            //delay 1s //FIXME
            Future.delayed(const Duration(seconds: 1), () {
              Native().stopCameraStream();
            });
          },
        ),
      ]),
    );
  }
}
