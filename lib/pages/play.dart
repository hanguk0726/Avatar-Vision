import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fullscreen_window/fullscreen_window.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:slider_controller/slider_controller.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/domain/metadata.dart';
import 'package:video_diary/domain/result.dart';
import 'package:video_diary/pages/video.dart';
import 'package:video_diary/tools/time.dart';
import 'package:video_diary/widgets/box_widget.dart';
import 'package:video_diary/widgets/key_listener.dart';

import '../domain/event.dart';
import '../services/database.dart';
import '../services/event_bus.dart';
import '../widgets/metadata_widget.dart';

class Play extends StatefulWidget {
  final String filePath;
  final String fileName;
  final int timestamp;
  final Function() onPlay;

  const Play({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.timestamp,
    required this.onPlay,
  });
  @override
  PlayState createState() => PlayState();
}

class PlayState extends State<Play> {
  late StreamSubscription<KeyEventPair> _eventSubscription;
  final Player player = Player();
  VideoController? controller;
  bool isFullscreen = false;
  double volume = 100;
  bool muted = false;
  Duration playtime = const Duration(seconds: 0);
  Duration animatedOpacity = const Duration(milliseconds: 300);
  bool showOverlayAndMouseCursor = true;
  Timer? _timer;
  bool completed = false;
  bool isMovedAway = false;
  final focusNode = FocusNode();
  final String eventKey = 'play';
  Metadata? metadata;

  @override
  void initState() {
    super.initState();
    initVideo();
    initKeyboradEvent();
    completed = false;
    player.streams.completed.listen((event) {
      setState(() {
        completed = event;
      });
    });
    player.streams.volume.listen((e) => setState(() {
          volume = e;
        }));
    player.streams.duration.listen((e) => setState(() {
          playtime = e;
        }));
    focusNode.requestFocus();
    startOverlayTimer();
    var db = DatabaseService();
    final _metadata = db.findByOsFileName(widget.fileName);
    if (_metadata is Success<Metadata>) {
      metadata = _metadata.value;
    }
  }

  void initKeyboradEvent() {
    _eventSubscription = EventBus().onEvent.listen((event) {
      if (event.key != eventKey) {
        return;
      }
      switch (event.event) {
        case KeyboardEvent.keyboardControlArrowUp:
          setVolume(volume + 10);
          break;
        case KeyboardEvent.keyboardControlArrowDown:
          setVolume(volume - 10);
          break;

        case KeyboardEvent.keyboardControlArrowLeft:
          {
            if (controller!.player.state.position >
                const Duration(seconds: 10)) {
              controller!.player.seek(controller!.player.state.position -
                  const Duration(seconds: 10));
            } else {
              controller!.player.seek(const Duration(seconds: 0));
            }
          }
          break;
        case KeyboardEvent.keyboardControlSpace:
          controller!.player.playOrPause();
          setState(() {});
          break;
        case KeyboardEvent.keyboardControlArrowRight:
          controller!.player.seek(
              controller!.player.state.position + const Duration(seconds: 10));
          break;
        case KeyboardEvent.keyboardControlM:
          if (muted) {
            controller!.player.setVolume(100);
            muted = false;
          } else {
            controller!.player.setVolume(0);
            muted = true;
          }
          setState(() {});
          break;
        case KeyboardEvent.keyboardControlF:
          FullScreenWindow.setFullScreen(!isFullscreen);
          isFullscreen = !isFullscreen;
          setState(() {});
          break;
        case KeyboardEvent.keyboardControlTab:
          isMovedAway = !isMovedAway;
          setState(() {});

          break;
        case KeyboardEvent.keyboardControlBackspace:
          Navigator.pop(context);
          break;
        case KeyboardEvent.keyboardControlEscape:
          if (isFullscreen) {
            FullScreenWindow.setFullScreen(false);
            isFullscreen = false;
            setState(() {});
          }
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
    _timer?.cancel();
    focusNode.unfocus();
    focusNode.dispose();
    super.dispose();
  }

  void initVideo() async {
    Future.microtask(() async {
      controller = await VideoController.create(player);
      await player.open(Media(widget.filePath));
      setState(() {});
    });
  }

  void startOverlayTimer() {
    setState(() {
      showOverlayAndMouseCursor = true;
    });
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2000), () {
      setState(() {
        showOverlayAndMouseCursor = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
        // cursor has some issue.
        // https://github.com/flutter/flutter/issues/76622
        cursor: showOverlayAndMouseCursor
            ? SystemMouseCursors.basic
            : SystemMouseCursors.none,
        onHover: (event) {
          if (event.delta.dx.abs() > 2 || event.delta.dy.abs() > 2) {
            startOverlayTimer();
          }
        },
        child: Scaffold(
            backgroundColor: Colors.black,
            body: Listener(
              child: keyListener(
                eventKey,
                focusNode,
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (controller!.player.state.playing) {
                          controller!.player.pause();
                        } else {
                          controller!.player.play();
                        }
                        setState(() {});
                        startOverlayTimer();
                      },
                      child: Video(
                        controller: controller,
                        fit: BoxFit.fill,
                      ),
                    ),
                    header(),
                    mediaControllBar(),
                    recordingInfo(),
                    if (metadata != null)
                      Positioned(
                          top: 32,
                          right: 32,
                          child:MetadataWidget(
                              metadata: metadata!,
                              smaller: true,
                            ))
                  ],
                ),
              ),
              onPointerSignal: (PointerSignalEvent event) {
                if (event is PointerScrollEvent) {
                  if (event.scrollDelta.dy < 0) {
                    setState(() {
                      isMovedAway = true;
                    });
                  } else {
                    // scrolled up
                    setState(() {
                      isMovedAway = false;
                    });
                  }
                }
              },
            )));
  }

  Widget recordingInfo() {
    var db = DatabaseService();
    return buildAnimatedPositioned(
        isMovedAway: isMovedAway,
        bottom: 32,
        left: 32,
        child: AnimatedOpacity(
          opacity: showOverlayAndMouseCursor ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          child: StreamBuilder<Duration>(
              stream: controller?.player.streams.position,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text.rich(
                    TextSpan(
                      style: TextStyle(
                          color: customSky,
                          fontSize: 26,
                          fontFamily: subFont,
                          fontWeight: FontWeight.w600),
                      text:
                          'LOG ENTRY:  ${formatInt(db.getLogEntryOrder(widget.timestamp) + 1)}\n',
                      children: <TextSpan>[
                        TextSpan(
                          text: 'TIME:  ${formatDuration(snapshot.data!)}\n',
                        ),
                        TextSpan(
                          text:
                              'DATE:  ${DateFormat('MM/dd/yyyy').format(DateTime.fromMillisecondsSinceEpoch(widget.timestamp))}',
                        ),
                      ],
                    ),
                  );
                } else {
                  return const SizedBox();
                }
              }),
        ));
  }

  Widget header() {
    return Positioned(
        left: 32,
        top: 32,
        child: AnimatedOpacity(
            duration: animatedOpacity,
            opacity: showOverlayAndMouseCursor ? 1.0 : 0.0,
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
                                  getFormattedTimestamp(
                                      timestamp: widget.timestamp),
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: mainFont,
                                      fontSize: 18),
                                ))),
                        const SizedBox(width: 32),
                      ],
                    )))));
  }

  void setVolume(double value) {
    if (value > 100) {
      value = 100;
    }
    if (value < 0) {
      value = 0;
    }
    setState(() {
      controller!.player.setVolume(value);
      volume = value;
      if (volume == 0) {
        muted = true;
      } else {
        muted = false;
      }
    });
  }

  Widget time() {
    return StreamBuilder<Duration>(
      stream: controller!.player.streams.position,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        Duration position = snapshot.data!;
        if (completed) {
          position = playtime;
        }
        return Text(
          '${position.inHours}:${position.inMinutes.remainder(60).toString().padLeft(2, '0')}:${position.inSeconds.remainder(60).toString().padLeft(2, '0')}',
          style: TextStyle(
            color: customSky,
            fontFamily: mainFont,
            fontSize: 18,
          ),
        );
      },
    );
  }

  Widget playProgressbar() {
    return StreamBuilder<Duration>(
      stream: controller!.player.streams.position,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        Duration position = snapshot.data!;
        if (completed) {
          position = playtime;
        }
        return ProgressBar(
          progress: position,
          buffered: playtime,
          total: playtime,
          barHeight: 15.0,
          barCapShape: BarCapShape.square,
          timeLabelLocation: TimeLabelLocation.none,
          progressBarColor: customSky,
          baseBarColor: Colors.transparent,
          bufferedBarColor: customOcean.withOpacity(0.5),
          thumbColor: Colors.transparent,
          thumbGlowColor: Colors.transparent,
          onSeek: (duration) {
            controller!.player.seek(duration);
          },
        );
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
        controller!.player.playOrPause();
        setState(() {});
      },
    );

    var pause = CupertinoButton(
      child: Icon(Icons.pause_sharp, color: color, size: size + 12),
      onPressed: () {
        controller!.player.playOrPause();
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
          width: 80,
          child: SliderController(
            value: volume,
            sliderDecoration: SliderDecoration(
                isThumbVisible: false,
                activeColor: customSky,
                inactiveColor: customOcean,
                borderRadius: 0,
                height: 8,
                thumbHeight: 0),
            onChangeStart: (value) {
              setVolume(
                  value); //sometime the slider will not update the value without 'onChangeStart'
            },
            onChanged: (value) {
              setVolume(value);
            },
          ),
        ),
        const SizedBox(width: 24),
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
    var playtimeWidget = Text(
      '${playtime.inHours}:${playtime.inMinutes.remainder(60).toString().padLeft(2, '0')}:${playtime.inSeconds.remainder(60).toString().padLeft(2, '0')}',
      style: TextStyle(
        color: customSky,
        fontFamily: mainFont,
        fontSize: 18,
      ),
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
          child: AnimatedOpacity(
              duration: animatedOpacity,
              opacity: showOverlayAndMouseCursor ? 1.0 : 0.0,
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
                              width: 500,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  time(),
                                  padding,
                                  back,
                                  padding,
                                  controller!.player.state.playing
                                      ? pause
                                      : play,
                                  padding,
                                  forward,
                                  padding,
                                  playtimeWidget
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
              ))),
    );
  }
}
