import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_diary/tools/time.dart';

class Setting with ChangeNotifier, DiagnosticableTreeMixin {
  Setting._privateConstructor();
  static final Setting _instance = Setting._privateConstructor();
  factory Setting() {
    return _instance;
  }
  final fileName = 'diary_app_setting.json';
  bool renderingWhileEncoding = false;
  String lastPreferredResolution = '';
  int timeZoneOffset = 0;

  Map<String, dynamic> _toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['renderingWhileEncoding'] = renderingWhileEncoding;
    data['lastPreferredResolution'] = lastPreferredResolution;
    data['timeZoneOffset'] = timeZoneOffset;
    return data;
  }

  bool toggleRenderingWhileEncoding() {
    renderingWhileEncoding = !renderingWhileEncoding;
    save();
    notifyListeners();
    return renderingWhileEncoding;
  }

  void setLastPreferredResolution(String resolution) {
    lastPreferredResolution = resolution;
    save();
    notifyListeners();
  }

  void save() {
    String jsonString = jsonEncode(_toJson());
    File file = File(fileName);
    List<int> bytes = utf8.encode(jsonString);
    try {
      file.writeAsBytesSync(bytes);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    notifyListeners();
  }

  Future<void> load() async {
    File file = File(fileName);
    bool exists = await file.exists();
    if (!exists) {
      return;
    }
    String jsonString = file.readAsStringSync();
    final Map<String, dynamic> data = jsonDecode(jsonString);
    renderingWhileEncoding = data['renderingWhileEncoding'] as bool? ?? false;
    lastPreferredResolution = data['lastPreferredResolution'] as String? ?? '';
    timeZoneOffset = data['timeZoneOffset'] as int? ?? getTimeZoneOffsetInSeconds();
    return;
  }
}
