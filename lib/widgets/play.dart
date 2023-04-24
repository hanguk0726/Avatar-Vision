//declare stateful widget name Play

import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:slider_controller/slider_controller.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/widgets/window.dart';

import '../domain/event.dart';
import '../services/event_bus.dart';

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
  late StreamSubscription<Event> _eventSubscription;
  final Player player = Player();
  VideoController? controller;
  bool isFullscreen = false;
  double volume = 100;
  bool muted = false;
  Duration playtime = const Duration(seconds: 0);
  Duration position = const Duration(seconds: 0);
  @override
  void initState() {
    super.initState();
    initVideo();
    initKeyboradEvent();
    player.streams.volume.listen((e) => setState(() {
          volume = e;
        }));
    player.streams.duration.listen((e) => setState(() {
          playtime = e;
        }));
    player.streams.position.listen((e) => setState(() {
          position = e;
        }));
  }

  void initKeyboradEvent() {
    _eventSubscription = EventBus().onEvent.listen((event) {
      switch (event) {
        case Event.keyboardControlArrowUp:
          setVolume(volume + 10);
          break;
        case Event.keyboardControlArrowDown:
          setVolume(volume - 10);
          break;

        case Event.keyboardControlArrowLeft:
          controller!.player.seek(
              controller!.player.state.position - const Duration(seconds: 10));
          break;
        case Event.keyboardControlArrowRight:
          controller!.player.seek(
              controller!.player.state.position + const Duration(seconds: 10));
          break;
        case Event.keyboardControlM:
          if (muted) {
            controller!.player.setVolume(100);
            muted = false;
          } else {
            controller!.player.setVolume(0);
            muted = true;
          }
          setState(() {});
          break;
        case Event.keyboardControlF:
          FullScreenWindow.setFullScreen(!isFullscreen);
          isFullscreen = !isFullscreen;
          setState(() {});
          break;

        case Event.keyboardControlSpace:
          if (controller!.player.state.playing) {
            controller!.player.pause();
          } else {
            controller!.player.play();
          }
          setState(() {});
          break;
        case Event.keyboardControlBackspace:
          Navigator.pop(context);
          break;

        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    Future.microtask(() async {
      await controller?.dispose();
      await player.dispose();
    });
    _eventSubscription.cancel();
    super.dispose();
  }

  void initVideo() async {
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

  void setVolume(double value) {
    if (value > 100) {
      value = 100;
    }
    if (value < 0) {
      value = 0;
    }
    volume = value;
    controller!.player.setVolume(value);
    if (volume == 0) {
      muted = true;
    } else {
      muted = false;
    }
    setState(() {});
  }

  Widget playProgressbar() {
    return ProgressBar(
      progress: position,
      buffered: playtime,
      total: playtime,
      barCapShape: BarCapShape.square,
      timeLabelLocation: TimeLabelLocation.none,
      progressBarColor: customOrange,
      baseBarColor: Colors.transparent,
      bufferedBarColor: customOcean.withOpacity(0.5),
      thumbColor: Colors.transparent,
      thumbGlowColor: Colors.transparent,
      onSeek: (duration) {
        controller!.player.seek(duration);
      },
    );
  }

  Widget mediaControllBar() {
    if (controller == null) {
      return const SizedBox();
    }
    double size = 32;
    Color color = customSky;

    var forward = CupertinoButton(
      child: Icon(Icons.forward_10_sharp, color: color, size: size),
      onPressed: () {
        controller!.player.seek(
            controller!.player.state.position + const Duration(seconds: 10));
      },
    );

    var back = CupertinoButton(
      child: Icon(Icons.replay_10_sharp, color: color, size: size),
      onPressed: () {
        controller!.player.seek(
            controller!.player.state.position - const Duration(seconds: 10));
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
    var volumeWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          child: Icon(muted ? Icons.volume_off_sharp : Icons.volume_up_sharp,
              color: customSky, size: size),
          onPressed: () {
            if (muted) {
              controller!.player.setVolume(100);
              muted = false;
            } else {
              controller!.player.setVolume(0);
              muted = true;
            }
            setState(() {});
          },
        ),
        SizedBox(
          width: 96,
          child: SliderController(
            value: volume,
            sliderDecoration: SliderDecoration(
                isThumbVisible: false,
                activeColor: customSky,
                inactiveColor: customOcean,
                borderRadius: 0,
                height: 8,
                thumbHeight: 0),
            onChanged: (value) {
              setVolume(value);
            },
          ),
        ),
        const SizedBox(width: 32),
      ],
    );

    var fullscreen = CupertinoButton(
      child: Icon(
          isFullscreen ? Icons.fullscreen_exit_sharp : Icons.fullscreen_sharp,
          color: customSky,
          size: size),
      onPressed: () async {
        FullScreenWindow.setFullScreen(!isFullscreen);
        isFullscreen = !isFullscreen;
        setState(() {});
        // At the moment, the windowManager has a bug in its fullscreen feature, which is problematic for the video player.
        // https://github.com/leanflutter/window_manager/issues/228
      },
    );

    var padding = const SizedBox(
      width: 32,
      height: 32,
    );
    return Positioned(
      bottom: 32,
      left: 32,
      right: 32,
      child: Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            children: [
              playProgressbar(),
              padding,
              Row(
                children: [
                  Flexible(
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: boxWidget(
                            color: customSky,
                            backgroundColor: customOcean,
                            child: volumeWidget,
                          ))),
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
                  Flexible(
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: boxWidget(
                              color: customSky,
                              backgroundColor: customOcean,
                              child: fullscreen)))
                ],
              )
            ],
          )),
    );
  }
}
