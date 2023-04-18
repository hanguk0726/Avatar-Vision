import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/widgets/tabItem.dart';

Widget pastEntries(double width, double height) {
  List<String> fileList = [
    // delcare mock video diary entries

    "2021-09-01 12:00:00",
    "2021-09-02 12:00:00",
    "2021-09-03 12:00:00",
    "2021-09-04 12:00:00",
    "2021-09-05 12:00:00",
    "2021-09-06 12:00:00",
    "2021-09-07 12:00:00",
    "2021-09-08 12:00:00",
    "2021-09-09 12:00:00",
    "2021-09-10 12:00:00",
    "2021-09-11 12:00:00",
    "2021-09-12 12:00:00",
    "2021-09-13 12:00:00",
    "2021-09-14 12:00:00",
    "2021-09-15 12:00:00",
    "2021-09-16 12:00:00",
    "2021-09-01 12:00:00",
    "2021-09-02 12:00:00",
    "2021-09-03 12:00:00",
    "2021-09-04 12:00:00",
    "2021-09-05 12:00:00",
    "2021-09-06 12:00:00",
    "2021-09-07 12:00:00",
    "2021-09-08 12:00:00",
    "2021-09-09 12:00:00",
    "2021-09-10 12:00:00",
    "2021-09-11 12:00:00",
    "2021-09-12 12:00:00",
    "2021-09-13 12:00:00",
    "2021-09-14 12:00:00",
    "2021-09-15 12:00:00",
    "2021-09-16 12:00:00",
  ];
  Color backgroundColor = customBlack;
  Color textColor = Colors.white;

  return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
          child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor.withOpacity(0.2),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: fileList.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 32.0, right: 32.0),
                        child: Row(
                          children: [
                            Text(fileList[index],
                                style: TextStyle(
                                    color: textColor,
                                    fontFamily: mainFont,
                                    fontSize: 16)),
                            const SizedBox(width: 8),
                          ],
                        ),
                      );
                    },
                  )))));
}
