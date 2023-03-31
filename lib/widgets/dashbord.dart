import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class SavingIndicator extends StatefulWidget {
  const SavingIndicator({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SavingIndicator createState() => _SavingIndicator();
}

class _SavingIndicator extends State<SavingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  Color color = const Color.fromARGB(255, 87, 87, 87);

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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Saving...",
          style: TextStyle(color: color),
        ),
        const SizedBox(width: 10),
        SpinKitFadingFour(
          color: color,
          size: 20.0,
          controller: _controller,
        )
      ],
    );
  }
}
