import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

// This could be refactored when Flutter supports sealed classes.
abstract class Event<T> {
  const Event._();

  factory Event.keyboard(KeyboardEventType type) = KeyboardEvent<T>;
  factory Event.metadata(String videoTitle) = MetadataEvent<T>;
}

enum KeyboardEventType {
  arrowUp,
  arrowDown,
  arrowLeft,
  arrowRight,
  enter,
  space,
  m,
  f,
  backspace,
  delete,
  escape,
}

class KeyboardEvent<T> extends Event<T> {
  final KeyboardEventType type;

  const KeyboardEvent(this.type) : super._();
  static const keyboardControlArrowUp =
      KeyboardEvent(KeyboardEventType.arrowUp);
  static const keyboardControlArrowDown =
      KeyboardEvent(KeyboardEventType.arrowDown);
  static const keyboardControlArrowLeft =
      KeyboardEvent(KeyboardEventType.arrowLeft);
  static const keyboardControlArrowRight =
      KeyboardEvent(KeyboardEventType.arrowRight);
  static const keyboardControlEnter = KeyboardEvent(KeyboardEventType.enter);
  static const keyboardControlSpace = KeyboardEvent(KeyboardEventType.space);
  static const keyboardControlM = KeyboardEvent(KeyboardEventType.m);
  static const keyboardControlF = KeyboardEvent(KeyboardEventType.f);
  static const keyboardControlBackspace =
      KeyboardEvent(KeyboardEventType.backspace);
  static const keyboardControlDelete = KeyboardEvent(KeyboardEventType.delete);
  static const keyboardControlEscape = KeyboardEvent(KeyboardEventType.escape);
}

class MetadataEvent<T> extends Event<T> {
  final String videoTitle;

  const MetadataEvent(this.videoTitle) : super._();

  
}

Event? rawKeyEventToEvent(RawKeyEvent event) {
  
  if (event is RawKeyDownEvent) {
    switch (event.logicalKey.keyLabel) {
      case 'Arrow Up':
        return KeyboardEvent.keyboardControlArrowUp;
      case 'Arrow Down':
        return KeyboardEvent.keyboardControlArrowDown;
      case 'Arrow Left':
        return KeyboardEvent.keyboardControlArrowLeft;
      case 'Arrow Right':
        return KeyboardEvent.keyboardControlArrowRight;
      case 'Enter':
        return KeyboardEvent.keyboardControlEnter;
      case ' ': // this empty value is actually a space
        return KeyboardEvent.keyboardControlSpace;
      case 'M':
        return KeyboardEvent.keyboardControlM;
      case 'F':
        return KeyboardEvent.keyboardControlF;
      case 'Backspace':
        return KeyboardEvent.keyboardControlBackspace;
      case 'Delete':
        return KeyboardEvent.keyboardControlDelete;
      case 'Escape':
        return KeyboardEvent.keyboardControlEscape;
      default:
        return null;
    }
  }
  return null;
}
