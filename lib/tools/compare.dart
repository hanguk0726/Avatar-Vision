
import 'package:flutter/animation.dart';

bool isWithinTolerance(Size size1, Size size2, double tolerance) {
  return (size1.width - size2.width).abs() < tolerance &&
      (size1.height - size2.height).abs() < tolerance;
}
