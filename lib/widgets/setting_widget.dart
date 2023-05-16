import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_diary/widgets/waveform.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/assets.dart';
import '../services/native.dart';
import '../services/setting.dart';
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

  return FocusScope(
      canRequestFocus: false,
      child: ClipRRect(
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
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                        child: Row(
                          children: [
                            Text("Fit to screen",
                                style: TextStyle(
                                    color: color,
                                    fontSize: 16,
                                    fontFamily: mainFont)),
                            const Spacer(),
                            Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: InkWell(
                                  onTap: () {
                                    windowManager.setSize(
                                        Size(screenWidth, screenHeight));
                                  },
                                  child: const Text(
                                    "Apply",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ))
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 32,
                      ),
                      Padding(
                          padding:
                              const EdgeInsets.only(left: 16.0, right: 8.0),
                          child: Row(
                            children: [
                              Text("Thumbnail view",
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 16,
                                      fontFamily: mainFont)),
                              const Spacer(),
                              Switch(
                                value: setting.thumbnailView,
                                onChanged: (value) {
                                  setting.thumbnailView = value;
                                 setting.save();
                                },
                                activeTrackColor: customSky.withOpacity(0.6),
                                activeColor: Colors.white,
                              ),
                            ],
                          )),
                      const SizedBox(
                        height: 32,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                        child: Row(
                          children: [
                            Tooltip(
                                message:
                                    "Scroll up or down to toggle a clear view on the mainCam.",
                                decoration: BoxDecoration(
                                  color: customOcean.withOpacity(0.8),
                                ),
                                textStyle: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: mainFont),
                                child: Text("Tip",
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 16,
                                        fontFamily: mainFont))),
                            const Spacer(),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 32,
                      ),
                    ],
                  )))));
}
