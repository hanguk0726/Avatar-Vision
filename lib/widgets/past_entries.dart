import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_diary/domain/assets.dart';
import 'package:video_diary/widgets/tabItem.dart';

Widget pastEntries() {
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
      width: 500,
      height: 500, //FIXME
      child: ClipRRect(
          child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor.withOpacity(0.2),
                  ),
                  child: SingleChildScrollView(
                      child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox(height: 8),
                      for (var i = 0; i < fileList.length; i++)
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 32.0, right: 32.0),
                          child: Row(
                            children: [
                              Text(fileList[i],
                                  style: TextStyle(
                                      color: textColor,
                                      fontFamily: mainFont,
                                      fontSize: 16)),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                    ],
                  ))))));
}
