import 'dart:io';

import 'package:path/path.dart';

import '../generated/objectbox.g.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late final Store store;

  Future<void> init() async {
    final dir = Directory.current;
    await dir.create(recursive: true);
    var dbPath = join(dir.path, 'video_diary_database');
    store = await openStore(directory: dbPath);
  }
}
