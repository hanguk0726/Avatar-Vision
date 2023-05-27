import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CustomButtonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final divided = (size.width / 5) * 4;
    Path path = Path();
    path.moveTo(0, size.height); // start at the bottom left corner

    // draw a straight line to the top left corner
    path.lineTo(0, 0);

    // draw a diagonal line to the top right corner
    path.lineTo(divided, 0);

    // draw a straight line to the bottom right corner
    path.lineTo(size.width, size.height);

    // draw a diagonal line to cut off the top-left corner
    path.lineTo(size.width * 0.75, size.height);

    // close the path to complete the shape
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomButtonClipper oldClipper) => false;
}
