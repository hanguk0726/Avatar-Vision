import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../domain/assets.dart';
import '../domain/writing_state.dart';

class SavingIndicator extends StatefulWidget {
  const SavingIndicator(
      {Key? key, required this.recording, required this.writingState})
      : super(key: key);
  final bool recording;
  final WritingState writingState;

  @override
  // ignore: library_private_types_in_public_api
  _SavingIndicator createState() => _SavingIndicator();
}

class _SavingIndicator extends State<SavingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  Color color = customSky;
  Color textColor = customNavy;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String idle = WritingState.idle.toName();
    if (widget.writingState.toName() == idle) return const SizedBox();
    return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              width: 200,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: color.withOpacity(0.2),
                  width: 4,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.writingState.toName(),
                    style: TextStyle(
                        color: textColor,
                        fontFamily: mainFont,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 25),
                  SpinKitFadingFour(
                    color: customNavy,
                    size: 20.0,
                    controller: _controller,
                  )
                ],
              ),
            )));
  }
}

Widget message(String text, bool ellipsis, bool indicator, {Widget? icon}) {
  Color color = customGrey;
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
