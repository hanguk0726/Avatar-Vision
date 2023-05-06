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
  String lastPreferredResolution = '';

  Map<String, dynamic> _toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['lastPreferredResolution'] = lastPreferredResolution;
    return data;
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
    lastPreferredResolution = data['lastPreferredResolution'] as String? ?? '';
    return;
  }
}
