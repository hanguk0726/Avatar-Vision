import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_diary/domain/assets.dart';

class WindowWidget extends StatefulWidget {
  final String metadataId;
  final bool visible;

  const WindowWidget(
      {super.key, required this.metadataId, this.visible = true}); // should be false 

  @override
  WindowWidgetState createState() => WindowWidgetState();
}

class WindowWidgetState extends State<WindowWidget> {
  Color borderColor = customSky;
  Color backgroundColor = customOcean;
  Color textColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor.withOpacity(0.2),
            border: Border.all(
              color: borderColor.withOpacity(0.8),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'text',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontFamily: mainFont,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
