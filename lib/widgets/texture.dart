import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../services/video_processor.dart';

Widget texture() {
  return StreamBuilder<int?>(
    stream: VideoProcessor.textureId.stream,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return SizedBox(
          height: 720,
          width: 1280,
          child: Texture(textureId: snapshot.data!),
        );
      } else {
        return const CircularProgressIndicator();
      }
    },
  );
}
