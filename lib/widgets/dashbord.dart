import 'dart:ui';

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
    //rounded container wich glassy effect color
    return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              width: 200,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Saving...",
                    style: TextStyle(color: color),
                  ),
                  const SizedBox(width: 25),
                  SpinKitFadingFour(
                    color: color,
                    size: 20.0,
                    controller: _controller,
                  )
                ],
              ),
            )));
    // );
    // return Row(
    //   mainAxisAlignment: MainAxisAlignment.center,
    //   children: [
    //     Text(
    //       "Saving...",
    //       style: TextStyle(color: color),
    //     ),
    //     const SizedBox(width: 10),
    //     SpinKitFadingFour(
    //       color: color,
    //       size: 20.0,
    //       controller: _controller,
    //     )
    //   ],
    // );
  }
}
