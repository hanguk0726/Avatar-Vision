// delcare fn that accept error condition and msg ans sub msg

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../domain/assets.dart';
import '../domain/error.dart';

Widget messageOnError({required CustomError error}) {
  return Center(
    child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          messageWidget(error.message, false, false,
              icon: Icon(
                Icons.error_outline,
                color: customOrange,
                size: 100.0,
              )),
          if (error.subMessage.isNotEmpty)
            Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(error.subMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontFamily: mainFont,
                        fontSize: 24)))
        ]),
  );
}

Widget messageWidget(String text, bool ellipsis, bool indicator,
    {Widget? icon}) {
  Color color = Colors.white;
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (icon != null) ...[
        icon,
        const SizedBox(width: 50),
      ],
      Text(
        ellipsis ? "$text..." : text,
        style: TextStyle(color: color, fontSize: 40, fontFamily: mainFont),
        textAlign: TextAlign.center,
      ),
      const SizedBox(width: 50),
      if (indicator)
        SpinKitFadingCube(
          color: color,
          size: 40.0,
        ),
    ],
  );
}
