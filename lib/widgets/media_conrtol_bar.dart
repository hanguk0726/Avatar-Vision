import 'package:flutter/material.dart';

Widget mediaControlBar(
    {required Function() onStart,
    required Function() onStop,
    required Function() reset}) {
  return Positioned(
    bottom: 30,
    left: 0,
    right: 0,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: onStart,
          child: const Text('Start'),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: onStop,
          child: const Text('Stop'),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: reset,
          child: const Text('Reset'),
        ),
      ],
    ),
  );
}
