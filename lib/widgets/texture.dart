import 'package:flutter/material.dart';

import '../services/native.dart';

Widget texture() {
  return SizedBox(
    height: 720,
    width: 1280,
    child: Texture(textureId: Native().textureId),
  );
}
