import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_diary/widgets/tabItem.dart';
import 'package:video_diary/widgets/waveform.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/assets.dart';
import '../services/setting.dart';
import '../services/native.dart';
import '../tools/compare.dart';
import 'dropdown.dart';

Widget settings(BuildContext context) {
  const color = Colors.white;
  const spacer = SizedBox(height: 24);
  final native = context.watch<Native>();
  final setting = context.watch<Setting>();
  final screenWidth = native.currentResolutionWidth;
  final screenHeight = native.currentResolutionHeight;
  final currentCameraDevice = native.currentCameraDevice;
  final currentResolution = native.currentResolution;
  final currentAudioDevice = native.currentAudioDevice;
  final cameraDevices = native.cameraDevices;
  final resolutions = native.resolutions;
  final audioDevices = native.audioDevices;

  Color backgroundColor = customOcean;
  onChangedAudioDevice(value) {
    Native().selectAudioDevice(value);
  }

  onChangedCameraDevice(value) {
    Native().selectCameraDevice(value);
  }

  return ClipRRect(
      child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Container(
              decoration: BoxDecoration(
                color: backgroundColor.withOpacity(0.2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                    child: Row(
                      children: [
                        IconButton(
                            icon: const Icon(Icons.refresh),
                            color: color,
                            onPressed: () async {
                              await Native().queryDevices();
                            }),
                        const Spacer(),
                      ],
                    ),
                  ),
                  spacer,
                  dropdown(
                      value: currentAudioDevice,
                      items: audioDevices,
                      onChanged: onChangedAudioDevice,
                      icon: const Icon(
                        Icons.mic,
                        color: color,
                      ),
                      textOnEmpty: "No audio input devices found",
                      iconOnEmpty: const Icon(Icons.mic_off, color: color),
                      textColor: color),
                  if (currentAudioDevice.isNotEmpty)
                    Waveform(
                      height: 100,
                      width: 300,
                      durationMillis: 500,
                    ),
                  spacer,
                  dropdown(
                      value: currentCameraDevice,
                      items: cameraDevices,
                      onChanged: onChangedCameraDevice,
                      icon: const Icon(Icons.camera_alt, color: color),
                      textOnEmpty: "No camera devices found",
                      iconOnEmpty:
                          const Icon(Icons.no_photography, color: color),
                      textColor: color),
                  spacer,
                  if (currentCameraDevice.isNotEmpty &&
                      currentResolution.isNotEmpty)
                    dropdown(
                        value: currentResolution,
                        items: resolutions,
                        onChanged: (resolution) {
                          Native().selectResolution(resolution);
                        },
                        icon: const Icon(Icons.photo, color: color),
                        textOnEmpty: "No resoltion available",
                        iconOnEmpty:
                            const Icon(Icons.do_not_disturb, color: color),
                        textColor: color),
                  spacer,
                  Tooltip(
                      message:
                          'Depending on the cpu specification, This may increase encoding time',
                      preferBelow: true,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                        child: Row(
                          children: [
                            Text("Render while recording",
                                style: TextStyle(
                                    color: color,
                                    fontSize: 16,
                                    fontFamily: mainFont)),
                            const Spacer(),
                            Switch(
                              value: setting.renderingWhileEncoding,
                              activeColor: customSky,
                              onChanged: (value) {
                                setting.toggleRenderingWhileEncoding();
                              },
                            ),
                          ],
                        ),
                      )),
                  spacer,
                  Tooltip(
                    message:
                        'This is enabled automatically when window size is fit to screen',
                    preferBelow: true,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                      child: Row(
                        children: [
                          Text("Fit to screen",
                              style: TextStyle(
                                  color: color,
                                  fontSize: 16,
                                  fontFamily: mainFont)),
                          const Spacer(),
                          FutureBuilder<Size>(
                            future: windowManager.getSize(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                final appWindowSize = snapshot.data!;
                                final fitToScreen = isWithinTolerance(
                                    Size(screenWidth, screenHeight),
                                    appWindowSize,
                                    10);
                                return Switch(
                                  value: fitToScreen,
                                  activeColor: customSky,
                                  onChanged: (value) {
                                    if (value) {
                                      windowManager.setSize(
                                          Size(screenWidth, screenHeight));
                                    }
                                  },
                                );
                              } else {
                                return CircularProgressIndicator(
                                    color: customSky);
                              }
                            },
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ))));
}

