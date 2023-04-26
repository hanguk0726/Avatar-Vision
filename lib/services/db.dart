import 'dart:io';

import 'package:path/path.dart';

import '../domain/metadata.dart';
import '../domain/result.dart';
import '../generated/objectbox.g.dart';

//(for objectbox.g) cmd : flutter pub run build_runner build
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
    // test();
  }

  Result<Metadata> getMetadata(String videoTitle) {
    final query = store
        .box<Metadata>()
        .query(Metadata_.videoTitle.equals(videoTitle))
        .build();
    final result = query.find();
    if (result.isEmpty) {
      return Error('No metadata found for $videoTitle');
    } else {
      return Success(result.first);
    }
  }

  void updateMetadata(String videoTitle, Metadata updatedData) {
    final query = store
        .box<Metadata>()
        .query(Metadata_.videoTitle.equals(videoTitle))
        .build();
    final result = query.find();
    if (result.isEmpty) {
      print('No metadata found for $videoTitle');
    } else {
      final metadata = result.first;
      // metadata.videoTitle = updatedData.videoTitle; //  transaction with OS
      // metadata.timestamp = updatedData.timestamp;
      metadata.note = updatedData.note;
      metadata.tags = updatedData.tags;
      metadata.thumbnail = updatedData.thumbnail;
      store.box<Metadata>().put(metadata);
    }
  }

  void test() {
    String title =
        "Y2Mate.is - Big Buck Bunny 60fps 4K - Official Blender Foundation Short Film-aqz-KE-bpKQ-1080p-1656220080931";
        // add mock data
    final metadata = Metadata(
        videoTitle: title,
        timestamp: DateTime.now().toUtc().millisecondsSinceEpoch,
        note: 'This is a note',
        tags: 'tag1, tag2, tag3',
        thumbnail: 'thumbnail');
    store.box<Metadata>().put(metadata);
  }
}
