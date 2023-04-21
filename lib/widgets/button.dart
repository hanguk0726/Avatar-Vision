import 'package:flutter/material.dart';
import 'package:video_diary/domain/assets.dart';

Widget customButton(
    Color color, Color textColor, String text, Function onClick) {
  double height = 60;
  return Container(
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        border: Border.all(
          color: color.withOpacity(0.8),
          width: 2,
        ),
      ),
      child: Container(
          height: height,
          padding: const EdgeInsets.only(left:12.0, right: 12.0),
          color: color.withOpacity(0.5),
          child: GestureDetector(
              onTap: () => onClick(),
              child: Center(
                child: Text(text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: textColor,
                        fontSize: 24,
                        fontFamily: mainFont,
                        fontWeight: FontWeight.bold)),
              ))));
}
