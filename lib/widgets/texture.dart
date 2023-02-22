import 'package:flutter/material.dart';

import '../services/video_process.dart';

Widget texture() {
  return FutureBuilder<int>(
    future: VideoProcess.textureId,
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
