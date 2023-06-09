import 'package:flutter/material.dart';

import '../services/native.dart';

Widget texture(double width, double height) {
  return SizedBox(
    width : width,
    height :height,
    child: Texture(textureId: Native().textureId),
  );
}
