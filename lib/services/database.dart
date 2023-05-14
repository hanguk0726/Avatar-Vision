import 'dart:ffi';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:video_diary/services/native.dart';

import '../domain/metadata.dart';
import '../domain/result.dart';
import '../generated/objectbox.g.dart';
import '../tools/time.dart';

//(for objectbox.g) cmd : flutter pub run build_runner build
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late final Store store;

  List<Metadata> pastEntries = [];
  int lastestTimestamp = 0;

  Future<void> init() async {
    final dir = Directory.current;
    await dir.create(recursive: true);
    var dbPath = join(dir.path, 'video_diary_database');
    store = await openStore(directory: dbPath);
    sync();
  }

  Result<Metadata> findByOsFileName(String fileName) {
    int timestamp = int.parse(fileName.split('_').last);
    final query = store
        .box<Metadata>()
        .query(Metadata_.timestamp.equals(timestamp))
        .build();
    final result = query.find();
    if (result.isEmpty) {
      debugPrint('No metadata found for $fileName');
      return Error('No metadata found for $timestamp');
    } else {
      return Success(result.first);
    }
  }

  void update(String videoTitle, Metadata updatedData) {
    final query =
        store.box<Metadata>().query(Metadata_.title.equals(videoTitle)).build();
    final result = query.find();
    if (result.isEmpty) {
      debugPrint('No metadata found for $videoTitle');
    } else {
      final metadata = result.first;
      metadata.title = updatedData.title;
      metadata.note = updatedData.note;
      metadata.tags = updatedData.tags;
      metadata.thumbnail = updatedData.thumbnail;
      store.box<Metadata>().put(metadata);
    }
  }

  void insert(int timestamp) {
    lastestTimestamp = timestamp;
    String fileName =
        getFormattedTimestamp(timestamp: timestamp, format: fileNameFormat);
    final metadata = Metadata(
        title: fileName,
        timestamp: timestamp,
        note: '',
        tags: '',
        thumbnail: '');
    store.box<Metadata>().put(metadata);
  }

  List<Metadata> getEntries() {
    Native native = Native();
    native.checkFileDirectoryAndSetFiles();
    List<Metadata> result = native.files
        .map((el) => findByOsFileName(el))
        .whereType<Success>()
        .map((el) => el.value)
        .toList()
        .cast<Metadata>();
    debugPrint('getEntries: ${result.length}');
    return result;
  }

  void clearOutdatedRecords() {
    var entries = getEntries();

    final query = store.box<Metadata>().query().build();
    final dataInDB = query.find();

    for (var el in dataInDB) {
      // the data inserted when start, but actual file could be writing now.
      bool isTheDataJustAdded =
          DateTime.now().millisecondsSinceEpoch - el.timestamp < 3600000;

      if (!entries.contains(el) && !isTheDataJustAdded) {
        store.box<Metadata>().remove(el.id);
      }
    }
  }

  sync() {
    pastEntries = getEntries();
    clearOutdatedRecords();
    debugPrint('DB Synced');
  }
}

String gererateFileName(int timestamp) {
  var fileName =
      getFormattedTimestamp(timestamp: timestamp, format: fileNameFormat);
  fileName += "_${timestamp.toString()}"; // this part is used for id of db row.
  // yyyy-MM-dd_HH-mm-ss_'epochMicroseconds'
  return fileName;
}

const fileNameFormat = 'yyyy-MM-dd_HH-mm-ss';
