import 'dart:ui';

import 'package:flutter/cupertino.dart';

Widget glassyBoxWidget(
    {required Color color,
    required Color backgroundColor,
    required Widget child,
    bool sharp = false}) {
  return ClipRRect(
      child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Container(
              decoration: BoxDecoration(
                color: backgroundColor.withOpacity(0.8),
                border: Border.all(
                  color: color.withOpacity(0.8),
                  width: 2,
                ),
                borderRadius: sharp
                    ? const BorderRadius.only(
                        topRight: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      )
                    : BorderRadius.circular(10),
              ),
              child: child)));
}
