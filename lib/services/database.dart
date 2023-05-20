import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:video_diary/services/native.dart';

import '../domain/metadata.dart';
import '../domain/result.dart';
import '../generated/objectbox.g.dart';
import '../tools/time.dart';

//(for objectbox.g) cmd : flutter pub run build_runner build
class DatabaseService with ChangeNotifier, DiagnosticableTreeMixin {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late final Store store;

  List<Metadata> pastEntries = [];
  List<Metadata> filteredPastEntries = [];
  List<Metadata> uiStatePastEntries = [];
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

  void update(int timestamp, Metadata updatedData) {
    final query = store
        .box<Metadata>()
        .query(Metadata_.timestamp.equals(timestamp))
        .build();
    final result = query.find();
    if (result.isEmpty) {
      debugPrint('No metadata found for $timestamp');
    } else {
      final metadata = result.first;
      metadata.title = updatedData.title;
      metadata.note = updatedData.note;
      metadata.tags = updatedData.tags;
      metadata.timestamp = updatedData.timestamp;
      metadata.thumbnail = updatedData.thumbnail;
      store.box<Metadata>().put(metadata);
    }
    sync();
  }

  void insert(int timestamp) {
    lastestTimestamp = timestamp;
    final metadata = Metadata(
        title: '', timestamp: timestamp, note: '', tags: '', thumbnail: '');
    store.box<Metadata>().put(metadata);
  }

  Future<List<Metadata>> getEntries() async {
    Native native = Native();
    await native.checkFileDirectoryAndSetFiles();
    List<Metadata> result = native.files
        .map((el) => findByOsFileName(el))
        .whereType<Success>()
        .map((el) => el.value)
        .toList()
        .cast<Metadata>();

    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    debugPrint('getEntries: ${result.length}');
    return result;
  }

  void resetUiStatePastEntries(bool notifiy) {
    uiStatePastEntries = pastEntries;
    if (notifiy) notifyListeners();
  }

  void filterEntriesByDate(int timestamp) async {
    DateTime targetDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    List<Metadata> result = pastEntries
        .where((el) => DateTime.fromMillisecondsSinceEpoch(el.timestamp)
            .isBefore(targetDate.add(const Duration(days: 1))))
        .toList();

    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    filteredPastEntries = result;
    uiStatePastEntries = filteredPastEntries;
    debugPrint('filterEntriesBefore: ${result.length}');
    notifyListeners();
  }



  void filterEntriesByText(String text) async {
    List<Metadata> result = [];
    result = pastEntries
        .where((el) =>
            el.title.toLowerCase().contains(text.toLowerCase()) ||
            (el.note != null &&
                el.note!.toLowerCase().contains(text.toLowerCase())))
        .toList();
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    filteredPastEntries = result;
    uiStatePastEntries = filteredPastEntries;
    debugPrint('filterEntriesByText: ${result.length}');
    notifyListeners();
  }

  void clearOutdatedRecords(List<Metadata> entries) async {
    final query = store.box<Metadata>().query().build();
    final dataInDB = query.find();
    // timestamp is an id for each record.
    final timestamp = entries.map((el) => el.timestamp).toList();
    for (var el in dataInDB) {
      // the data inserted when start, but actual file could be writing now.
      bool isTheDataJustAdded =
          DateTime.now().millisecondsSinceEpoch - el.timestamp < 3600000;

      if (!timestamp.contains(el.timestamp) && !isTheDataJustAdded) {
        store.box<Metadata>().remove(el.id);
      }
    }
  }


  Future<void> sync() async {
    pastEntries = await getEntries();
    uiStatePastEntries = pastEntries;
    clearOutdatedRecords(pastEntries);
    notifyListeners();
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
