import 'package:flutter/material.dart';

class Waveform extends StatefulWidget {
  final List<double> data;
  final double height;
  final double width;
  final Duration duration;

  Waveform({
    required this.data,
    required this.height,
    required this.width,
    required this.duration,
  });

  @override
  _WaveformState createState() => _WaveformState();
}

class _WaveformState extends State<Waveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(Waveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
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
        Colors.blue.withOpacity(0.4),
        Colors.blue.withOpacity(0.8),
        Colors.blue.withOpacity(0.4),
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
      // final double left = i * barWidth - barWidth / 2;
      // final double right = i * barWidth + barWidth / 2;
      final double left = i * barWidth - barWidth / 2 + 10;
      final double right = i * barWidth + barWidth / 2 - 10;
      final double top = halfHeight - data[i] * progress;
      final double bottom = halfHeight + data[i] * progress;
      final rect = Rect.fromLTRB(left, top + 10, right, bottom - 10);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(halfHeight)), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.progress != progress;
  }
}
