import 'package:flutter/cupertino.dart';

import '../domain/event.dart';
import '../services/event_bus.dart';

Widget keyListener(
  String key,
  FocusNode focusNode,
  Widget child,
) {
  return RawKeyboardListener(
    focusNode: focusNode,
    onKey: (event) {
      debugPrint(
        "${event.logicalKey.keyLabel}, $key",
      );
      var e = rawKeyEventToEvent(event);
      if (e != null) {
        EventBus().fire(e, key);
      }
    },
    child: child,
  );
}
