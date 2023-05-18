import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../domain/event.dart';

class EventBus {
  EventBus._internal();

  static final EventBus _singleton = EventBus._internal();

  factory EventBus() => _singleton;

  final _eventController = StreamController<KeyEventPair>.broadcast();

  Stream<KeyEventPair> get onEvent => _eventController.stream;

  bool clearUiMode = false;
  bool off = false;
  void fire(Event event, String key) {
    if (off) {
      return;
    }
    if (clearUiMode) {
      //only accept space which is used to toggle clear ui
      if (event == KeyboardEvent.keyboardControlSpace) {
        _eventController.sink.add(KeyEventPair(event, key));
      }
      return;
    }
    _eventController.sink.add(KeyEventPair(event, key));
  }

  void destroy() {
    _eventController.close();
  }
}

class KeyEventPair {
  final Event event;
  final String key;
  KeyEventPair(this.event, this.key);
}
