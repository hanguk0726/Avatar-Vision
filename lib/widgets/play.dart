//declare stateful widget name Play

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
    // screenManager: const ScreenManager(forceLandScapeInFullscreen: false),
    enabledControls: const EnabledControls(),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      init();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void init() async {
    File file = File(widget.filePath);

    _controller.setDataSource(
        DataSource(
          file: file,
          type: DataSourceType.file,
        ),
        autoplay: true);
  }

  Widget get header {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          CupertinoButton(
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
            onPressed: () {
              // close the fullscreen
              Navigator.pop(context);
            },
          ),
          Expanded(
            child: Text(
              widget.fileName,
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: MeeduVideoPlayer(
            controller: _controller,
          ),
        ),
      ),
    );
  }
}
