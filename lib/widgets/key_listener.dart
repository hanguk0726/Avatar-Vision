import 'package:flutter/cupertino.dart';

import '../domain/event.dart';
import '../services/event_bus.dart';

Widget keyListener(String key, Widget child) {
  return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (event) {
        var e = rawKeyEventToEvent(event);
        debugPrint(
          "${event.logicalKey.keyLabel}, $key",
        );
        if (e != null) {
          EventBus().fire(e, key);
        }
      },
      child: child);
}
