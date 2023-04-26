import 'dart:async';

import '../domain/event.dart';

class EventBus {
  EventBus._internal();

  static final EventBus _singleton = EventBus._internal();

  factory EventBus() => _singleton;

  final _eventController = StreamController<KeyEventPair>.broadcast();

  Stream<KeyEventPair> get onEvent => _eventController.stream;

  void fire(Event event, String key) {
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
