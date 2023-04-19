//declare stateful widget name Play

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_meedu_videoplayer/meedu_player.dart';

class Play extends StatefulWidget {
  final String filePath;
  final String fileName;
  final Function() onPlay;

  const Play({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.onPlay,
  });
  @override
  PlayState createState() => PlayState();
}

class PlayState extends State<Play> {
  final _controller = MeeduPlayerController(
    screenManager: const ScreenManager(forceLandScapeInFullscreen: false),
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    play();
  }

  void play() async {
    File file = File(widget.filePath);
    _controller.launchAsFullscreen(
      context,
      autoplay: true,
      dataSource: DataSource(
        file: file,
        type: DataSourceType.file,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
