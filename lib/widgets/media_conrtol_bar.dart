import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_diary/widgets/button.dart';

import '../domain/assets.dart';
import '../services/native.dart';

Widget mediaControlButton(
    {required BuildContext context,
    required Function onRecordStart,
    required Function onRecordStop}) {
  final native = context.watch<Native>();

  final recording = native.recording;
  final rendering = native.rendering;
  final currentCameraDevice = native.currentCameraDevice;

  bool showMediaControlButton =
      currentCameraDevice.isNotEmpty && rendering && !recording;

  if (showMediaControlButton) {
    return customButton(customSky, customBlack, 'REC', () {
      onRecordStart();
      Native().startRecording();
    });
  }
  if (recording) {
    return customButton(customOrange, Colors.white, 'STOP', () {
      onRecordStop();
      Native().stopRecording();
    });
  }

  return const SizedBox();
}
