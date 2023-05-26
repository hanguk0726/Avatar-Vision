import 'package:flutter/services.dart';

abstract class Event<T> {
  const Event._();

  factory Event.keyboard(KeyAction type) = KeyboardEvent<T>;
  factory Event.metadata(int timestamp) = MetadataEvent<T>;
}

enum KeyAction {
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
  tab
}

class KeyboardEvent<T> extends Event<T> {
  final KeyAction keyAction;

  const KeyboardEvent(this.keyAction) : super._();

  static const keyboardControlArrowUp =
      KeyboardEvent(KeyAction.arrowUp);
  static const keyboardControlArrowDown =
      KeyboardEvent(KeyAction.arrowDown);
  static const keyboardControlArrowLeft =
      KeyboardEvent(KeyAction.arrowLeft);
  static const keyboardControlArrowRight =
      KeyboardEvent(KeyAction.arrowRight);
  static const keyboardControlEnter = KeyboardEvent(KeyAction.enter);
  static const keyboardControlSpace = KeyboardEvent(KeyAction.space);
  static const keyboardControlM = KeyboardEvent(KeyAction.m);
  static const keyboardControlF = KeyboardEvent(KeyAction.f);
  static const keyboardControlBackspace =
      KeyboardEvent(KeyAction.backspace);
  static const keyboardControlDelete = KeyboardEvent(KeyAction.delete);
  static const keyboardControlEscape = KeyboardEvent(KeyAction.escape);
  static const keyboardControlTab = KeyboardEvent(KeyAction.tab);
}

class MetadataEvent<T> extends Event<T> {
  final int timestamp;

  const MetadataEvent(this.timestamp) : super._();
}

class FileEvent<T> extends Event<T> {
  final List<int> timestamps;
  final int command;
  static const int cancel = 0;
  static const int selected = 1;
  static const int sendFileToDesktop = 2;
  static const int delete = 3;
  const FileEvent(this.timestamps, this.command) : super._();
}

class DialogEvent<T> extends Event<T> {
  final String text;
  final String eventKey;
  final String? buttonSky;
  final String? buttonOrange;
  final Future<void> Function()? buttonSkyTask;
  final Future<void> Function()? buttonOrangeTask;
  final Future<void> Function()? automaticTask;
  const DialogEvent(
      {required this.text,
      required this.eventKey,
      this.buttonSky,
      this.buttonOrange,
      this.buttonSkyTask,
      this.buttonOrangeTask,
      this.automaticTask})
      : super._();

  static const dismiss = DialogEvent(text: 'dismiss', eventKey: 'system');
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
      case ' ': // this value indicates a space actually.
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
      case 'Tab':
        return KeyboardEvent.keyboardControlTab;
      default:
        return null;
    }
  }
  return null;
}
