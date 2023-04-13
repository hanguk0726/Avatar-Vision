import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_diary/domain/assets.dart';

import '../services/native.dart';

class Waveform extends StatefulWidget {
  final List<double> data = [
    0,
    3,
    6,
    9,
    12,
    15,
    18,
    21,
    24,
    27,
    30,
    33,
    30,
    27,
    24,
    21,
    18,
    15,
    12,
    9,
    6,
    3,
  ];

  final double height;
  final double width;
  final int durationMillis;

  Waveform({
    super.key,
    required this.height,
    required this.width,
    required this.durationMillis,
  });

  @override
  WaveformState createState() => WaveformState();
}

class WaveformState extends State<Waveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  late BehaviorSubject<bool> _hasAudio;
  @override
  void initState() {
    super.initState();
    _hasAudio = BehaviorSubject.seeded(false);
    int duration = widget.durationMillis;
    int reverseDuration = (widget.durationMillis / 2).round();

    Native().observeAudioBuffer(_hasAudio);

    _controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: duration),
        reverseDuration: Duration(milliseconds: reverseDuration))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reverse();
        }
      });

    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
      reverseCurve: Curves.easeInOutSine,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);

    _hasAudio.listen((hasAudio) {
      if (hasAudio &&
          _controller.status == AnimationStatus.dismissed &&
          !_controller.isAnimating &&
          mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _hasAudio.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(Waveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.durationMillis != oldWidget.durationMillis) {
      _controller.duration = Duration(milliseconds: widget.durationMillis);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate the width of each rectangle
    final double barWidth = widget.width / widget.data.length;

    return AnimatedBuilder(
      animation: _animation,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _WaveformPainter(
            data: widget.data,
            barWidth: barWidth,
            progress: _animation.value,
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> data;
  final double barWidth;
  final double progress;

  _WaveformPainter({
    required this.data,
    required this.barWidth,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double halfHeight = size.height / 2;

    // Create the gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        customSky.withOpacity(0.4),
        customSky.withOpacity(0.8),
        customSky.withOpacity(0.4),
      ],
    );

    // Create the rounded rectangle path
    final path = Path()
      ..moveTo(0, halfHeight)
      ..lineTo(0, halfHeight - data[0] * progress)
      ..lineTo(barWidth / 2, halfHeight - data[0] * progress)
      ..lineTo(barWidth / 2, halfHeight + data[0] * progress)
      ..lineTo(0, halfHeight + data[0] * progress)
      ..close();

    // Create the rounded rectangle shape
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(halfHeight),
    );

    // Create the paint object
    final paint = Paint()..shader = gradient.createShader(path.getBounds());

    // Draw the rounded rectangle path
    canvas.drawPath(path, paint);

    // Draw the remaining rectangles
    for (int i = 1; i < data.length; i++) {
      final double left = i * barWidth - barWidth / 2 + 10;
      final double right = i * barWidth + barWidth / 2 - 10;
      final double top = halfHeight - data[i] * progress;
      final double bottom = halfHeight + data[i] * progress;
      final rect = Rect.fromLTRB(left, top + 5, right, bottom - 5);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(halfHeight)), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.progress != progress;
  }
}
