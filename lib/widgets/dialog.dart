import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:video_diary/domain/event.dart';

import '../domain/assets.dart';
import '../services/event_bus.dart';
import 'button.dart';

class CustomDialog extends StatefulWidget {
  const CustomDialog(
      {Key? key,
      required this.text,
      required this.eventKey,
      this.buttonSky,
      this.buttonSkyTask,
      this.buttonOrange,
      this.buttonOrangeTask,
      this.automaticTask})
      : super(key: key);

  final String text;
  final String eventKey;
  final String? buttonSky;
  final String? buttonOrange;
  final Future<void> Function()? buttonSkyTask;
  final Future<void> Function()? buttonOrangeTask;
  final Future<void> Function()? automaticTask;

  @override
  CustomDialogState createState() => CustomDialogState();
}

class CustomDialogState extends State<CustomDialog>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  Color color = customSky;
  Color textColor = Colors.white;
  double? width;

  void dismiss() {
    var eventBus = EventBus();
    eventBus.fire(DialogEvent.dismiss, widget.eventKey);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    if (widget.automaticTask != null) {
      bool twoSeconds = false;
      bool taskDone = false;

      Future<void> taskFuture = widget.automaticTask!();

      Timer(const Duration(seconds: 2), () {
        twoSeconds = true;
        if (taskDone) {
          dismiss();
        }
      });

      // Handle task completion
      taskFuture.then((value) {
        taskDone = true;
        if (twoSeconds) {
          dismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
        child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        height: 60,
        constraints: const BoxConstraints(maxWidth: 550),
        decoration: BoxDecoration(
          color: color.withOpacity(0.5),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 4,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(right: 12.0, left: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.text,
                style: TextStyle(
                    color: textColor,
                    fontFamily: mainFont,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 72),
              if (widget.buttonSky != null && widget.buttonSkyTask != null) ...[
                customButton(customSky, Colors.white, widget.buttonSky!, () {
                  widget.buttonSkyTask!().then((value) {
                    setState(() {
                      dismiss();
                    });
                  });
                },
                    height: 32.0,
                    backgroundColorOpacity: 0.6,
                    borderOpacity: 0.8,
                    fontSize: 18.0)
              ],
              if (widget.buttonOrange != null &&
                  widget.buttonOrangeTask != null) ...[
                const SizedBox(width: 12),
                customButton(customYellow, Colors.white, widget.buttonOrange!,
                    () {
                  widget.buttonOrangeTask!().then((value) {
                    setState(() {
                      dismiss();
                    });
                  });
                },
                    height: 32.0,
                    backgroundColorOpacity: 0.6,
                    borderOpacity: 0.8,
                    fontSize: 18.0)
              ],
              if (widget.automaticTask != null) ...[
                const SizedBox(width: 12),
                SpinKitFadingFour(
                  color: Colors.white,
                  size: 20.0,
                  controller: _controller,
                )
              ]
            ],
          ),
        ),
      ),
    ));
  }
}
