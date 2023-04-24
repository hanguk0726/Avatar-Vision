import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

enum Event {
  keyboardControlArrowUp,
  keyboardControlArrowDown,
  keyboardControlArrowLeft,
  keyboardControlArrowRight,
  keyboardControlEnter,
  keyboardControlSpacebar,
  keyboardControlM,
  keyboardControlF,
}

Event? rawKeyEventToEvent(RawKeyEvent event) {
  debugPrint(event.logicalKey.keyLabel);
  if (event is RawKeyDownEvent) {
    switch (event.logicalKey.keyLabel) {
      case 'Arrow Up':
        return Event.keyboardControlArrowUp;
      case 'Arrow Down':
        return Event.keyboardControlArrowDown;
      case 'Arrow Left':
        return Event.keyboardControlArrowLeft;
      case 'Arrow Right':
        return Event.keyboardControlArrowRight;
      case 'Enter':
        return Event.keyboardControlEnter;
      case ' ':
        return Event.keyboardControlSpacebar;
      case 'm':
        return Event.keyboardControlM;
      case 'f':
        return Event.keyboardControlF;
      default:
        return null;
    }
  }
  return null;
}
