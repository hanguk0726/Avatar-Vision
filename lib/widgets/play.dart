//declare stateful widget name Play

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/widgets/window.dart';

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
  final Player player = Player();
  VideoController? controller;
  bool isFullscreen = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    Future.microtask(() async {
      await controller?.dispose();
      await player.dispose();
    });
    super.dispose();
  }

  void init() async {
    Future.microtask(() async {
      controller = await VideoController.create(player);
      await player.open(Media(widget.filePath));
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Video(
            controller: controller,
            fit: BoxFit.fill,
          ),
          header(),
          mediaControllBar(),
        ],
      ),
    );
  }

  // Widget overlay() {
  //   return FutureBuilder<Size>(
  //       future: windowManager.getSize(),
  //       builder: (BuildContext context, AsyncSnapshot<Size> snapshot) {
  //         if (snapshot.hasData) {
  //           return Container(
  //             color:  Colors.grey.withOpacity(0.1),
  //             width: snapshot.data!.width,
  //             height: snapshot.data!.height,
  //             child: fullscreen(),
  //           );
  //         } else {
  //           return const SizedBox();
  //         }
  //       });
  // }

  Widget header() {
    return Positioned(
        left: 32,
        top: 32,
        child: boxWidget(
            color: customSky,
            backgroundColor: customOcean,
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoButton(
                      child: const Icon(
                        Icons.arrow_back_sharp,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (isFullscreen) {
                          FullScreenWindow.setFullScreen(false);
                          isFullscreen = false;
                          setState(() {});
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    Flexible(
                        child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              widget.fileName,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: mainFont,
                                  fontSize: 18),
                            ))),
                    const SizedBox(width: 32),
                  ],
                ))));
  }

  Widget mediaControllBar() {
    if (controller == null) {
      return const SizedBox();
    }
    double size = 32;
    Color color = customSky;

    var forward = CupertinoButton(
      child: Icon(Icons.forward_10_sharp, color: color, size: size),
      onPressed: () {},
    );

    var back = CupertinoButton(
      child: Icon(Icons.replay_10_sharp, color: color, size: size),
      onPressed: () {
        // Back 10 seconds logic
      },
    );

    var play = CupertinoButton(
      child: Icon(Icons.play_arrow_sharp, color: color, size: size + 12),
      onPressed: () {
        controller!.player.play();
        setState(() {});
      },
    );

    var pause = CupertinoButton(
      child: Icon(Icons.pause_sharp, color: color, size: size + 12),
      onPressed: () {
        controller!.player.pause();
        setState(() {});
      },
    );
    var volume = CupertinoButton(
      child: Icon(Icons.volume_up_sharp, color: customSky, size: 32),
      onPressed: () {},
    );

    var fullscreen = CupertinoButton(
      child: Icon(
          isFullscreen ? Icons.fullscreen_exit_sharp : Icons.fullscreen_sharp,
          color: customSky,
          size: 32),
      onPressed: () async {
        FullScreenWindow.setFullScreen(!isFullscreen);
        isFullscreen = !isFullscreen;
        setState(() {});
        // At the moment, the windowManager has a bug in its fullscreen feature, which is problematic for the video player.
        // https://github.com/leanflutter/window_manager/issues/228
      },
    );

    var padding = const SizedBox(width: 32);
    return Positioned(
      bottom: 32,
      left: 32,
      right: 32,
      child: Align(
          alignment: Alignment.bottomCenter,
          child: Row(
            children: [
              boxWidget(
                  color: customSky,
                  backgroundColor: customOcean,
                  child: volume),
              const Spacer(),
              boxWidget(
                  color: customSky,
                  backgroundColor: customOcean,
                  child: SizedBox(
                      width: 400,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          back,
                          padding,
                          controller!.player.state.playing ? pause : play,
                          padding,
                          forward,
                        ],
                      ))),
              const Spacer(),
              boxWidget(
                  color: customSky,
                  backgroundColor: customOcean,
                  child: fullscreen)
            ],
          )),
    );
  }
}
