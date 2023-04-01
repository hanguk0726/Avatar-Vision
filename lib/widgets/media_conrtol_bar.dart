import 'package:flutter/material.dart';

Widget mediaControlBar(
    {required bool recording,
    required Function() onStart,
    required Function() onStop}) {
  return Positioned(
    bottom: 30,
    left: 0,
    right: 0,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (recording)
          ElevatedButton(
            onPressed: onStop,
            child: const Text('Stop'),
          )
        else
          ElevatedButton(
            onPressed: onStart,
            child: const Text('Record'),
          ),
      ],
    ),
  );
}
