import 'dart:async';

import '../domain/event.dart';

class EventBus {
  EventBus._internal();

  static final EventBus _singleton = EventBus._internal();

  factory EventBus() => _singleton;

  final _eventController = StreamController<Event>.broadcast();

  Stream<Event> get onEvent => _eventController.stream;

  void fire(Event event) {
    _eventController.sink.add(event);
  }

  void destroy() {
    _eventController.close();
  }
}
