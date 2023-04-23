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
          fullscreen(),
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

  Widget fullscreen() {
    return Positioned(
      right: 32,
      bottom: 32,
      child: boxWidget(
          color: customSky,
          backgroundColor: customOcean,
          child: CupertinoButton(
            child: Icon(
                isFullscreen
                    ? Icons.fullscreen_exit_sharp
                    : Icons.fullscreen_sharp,
                color: customSky,
                size: 32),
            onPressed: () async {
              FullScreenWindow.setFullScreen(!isFullscreen);
              isFullscreen = !isFullscreen;
              setState(() {});
              // At the moment, the windowManager has a bug in its fullscreen feature, which is problematic for the video player.
              // https://github.com/leanflutter/window_manager/issues/228
            },
          )),
    );
  }

  Widget mediaControllBar() {
    if (controller == null) {
      return const SizedBox();
    }
    Color color = customSky;
    var forward = IconButton(
      icon: Icon(
        Icons.forward_10_sharp,
        color: color,
      ),
      onPressed: () {},
    );
    var back = IconButton(
      icon: Icon(
        Icons.replay_10_sharp,
        color: color,
      ),
      onPressed: () {
        // Back 10 seconds logic
      },
    );

    var play = IconButton(
      icon: Icon(
        Icons.play_arrow_sharp,
        color: color,
      ),
      onPressed: () {
        controller!.player.play();
        setState(() {});
      },
    );
    var pause = IconButton(
      icon: Icon(
        Icons.pause_sharp,
        color: color,
      ),
      onPressed: () {
        controller!.player.pause();
        setState(() {});
      },
    );

    return Positioned(
        bottom: 32,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 400
          ),
          child: boxWidget(
              color: customSky,
              backgroundColor: customOcean,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  back,
                  controller!.player.state.playing ? pause : play,
                  forward,
                ],
              )),
        ));
  }
}
