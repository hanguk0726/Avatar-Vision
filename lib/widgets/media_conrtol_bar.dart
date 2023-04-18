import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_diary/widgets/button.dart';

import '../domain/assets.dart';
import '../domain/writing_state.dart';
import '../services/native.dart';

Widget mediaControlButton({required BuildContext context}) {
  final native = context.watch<Native>();

  final writingState = native.writingState;
  final recording = native.recording;
  final rendering = native.rendering;
  final currentCameraDevice = native.currentCameraDevice;

  bool showRenderButton = writingState == WritingState.idle &&
      !rendering &&
      currentCameraDevice.isNotEmpty;
  bool showMediaControlButton =
      currentCameraDevice.isNotEmpty && rendering && !recording;
      
  if (showMediaControlButton) {
    return customButton(customSky, customBlack, 'REC', () {
      Native().startRecording();
    });
  }
  if (recording) {
    return customButton(customOrange, Colors.white, 'STOP', () {
      Native().stopRecording();
    });
  }

  if (showRenderButton) {
    return customButton(customOcean, Colors.white, 'RENDER', () {
      Native().startCamera();
    });
  }
  return const SizedBox();
}
