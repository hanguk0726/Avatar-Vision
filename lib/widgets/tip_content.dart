import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_diary/domain/assets.dart';

Widget tipContent() {
  var backgroundColor = Colors.white ;
  var borderColor = customOrange;
  var textStyle =
      TextStyle(color:
      customBlack
      //  Colors.white
      , fontFamily: mainFont, fontSize: 18);
  return SizedBox(
      width: 550,
      height: 500,
      child: ClipRRect(
          child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor.withOpacity(0.6),
                    // border: Border.all(
                    //   color: borderColor,
                    //   width: 2,
                    // ),
                    // borderRadius: BorderRadius.circular(0),
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
                              "Scroll up/down or press Spacebar to toggle a clear view on the mainCam.",
                              style: textStyle,
                            ),
                            Text("You can turn off this tip on setting.",
                                style: textStyle)
                          ]))))));
}
