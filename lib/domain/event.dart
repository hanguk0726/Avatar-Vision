import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

enum Event {
  keyboardControlArrowUp,
  keyboardControlArrowDown,
  keyboardControlArrowLeft,
  keyboardControlArrowRight,
  keyboardControlEnter,
  keyboardControlSpace,
  keyboardControlM,
  keyboardControlF,
  keyboardControlBackspace,
  keyboardControlDelete,
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
      case ' ': // this empty value is actually a space
        return Event.keyboardControlSpace;
      case 'M':
        return Event.keyboardControlM;
      case 'F':
        return Event.keyboardControlF;
      case 'Backspace':
        return Event.keyboardControlBackspace;
      case 'Delete':
        return Event.keyboardControlDelete;
      default:
        return null;
    }
  }
  return null;
}
