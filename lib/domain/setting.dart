import 'package:flutter/foundation.dart';

class Setting with ChangeNotifier, DiagnosticableTreeMixin {
  Setting._privateConstructor();
  static final Setting _instance = Setting._privateConstructor();
  factory Setting() {
    return _instance;
  }

  bool renderingWhileEncoding = false;
}
