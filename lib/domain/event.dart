import 'package:flutter/services.dart';

enum Event {
  keyboardControlArrowUp,
  keyboardControlArrowDown,
  keyboardControlArrowLeft,
  keyboardControlArrowRight,
  keyboardControlEnter,
}

Event? rawKeyEventToEvent(RawKeyEvent event) {
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
      default:
        return null;
    }
  }
  return null;
}
