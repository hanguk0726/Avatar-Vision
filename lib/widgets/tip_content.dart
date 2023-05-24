import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:video_diary/domain/assets.dart';

Widget tipContent() {
  var backgroundColor = customSky;
  var textStyle =
      TextStyle(color: Colors.white, fontFamily: mainFont, fontSize: 18);
  return SizedBox(
      width: 400,
      height: 400,
      child: ClipRRect(
          child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor.withOpacity(0.2),
                  ),
                  constraints: const BoxConstraints(
                    minHeight: 520,
                  ),
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Scroll up/down or press Tab to toggle \na clear view on the mainCam and player.",
                              style: textStyle,
                            ),
                            const SizedBox(height: 32),
                            Text("You can turn off this tip on setting.",
                                style: textStyle),
                            const SizedBox(height: 32),
                            Text("Press Arrow keys to change the taps.",
                                style: textStyle),
                            const SizedBox(height: 32),
                            Text("Press F key to start fullscreen mode.",
                                style: textStyle),
                            const SizedBox(height: 32),
                            Text("To select multiple records in pastEntries, \nsimply perform a long tap on a record.",
                                style: textStyle),
                          ]))))));
}
